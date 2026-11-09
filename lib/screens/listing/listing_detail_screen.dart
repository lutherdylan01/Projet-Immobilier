import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/listing.dart';
import '../../services/chat_service.dart';
import '../../services/listing_service.dart';
import '../../services/supabase_client.dart';
import '../../utils/amenities.dart';
import '../../utils/format.dart';
import '../../widgets/listing_map.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/visit_request_sheet.dart';
import '../chat/chat_screen.dart';
import 'listing_form_screen.dart';

/// Fiche complète d'un logement : photos, prix, commodités, carte, contact.
class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late Future<Listing> _future;

  @override
  void initState() {
    super.initState();
    _future = ListingService().getById(widget.listingId);
  }

  void _reload() => setState(() => _future = ListingService().getById(widget.listingId));

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _openChat(Listing l) async {
    try {
      final id = await ChatService().openConversation(l.id);
      if (!mounted) return;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id)));
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  Future<void> _whatsapp(Listing l) async {
    final number = l.owner?.whatsappNumber?.replaceAll('+', '');
    if (number == null) return _snack('Numéro indisponible');
    final text = Uri.encodeComponent(
        'Bonjour, je suis intéressé(e) par votre annonce « ${l.title} » '
        '(${l.neighborhood}, ${l.city}) vue sur Logement CM.');
    final ok = await launchUrl(Uri.parse('https://wa.me/$number?text=$text'),
        mode: LaunchMode.externalApplication);
    if (!ok) _snack('WhatsApp n\'est pas disponible');
  }

  Future<void> _call(Listing l) async {
    final phone = l.owner?.phone;
    if (phone == null) return _snack('Numéro indisponible');
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Listing>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
              appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(friendlyError(snap.error!)),
                TextButton(onPressed: _reload, child: const Text('Réessayer')),
              ]),
            ),
          );
        }
        return _buildListing(snap.data!);
      },
    );
  }

  Widget _buildListing(Listing l) {
    final theme = Theme.of(context);
    final isMine = l.ownerId == supabase.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(listingTypeLabels[l.type]!),
        actions: [
          if (isMine)
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => ListingFormScreen(existing: l)));
                if (changed == true) _reload();
              },
            )
          else
            IconButton(
              tooltip: 'Signaler cette annonce',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => showReportDialog(context, l.id),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _PhotoCarousel(photos: l.photos),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${formatFcfa(l.priceMonthly)} / mois',
                    style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(l.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 4),
                  Expanded(child: Text('${l.neighborhood}, ${l.city}')),
                ]),
                const SizedBox(height: 16),
                _InfoRow('Caution', l.deposit == 0 ? 'Aucune' : formatFcfa(l.deposit)),
                _InfoRow('Avance demandée',
                    l.advanceMonths == 0 ? 'Aucune' : '${l.advanceMonths} mois'),
                if (l.bedrooms != null) _InfoRow('Chambres', '${l.bedrooms}'),
                _InfoRow('Statut', listingStatusLabels[l.status]!),
                if (l.amenities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Commodités', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: l.amenities.map((code) {
                      final a = amenityByCode(code);
                      return Chip(
                        avatar: Icon(a?.icon ?? Icons.check, size: 18),
                        label: Text(a?.label ?? code),
                      );
                    }).toList(),
                  ),
                ],
                if (l.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 16),
                  Text('Description', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(l.description!),
                ],
                if (l.hasLocation) ...[
                  const SizedBox(height: 16),
                  Text('Localisation', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ListingMap(latitude: l.latitude!, longitude: l.longitude!),
                ],
                if (!isMine) ...[
                  const SizedBox(height: 24),
                  Text('Bailleur : ${l.owner?.fullName ?? '—'}',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Conseil sécurité : visitez toujours le logement avant de payer '
                      'quoi que ce soit. Ne payez jamais de « frais de visite » à distance.',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMine || l.status != ListingStatus.disponible
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openChat(l),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Message'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => showVisitRequestSheet(context, l.id),
                          icon: const Icon(Icons.event_available_outlined),
                          label: const Text('Visite'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _whatsapp(l),
                          icon: const Icon(Icons.chat),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _call(l),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Appeler'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 150, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _PhotoCarousel extends StatefulWidget {
  final List<ListingPhoto> photos;
  const _PhotoCarousel({required this.photos});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.photos.isEmpty) {
      return Container(
        height: 220,
        color: scheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.home_outlined, size: 64)),
      );
    }
    final width = MediaQuery.of(context).size.width;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return SizedBox(
      height: 260,
      child: Stack(children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.photos[i].url,
            fit: BoxFit.cover,
            memCacheWidth: (width * dpr).round(),
            placeholder: (_, _) => Container(color: scheme.surfaceContainerHighest),
            errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.black54, borderRadius: BorderRadius.circular(12)),
            child: Text('${_current + 1}/${widget.photos.length}',
                style: const TextStyle(color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
