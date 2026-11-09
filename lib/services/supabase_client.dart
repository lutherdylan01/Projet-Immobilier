import 'package:supabase_flutter/supabase_flutter.dart';

/// Raccourci vers le client Supabase, utilisé par tous les services.
SupabaseClient get supabase => Supabase.instance.client;

/// Identifiant de l'utilisateur connecté (lève une erreur s'il n'y en a pas).
String get currentUserId {
  final user = supabase.auth.currentUser;
  if (user == null) throw StateError('Aucun utilisateur connecté');
  return user.id;
}

/// Transforme une erreur technique en message compréhensible.
String friendlyError(Object e) {
  if (e is AuthException) {
    final msg = e.message.toLowerCase();
    if (msg.contains('expired') || msg.contains('invalid')) {
      return 'Code incorrect ou expiré. Réessayez.';
    }
    if (msg.contains('rate')) return 'Trop de tentatives. Patientez quelques minutes.';
    return e.message;
  }
  if (e is PostgrestException) {
    if (e.code == '23505') return 'Vous avez déjà effectué cette action.';
    if (e.code == '42501') return 'Action non autorisée.';
    return e.message;
  }
  if (e is StorageException) return 'Échec de l\'envoi de la photo : ${e.message}';
  final text = e.toString();
  if (text.contains('SocketException') || text.contains('ClientException')) {
    return 'Pas de connexion Internet. Réessayez.';
  }
  return 'Une erreur est survenue. Réessayez.';
}
