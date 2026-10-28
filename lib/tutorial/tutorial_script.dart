import 'package:flutter/widgets.dart';

import '../l10n/app_language.dart';
import '../online/reactions.dart';
import '../rules/intent.dart';
import '../rules/role.dart';
import 'tutorial_story.dart';

// Il copione delle tre mani di prova: chi siede dove, che carta ha, e cosa
// fanno i bot fase per fase (cosa scrivono, che gesti lanciano, come votano).
// La partita gira sul motore vero: il copione decide solo le mosse dei bot.

/// Un pezzo del copione: una riga in chat, una mossa, un gesto.
sealed class Cue {
  const Cue();
}

/// Un bot scrive in chat (nella piazza, o in quella della famiglia).
class Say extends Cue {
  final String seat;
  final String text;
  final bool family;

  const Say(this.seat, this.text, {this.family = false});
}

/// Un bot fa la sua mossa (di notte, o al voto: anche cambiando idea).
class Move extends Cue {
  final PlayerIntent intent;

  const Move(this.intent);
}

/// Un bot lancia un gesto a un altro posto.
class Toss extends Cue {
  final String from;
  final String to;
  final TableGesture gesture;

  const Toss(this.from, this.to, this.gesture);
}

/// Una riga del narratore, con il pezzo di schermo da illuminare.
class TutorialCoach {
  final String line;
  final Key? spot;

  const TutorialCoach(this.line, [this.spot]);
}

/// Una fase del copione (`night-1`, `discussion-2`...).
class Scene {
  /// Quello che fanno i bot appena si apre la fase.
  final List<Cue> opening;

  /// Quello che rispondono quando scrivi la tua (la prima volta).
  final List<Cue> answer;

  /// Le risposte già pronte, da toccare invece di scrivere.
  final List<String> replies;

  /// Su chi puoi puntare in questa fase; null: su chi vuoi.
  final Set<String>? expect;

  final TutorialCoach? coach;
  final TutorialCoach? answered;
  final TutorialCoach? acted;

  const Scene({
    this.opening = const [],
    this.answer = const [],
    this.replies = const [],
    this.expect,
    this.coach,
    this.answered,
    this.acted,
  });
}

/// Una mano di prova intera.
class TutorialScript {
  final TutorialStory story;
  final int seed;
  final Map<String, Role> roles;
  final Map<String, Scene> scenes;

  /// La riga finale sulla vittoria della fazione.
  final String winLine;

  const TutorialScript({
    required this.story,
    required this.seed,
    required this.roles,
    required this.scenes,
    required this.winLine,
  });

  /// I posti: tu sei l'1, i bot dal 2 al 6.
  static const you = 's1';
  static const names = {'s2': 'Vito', 's3': 'Bruno', 's4': 'Carmela', 's5': 'Dora', 's6': 'Enzo'};

  /// Chi dei bot è una donna: l'italiano concorda («Carmela è stata linciata»).
  static const women = {'s4', 's5'};

