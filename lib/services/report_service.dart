import 'supabase_client.dart';

/// Motifs de signalement (codes identiques à l'enum SQL report_reason).
const reportReasons = <String, String>{
  'arnaque': 'Arnaque / demande d\'argent suspecte',
  'deja_loue': 'Logement déjà loué',
  'fausses_photos': 'Photos qui ne correspondent pas',
  'prix_trompeur': 'Prix trompeur',
  'contenu_inapproprie': 'Contenu inapproprié',
  'autre': 'Autre',
};

class ReportService {
  Future<void> report({
    required String listingId,
    required String reason,
    String? details,
  }) =>
      supabase.from('reports').insert({
        'listing_id': listingId,
        'reporter_id': currentUserId,
        'reason': reason,
        'details': (details?.trim().isEmpty ?? true) ? null : details!.trim(),
      });
}
