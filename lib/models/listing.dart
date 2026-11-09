import '../config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ListingType { chambre, studio, appartement, maison, duplex }

enum ListingStatus { disponible, loue, retire, suspendu }

const listingTypeLabels = {
  ListingType.chambre: 'Chambre',
  ListingType.studio: 'Studio',
  ListingType.appartement: 'Appartement',
  ListingType.maison: 'Maison',
  ListingType.duplex: 'Duplex',
};

const listingStatusLabels = {
  ListingStatus.disponible: 'Disponible',
  ListingStatus.loue: 'Loué',
  ListingStatus.retire: 'Retiré',
  ListingStatus.suspendu: 'Suspendu (signalements)',
};

class ListingPhoto {
  final String id;
  final String storagePath;
  final int position;

  const ListingPhoto({required this.id, required this.storagePath, required this.position});

  /// Adresse publique de la photo dans Supabase Storage.
  String get url => Supabase.instance.client.storage
      .from(AppConfig.photosBucket)
      .getPublicUrl(storagePath);

  factory ListingPhoto.fromMap(Map<String, dynamic> m) => ListingPhoto(
        id: m['id'] as String,
        storagePath: m['storage_path'] as String,
        position: (m['position'] as num?)?.toInt() ?? 0,
      );
}

/// Coordonnées du bailleur, chargées avec la fiche détaillée.
class ListingOwner {
  final String? fullName;
  final String? phone;
  final String? whatsapp;
  const ListingOwner({this.fullName, this.phone, this.whatsapp});

  String? get whatsappNumber => (whatsapp?.isNotEmpty ?? false) ? whatsapp : phone;
}

class Listing {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final ListingType type;
  final int priceMonthly;
  final int deposit;
  final int advanceMonths;
  final int? bedrooms;
  final String city;
  final String neighborhood;
  final double? latitude;
  final double? longitude;
  final List<String> amenities;
  final ListingStatus status;
  final DateTime createdAt;
  final List<ListingPhoto> photos;
  final ListingOwner? owner;

  const Listing({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.type,
    required this.priceMonthly,
    required this.deposit,
    required this.advanceMonths,
    this.bedrooms,
    required this.city,
    required this.neighborhood,
    this.latitude,
    this.longitude,
    required this.amenities,
    required this.status,
    required this.createdAt,
    this.photos = const [],
    this.owner,
  });

  bool get hasLocation => latitude != null && longitude != null;
  String? get coverUrl => photos.isEmpty ? null : photos.first.url;

  factory Listing.fromMap(Map<String, dynamic> m) {
    final photos = ((m['listing_photos'] as List?) ?? [])
        .map((p) => ListingPhoto.fromMap(p as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final owner = m['owner'] as Map<String, dynamic>?;
    return Listing(
      id: m['id'] as String,
      ownerId: m['owner_id'] as String,
      title: m['title'] as String,
      description: m['description'] as String?,
      type: ListingType.values.byName(m['type'] as String),
      priceMonthly: (m['price_monthly'] as num).toInt(),
      deposit: (m['deposit'] as num?)?.toInt() ?? 0,
      advanceMonths: (m['advance_months'] as num?)?.toInt() ?? 0,
      bedrooms: (m['bedrooms'] as num?)?.toInt(),
      city: m['city'] as String,
      neighborhood: m['neighborhood'] as String,
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      amenities: List<String>.from((m['amenities'] as List?) ?? const []),
      status: ListingStatus.values.byName(m['status'] as String),
      createdAt: DateTime.parse(m['created_at'] as String),
      photos: photos,
      owner: owner == null
          ? null
          : ListingOwner(
              fullName: owner['full_name'] as String?,
              phone: owner['phone'] as String?,
              whatsapp: owner['whatsapp'] as String?,
            ),
    );
  }

  /// Données envoyées à Supabase lors d'une création ou modification.
  static Map<String, dynamic> toInsertMap({
    required String title,
    String? description,
    required ListingType type,
    required int priceMonthly,
    required int deposit,
    required int advanceMonths,
    int? bedrooms,
    required String city,
    required String neighborhood,
    double? latitude,
    double? longitude,
    required List<String> amenities,
  }) =>
      {
        'title': title,
        'description': description,
        'type': type.name,
        'price_monthly': priceMonthly,
        'deposit': deposit,
        'advance_months': advanceMonths,
        'bedrooms': bedrooms,
        'city': city,
        'neighborhood': neighborhood,
        'latitude': latitude,
        'longitude': longitude,
        'amenities': amenities,
      };
}
