import 'dart:math';

import '../rules/game_engine.dart';
import '../rules/player.dart';
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
  factory NarratorScript({NarrationPack pack = italianPack, CitySetting? city, Random? random, MethodDeck? deck}) {
    final rng = random ?? Random();
    return NarratorScript._(
      pack,
      city ?? pack.cities[rng.nextInt(pack.cities.length)],
      Picker(rng),
      deck ?? (random == null ? MethodDeck.session : MethodDeck(rng)),
    );
  }

  /// [online]: la partita in cui ognuno è a casa sua col suo telefono. Lì
  /// il copione è solo il racconto: niente istruzioni pensate per il
  /// telefono che gira al tavolo (le fasi le scandisce il server).
  List<ScriptLine> opening({bool online = false}) => [
        _story(_picker.pick('opening', city.openings)),
        if (!online) _fact(pack.howToPlay),
      ];

  List<ScriptLine> nightFalls(int round, {bool online = false}) => [
        _story(round == 1 ? _picker.pick('night.first', pack.firstNights) : _picker.pick('night', pack.nights)),
        if (!online) _fact(pack.nightInstruction),
      ];

  /// Sorteggia come è morta una vittima. Chi mette in scena il delitto e chi
  /// lo racconta devono usare la stessa storia: si compone una volta sola.
  DeathStory composeDeath() => DeathStory.compose(_picker, pack, city, method: _deck.draw(pack.methods));

  /// Un agguato che il Dottore manda a vuoto: l'agguato si pesca dallo
  /// stesso mazzo delle morti, fra quelli a cui il Dottore sa rimediare.
  DeathStory composeRescue() => DeathStory.rescue(
        _picker,
        pack,
        city,
        attack: _deck.draw(pack.methods, where: (method) => DeathStory.rescuesFor(method.id).isNotEmpty),
      );

  /// Un agguato che va a vuoto per fortuna: dallo stesso mazzo, fra quelli
  /// che un colpo di fortuna sa fermare.
  DeathStory composeLucky() => DeathStory.lucky(
        _picker,
        pack,
        city,
        attack: _deck.draw(pack.methods, where: (method) => DeathStory.luckFor(method.id).isNotEmpty),
      );

  /// Una scena per ogni agguato della notte, nell'ordine del rapporto: le
  /// morti della famiglia pescano dal mazzo, e così gli agguati andati a
  /// vuoto (anche quelli del Cecchino: al tavolo non si capisce chi ha
  /// sparato). Il Cecchino che va a segno ha i suoi filmati.
  List<DeathStory> stage(DawnReport report) => [
        for (final attack in report.attacks)
          switch (attack.outcome) {
            AttackOutcome.healed => composeRescue(),
            AttackOutcome.shrugged => composeLucky(),
            AttackOutcome.escorted => DeathStory.escort(_picker, pack, city, attack: _deck.draw(pack.methods)),
        AttackOutcome.killed when attack.source == AttackSource.sniper => DeathStory.sniper(_picker, pack, city),
        AttackOutcome.killed when attack.source == AttackSource.fire => DeathStory.fire(_picker, pack, city),
            AttackOutcome.killed => composeDeath(),
          },
      ];

  /// [stories] sono gli agguati già messi in scena, uno per [DawnReport.attacks];
  /// se mancano vengono composti qui.
  List<ScriptLine> dawn(
    DawnReport report, {
    required Duration discussion,
    List<DeathStory>? stories,
    bool online = false,
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

    for (final broken in report.heartbroken) {
      lines.add(_story(_picker.pick('heartbreak', pack.heartbreaks), name: broken.name));
      lines.add(_fact(pack.heartbreakFact, name: broken.name));
    }

    final resurrected = report.resurrected;
    if (resurrected != null) {
      lines.add(_story(_picker.pick('resurrection', pack.resurrections)));
      lines.add(_fact(pack.resurrectedFact, name: resurrected.name));
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
      lines.add(_fact(online ? pack.silencedFactOnline : pack.silencedFact, name: silenced.name));
    }

    if (report.winner == null && !online) {
      final count = discussion.inMinutes;
      final minutes = count == 1 ? [VoicePart.spoken(pack.oneMinute)] : _parts(pack.manyMinutes, count: count);
      lines.add(_fact(pack.dayInstruction, minutes: minutes));
    }
    return lines;
  }

  /// Il telefono passa a [name]: chi lo prende, e che gli altri guardino
  /// altrove (o, per la carta, che nessuno la veda).
  List<ScriptLine> curtain(String name, {bool card = false}) =>
      [_story(pack.passPhone, name: name), _fact(card ? pack.cardCurtainHint : pack.curtainHint)];

  /// La mossa della notte è fatta: il telefono si posa.
  ScriptLine putPhoneDown() => _fact(pack.putPhoneDown);

  /// Il voto a turno: tocca a [name] (col numero di posto, «4 Dario»).
  ScriptLine voterTurn(String name) => _fact(pack.voterTurn, name: name);

  List<ScriptLine> voteCall() => [_story(_picker.pick('vote', pack.voteCalls)), _fact(pack.voteInstruction)];

  /// La prima battuta porta il condannato al patibolo; la seconda gira la
  /// carta, e chi impagina il copione la tiene coperta fino a quel momento.
  List<ScriptLine> lynch(LynchReport report) {
    final condemned = report.condemned;
    if (condemned == null && report.truce) {
      return [_fact(pack.truceFact), _story(_picker.pick('lynch.truce', pack.truces))];
    }
    if (condemned == null) {
      return [_fact(pack.noLynchFact), _story(_picker.pick('lynch.none', pack.noLynch))];
    }

    final role = report.role!;
    final isMafia = role.team == Team.mafia;
    final String reaction;
    final hunter = report.bountyHunter;
    if (report.personalWin) {
      reaction = _picker.pick('lynch.fool', pack.foolWins);
    } else if (hunter != null) {
      reaction = _picker.pick('lynch.bounty', pack.bountyWins);
    } else if (!isMafia) {
      reaction = _picker.pick('lynch.innocent', pack.lynchedInnocent);
    } else if (report.winner == Team.citizens) {
      reaction = _picker.pick('lynch.last', pack.lynchedLastMafioso);
    } else {
      reaction = _picker.pick('lynch.mafia', pack.lynchedMafioso);
    }
    return [
      _story(_picker.pick('lynch.scene', pack.lynchScenes), name: condemned.name),
      _line([
          ..._parts(pack.cardTurns, name: condemned.name, role: pack.role(role).label),
        VoicePart.spoken(
          ' ${switch (role.team) {
            Team.mafia => pack.wasMafia,
            Team.citizens => pack.wasCitizen,
            Team.neutral => pack.wasNeutral,
          }}',
      ),
      ], fact: true),
      _story(reaction),
      if (report.personalWin) _fact(pack.foolWinsFact, name: condemned.name),
      if (hunter != null) _fact(pack.bountyWinsFact, name: hunter.name),
      if (report.heartbroken case final broken?) ...[
        _story(_picker.pick('heartbreak', pack.heartbreaks), name: broken.name),
        _fact(pack.heartbreakFact, name: broken.name),
      ],
    ];
  }

  /// Il colpo dell'Artigliere, di giorno: il boato, chi ha colpito, la sua
  /// carta che si gira (come per un linciato) e l'eventuale crepacuore.
  List<ScriptLine> cannon(CannonShot shot) => [
        _story(_picker.pick('cannon', pack.cannonShots)),
        _fact(pack.cannonFact, name: shot.target.name),
        _line([
          ..._parts(pack.cardTurns, name: shot.target.name, role: pack.role(shot.role).label),
          VoicePart.spoken(
            ' ${switch (shot.role.team) {
              Team.mafia => pack.wasMafia,
              Team.citizens => pack.wasCitizen,
              Team.neutral => pack.wasNeutral,
            }}',
          ),
        ], fact: true),
        if (shot.heartbroken case final broken?) ...[
          _story(_picker.pick('heartbreak', pack.heartbreaks), name: broken.name),
          _fact(pack.heartbreakFact, name: broken.name),
        ],
      ];

  /// Con [assassin] la città l'ha ripulita il Sicario, non il Piromane; con
  /// [bountyHunter] ha chiuso la partita una taglia pagata in piazza.
  ///
  /// Con [lovers] gli innamorati sono arrivati vivi alla fine: vincono anche loro.
  List<ScriptLine> ending(
    Team winner, {
    bool assassin = false,
    Player? bountyHunter,
    List<Player> loanSharks = const [],
    bool lovers = false,
    bool presidentFell = false,
    bool sect = false,
  }) {
    final sharks = [
      if (presidentFell) _fact(pack.presidentFallsFact),
      for (final shark in loanSharks) _fact(pack.loanSharkWinsFact, name: shark.name),
      if (lovers) _fact(pack.loversWinFact),
    ];
    if (winner == Team.neutral && bountyHunter != null) {
      return [_fact(pack.bountyWinsFact, name: bountyHunter.name), ...sharks];
    }
    if (winner == Team.neutral && sect) {
      return [_fact(pack.sectWinsFact), _story(_picker.pick('ending.sect', pack.sectWins)), ...sharks];
    }
    if (winner == Team.neutral && assassin) {
      return [_fact(pack.assassinWinsFact), _story(_picker.pick('ending.assassin', pack.assassinWins)), ...sharks];
    }
    if (winner == Team.neutral) {
      return [_fact(pack.arsonistWinsFact), _story(_picker.pick('ending.neutral', pack.arsonistWins)), ...sharks];
    }
    final mafiaWon = winner == Team.mafia;
    return [
      _fact(mafiaWon ? pack.mafiaWinsFact : pack.citizensWinFact),
      _story(_picker.pick('ending.${winner.name}', mafiaWon ? pack.mafiaWins : pack.citizensWin)),
      ...sharks,
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
