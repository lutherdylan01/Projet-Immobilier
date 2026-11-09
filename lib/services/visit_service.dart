import '../models/visit_request.dart';
import 'supabase_client.dart';

class VisitService {
  Future<void> request({
    required String listingId,
    required DateTime proposedAt,
    String? message,
  }) =>
      supabase.from('visit_requests').insert({
        'listing_id': listingId,
        'tenant_id': currentUserId,
        'proposed_at': proposedAt.toUtc().toIso8601String(),
        'message': (message?.trim().isEmpty ?? true) ? null : message!.trim(),
      });

  /// Visites demandées par moi (locataire) ou sur mes logements (bailleur).
  /// Les politiques RLS filtrent automatiquement.
  Future<List<VisitRequest>> myVisits() async {
    final rows = await supabase
        .from('visit_requests')
        .select('*, listing:listings(title, owner_id), '
            'tenant:profiles!visit_requests_tenant_id_fkey(full_name, phone)')
        .order('proposed_at', ascending: true);
    return rows.map(VisitRequest.fromMap).toList();
  }

  Future<void> setStatus(String id, VisitStatus status) => supabase
      .from('visit_requests')
      .update({'status': status.db}).eq('id', id);
}
