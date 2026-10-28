import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:url_launcher/url_launcher.dart';

/// Il permesso del microfono, chiesto al sistema subito, quando si sceglie
/// «Microfono»: mai al momento di parlare. Si chiede aprendo e chiudendo
/// subito una traccia audio (iOS, Android, macOS e Windows mostrano allora la
/// loro domanda; se la risposta c'è già, non chiedono niente). Niente viene
/// trasmesso: la traccia non entra in nessuna stanza.
abstract final class MicPermission {
  /// Vero se il microfono si può usare. I test lo sostituiscono.
  static Future<bool> Function() request = _probe;

  /// Apre le impostazioni del sistema dove si dà il microfono.
  static Future<void> Function() openSettings = _openSettings;

  /// Si può aprire una pagina delle impostazioni su questa piattaforma.
  static bool get canOpenSettings => !kIsWeb && !Platform.isLinux;

  static Future<bool> _probe() async {
    try {
      final track = await lk.LocalAudioTrack.create();
      try {
        await track.mediaStreamTrack.stop();
        await track.mediaStream.dispose();
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  static const _android = MethodChannel('oberta/system');

  static Future<void> _openSettings() async {
    try {
      if (Platform.isAndroid) {
        await _android.invokeMethod<void>('openAppSettings');
      } else if (Platform.isIOS) {
        await launchUrl(Uri.parse('app-settings:'));
      } else if (Platform.isMacOS) {
        await launchUrl(Uri.parse('x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone'));
      } else if (Platform.isWindows) {
        await launchUrl(Uri.parse('ms-settings:privacy-microphone'));
      }
    } catch (_) {}
  }
}
