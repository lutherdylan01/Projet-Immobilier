import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../config.dart';
import '../../models/listing.dart';
import '../../services/listing_service.dart';
import '../../services/supabase_client.dart';
import '../../utils/amenities.dart';
import '../../utils/format.dart';
import 'location_picker_screen.dart';

/// Ajout ou modification d'un logement par le bailleur.
/// Retourne `true` (Navigator.pop) si quelque chose a été enregistré.
class ListingFormScreen extends StatefulWidget {
  final Listing? existing;
  const ListingFormScreen({super.key, this.existing});

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final _form = GlobalKey<FormState>();
  final _service = ListingService();
  final _picker = ImagePicker();

  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _price =
      TextEditingController(text: widget.existing?.priceMonthly.toString());
  late final _deposit =
      TextEditingController(text: widget.existing?.deposit.toString() ?? '0');
  late final _advance =
      TextEditingController(text: widget.existing?.advanceMonths.toString() ?? '0');
  late final _bedrooms =
      TextEditingController(text: widget.existing?.bedrooms?.toString());
  late final _neighborhood = TextEditingController(text: widget.existing?.neighborhood);

  late ListingType _type = widget.existing?.type ?? ListingType.chambre;
  late String? _city = widget.existing?.city;
  late final Set<String> _amenities = {...?widget.existing?.amenities};
  late LatLng? _location = widget.existing?.hasLocation ?? false
      ? LatLng(widget.existing!.latitude!, widget.existing!.longitude!)
      : null;

  /// Photos déjà en ligne (modification) et nouvelles photos choisies.
  late final List<ListingPhoto> _existingPhotos = [...?widget.existing?.photos];
  final List<ListingPhoto> _removedPhotos = [];
  final List<XFile> _newPhotos = [];

  bool _saving = false;
  String _progress = '';

  bool get _isEdit => widget.existing != null;
  int get _photoCount => _existingPhotos.length + _newPhotos.length;

  @override
  void dispose() {
    for (final c in [_title, _description, _price, _deposit, _advance, _bedrooms, _neighborhood]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = AppConfig.maxPhotos - _photoCount;
    if (remaining <= 0) return;
    // Compression à la source : ~100-200 Ko par photo au lieu de 3-5 Mo.
    final files = await _picker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
      limit: remaining > 1 ? remaining : null,
    );
    setState(() => _newPhotos.addAll(files.take(remaining)));
  }

