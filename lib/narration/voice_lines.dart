import 'dart:convert';

import '../rules/role.dart';
import 'narration_pack.dart';

/// Un pezzo di battuta, per la voce del narratore automatico.
///
/// Una battuta si legge a pezzi: i pezzi fissi del copione hanno la loro
/// registrazione, i nomi dei giocatori no (la voce tace e sullo schermo il
/// nome si accende). [display] è quello che si vede, e messi in fila i pezzi
/// ridanno il testo della battuta; [say] è il testo inciso, `null` per i
/// nomi e per i pezzi fatti solo di punteggiatura.
class VoicePart {
  final String display;
  final String? say;

  /// Vero per il nome di un giocatore: sullo schermo si accende, la voce tace.
  final bool isName;

  const VoicePart._(this.display, this.say, this.isName);

  /// Un pezzo da dire, inciso come [say] (di solito quello che si vede). Se
  /// è solo punteggiatura non c'è niente da incidere.
  factory VoicePart.spoken(String display, {String? say}) {
    final text = normalizeVoiceText(say ?? display);
    return VoicePart._(display, isSpeakable(text) ? text : null, false);
  }

  /// Il nome di un giocatore: la voce lo lascia al tavolo.
  const VoicePart.name(this.display)
      : say = null,
        isName = true;
}

/// Il testo inciso come chiave: spazi in fila ridotti a uno, niente spazi ai bordi.
String normalizeVoiceText(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// C'è qualcosa da dire: almeno una lettera o una cifra.
bool isSpeakable(String text) => RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text);

/// La chiave stabile di una registrazione: FNV-1a a 64 bit di lingua e testo,
/// dei byte UTF-8, in esadecimale. Cambia il testo, cambia la chiave: la
/// vecchia clip resta orfana e il generatore incide la nuova.
String voiceKey(String language, String text) {
  // Gli interi di Dart sul telefono sono a 64 bit e la moltiplicazione
  // gira in tondo: è proprio il conto di FNV.
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode('$language|${normalizeVoiceText(text)}')) {
    hash = (hash ^ byte) * 0x100000001b3;
  }
  return (hash >>> 32).toRadixString(16).padLeft(8, '0') + (hash & 0xffffffff).toRadixString(16).padLeft(8, '0');
}

/// I segnaposto che spezzano una battuta: lì dentro va qualcosa che cambia
/// da una partita all'altra. `{city}` no: le città sono poche, e ogni frase
/// si incide già con la sua.
const dynamicPlaceholders = ['{name}', '{role}', '{minutes}'];

final _dynamic = RegExp(r'\{(name|role|minutes)\}');

/// Divide un testo (con la città già messa) nei pezzi fissi e nei segnaposto
/// che restano. I segnaposto escono come `{name}`, `{role}`, `{minutes}`.
List<String> splitTemplate(String text) {
  final out = <String>[];
  var at = 0;
  for (final match in _dynamic.allMatches(text)) {
    if (match.start > at) out.add(text.substring(at, match.start));
    out.add(match.group(0)!);
    at = match.end;
  }
  if (at < text.length) out.add(text.substring(at));
  return out;
}

/// Un testo incidibile, con l'indicazione di cosa sia.
class VoiceSegment {
  final String kind;
  final String text;

  const VoiceSegment(this.kind, this.text);
}

/// Il numero più alto che la voce sa dire per la durata della discussione.
const maxSpokenMinutes = 20;

/// Tutto quello che la voce del narratore può dover dire in una lingua: i
/// pezzi fissi di ogni battuta, per ogni città, i nomi dei ruoli, i numeri
/// dei minuti, i titoli delle città. È l'elenco da cui il generatore incide
/// le clip (vedi `tool/voice/`).
///
/// Chi aggiunge un campo al [NarrationPack] che il narratore legge deve
/// aggiungerlo qui: il test del copione se ne accorge se manca.
List<VoiceSegment> voiceSegments(NarrationPack pack) {
  final seen = <String>{};
  final out = <VoiceSegment>[];
  void add(String kind, String text) {
    final say = normalizeVoiceText(text);
    if (!isSpeakable(say) || !seen.add(say)) return;
    out.add(VoiceSegment(kind, say));
  }

  void template(String text, Iterable<CitySetting> cities) {
    final filled = text.contains('{city}') ? [for (final city in cities) text.replaceAll('{city}', city.name)] : [text];
    for (final line in filled) {
      for (final piece in splitTemplate(line)) {
        if (!dynamicPlaceholders.contains(piece)) add('segment', piece);
      }
    }
  }

  for (final city in pack.cities) {
    for (final text in [...city.openings, for (final scene in city.scenes) scene.text]) {
      template(text, [city]);
    }
  }
  for (final text in spokenTemplates(pack)) {
    template(text, pack.cities);
  }
  add('segment', pack.someone);
  // Il narratore parla solo nel gioco su un telefono: i ruoli che esistono
  // solo online (il Compare) non hanno bisogno della voce.
  for (final entry in pack.roles.entries) {
    if (entry.key.playableIn(PlayMode.sharedPhone)) add('role', entry.value.label);
  }
  for (var n = 1; n <= maxSpokenMinutes; n++) {
    add('number', '$n');
  }
  for (final city in pack.cities) {
    add('title', city.title);
  }
  return out;
}

/// I testi del pacchetto che il narratore legge e che valgono in ogni città.
List<String> spokenTemplates(NarrationPack pack) => [
      pack.howToPlay,
      ...pack.firstNights,
      ...pack.nights,
      pack.nightInstruction,
      pack.nobodyDied,
      ...pack.quietDawns,
      ...pack.secondVictims,
      pack.victimFact,
      ...pack.sniperShots.allLines,
      ...pack.rescues.allLines,
      pack.savedFact,
      ...pack.shrugs.allLines,
      pack.shruggedFact,
      for (final method in pack.methods) method.text,
      for (final epilogue in pack.epilogues) epilogue.text,
      ...pack.scoops,
      pack.scoopMafia,
      pack.scoopClean,
      ...pack.silences,
      pack.silencedFact,
      pack.dayInstruction,
      pack.oneMinute,
      pack.manyMinutes,
      ...pack.voteCalls,
      pack.voteInstruction,
      ...pack.lynchScenes,
      pack.cardTurns,
      pack.wasMafia,
      pack.wasCitizen,
      pack.wasNeutral,
      ...pack.lynchedInnocent,
      ...pack.lynchedMafioso,
      ...pack.lynchedLastMafioso,
      ...pack.noLynch,
      pack.noLynchFact,
      ...pack.truces,
      pack.truceFact,
      ...pack.heartbreaks,
      pack.heartbreakFact,
      pack.loversWinFact,
      ...pack.citizensWin,
      pack.citizensWinFact,
      ...pack.mafiaWins,
      pack.mafiaWinsFact,
      ...pack.fires,
      pack.burnedFact,
      ...pack.resurrections,
      pack.resurrectedFact,
      ...pack.foolWins,
      pack.foolWinsFact,
      ...pack.arsonistWins,
      pack.arsonistWinsFact,
      ...pack.bountyWins,
      pack.bountyWinsFact,
      pack.loanSharkWinsFact,
      ...pack.assassinWins,
      pack.assassinWinsFact,
    ];
