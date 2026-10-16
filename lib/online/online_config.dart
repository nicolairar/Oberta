/// Dove sta il server, deciso quando si compila l'app:
///
///     flutter run --dart-define-from-file=config/supabase.json
///
/// Senza quel file i valori sono vuoti, e l'online semplicemente non c'è:
/// il gioco su un telefono solo funziona lo stesso.
class OnlineConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// I client OAuth di Google: quello iOS per l'app, quello web per Supabase.
  /// Se manca uno dei due, il pulsante di Google non si mostra.
  final String googleIosClientId;
  final String googleWebClientId;

  const OnlineConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.googleIosClientId = '',
    this.googleWebClientId = '',
  });

  static const compiled = OnlineConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
  );

  bool get isComplete => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get hasGoogle => googleIosClientId.isNotEmpty && googleWebClientId.isNotEmpty;
}
