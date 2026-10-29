import 'package:flutter/foundation.dart';

/// Build di prova o build da negozio: l'unico interruttore dell'app.
///
/// Una build `--release` **senza** dart-define è quella da negozio (App
/// Store, Google Play, Steam): non ci sono la classificata aperta, la soglia
/// di due persone coi bot di prova, il menu di prova Steam. Non serve
/// ricordarsi niente: è il caso di partenza. (L'accesso con email non è
/// più una cosa di prova: c'è per tutti, senza password.)
///
/// Una build di prova lo dice con `--dart-define=OBERTA_TEST=true`:
/// `RANKED_DEBUG=1 bundle exec fastlane ios beta` (TestFlight interno) e il
/// CI desktop con `steam_test`. `RANKED_DEBUG=true`, il nome di prima, vale
/// ancora uguale, perché un comando vecchio non perda niente.
///
/// In debug e profile (`flutter run`, i test, le prove delle prestazioni) gli
/// strumenti di prova ci sono sempre, la classificata resta chiusa come nel
/// negozio. Quello che è solo `kDebugMode` (il «+ giocatore di prova» nella
/// lobby del telefono, nessun controllo dell'App Store) resta com'è: non
/// arriva mai in una build `--release`.
///
/// Le cose che il server decide da sé (bot nelle stanze, minimo della
/// classificata) si spengono con
/// `supabase/scripts/prelaunch.sql` (docs/app-store.md).
abstract final class BuildFlags {
  /// Compilata come build di prova (TestFlight interno, Steam di prova).
  static const testBuild = bool.fromEnvironment('OBERTA_TEST') || bool.fromEnvironment('RANKED_DEBUG');

  /// Gli strumenti di prova: in una build di prova, in debug e in profile.
  /// In una build da negozio è falso, e il compilatore toglie il codice.
  static const testTools = testBuild || !kReleaseMode;
}
