import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/narration/english_pack.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/narration/narration_pack.dart';
import 'package:oberta/narration/narrator_script.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/online/game/chronicle_headlines.dart';

/// Nomi che non compaiono mai nel copione: se ci sono, li ha messi il motore.
final _people = [
  for (final name in ['Xaverio', 'Quintilia', 'Wolfango', 'Ypsilda', 'Zebedeo']) Player(id: name, name: name),
];

int _count(String text, String word) => RegExp(RegExp.escape(word)).allMatches(text).length;

/// Tutte le combinazioni di agguati, da uno a [max], su persone diverse.
Iterable<List<NightAttack>> _nights(int max) sync* {
  final kinds = [
    for (final source in AttackSource.values)
      for (final outcome in AttackOutcome.values) (source, outcome),
  ];
  Iterable<List<(AttackSource, AttackOutcome)>> combos(int n, int from) sync* {
    if (n == 0) {
      yield [];
      return;
    }
    for (var i = from; i < kinds.length; i++) {
      for (final rest in combos(n - 1, i)) {
        yield [kinds[i], ...rest];
      }
    }
  }

  for (var n = 1; n <= max; n++) {
    for (final combo in combos(n, 0)) {
      yield [for (var i = 0; i < combo.length; i++) NightAttack(_people[i], combo[i].$1, combo[i].$2)];
    }
  }
}

void _clean(String text, String where) {
  expect(text.contains('{') || text.contains('}'), isFalse, reason: '$where: segnaposto rimasto in «$text»');
  expect(text.trim(), isNotEmpty, reason: '$where: riga vuota');
}

