/// Il codice per entrare in una stanza online: sei caratteri da un alfabeto
/// senza lettere che si confondono (niente 0/O, 1/I/L). Lo stesso alfabeto
/// lo usa il server quando apre la stanza.
abstract final class JoinCode {
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 6;

  /// Che cosa c'è nel QR della stanza.
  static const _qrPrefix = 'oberta://room/';

  static String qrPayload(String code) => '$_qrPrefix$code';

  /// Il codice scritto da qualcuno, ripulito: maiuscole, niente spazi o
  /// trattini. Null se non è un codice valido.
  static String? normalize(String typed) {
    final code = typed.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (code.length != length) return null;
    for (final char in code.split('')) {
      if (!alphabet.contains(char)) return null;
    }
    return code;
  }

  /// Il codice letto da un QR: quello della stanza, o un codice nudo.
  static String? fromScan(String raw) {
    final text = raw.trim();
    if (text.toLowerCase().startsWith(_qrPrefix)) return normalize(text.substring(_qrPrefix.length));
    return normalize(text);
  }
}
