/// Come si confronta una parola riservata con un nome unico ridotto alla
/// sua forma di controllo (vedi `HandleRules.moderationForms`).
enum ReservedMatch {
  /// Basta che compaia dentro il nome: parole lunghe e inequivocabili.
  contains,

  /// Solo se il nome è proprio quella parola: parole corte che compaiono
  /// dentro nomi innocenti («pedone», «nazionale», «negroni»...).
  exact,
}

typedef ReservedWord = ({String word, String lang, ReservedMatch match});

/// Le parole che un nome unico non può contenere: offese, odio, razzismo,
/// omofobia, sesso, bullismo, nazismo, e i nomi che fingono di essere lo
/// staff. È la copia per l'app (per dire subito «nome non consentito");
/// l'originale che decide sta nel database, nella tabella `reserved_words`
/// della migrazione `20261017140000_instagram_handles.sql`. Le due liste
/// devono restare uguali: un test lo controlla.
///
/// Le parole si scrivono semplici, in minuscolo e senza segni: il controllo
/// le riduce come riduce i nomi (lettere doppie comprese).
const List<ReservedWord> reservedWords = [
  // Lo staff e il gioco.
  (word: 'admin', lang: 'any', match: ReservedMatch.exact),
  (word: 'administrator', lang: 'en', match: ReservedMatch.contains),
  (word: 'amministratore', lang: 'it', match: ReservedMatch.contains),
  (word: 'moderator', lang: 'en', match: ReservedMatch.contains),
  (word: 'moderatore', lang: 'it', match: ReservedMatch.contains),
  (word: 'mod', lang: 'any', match: ReservedMatch.exact),
  (word: 'oberta', lang: 'any', match: ReservedMatch.exact),
  (word: 'omerta', lang: 'any', match: ReservedMatch.exact),
  (word: 'support', lang: 'en', match: ReservedMatch.contains),
  (word: 'supporto', lang: 'it', match: ReservedMatch.contains),
  (word: 'assistenza', lang: 'it', match: ReservedMatch.contains),
  (word: 'staff', lang: 'any', match: ReservedMatch.contains),
  (word: 'official', lang: 'en', match: ReservedMatch.contains),
  (word: 'ufficiale', lang: 'it', match: ReservedMatch.contains),
  (word: 'narrator', lang: 'en', match: ReservedMatch.contains),
  (word: 'narratore', lang: 'it', match: ReservedMatch.contains),
  (word: 'system', lang: 'en', match: ReservedMatch.exact),
  (word: 'sistema', lang: 'it', match: ReservedMatch.exact),
  (word: 'root', lang: 'any', match: ReservedMatch.exact),
  (word: 'bot', lang: 'any', match: ReservedMatch.exact),
  (word: 'anthropic', lang: 'any', match: ReservedMatch.contains),

  // Odio e nazismo.
  (word: 'hitler', lang: 'any', match: ReservedMatch.contains),
  (word: 'nazi', lang: 'any', match: ReservedMatch.exact),
  (word: 'neonazi', lang: 'any', match: ReservedMatch.contains),
  (word: 'naziskin', lang: 'any', match: ReservedMatch.contains),
  (word: 'heil', lang: 'any', match: ReservedMatch.exact),
  (word: 'siegheil', lang: 'any', match: ReservedMatch.contains),
  (word: 'heilhitler', lang: 'any', match: ReservedMatch.contains),
  (word: 'gestapo', lang: 'any', match: ReservedMatch.contains),
  (word: 'auschwitz', lang: 'any', match: ReservedMatch.contains),
  (word: 'holocaust', lang: 'en', match: ReservedMatch.contains),
  (word: 'olocausto', lang: 'it', match: ReservedMatch.contains),
  (word: 'whitepower', lang: 'en', match: ReservedMatch.contains),
  (word: 'kkk', lang: 'any', match: ReservedMatch.exact),
  (word: 'kukluxklan', lang: 'any', match: ReservedMatch.contains),
  (word: 'mussolini', lang: 'it', match: ReservedMatch.contains),
  (word: 'duce', lang: 'it', match: ReservedMatch.exact),
  (word: 'fascio', lang: 'it', match: ReservedMatch.exact),
  (word: 'fascista', lang: 'it', match: ReservedMatch.contains),

  // Razzismo.
  (word: 'nigger', lang: 'en', match: ReservedMatch.contains),
  (word: 'nigga', lang: 'en', match: ReservedMatch.contains),
  (word: 'negro', lang: 'any', match: ReservedMatch.exact),
  (word: 'negri', lang: 'it', match: ReservedMatch.exact),
  (word: 'negra', lang: 'it', match: ReservedMatch.exact),
  (word: 'kike', lang: 'en', match: ReservedMatch.exact),
  (word: 'chink', lang: 'en', match: ReservedMatch.contains),
  (word: 'spic', lang: 'en', match: ReservedMatch.exact),
  (word: 'wetback', lang: 'en', match: ReservedMatch.contains),
  (word: 'coon', lang: 'en', match: ReservedMatch.exact),
  (word: 'paki', lang: 'en', match: ReservedMatch.exact),
  (word: 'zingaro', lang: 'it', match: ReservedMatch.contains),
  (word: 'zingari', lang: 'it', match: ReservedMatch.contains),
  (word: 'terrone', lang: 'it', match: ReservedMatch.contains),
  (word: 'terroni', lang: 'it', match: ReservedMatch.contains),
  (word: 'polentone', lang: 'it', match: ReservedMatch.contains),
  (word: 'muslimdog', lang: 'en', match: ReservedMatch.contains),

  // Omofobia e transfobia.
  (word: 'faggot', lang: 'en', match: ReservedMatch.contains),
  (word: 'fag', lang: 'en', match: ReservedMatch.exact),
  (word: 'dyke', lang: 'en', match: ReservedMatch.exact),
  (word: 'tranny', lang: 'en', match: ReservedMatch.contains),
  (word: 'frocio', lang: 'it', match: ReservedMatch.contains),
  (word: 'froci', lang: 'it', match: ReservedMatch.contains),
  (word: 'frocia', lang: 'it', match: ReservedMatch.contains),
  (word: 'ricchione', lang: 'it', match: ReservedMatch.contains),
  (word: 'recchione', lang: 'it', match: ReservedMatch.contains),
  (word: 'culattone', lang: 'it', match: ReservedMatch.contains),
  (word: 'finocchio', lang: 'it', match: ReservedMatch.exact),
  (word: 'checca', lang: 'it', match: ReservedMatch.exact),

  // Disabilità.
  (word: 'retard', lang: 'en', match: ReservedMatch.contains),
  (word: 'ritardato', lang: 'it', match: ReservedMatch.contains),
  (word: 'mongoloide', lang: 'it', match: ReservedMatch.contains),
  (word: 'handicappato', lang: 'it', match: ReservedMatch.contains),
  (word: 'spastic', lang: 'en', match: ReservedMatch.contains),

  // Violenza e bullismo.
  (word: 'killyourself', lang: 'en', match: ReservedMatch.contains),
  (word: 'kys', lang: 'en', match: ReservedMatch.exact),
  (word: 'killthe', lang: 'en', match: ReservedMatch.contains),
  (word: 'killall', lang: 'en', match: ReservedMatch.contains),
  (word: 'killjews', lang: 'en', match: ReservedMatch.contains),
  (word: 'killgays', lang: 'en', match: ReservedMatch.contains),
  (word: 'killblacks', lang: 'en', match: ReservedMatch.contains),
  (word: 'killmuslims', lang: 'en', match: ReservedMatch.contains),
  (word: 'killwomen', lang: 'en', match: ReservedMatch.contains),
  (word: 'deathto', lang: 'en', match: ReservedMatch.contains),
  (word: 'uccidi', lang: 'it', match: ReservedMatch.contains),
  (word: 'ucciditi', lang: 'it', match: ReservedMatch.contains),
  (word: 'ammazza', lang: 'it', match: ReservedMatch.contains),
  (word: 'suicidati', lang: 'it', match: ReservedMatch.contains),
  (word: 'morteai', lang: 'it', match: ReservedMatch.contains),
  (word: 'morteagli', lang: 'it', match: ReservedMatch.contains),
  (word: 'rapist', lang: 'en', match: ReservedMatch.exact),
  (word: 'rape', lang: 'en', match: ReservedMatch.exact),
  (word: 'stupro', lang: 'it', match: ReservedMatch.contains),
  (word: 'stupratore', lang: 'it', match: ReservedMatch.contains),
  (word: 'pedophile', lang: 'en', match: ReservedMatch.contains),
  (word: 'paedophile', lang: 'en', match: ReservedMatch.contains),
  (word: 'pedo', lang: 'any', match: ReservedMatch.exact),
  (word: 'pedofilo', lang: 'it', match: ReservedMatch.contains),
  (word: 'molester', lang: 'en', match: ReservedMatch.contains),
  (word: 'ciccione', lang: 'it', match: ReservedMatch.contains),
  (word: 'fatass', lang: 'en', match: ReservedMatch.contains),

  // Volgarità e sesso.
  (word: 'fuck', lang: 'en', match: ReservedMatch.contains),
  (word: 'shit', lang: 'en', match: ReservedMatch.contains),
  (word: 'bitch', lang: 'en', match: ReservedMatch.contains),
  (word: 'cunt', lang: 'en', match: ReservedMatch.contains),
  (word: 'whore', lang: 'en', match: ReservedMatch.contains),
  (word: 'slut', lang: 'en', match: ReservedMatch.contains),
  (word: 'asshole', lang: 'en', match: ReservedMatch.contains),
  (word: 'bastard', lang: 'en', match: ReservedMatch.contains),
  (word: 'motherfucker', lang: 'en', match: ReservedMatch.contains),
  (word: 'dick', lang: 'en', match: ReservedMatch.exact),
  (word: 'cock', lang: 'en', match: ReservedMatch.exact),
  (word: 'pussy', lang: 'en', match: ReservedMatch.contains),
  (word: 'penis', lang: 'en', match: ReservedMatch.exact),
  (word: 'vagina', lang: 'any', match: ReservedMatch.contains),
  (word: 'porn', lang: 'any', match: ReservedMatch.contains),
  (word: 'hentai', lang: 'any', match: ReservedMatch.contains),
  (word: 'milf', lang: 'any', match: ReservedMatch.contains),
  (word: 'dildo', lang: 'any', match: ReservedMatch.contains),
  (word: 'blowjob', lang: 'en', match: ReservedMatch.contains),
  (word: 'sex', lang: 'any', match: ReservedMatch.exact),
  (word: 'cazzo', lang: 'it', match: ReservedMatch.contains),
  (word: 'minchia', lang: 'it', match: ReservedMatch.contains),
  (word: 'coglione', lang: 'it', match: ReservedMatch.contains),
  (word: 'stronzo', lang: 'it', match: ReservedMatch.contains),
  (word: 'stronza', lang: 'it', match: ReservedMatch.contains),
  (word: 'puttana', lang: 'it', match: ReservedMatch.contains),
  (word: 'troia', lang: 'it', match: ReservedMatch.exact),
  (word: 'zoccola', lang: 'it', match: ReservedMatch.contains),
  (word: 'mignotta', lang: 'it', match: ReservedMatch.contains),
  (word: 'vaffanculo', lang: 'it', match: ReservedMatch.contains),
  (word: 'fanculo', lang: 'it', match: ReservedMatch.contains),
  (word: 'merda', lang: 'it', match: ReservedMatch.contains),
  (word: 'pompino', lang: 'it', match: ReservedMatch.contains),
  (word: 'figa', lang: 'it', match: ReservedMatch.exact),
  (word: 'fica', lang: 'it', match: ReservedMatch.exact),
  (word: 'pene', lang: 'it', match: ReservedMatch.exact),
  (word: 'tette', lang: 'it', match: ReservedMatch.exact),
  (word: 'scopare', lang: 'it', match: ReservedMatch.contains),

  // Bestemmie.
  (word: 'porcodio', lang: 'it', match: ReservedMatch.contains),
  (word: 'diocane', lang: 'it', match: ReservedMatch.contains),
  (word: 'dioporco', lang: 'it', match: ReservedMatch.contains),
  (word: 'porcamadonna', lang: 'it', match: ReservedMatch.contains),
  (word: 'madonnaputtana', lang: 'it', match: ReservedMatch.contains),
];
