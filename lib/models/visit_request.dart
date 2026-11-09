/// Statut d'une demande de visite. `db` = valeur stockée dans Supabase.
enum VisitStatus {
  pending('en_attente', 'En attente'),
  accepted('acceptee', 'Acceptée'),
  refused('refusee', 'Refusée'),
  cancelled('annulee', 'Annulée');

  const VisitStatus(this.db, this.label);
  final String db;
  final String label;

  static VisitStatus fromDb(String value) =>
      values.firstWhere((s) => s.db == value, orElse: () => pending);
}

class VisitRequest {
  final String id;
  final String listingId;
  final String tenantId;
  final DateTime proposedAt;
  final String? message;
  final VisitStatus status;
  final String? listingTitle;
  final String? listingOwnerId;
  final String? tenantName;
  final String? tenantPhone;

  const VisitRequest({
    required this.id,
    required this.listingId,
    required this.tenantId,
    required this.proposedAt,
    this.message,
    required this.status,
    this.listingTitle,
    this.listingOwnerId,
    this.tenantName,
    this.tenantPhone,
  });

  factory VisitRequest.fromMap(Map<String, dynamic> m) {
    final listing = m['listing'] as Map?;
    final tenant = m['tenant'] as Map?;
    return VisitRequest(
      id: m['id'] as String,
      listingId: m['listing_id'] as String,
      tenantId: m['tenant_id'] as String,
      proposedAt: DateTime.parse(m['proposed_at'] as String),
      message: m['message'] as String?,
      status: VisitStatus.fromDb(m['status'] as String),
      listingTitle: listing?['title'] as String?,
      listingOwnerId: listing?['owner_id'] as String?,
      tenantName: tenant?['full_name'] as String?,
      tenantPhone: tenant?['phone'] as String?,
    );
  }
}
