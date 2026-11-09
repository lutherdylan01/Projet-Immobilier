/// Clés de connexion à Supabase.
///
/// Elles ne sont PAS écrites dans le code : on les passe au lancement avec
///   flutter run --dart-define-from-file=env.json
/// (voir env.example.json et le README).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Nom du bucket Supabase Storage qui contient les photos.
  static const photosBucket = 'listing-photos';

  /// Nombre maximum de photos par logement.
  static const maxPhotos = 8;

  /// Nombre d'annonces chargées à la fois (pagination : économise les données).
  static const pageSize = 20;

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