  Future<void> _takePhoto() async {
    if (_photoCount >= AppConfig.maxPhotos) return;
    final file = await _picker.pickImage(
        source: ImageSource.camera, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
    if (file != null) setState(() => _newPhotos.add(file));
  }

  Future<void> _pickLocation() async {
    final p = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: _location)));
    if (p != null) setState(() => _location = p);
  }

  int _int(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_photoCount == 0) {
      _snack('Ajoutez au moins une photo');
      return;
    }
    setState(() {
      _saving = true;
      _progress = 'Enregistrement…';
    });
    try {
      final data = Listing.toInsertMap(
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        type: _type,
        priceMonthly: _int(_price),
        deposit: _int(_deposit),
        advanceMonths: _int(_advance),
        bedrooms: _bedrooms.text.trim().isEmpty ? null : _int(_bedrooms),
        city: _city!,
        neighborhood: _neighborhood.text.trim(),
        latitude: _location?.latitude,
        longitude: _location?.longitude,
        amenities: _amenities.toList(),
      );

      final String id;
      if (_isEdit) {
        id = widget.existing!.id;
        await _service.update(id, data);
      } else {
        id = await _service.create(data);
      }

      for (final p in _removedPhotos) {
        await _service.removePhoto(p);
      }
      var position = _existingPhotos.fold<int>(
              -1, (max, p) => p.position > max ? p.position : max) +
          1;
      for (var i = 0; i < _newPhotos.length; i++) {
        setState(() => _progress = 'Envoi photo ${i + 1}/${_newPhotos.length}…');
        await _service.addPhoto(id, _newPhotos[i], position++);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  Widget _photoTile({required Widget image, required VoidCallback onRemove}) {
    return Stack(children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 90, height: 90, child: image)),
      Positioned(
        right: 0,
        top: 0,
        child: InkWell(
          onTap: onRemove,
          child: const CircleAvatar(
              radius: 12, backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 16, color: Colors.white)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Modifier le logement' : 'Nouveau logement')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- Photos ----
              Text('Photos ($_photoCount/${AppConfig.maxPhotos})',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ..._existingPhotos.map((p) => _photoTile(
                      image: CachedNetworkImage(
                          imageUrl: p.url, fit: BoxFit.cover, memCacheWidth: 270),
                      onRemove: () => setState(() {
                        _existingPhotos.remove(p);
                        _removedPhotos.add(p);
                      }),
                    )),
                ..._newPhotos.map((f) => _photoTile(
                      image: FutureBuilder(
                        future: f.readAsBytes(),
                        builder: (_, s) => s.hasData
                            ? Image.memory(s.data!, fit: BoxFit.cover, cacheWidth: 270)
                            : const ColoredBox(color: Colors.black12),
                      ),
                      onRemove: () => setState(() => _newPhotos.remove(f)),
                    )),
                if (_photoCount < AppConfig.maxPhotos) ...[
                  _AddPhotoButton(icon: Icons.photo_library_outlined, label: 'Galerie', onTap: _pickPhotos),
                  _AddPhotoButton(icon: Icons.photo_camera_outlined, label: 'Caméra', onTap: _takePhoto),
                ],
              ]),
              const SizedBox(height: 24),

              // ---- Infos principales ----
              DropdownButtonFormField<ListingType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type de logement'),
                items: ListingType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(listingTypeLabels[t]!)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(
                    labelText: 'Titre', hintText: 'Ex : Studio moderne près du carrefour'),
                validator: (v) =>
                    (v == null || v.trim().length < 5) ? 'Au moins 5 caractères' : null,
              ),
              TextFormField(
                controller: _description,
                maxLines: 4,
                maxLength: 3000,
                decoration: const InputDecoration(labelText: 'Description (facultatif)'),
              ),
              const SizedBox(height: 12),

              // ---- Prix ----
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Loyer mensuel', suffixText: 'FCFA'),
                validator: (v) => _int(_price) <= 0 ? 'Indiquez le loyer' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _deposit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Caution', suffixText: 'FCFA'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _advance,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Avance', suffixText: 'mois'),
                    validator: (_) => _int(_advance) > 24 ? 'Maximum 24' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bedrooms,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nombre de chambres (facultatif)'),
              ),
              const SizedBox(height: 24),

              // ---- Localisation ----
              Text('Localisation', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _city,
                decoration: const InputDecoration(labelText: 'Ville'),
                items: [
                  ...cameroonCities,
                  if (_city != null && !cameroonCities.contains(_city)) _city!,
                ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _city = v),
                validator: (v) => v == null ? 'Choisissez la ville' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _neighborhood,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Quartier', hintText: 'Ex : Bastos, Akwa, Ndogbong'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: Icon(_location == null ? Icons.add_location_alt_outlined : Icons.check_circle),
                label: Text(_location == null
                    ? 'Placer le logement sur la carte'
                    : 'Position enregistrée (modifier)'),
              ),
              const SizedBox(height: 24),

              // ---- Commodités ----
              Text('Commodités', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: amenities
                    .map((a) => FilterChip(
                          avatar: Icon(a.icon, size: 18),
                          label: Text(a.label),
                          selected: _amenities.contains(a.code),
                          onSelected: (s) => setState(
                              () => s ? _amenities.add(a.code) : _amenities.remove(a.code)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? Text(_progress)
                    : Text(_isEdit ? 'Enregistrer les modifications' : 'Publier le logement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AddPhotoButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    );
  }
}