void main() {
  for (final (pack, italian) in [(italianPack, true), (englishPack, false)]) {
    final lang = italian ? 'it' : 'en';
    // Il Dottore che salva lo dice già la frase del salvataggio: lì non è una
    // carta scoperta. Le parole corte ("One") stanno anche nelle frasi comuni.
    final hidden = {
      for (final role in Role.values)
        if (role != Role.medico && role != Role.presidente && pack.role(role).label.split(' ').last.length > 3)
          pack.role(role).label.split(' ').last.toLowerCase(),
    };

    void checkDawn(DawnReport dawn, int seed) {
      final script = NarratorScript(pack: pack, random: Random(seed));
      final lines = script.dawn(dawn, discussion: const Duration(minutes: 2), online: seed.isEven);
      final (:headline, :dead) = dawnHeadline(dawn, language: italian ? AppLanguage.it : AppLanguage.en, everyoneAlive: 'EVERYONE');
      final where = '$lang ${dawn.attacks.map((a) => '${a.source.name}/${a.outcome.name}').join('+')}';
      _clean(headline, '$where titolo');
      for (final line in lines) {
        _clean(line.text, where);
      }
      final facts = [
        for (final l in lines)
          if (l.isFact) l.text,
      ].join('\n');
      final all = [for (final l in lines) l.text].join('\n');
      for (final attack in dawn.attacks) {
        final name = attack.target.name;
        if (attack.isFatal) {
          expect(_count(facts, name), 1, reason: '$where: $name nei fatti\n$facts');
          expect(_count(headline, name), 1, reason: '$where: $name nel titolo «$headline»');
        } else if (name != dawn.scoop?.subject.name && name != dawn.silenced?.name) {
          expect(_count(all, name), 0, reason: '$where: chi si salva resta anonimo\n$all');
          expect(_count(headline, name), 0, reason: '$where: titolo «$headline»');
        }
      }
      expect(dead, [for (final v in dawn.victims) v.name]);
      // I ruoli dei morti restano segreti: all'alba non si legge nessuna carta.
      for (final label in hidden) {
        for (final fact in [
          for (final l in lines)
            if (l.isFact) l.text,
        ]) {
          expect(
            RegExp('\\b${RegExp.escape(label)}\\b').hasMatch(fact.toLowerCase()),
            isFalse,
            reason: '$where: «$label» in «$fact»',
          );
        }
      }
      if (dawn.attacks.every((a) => !a.isFatal) && dawn.resurrected == null) expect(headline, 'EVERYONE');
    }

    test('$lang: ogni notte da uno a quattro agguati ha un titolo e un racconto puliti', () {
      var seed = 0;
      for (final attacks in _nights(4)) {
        checkDawn(DawnReport(round: 1, attacks: attacks), seed++);
      }
    });

    test('$lang: scoop, silenzio, resurrezione e fine partita all\'alba', () {
      final [a, b, c, d, _] = _people;
      var seed = 100;
      for (final attacks in [
        <NightAttack>[],
        [NightAttack(a, AttackSource.family, AttackOutcome.killed)],
        [
          NightAttack(a, AttackSource.fire, AttackOutcome.killed),
          NightAttack(b, AttackSource.assassin, AttackOutcome.healed),
        ],
      ]) {
        for (final team in Team.values) {
          checkDawn(DawnReport(round: 2, attacks: attacks, scoop: Exposure(c, team)), seed++);
        }
        checkDawn(DawnReport(round: 2, attacks: attacks, silenced: d), seed++);
        checkDawn(DawnReport(round: 2, attacks: attacks, resurrected: c), seed++);
        for (final winner in Team.values) {
          checkDawn(DawnReport(round: 2, attacks: attacks, silenced: d, winner: winner), seed++);
        }
        final s = NarratorScript(pack: pack, random: Random(seed));
        final scoop = s.dawn(
          DawnReport(round: 2, attacks: attacks, scoop: Exposure(c, Team.mafia)),
          discussion: Duration.zero,
        );
        expect(scoop.map((l) => l.text).join(), contains(c.name));
        final silence = s.dawn(
          DawnReport(round: 2, attacks: attacks, silenced: d),
          discussion: Duration.zero,
        );
        expect(silence.map((l) => l.text).join(), contains(d.name));
        final ended = s.dawn(
          DawnReport(round: 2, attacks: attacks, silenced: d, winner: Team.mafia),
          discussion: Duration.zero,
        );
        expect(ended.map((l) => l.text).join(), isNot(contains(d.name)), reason: 'a partita finita non si tace');
        final risen = s.dawn(
          DawnReport(round: 2, attacks: attacks, resurrected: c),
          discussion: Duration.zero,
        );
        expect(
          _count(
            [
              for (final l in risen)
                if (l.isFact) l.text,
            ].join(),
            c.name,
          ),
          1,
        );
      }
      final (:headline, dead: _) = dawnHeadline(
        DawnReport(round: 2, resurrected: c),
        language: italian ? AppLanguage.it : AppLanguage.en,
        everyoneAlive: '',
      );
      expect(headline, contains(c.name));
    });

    test('$lang: ogni linciaggio, il Fesso, la taglia, il pareggio, la fine', () {
      final [a, hunter, ..._] = _people;
      var seed = 200;
      void checkLynch(LynchReport report) {
        final lines = NarratorScript(pack: pack, random: Random(seed++)).lynch(report);
        final headline = lynchHeadline(
          report,
          language: italian ? AppLanguage.it : AppLanguage.en,
          tag: (p) => p.name,
          roleLabel: (r) => pack.role(r).label,
        );
        final where = '$lang ${report.role?.name} fool=${report.personalWin} bounty=${report.bountyHunter != null}';
        _clean(headline, '$where titolo');
        for (final line in lines) {
          _clean(line.text, where);
        }
        final text = lines.map((l) => l.text).join('\n');
        final condemned = report.condemned;
        if (condemned == null) return;
        expect(headline, contains(condemned.name), reason: where);
        expect(text, contains(condemned.name), reason: where);
        expect(text.toLowerCase(), contains(pack.role(report.role!).label.toLowerCase()), reason: '$where\n$text');
        if (report.bountyHunter != null) {
          expect(text, contains(hunter.name), reason: where);
          expect(headline, contains(hunter.name), reason: where);
        }
        if (report.personalWin) {
          expect(headline, contains(italian ? 'Fesso' : 'Fool'), reason: where);
        }
      }

      checkLynch(const LynchReport(round: 1));
      for (final role in Role.values) {
        for (final winner in [null, ...Team.values]) {
          checkLynch(LynchReport(round: 1, condemned: a, role: role, winner: winner));
        }
      }
      checkLynch(LynchReport(round: 1, condemned: a, role: Role.fesso, personalWin: true));
      checkLynch(LynchReport(round: 1, condemned: a, role: Role.cittadino, bountyHunter: hunter, winner: Team.neutral));
    });

    test('$lang: ogni fine partita, anche le vittorie in solitaria', () {
      final hunter = _people[1];
      for (final (winner, assassin, bounty) in [
        for (final team in Team.values) (team, false, false),
        (Team.neutral, true, false),
        (Team.neutral, false, true),
      ]) {
        final lines = NarratorScript(
          pack: pack,
          random: Random(3),
        ).ending(winner, assassin: assassin, bountyHunter: bounty ? hunter : null);
        expect(lines, isNotEmpty);
        for (final line in lines) {
          _clean(line.text, '$lang fine ${winner.name}');
        }
        final text = lines.map((l) => l.text).join();
        if (bounty) expect(text, contains(hunter.name));
        if (winner == Team.neutral && !bounty) {
          expect(text.toLowerCase(), contains(pack.role(assassin ? Role.sicario : Role.piromane).label.toLowerCase()));
        }
      }
    });
  }

  test('il Sindaco si annuncia con il suo nome, in tutte e due le lingue', () {
    for (final NarrationPack pack in [italianPack, englishPack]) {
      final line = pack.mayorRevealed.replaceAll('{name}', 'Xaverio');
      _clean(line, 'sindaco');
      expect(line, contains('Xaverio'));
    }
  });
}