  factory TutorialScript.of(TutorialStory story, AppLanguage language) {
    String m(String key, [Map<String, Object?> args = const {}]) => language.message('tutorialScript.$key', args);
    const card = Key('online.card');
    const chat = Key('game.chatSlot');
    const table = Key('game.tableSlot');
    const ready = Key('online.ready');
    const verdict = Key('online.verdict');
    Key seat(String s) => Key('seat-$s');
    final readyLine = TutorialCoach(m('whenYouHave'), ready);
    final dawnFilm = TutorialCoach(m('atDawnYou'));

    switch (story) {
      case TutorialStory.city:
        return TutorialScript(
          story: story,
          seed: 1931,
          roles: const {
            's1': Role.detective,
            's2': Role.mafioso,
            's3': Role.cittadino,
            's4': Role.mafioso,
            's5': Role.medico,
            's6': Role.cittadino,
          },
          winLine: m('theTownWins.city'),
          scenes: {
            'reveal-1': Scene(
              coach: TutorialCoach(
                m('youAreThe.city'),
                card,
              ),
            ),
            'night-1': Scene(
              opening: const [
                Move(MafiaVote('s2', 's3')),
                Move(MafiaVote('s4', 's3')),
                Move(NightAction('s5', 's6')),
                Move(Pass('s3')),
                Move(Pass('s6')),
              ],
              expect: {'s2'},
              coach: TutorialCoach(m('atNightYou.city'), seat('s2')),
              acted: TutorialCoach(m('vitoIsFamily.city'), table),
            ),
            'dawnFilms-1': Scene(coach: dawnFilm),
            'dawn-1': Scene(coach: readyLine),
            'discussion-1': Scene(
              opening: [
                Say('s5', m('brunoNeverHurt.city')),
                Say('s2', m('iWasAt.city')),
                Say('s4', m('trueLookAt.city')),
                const Toss('s4', 's6', TableGesture.eye),
                Say('s6', m('meDetectiveWhat.city')),
              ],
              replies: [
                m('iCheckedVito.city'),
                m('isLyingI.city'),
              ],
              answer: [
                Say('s2', m('liarHeJust.city')),
                const Toss('s2', 's1', TableGesture.eye),
                Say('s5', m('ifTheDetective.city')),
                Say('s6', m('meTooWe.city')),
              ],
              coach: TutorialCoach(m('theSquareTalks.city'), chat),
              answered: TutorialCoach(m('theyBelieveYou.city'), ready),
            ),
            'vote-1': Scene(
              opening: [
                const Move(DayVote('s4', 's6')),
                const Move(DayVote('s2', 's1')),
                const Move(DayVote('s6', 's4')),
                const Move(DayVote('s5', 's2')),
                Say('s6', m('onSecondThought.city')),
                const Move(DayVote('s6', 's2')),
              ],
              expect: {'s2'},
              coach: TutorialCoach(m('watchTheHands.city'), seat('s2')),
            ),
            'verdict-1': Scene(
              coach: TutorialCoach(m('theLynchedShows.city'), verdict),
            ),
            'night-2': Scene(
              opening: const [Move(MafiaVote('s4', 's1')), Move(NightAction('s5', 's1')), Move(Pass('s6'))],
              expect: {'s4'},
              coach: TutorialCoach(m('anotherNightCheck.city'), seat('s4')),
              acted: TutorialCoach(m('carmelaIsFamily.city'), table),
            ),
            'dawnFilms-2': Scene(coach: TutorialCoach(m('tonightTheyCame.city'))),
            'dawn-2': Scene(coach: TutorialCoach(m('theDoctorSaved.city'), ready)),
            'discussion-2': Scene(
              opening: [
                Say('s5', m('iWatchedOver.city')),
                Say('s4', m('luckyYouBut.city')),
                Say('s6', m('detectiveWhoDid.city')),
              ],
              replies: [
                m('carmelaFamily.city'),
                m('isTheLast.city'),
              ],
              answer: [
                Say('s4', m('ohPleaseIs.city')),
                Say('s5', m('iSavedYou.city')),
                const Toss('s5', 's1', TableGesture.toast),
                Say('s6', m('weVote.city')),
              ],
              coach: TutorialCoach(m('lastDayTell.city'), chat),
              answered: TutorialCoach(m('goodReadyAnd.city'), ready),
            ),
            'vote-2': Scene(
              opening: [
                const Move(DayVote('s4', 's1')),
                const Move(DayVote('s5', 's4')),
                const Move(DayVote('s6', 's5')),
                Say('s6', m('noWait.city')),
                const Move(DayVote('s6', 's4')),
              ],
              expect: {'s4'},
              coach: TutorialCoach(m('voteCarmela.city'), seat('s4')),
            ),
            'verdict-2': Scene(
              coach: TutorialCoach(m('noFamilyLeft.city'), verdict),
            ),
          },
        );

      case TutorialStory.family:
        return TutorialScript(
          story: story,
          seed: 1932,
          roles: const {
            's1': Role.mafioso,
            's2': Role.mafioso,
            's3': Role.cittadino,
            's4': Role.medico,
            's5': Role.cittadino,
            's6': Role.cittadino,
          },
          winLine: m('theFamilyWins.family'),
          scenes: {
            'reveal-1': Scene(
              coach: TutorialCoach(
                m('thisTimeYou.family'),
                card,
              ),
            ),
            'night-1': Scene(
              opening: [
                Say('s2', m('justTheTwo.family'), family: true),
                Say('s2', m('iSayEnzo.family'), family: true),
                const Move(MafiaVote('s2', 's6')),
                const Move(NightAction('s4', 's6')),
                const Move(Pass('s3')),
                const Move(Pass('s5')),
                const Move(Pass('s6')),
              ],
              replies: [m('ok.family'), m('fineEnzoTonight.family')],
              answer: [Say('s2', m('perfectTap.family'), family: true)],
              expect: {'s6'},
              coach: TutorialCoach(m('atNightThe.family'), chat),
              answered: TutorialCoach(m('nowTapEnzo.family'), seat('s6')),
              acted: TutorialCoach(m('twoVotesOn.family'), table),
            ),
            'dawnFilms-1': Scene(coach: dawnFilm),
            'dawn-1': Scene(
              coach: TutorialCoach(m('enzoLivesThe.family'), ready),
            ),
            'discussion-1': Scene(
              opening: [
                Say('s5', m('someoneWentTo.family')),
                Say('s6', m('aliveByA.family')),
                Say('s3', m('wasOutOn.family')),
                const Toss('s3', 's1', TableGesture.eye),
                Say('s6', m('wellTalk.family')),
                Say('s2', m('easyWasAt.family')),
              ],
              replies: [
                m('brunoAccusesFirst.family'),
                m('iWasAsleep.family'),
              ],
              answer: [
                Say('s4', m('brunoIsIn.family')),
                Say('s2', m('toldYouIs.family')),
                const Toss('s2', 's3', TableGesture.cigar),
                Say('s3', m('whatIAm.family')),
              ],
              coach: TutorialCoach(m('theyAccuseYou.family'), chat),
              answered: TutorialCoach(m('itWorkedReady.family'), ready),
            ),
            'vote-1': Scene(
              opening: [
                const Move(DayVote('s3', 's1')),
                const Move(DayVote('s6', 's1')),
                const Move(DayVote('s5', 's1')),
                const Move(DayVote('s2', 's3')),
                const Move(DayVote('s4', 's3')),
                Say('s5', m('changedMyMind.family')),
                const Move(DayVote('s5', 's3')),
              ],
              expect: {'s3'},
              coach: TutorialCoach(m('handsAreMoving.family'), seat('s3')),
            ),
            'verdict-1': Scene(
              coach: TutorialCoach(m('brunoWasInnocent.family'), verdict),
            ),
            'night-2': Scene(
              opening: [
                Say('s2', m('theDoctorSaved.family'), family: true),
                Say('s2', m('herTonightYou.family'), family: true),
                const Move(MafiaVote('s2', 's4')),
                const Move(NightAction('s4', 's5')),
                const Move(Pass('s5')),
                const Move(Pass('s6')),
              ],
              replies: [m('iAmIn.family'), m('fineCarmela.family')],
              answer: [Say('s2', m('letSGo.family'), family: true)],
              expect: {'s4'},
              coach: TutorialCoach(m('vitoHasAn.family'), chat),
              answered: TutorialCoach(m('tapCarmelaSeat.family'), seat('s4')),
            ),
            'dawnFilms-2': Scene(coach: dawnFilm),
            'dawn-2': Scene(
              coach: TutorialCoach(m('twoAgainstTwo.family')),
            ),
          },
        );

      case TutorialStory.solo:
        return TutorialScript(
          story: story,
          seed: 1933,
          roles: const {
            's1': Role.fesso,
            's2': Role.mafioso,
            's3': Role.cittadino,
            's4': Role.medico,
            's5': Role.detective,
            's6': Role.cittadino,
          },
          winLine: m('soloPlayersHave.solo'),
          scenes: {
            'reveal-1': Scene(
              coach: TutorialCoach(
                m('youPlayAlone.solo'),
                card,
              ),
            ),
            'night-1': Scene(
              opening: const [
                Move(MafiaVote('s2', 's3')),
                Move(NightAction('s4', 's6')),
                Move(NightAction('s5', 's1')),
                Move(Pass('s3')),
                Move(Pass('s6')),
              ],
              coach: TutorialCoach(m('theFoolHas.solo'), table),
              acted: TutorialCoach(m('atNightYou.solo'), table),
            ),
            'dawnFilms-1': Scene(coach: dawnFilm),
            'dawn-1': Scene(coach: TutorialCoach(m('brunoIsGone.solo'), ready)),
            'discussion-1': Scene(
              opening: [
                Say('s5', m('brunoIsDead.solo')),
                Say('s2', m('iWasAsleep.solo')),
                Say('s6', m('yeahDoesNot.solo')),
                const Toss('s6', 's1', TableGesture.eye),
                Say('s4', m('giveHimA.solo')),
              ],
              replies: [
                m('brunoOneLess.solo'),
                m('iSayNothing.solo'),
              ],
              answer: [
                Say('s2', m('youHeardThat.solo')),
                const Toss('s2', 's1', TableGesture.cigar),
                Say('s5', m('isSeriouslyWeird.solo')),
                Say('s4', m('sorryYouDid.solo')),
              ],
              coach: TutorialCoach(m('actShadySay.solo'), chat),
              answered: TutorialCoach(m('theyFellFor.solo'), ready),
            ),
            'vote-1': Scene(
              opening: [
                const Move(DayVote('s5', 's1')),
                const Move(DayVote('s2', 's6')),
                const Move(DayVote('s6', 's1')),
                const Move(DayVote('s4', 's2')),
                Say('s2', m('fineMeToo.solo')),
                const Move(DayVote('s2', 's1')),
                const Move(DayVote('s4', 's1')),
              ],
              coach: TutorialCoach(m('everyonePointsAt.solo'), table),
            ),
            'verdict-1': Scene(
              coach: TutorialCoach(m('theyLynchedYou.solo'), verdict),
            ),
          },
        );
    }
  }
}
