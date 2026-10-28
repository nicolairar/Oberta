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

  /// Si sta trasmettendo: la traccia c'è e non è in muto.
  bool get microphoneOn;

  /// La traccia del microfono è pubblicata (in muto o no): premere parla
  /// subito.
  bool get microphoneReady;

  /// LiveKit lascia pubblicare adesso: il server può togliere la parola a
  /// stanza aperta (un morto, il voto) prima che il telefono chieda di nuovo.
  bool get publishAllowed => true;

  /// Quanto forte arriva la propria voce adesso, da 0 a 1.
  double get level => 0;

  Future<void> connect(String url, String token);

  Future<void> disconnect();

  /// Prepara il microfono: la traccia si pubblica già in muto (non passa
  /// niente, nemmeno il primo pacchetto). Falso se non si è potuto.
  Future<bool> prepareMicrophone();

  /// Toglie la traccia e spegne la cattura (il telefono smette di ascoltare).
  Future<void> releaseMicrophone();

  /// Trasmette ([on]) o mette in muto. Se la traccia non c'è ancora la
  /// prepara prima. Falso se non si è potuto.
  Future<bool> setMicrophone(bool on);

  /// Chi questo dispositivo non vuole sentire ([unheard]) e chi non deve
  /// sentire questo dispositivo ([deafTo]: i bloccati; il server di LiveKit
  /// non gli manda la nostra voce).
  Future<void> setPrivacy({required Set<String> unheard, required Set<String> deafTo});

  Future<void> dispose();
}
