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

  /// Il client OAuth Android (pacchetto + SHA-1 delle chiavi di firma). Il
  /// codice non lo usa: Android chiede il token per il client web. C'è solo
  /// quando il proprietario l'ha creato (docs/release.md), e accende il
  /// pulsante di Google su Android: senza, Google risponderebbe con un errore.
  final String googleAndroidClientId;

  const OnlineConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.googleIosClientId = '',
    this.googleWebClientId = '',
    this.googleAndroidClientId = '',
  });

  static const compiled = OnlineConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    googleAndroidClientId: String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID'),
  );

  bool get isComplete => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get hasGoogle => googleIosClientId.isNotEmpty && googleWebClientId.isNotEmpty;

  bool get hasGoogleAndroid => googleAndroidClientId.isNotEmpty && googleWebClientId.isNotEmpty;
}
