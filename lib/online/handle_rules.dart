import 'reserved_words.dart';

/// Che cosa non va in un nome unico. La UI ha un messaggio per ciascuno.
enum HandleProblem {
  /// Meno di [HandleRules.minLength] caratteri.
  tooShort,

  /// Più di [HandleRules.maxLength] caratteri.
  tooLong,

  /// Un carattere che non è una lettera a–z, una cifra, `.` o `_`.
  characters,

  /// Comincia con `.` o `_`.
  start,

  /// Finisce con un punto.
  endsWithDot,

  /// Due punti di fila.
  doubleDot,

  /// Più di tre segni (`.` o `_`) di fila.
  tooManySymbols,

  /// Somiglia ai nomi dei bot (`bot.alfa`...): quelli sono solo dei bot.
  botName,

  /// Offende, insulta, o finge di essere lo staff.
  notAllowed,
}

/// Le regole del nome unico, come su Instagram: lettere minuscole, cifre,
/// `_` e `.`, da 3 a 12 caratteri, unico senza badare alle maiuscole. Le
/// stesse regole le applica il database (vincoli e trigger su
/// `profiles.handle`): qui servono a rispondere subito, mentre si scrive.
class HandleRules {
  const HandleRules._();

  static const minLength = 3;
  static const maxLength = 12;

  /// I caratteri che si possono scrivere, prima di guardare il resto.
  static final allowedCharacters = RegExp(r'[a-z0-9._]');

  /// Il nome unico come lo si salva: in minuscolo, senza spazi intorno.
  static String normalize(String typed) => typed.trim().toLowerCase();

  /// Il primo problema di [handle] (già normalizzato), o null se va bene.
  static HandleProblem? check(String handle) {
    if (handle.length < minLength) return HandleProblem.tooShort;
    if (handle.length > maxLength) return HandleProblem.tooLong;
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(handle)) return HandleProblem.characters;
    if (!RegExp('^[a-z0-9]').hasMatch(handle)) return HandleProblem.start;
    if (handle.endsWith('.')) return HandleProblem.endsWithDot;
    if (handle.contains('..')) return HandleProblem.doubleDot;
    if (RegExp(r'[._]{4}').hasMatch(handle)) return HandleProblem.tooManySymbols;
    if (looksLikeBot(handle)) return HandleProblem.botName;
    if (isBlocked(handle)) return HandleProblem.notAllowed;
    return null;
  }

  static bool isValid(String handle) => check(handle) == null;

  /// I nomi dei bot sono `bot.` più una parola (`bot.alfa`): nessun umano
  /// può prendere un nome che cominci con «bot» seguito da un segno o da
  /// una cifra, né con «b0t».
  static bool looksLikeBot(String handle) => RegExp(r'^b[o0]t([._0-9]|$)').hasMatch(handle);

  /// Il nome di un bot: `bot.` e la parola dell'alfabeto NATO in minuscolo.
  /// Rispetta tutte le regole di forma, ma nessun umano lo può scegliere.
  static String botHandle(String word) => 'bot.${word.toLowerCase()}';

  /// Le forme di controllo di un nome: minuscolo, il leetspeak tradotto
  /// (0→o, 1→i o l, 3→e, 4→a, 5→s, 7→t, @→a, $→s), via tutto ciò che non è
  /// una lettera (punti, trattini bassi, le altre cifre). Una con le lettere
  /// ripetute ridotte a una ([collapsed]), una senza.
  static List<({String plain, String collapsed})> moderationForms(String handle) {
    final lower = handle.toLowerCase();
    return {
      for (final one in const ['i', 'l']) _strip(_leet(lower, one)),
    }.map((plain) => (plain: plain, collapsed: collapse(plain))).toList();
  }

  static String _leet(String text, String one) {
    const map = {'0': 'o', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', r'$': 's'};
    final out = StringBuffer();
    for (final char in text.split('')) {
      out.write(char == '1' ? one : map[char] ?? char);
    }
    return out.toString();
  }

  static String _strip(String text) => text.replaceAll(RegExp('[^a-z]'), '');

  /// Le lettere ripetute ridotte a una: «fuuuck» → «fuck».
  static String collapse(String text) => text.replaceAllMapped(RegExp(r'(.)\1+'), (match) => match[1]!);

  /// Vero se il nome contiene una parola riservata ([reservedWords]): le
  /// parole [ReservedMatch.exact] valgono solo per il nome intero (senza
  /// ridurre le doppie, così «mood» non diventa «mod»), le altre ovunque nel
  /// nome, con le doppie ridotte da tutte e due le parti.
  static bool isBlocked(String handle, {List<ReservedWord> words = reservedWords}) {
    final forms = moderationForms(handle);
    for (final entry in words) {
      for (final form in forms) {
        final hit = switch (entry.match) {
          ReservedMatch.exact => form.plain == entry.word,
          ReservedMatch.contains => form.collapsed.contains(collapse(entry.word)),
        };
        if (hit) return true;
      }
    }
    return false;
  }

  /// Le parole riservate solo come nomi (lo staff, il nome dell'app): in
  /// chat si possono scrivere. Come la colonna `in_chat` di reserved_words.
  static const chatExempt = {
    'admin', 'administrator', 'amministratore', 'moderator', 'moderatore', 'mod', 'oberta', 'omerta',
    'support', 'supporto', 'assistenza', 'staff', 'official', 'ufficiale', 'narrator', 'narratore',
  };

  /// Vero se un messaggio di chat non passa: come `_chat_blocked` sul
  /// server, le parole «ovunque» si cercano in tutto il messaggio, quelle
  /// «esatte» parola per parola.
  static bool offensive(String text, {List<ReservedWord> words = reservedWords}) {
    final chat = [for (final entry in words) if (!chatExempt.contains(entry.word)) entry];
    final whole = moderationForms(text);
    for (final entry in chat) {
      if (entry.match != ReservedMatch.contains) continue;
      if (whole.any((form) => form.collapsed.contains(collapse(entry.word)))) return true;
    }
    for (final token in text.split(RegExp(r'\s+'))) {
      final forms = moderationForms(token);
      for (final entry in chat) {
        if (entry.match == ReservedMatch.exact && forms.any((form) => form.plain == entry.word)) return true;
      }
    }
    return false;
  }
}
