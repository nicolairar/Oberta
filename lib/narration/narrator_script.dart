import 'dart:math';

import '../rules/game_engine.dart';
import '../rules/role.dart';
import 'death_story.dart';
import 'italian_pack.dart';
import 'method_deck.dart';
import 'narration_pack.dart';
import 'picker.dart';
import 'voice_lines.dart';

export 'voice_lines.dart' show VoicePart;

/// Una battuta del copione. Quelle d'atmosfera raccontano; quelle [isFact]
/// dicono in parole semplici cosa è successo o cosa si fa adesso, e vanno
/// lette (e mostrate) in modo che nessuno al tavolo se le perda.
class ScriptLine {
  final String text;
  final bool isFact;

  /// La stessa battuta a pezzi, per la voce del narratore automatico: messi
  /// in fila ridanno [text]. Vuota per le battute che nessuno ha inciso.
  final List<VoicePart> voice;

  const ScriptLine(this.text, {this.voice = const []}) : isFact = false;
  const ScriptLine.fact(this.text, {this.voice = const []}) : isFact = true;
}

/// Il copione del narratore: per ogni momento della partita compone le
/// battute da leggere ad alta voce, pescate ogni volta in modo diverso.
/// Lo stesso testo servirà alla voce sintetica del narratore automatico.
class NarratorScript {
  final NarrationPack pack;

  /// La città in cui è ambientata questa partita, sorteggiata all'inizio.
  final CitySetting city;
  final Picker _picker;
  final MethodDeck _deck;

  NarratorScript._(this.pack, this.city, this._picker, this._deck);

  /// Senza [random] le morti si pescano dal mazzo della serata, che non si
  /// ripete da una partita all'altra; con un seme, da un mazzo tutto suo.
  factory NarratorScript({
    NarrationPack pack = italianPack,
    CitySetting? city,
    Random? random,
    MethodDeck? deck,
  }) {
    final rng = random ?? Random();
    return NarratorScript._(
      pack,
      city ?? pack.cities[rng.nextInt(pack.cities.length)],
      Picker(rng),
      deck ?? (random == null ? MethodDeck.session : MethodDeck(rng)),
    );
  }

  List<ScriptLine> opening() => [
        _story(_picker.pick('opening', city.openings)),
        _fact(pack.howToPlay),
      ];

  List<ScriptLine> nightFalls(int round) => [
        _story(round == 1 ? _picker.pick('night.first', pack.firstNights) : _picker.pick('night', pack.nights)),
        _fact(pack.nightInstruction),
      ];

  /// Sorteggia come è morta una vittima. Chi mette in scena il delitto e chi
  /// lo racconta devono usare la stessa storia: si compone una volta sola.
  DeathStory composeDeath() =>
      DeathStory.compose(_picker, pack, city, method: _deck.draw(pack.methods));

  /// Una scena per ogni agguato della notte, nell'ordine del rapporto: la
  /// famiglia pesca dal mazzo; il Cecchino, il Dottore e chi ha la pelle
  /// dura hanno la loro.
  List<DeathStory> stage(DawnReport report) => [
        for (final attack in report.attacks)
          switch (attack.outcome) {
            AttackOutcome.healed => DeathStory.rescue(_picker, pack, city),
            AttackOutcome.shrugged => DeathStory.lucky(_picker, pack, city),
            AttackOutcome.killed when attack.source == AttackSource.sniper =>
              DeathStory.sniper(_picker, pack, city),
            AttackOutcome.killed => composeDeath(),
          },
      ];

  /// [stories] sono gli agguati già messi in scena, uno per [DawnReport.attacks];
  /// se mancano vengono composti qui.
  List<ScriptLine> dawn(
    DawnReport report, {
    required Duration discussion,
    List<DeathStory>? stories,
  }) {
    final lines = <ScriptLine>[];
    final scenes = stories ?? stage(report);

    if (report.attacks.isEmpty) {
      lines.add(_fact(pack.nobodyDied));
      lines.add(_story(_picker.pick('dawn.quiet', pack.quietDawns)));
    }
    for (var i = 0; i < report.attacks.length; i++) {
      // Chi l'ha scampata resta anonimo: il tavolo sa solo che qualcuno è
      // stato preso di mira, non chi.
      final name = scenes[i].survived ? pack.someone : report.attacks[i].target.name;
      if (i > 0) lines.add(_story(_picker.pick('dawn.again', pack.secondVictims)));
      for (final paragraph in scenes[i].paragraphs) {
        lines.add(_story(paragraph, name: name));
      }
      lines.add(_fact(scenes[i].fact, name: name));
    }

    final scoop = report.scoop;
    if (scoop != null) {
      final name = scoop.subject.name;
      lines.add(_story(_picker.pick('scoop', pack.scoops), name: name));
      lines.add(_fact(scoop.team == Team.mafia ? pack.scoopMafia : pack.scoopClean, name: name));
    }

    // Il silenzio vale per la discussione: se la partita è finita, non serve.
    final silenced = report.silenced;
    if (silenced != null && report.winner == null) {
      lines.add(_story(_picker.pick('silence', pack.silences), name: silenced.name));
      lines.add(_fact(pack.silencedFact, name: silenced.name));
    }

    if (report.winner == null) {
      final count = discussion.inMinutes;
      final minutes = count == 1 ? [VoicePart.spoken(pack.oneMinute)] : _parts(pack.manyMinutes, count: count);
      lines.add(_fact(pack.dayInstruction, minutes: minutes));
    }
    return lines;
  }

