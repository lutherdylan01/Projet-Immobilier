import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/listing.dart';
import 'supabase_client.dart';

/// Critères de recherche d'un locataire.
class ListingFilter {
  final String? city;
  final String? neighborhood;
  final int? maxPrice;
  final ListingType? type;

  const ListingFilter({this.city, this.neighborhood, this.maxPrice, this.type});
}

class ListingService {
  /// Colonnes chargées pour la liste : uniquement la 1re photo (économise les données).
  static const _listColumns = '*, listing_photos(id, storage_path, position)';

  /// Recherche paginée parmi les annonces disponibles.
  Future<List<Listing>> search(ListingFilter f, {int page = 0}) async {
    var query = supabase
        .from('listings')
        .select(_listColumns)
        .eq('status', 'disponible');

    if (f.city != null && f.city!.isNotEmpty) {
      query = query.eq('city', f.city!);
    }
    if (f.neighborhood != null && f.neighborhood!.trim().isNotEmpty) {
      query = query.ilike('neighborhood', '%${f.neighborhood!.trim()}%');
    }
    if (f.maxPrice != null) {
      query = query.lte('price_monthly', f.maxPrice!);
    }
    if (f.type != null) {
      query = query.eq('type', f.type!.name);
    }

    final from = page * AppConfig.pageSize;
    final rows = await query
        .order('created_at', ascending: false)
        .order('position', referencedTable: 'listing_photos')
        .limit(1, referencedTable: 'listing_photos')
        .range(from, from + AppConfig.pageSize - 1);
    return rows.map(Listing.fromMap).toList();
  }

  /// Fiche complète : toutes les photos + coordonnées du bailleur.
  Future<Listing> getById(String id) async {
    final row = await supabase
        .from('listings')
        .select('*, listing_photos(id, storage_path, position), '
            'owner:profiles!listings_owner_id_fkey(full_name, phone, whatsapp)')
        .eq('id', id)
        .single();
    return Listing.fromMap(row);
  }

  /// Annonces du bailleur connecté (tous statuts).
  Future<List<Listing>> myListings() async {
    final rows = await supabase
        .from('listings')
        .select(_listColumns)
        .eq('owner_id', currentUserId)
        .order('created_at', ascending: false)
        .order('position', referencedTable: 'listing_photos')
        .limit(1, referencedTable: 'listing_photos');
    return rows.map(Listing.fromMap).toList();
  }

  /// Crée une annonce et retourne son identifiant.
  Future<String> create(Map<String, dynamic> data) async {
    final row = await supabase
        .from('listings')
        .insert({...data, 'owner_id': currentUserId})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> update(String id, Map<String, dynamic> data) =>
      supabase.from('listings').update(data).eq('id', id);

  Future<void> setStatus(String id, ListingStatus status) =>
      supabase.from('listings').update({'status': status.name}).eq('id', id);

  /// Supprime définitivement l'annonce et ses photos.
  Future<void> delete(Listing listing) async {
    final full = await getById(listing.id);
    if (full.photos.isNotEmpty) {
      await supabase.storage
          .from(AppConfig.photosBucket)
          .remove(full.photos.map((p) => p.storagePath).toList());
    }
    await supabase.from('listings').delete().eq('id', listing.id);
  }

  /// Envoie une photo (déjà compressée par image_picker) et l'associe à l'annonce.
  Future<void> addPhoto(String listingId, XFile file, int position) async {
    final bytes = await file.readAsBytes();
    final path =
        '$currentUserId/$listingId/${DateTime.now().millisecondsSinceEpoch}_$position.jpg';
    await supabase.storage.from(AppConfig.photosBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );
    await supabase.from('listing_photos').insert({
      'listing_id': listingId,
      'storage_path': path,
      'position': position,
    });
  }

  Future<void> removePhoto(ListingPhoto photo) async {
    await supabase.storage.from(AppConfig.photosBucket).remove([photo.storagePath]);
    await supabase.from('listing_photos').delete().eq('id', photo.id);
  }
}
