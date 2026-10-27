import 'handle_rules.dart';

/// I nomi unici proposti: dal nome Steam di chi entra con Steam, e i nomi
/// liberi lì vicino quando quello scelto è preso. Fuori da [HandleRules]
/// perché quelle regole entrano anche nel motore del server.
abstract final class HandleSuggestions {
  /// Il nome unico proposto a chi entra con Steam, dal suo nome Steam:
  /// minuscolo, accenti tolti, solo lettere, cifre, `.` e `_`, niente segni
  /// all'inizio né doppi, al massimo [HandleRules.maxLength]. Null se non ne esce un
  /// nome valido (troppo corto, offensivo, da bot).
  static String? fromPersona(String persona) {
    final out = StringBuffer();
    for (final char in persona.toLowerCase().runes.map(String.fromCharCode)) {
      out.write(_plainLetters[char] ?? char);
    }
    var name = out.toString().replaceAll(RegExp('[^a-z0-9._]'), '');
    name = name.replaceAll(RegExp('[._]{2,}'), '_').replaceFirst(RegExp('^[._]+'), '');
    if (name.length > HandleRules.maxLength) name = name.substring(0, HandleRules.maxLength);
    name = name.replaceFirst(RegExp(r'[._]+$'), '');
    return HandleRules.isValid(name) ? name : null;
  }

  /// Altri nomi vicini a [base] (già valido), per quando è preso: [base] con
  /// un numero in fondo, accorciato quanto serve. Solo nomi validi.
  static Iterable<String> variants(String base) sync* {
    for (var n = 1; n < 1000; n++) {
      final tail = '$n';
      var head = base.length + tail.length > HandleRules.maxLength
          ? base.substring(0, HandleRules.maxLength - tail.length)
          : base;
      head = head.replaceFirst(RegExp(r'\.+$'), '');
      final name = '$head$tail';
      if (name != base && HandleRules.isValid(name)) yield name;
    }
  }

  /// I primi [count] nomi liberi tra [variants] di [base], chiedendo a
  /// [available] (il server) al massimo [maxAsks] volte.
  static Future<List<String>> freeVariants(
    String base,
    Future<bool> Function(String handle) available, {
    int count = 3,
    int maxAsks = 12,
  }) async {
    final free = <String>[];
    var asked = 0;
    for (final name in variants(base)) {
      if (free.length >= count || asked >= maxAsks) break;
      asked++;
      if (await available(name)) free.add(name);
    }
    return free;
  }

  static const _plainLetters = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'œ': 'oe',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ß': 'ss',
    'š': 's',
    'ž': 'z',
    'ł': 'l',
    ' ': '',
    '-': '_',
  };
}
