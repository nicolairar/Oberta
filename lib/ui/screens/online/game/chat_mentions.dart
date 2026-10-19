/// Se un messaggio della chat chiama in causa un giocatore: il suo numero
/// di posto come parola a sé («3», «#3», «il 3», «3?», ma non «13» o «30»),
/// o il suo nome («@anna», «anna», senza badare alle maiuscole, ma non
/// dentro un'altra parola come «annalisa»).
///
/// I propri messaggi non chiamano mai in causa se stessi: [fromMe] li
/// esclude.
bool mentions(String body, {int? number, String? name, bool fromMe = false}) {
  if (fromMe) return false;
  if (number != null && number > 0) {
    if (RegExp('(?<![0-9])#?$number(?![0-9])').hasMatch(body)) return true;
  }
  final who = name?.trim();
  if (who != null && who.isNotEmpty) {
    final pattern = RegExp('(?<![\\p{L}\\p{N}_])@?${RegExp.escape(who)}(?![\\p{L}\\p{N}_])', caseSensitive: false, unicode: true);
    if (pattern.hasMatch(body)) return true;
  }
  return false;
}
