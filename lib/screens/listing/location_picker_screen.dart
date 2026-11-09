import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../widgets/listing_map.dart';

/// Le bailleur touche la carte (ou utilise sa position GPS) pour placer son logement.
/// Retourne le point choisi avec Navigator.pop.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  LatLng? _point;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  Future<void> _useMyPosition() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Activez la localisation (GPS) du téléphone.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Autorisation de localisation refusée.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() => _point = p);
      _map.move(p, 17);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is String ? e : 'Position introuvable. Touchez la carte.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Position du logement'),
        actions: [
          TextButton(
            onPressed: _point == null ? null : () => Navigator.of(context).pop(_point),
            child: const Text('Valider'),
          ),
        ],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _point ?? defaultMapCenter,
            initialZoom: _point == null ? 12 : 16,
            onTap: (_, latLng) => setState(() => _point = latLng),
          ),
          children: [
            osmTileLayer(),
            if (_point != null)
              MarkerLayer(markers: [
                Marker(
                  point: _point!,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 44),
                ),
              ]),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_point == null
                  ? 'Touchez la carte à l\'emplacement du logement.'
                  : 'Position choisie. Touchez ailleurs pour la corriger.'),
            ),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _locating ? null : _useMyPosition,
        icon: _locating
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location),
        label: const Text('Ma position'),
      ),
    );
  }
}
