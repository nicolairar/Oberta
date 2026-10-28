/// Il motore audio della voce, visto dal [VoiceController]: collegarsi a una
/// stanza, accendere il microfono, sentire o non sentire qualcuno, chi sta
/// parlando. L'implementazione vera è LiveKit (livekit_voice_engine.dart);
/// i test usano un finto.
abstract class VoiceEngine {
  /// Chiamato quando cambia qualcosa: chi c'è, chi parla, il microfono.
  void Function()? onChanged;

  /// Chiamato quando la stanza si chiude da sola (rete persa del tutto, il
  /// server che toglie il posto): il controller chiede di nuovo il permesso.
  void Function()? onLost;

  bool get connected;

  /// Gli altri nella stanza (le loro identità: un posto, mai un account).
  Set<String> get participants;

  /// Chi sta parlando adesso, anche questo dispositivo ([selfIdentity]).
  Set<String> get speaking;

  String? get selfIdentity;

  bool get microphoneOn;

  Future<void> connect(String url, String token);

  Future<void> disconnect();

  /// Accende o spegne il microfono (il sistema chiede il permesso la prima
  /// volta). Falso se non si è potuto.
  Future<bool> setMicrophone(bool on);

  /// Chi questo dispositivo non vuole sentire ([unheard]) e chi non deve
  /// sentire questo dispositivo ([deafTo]: i bloccati; il server di LiveKit
  /// non gli manda la nostra voce).
  Future<void> setPrivacy({required Set<String> unheard, required Set<String> deafTo});

  Future<void> dispose();
}
