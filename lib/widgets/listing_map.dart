import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Adresse des tuiles OpenStreetMap (gratuites, sans clé ni carte bancaire).
/// Respectez la politique d'usage : https://operations.osmfoundation.org/policies/tiles/
const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const osmUserAgent = 'cm.logement.logement_cm';

/// Centre par défaut : Yaoundé.
const defaultMapCenter = LatLng(3.8480, 11.5021);

TileLayer osmTileLayer() => TileLayer(
      urlTemplate: osmTileUrl,
      userAgentPackageName: osmUserAgent,
      // Garde les tuiles en mémoire pour éviter de les retélécharger.
      keepBuffer: 1,
    );

/// Petite carte non interactive montrant la position d'un logement.
class ListingMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  const ListingMap({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            osmTileLayer(),
            MarkerLayer(markers: [
              Marker(
                point: point,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ]),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
      ),
    );
  }
}
