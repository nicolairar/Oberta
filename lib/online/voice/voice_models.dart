/// La voce al tavolo: come la si vuole su questo dispositivo, e che cosa il
/// server concede adesso (Edge Function `voice-token`). Il server decide
/// tutto: chi parla, chi ascolta, in quale stanza; il telefono chiede di
/// nuovo a ogni cambio di fase e quando il server dice di riprovare.
library;

/// Come si usa la voce su questo dispositivo.
enum VoiceMode {
  /// Niente voce: non ci si collega.
  off,

  /// Si ascolta, il microfono resta spento.
  listen,

  /// Si ascolta e si parla (quando il gioco lo permette).
  mic,
}

/// Quello che il server concede adesso. [room] null: nessuna stanza (la
/// notte di chi non è della famiglia, i film, la carta); [retryIn] dice fra
/// quanto chiedere di nuovo, quando la fase sta per aprirsi.
class VoiceGrant {
  final String? room;
  final String? kind;
  final String? identity;
  final String? url;
  final String? token;
  final bool canPublish;
  final bool canSubscribe;
  final Duration? retryIn;
  final Duration? expiresIn;

  const VoiceGrant({
    this.room,
    this.kind,
    this.identity,
    this.url,
    this.token,
    this.canPublish = false,
    this.canSubscribe = false,
    this.retryIn,
    this.expiresIn,
  });

  static const none = VoiceGrant();

  bool get connects => room != null && url != null && token != null;

  factory VoiceGrant.fromJson(Map<String, Object?> json) {
    Duration? ms(Object? v) => v is num ? Duration(milliseconds: v.toInt()) : null;
    return VoiceGrant(
      room: json['room'] as String?,
      kind: json['kind'] as String?,
      identity: json['identity'] as String?,
      url: json['url'] as String?,
      token: json['token'] as String?,
      canPublish: json['canPublish'] == true,
      canSubscribe: json['canSubscribe'] == true,
      retryIn: ms(json['retryIn']),
      expiresIn: json['expiresIn'] is num ? Duration(seconds: (json['expiresIn'] as num).toInt()) : null,
    );
  }
}

/// Perché la voce non c'è.
enum VoiceRefusal {
  /// Il server non ha LiveKit, o l'ha spenta per questo tipo di stanza.
  unavailable,

  /// Non si è (più) seduti in questa stanza.
  notMember,

  /// Rete o server: si riprova da soli.
  network,
}

class VoiceRefused implements Exception {
  final VoiceRefusal reason;

  const VoiceRefused(this.reason);

  @override
  String toString() => 'VoiceRefused(${reason.name})';
}

/// Chi dà i permessi della voce (il server).
abstract class VoiceTokenSource {
  /// Il permesso per la stanza [roomId], adesso. Lancia [VoiceRefused].
  Future<VoiceGrant> grant(String roomId);
}
