import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'supabase_client.dart';

class AuthService {
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
  User? get currentUser => supabase.auth.currentUser;

  /// Étape 1 : envoie un code par SMS au numéro (format +2376XXXXXXXX).
  Future<void> sendOtp(String phone) =>
      supabase.auth.signInWithOtp(phone: phone);

  /// Étape 2 : vérifie le code reçu. Crée le compte s'il n'existe pas.
  Future<void> verifyOtp(String phone, String code) =>
      supabase.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);

  Future<Profile?> loadMyProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  /// Enregistre le nom, le rôle et éventuellement un numéro WhatsApp.
  Future<void> updateProfile({
    required String fullName,
    required UserRole role,
    String? whatsapp,
  }) async {
    await supabase.from('profiles').update({
      'full_name': fullName,
      'role': role.name,
      'whatsapp': (whatsapp?.isEmpty ?? true) ? null : whatsapp,
    }).eq('id', currentUserId);
  }

  Future<void> signOut() => supabase.auth.signOut();
}