  List<ScriptLine> voteCall() => [
        _story(_picker.pick('vote', pack.voteCalls)),
        _fact(pack.voteInstruction),
      ];

  /// La prima battuta porta il condannato al patibolo; la seconda gira la
  /// carta, e chi impagina il copione la tiene coperta fino a quel momento.
  List<ScriptLine> lynch(LynchReport report) {
    final condemned = report.condemned;
    if (condemned == null) {
      return [_fact(pack.noLynchFact), _story(_picker.pick('lynch.none', pack.noLynch))];
    }

    final role = report.role!;
    final isMafia = role.team == Team.mafia;
    final String reaction;
    if (!isMafia) {
      reaction = _picker.pick('lynch.innocent', pack.lynchedInnocent);
    } else if (report.winner == Team.citizens) {
      reaction = _picker.pick('lynch.last', pack.lynchedLastMafioso);
    } else {
      reaction = _picker.pick('lynch.mafia', pack.lynchedMafioso);
    }
    return [
      _story(_picker.pick('lynch.scene', pack.lynchScenes), name: condemned.name),
      _line(
        [
          ..._parts(pack.cardTurns, name: condemned.name, role: pack.role(role).label),
          VoicePart.spoken(' ${isMafia ? pack.wasMafia : pack.wasCitizen}'),
        ],
        fact: true,
      ),
      _story(reaction),
    ];
  }

  List<ScriptLine> ending(Team winner) {
    final mafiaWon = winner == Team.mafia;
    return [
      _fact(mafiaWon ? pack.mafiaWinsFact : pack.citizensWinFact),
      _story(_picker.pick('ending.${winner.name}', mafiaWon ? pack.mafiaWins : pack.citizensWin)),
    ];
  }

  /// La domanda che un giocatore legge, da solo, quando di notte tocca a lui.
  /// Il compito di copertura cambia domanda ogni notte.
  String taskPrompt(NightTask task, int round) =>
      pack.taskPrompts[task.kind] ?? pack.decoyPrompts[(round - 1) % pack.decoyPrompts.length];

  String taskHint(NightTask task) => pack.taskHints[task.kind]!;

  ScriptLine _story(String template, {String? name}) => _line(_parts(template, name: name));

  ScriptLine _fact(String template, {String? name, List<VoicePart>? minutes}) =>
      _line(_parts(template, name: name, minutes: minutes), fact: true);

  /// Il testo della battuta è quello che si vede dei suoi pezzi, in fila.
  ScriptLine _line(List<VoicePart> parts, {bool fact = false}) {
    final text = parts.map((part) => part.display).join();
    return fact ? ScriptLine.fact(text, voice: parts) : ScriptLine(text, voice: parts);
  }

  /// Riempie un testo del pacchetto e lo spezza per la voce: la città è già
  /// nella frase incisa; il nome resta al tavolo; il ruolo, i minuti e il
  /// loro numero hanno le loro clip. Quello che manca resta com'è.
  List<VoicePart> _parts(String template, {String? name, String? role, List<VoicePart>? minutes, int? count}) {
    final pieces = splitTemplate(template.replaceAll('{city}', city.name));
    return [
      for (var i = 0; i < pieces.length; i++)
        ...switch (pieces[i]) {
          '{name}' when name != null => [_name(name, first: i == 0)],
          '{role}' when role != null => [VoicePart.spoken(role.toUpperCase(), say: role)],
          '{minutes}' when minutes != null => minutes,
          '{minutes}' when count != null => [VoicePart.spoken('$count')],
          final piece when dynamicPlaceholders.contains(piece) => [VoicePart.spoken(piece, say: '')],
          final piece => [VoicePart.spoken(piece)],
        },
    ];
  }

  /// Un giocatore non si pronuncia; "qualcuno" sì, ed è maiuscolo se apre la frase.
  VoicePart _name(String name, {required bool first}) {
    final shown = first && name.isNotEmpty ? name[0].toUpperCase() + name.substring(1) : name;
    return name == pack.someone ? VoicePart.spoken(shown, say: name) : VoicePart.name(shown);
  }
}
