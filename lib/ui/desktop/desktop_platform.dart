import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Il gioco gira come app desktop vera (macOS, Windows, Linux). L'app per
/// iPhone aperta su un Mac con Apple silicon resta iOS: lì vale il telefono.
abstract final class DesktopPlatform {
  /// Per i test e le foto: finge il desktop (o il telefono) a prescindere.
  static bool? debugOverride;

  static bool get isDesktop =>
      debugOverride ??
      (!kIsWeb &&
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux) &&
          // `flutter test` gira sul Mac ma prova l'app del telefono.
          !Platform.environment.containsKey('FLUTTER_TEST'));
}
