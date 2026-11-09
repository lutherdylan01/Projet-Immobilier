enum UserRole { bailleur, locataire }

UserRole? parseRole(String? value) => switch (value) {
      'bailleur' => UserRole.bailleur,
      'locataire' => UserRole.locataire,
      _ => null,
    };

class Profile {
  final String id;
  final String? phone;
  final String? fullName;
  final UserRole? role;
  final String? whatsapp;

  const Profile({
    required this.id,
    this.phone,
    this.fullName,
    this.role,
    this.whatsapp,
  });

  /// Le profil est complet quand le nom et le rôle sont renseignés.
  bool get isComplete => role != null && (fullName?.trim().isNotEmpty ?? false);
  bool get isLandlord => role == UserRole.bailleur;

  /// Numéro à utiliser pour WhatsApp (celui dédié s'il existe).
  String? get whatsappNumber =>
      (whatsapp?.isNotEmpty ?? false) ? whatsapp : phone;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        phone: m['phone'] as String?,
        fullName: m['full_name'] as String?,
        role: parseRole(m['role'] as String?),
        whatsapp: m['whatsapp'] as String?,
      );
}
