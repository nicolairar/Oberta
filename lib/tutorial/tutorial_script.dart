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
    String t(String it, String en) => language == AppLanguage.en ? en : it;
    const card = Key('online.card');
    const chat = Key('game.chatSlot');
    const table = Key('game.tableSlot');
    const ready = Key('online.ready');
    const verdict = Key('online.verdict');
    Key seat(String s) => Key('seat-$s');
    final readyLine = TutorialCoach(t('Quando hai letto, «Pronto».', 'When you have read it, «Ready».'), ready);
    final dawnFilm = TutorialCoach(t('All\'alba si scopre com\'è andata la notte.', 'At dawn you see how the night went.'));

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
          winLine: t(
            'La città vince quando non resta nessuno della Famiglia. Le prove contano più delle chiacchiere.',
            'The town wins when no Family is left. Proof beats chatter.',
          ),
          scenes: {
            'reveal-1': Scene(
              coach: TutorialCoach(
                t('Sei il Commissario. Tieni premuta la carta, poi «Pronto».', 'You are the Detective. Hold the card, then «Ready».'),
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
              coach: TutorialCoach(t('Di notte indaghi. Tocca Vito, il 2, e conferma.', 'At night you investigate. Tap Vito, seat 2, and confirm.'), seat('s2')),
              acted: TutorialCoach(t('Vito è della Famiglia. Solo tu lo sai, per ora.', 'Vito is Family. Only you know it, for now.'), table),
            ),
            'dawnFilms-1': Scene(coach: dawnFilm),
            'dawn-1': Scene(coach: readyLine),
            'discussion-1': Scene(
              opening: [
                Say('s5', t('Bruno non faceva male a nessuno. Chi lo voleva morto?', 'Bruno never hurt anyone. Who wanted him dead?')),
                Say('s2', t('Io ero al bar tutta sera. Chiedete al 4.', 'I was at the bar all night. Ask 4.')),
                Say('s4', t('Confermo. Guardate il 6, piuttosto: troppo calmo.', 'True. Look at 6 instead: far too calm.')),
                const Toss('s4', 's6', TableGesture.eye),
                Say('s6', t('Io?? Commissario, tu cosa sai?', 'Me?? Detective, what do you know?')),
              ],
              replies: [
                t('Ho indagato su Vito: è della Famiglia.', 'I checked Vito: Family.'),
                t('Il 2 mente. L\'ho visto stanotte.', '2 is lying. I saw him tonight.'),
              ],
              answer: [
                Say('s2', t('Bugiardo! Vuole solo confondervi.', 'Liar! He just wants to confuse you.')),
                const Toss('s2', 's1', TableGesture.eye),
                Say('s5', t('Se lo dice il Commissario, io ci sto.', 'If the Detective says so, I am in.')),
                Say('s6', t('Anche io. Si vota il 2.', 'Me too. We vote 2.')),
              ],
              coach: TutorialCoach(t('In piazza si parla. Di\' quello che sai su Vito.', 'The square talks. Say what you know about Vito.'), chat),
              answered: TutorialCoach(t('Ti credono. «Pronto», e si vota.', 'They believe you. «Ready», and we vote.'), ready),
            ),
            'vote-1': Scene(
              opening: [
                const Move(DayVote('s4', 's6')),
                const Move(DayVote('s2', 's1')),
                const Move(DayVote('s6', 's4')),
                const Move(DayVote('s5', 's2')),
                Say('s6', t('Ripensandoci... il 2.', 'On second thought... 2.')),
                const Move(DayVote('s6', 's2')),
              ],
              expect: {'s2'},
              coach: TutorialCoach(t('Guarda le mani: cambiano idea. Punta il dito su Vito.', 'Watch the hands: minds change. Point at Vito.'), seat('s2')),
            ),
            'verdict-1': Scene(
              coach: TutorialCoach(t('Il linciato scopre la carta. La piazza ha visto giusto.', 'The lynched shows the card. The square got it right.'), verdict),
            ),
            'night-2': Scene(
              opening: const [Move(MafiaVote('s4', 's1')), Move(NightAction('s5', 's1')), Move(Pass('s6'))],
              expect: {'s4'},
              coach: TutorialCoach(t('Un\'altra notte. Indaga su Carmela, la 4.', 'Another night. Check Carmela, seat 4.'), seat('s4')),
              acted: TutorialCoach(t('Anche Carmela è della Famiglia.', 'Carmela is Family too.'), table),
            ),
            'dawnFilms-2': Scene(coach: TutorialCoach(t('Stanotte cercavano te...', 'Tonight they came for you...'))),
            'dawn-2': Scene(coach: TutorialCoach(t('Il Dottore ti ha salvato. Ora tocca a te.', 'The Doctor saved you. Your move now.'), ready)),
            'discussion-2': Scene(
              opening: [
                Say('s5', t('Stanotte ho vegliato sul Commissario. Ci hanno provato.', 'I watched over the Detective tonight. They tried.')),
                Say('s4', t('Che fortuna... ma Vito agiva da solo.', 'Lucky you... but Vito acted alone.')),
                Say('s6', t('Commissario, su chi hai indagato stanotte?', 'Detective, who did you check tonight?')),
              ],
              replies: [
                t('Su Carmela: è della Famiglia.', 'Carmela: Family.'),
                t('La 4 è l\'ultima. Votatela.', '4 is the last one. Vote her.'),
              ],
              answer: [
                Say('s4', t('Ma figurati! Il 1 delira.', 'Oh please! 1 is raving.')),
                Say('s5', t('Io ti ho salvato: mi fido.', 'I saved you: I trust you.')),
                const Toss('s5', 's1', TableGesture.toast),
                Say('s6', t('Votiamo la 4.', 'We vote 4.')),
              ],
              coach: TutorialCoach(t('Ultima giornata. Di\' alla piazza di Carmela.', 'Last day. Tell the square about Carmela.'), chat),
              answered: TutorialCoach(t('Bene. «Pronto», e si vota.', 'Good. «Ready», and we vote.'), ready),
            ),
            'vote-2': Scene(
              opening: [
                const Move(DayVote('s4', 's1')),
                const Move(DayVote('s5', 's4')),
                const Move(DayVote('s6', 's5')),
                Say('s6', t('No, aspetta: la 4.', 'No, wait: 4.')),
                const Move(DayVote('s6', 's4')),
              ],
              expect: {'s4'},
              coach: TutorialCoach(t('Vota Carmela.', 'Vote Carmela.'), seat('s4')),
            ),
            'verdict-2': Scene(
              coach: TutorialCoach(t('Niente più Famiglia: la città ha vinto.', 'No Family left: the town wins.'), verdict),
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
          winLine: t(
            'La Famiglia vince quando è tanta quanto la città. Di giorno, mentite bene.',
            'The Family wins once it matches the town in number. By day, lie well.',
          ),
          scenes: {
            'reveal-1': Scene(
              coach: TutorialCoach(
                t('Stavolta sei della Famiglia. Tieni premuta la carta, poi «Pronto».', 'This time you are Family. Hold the card, then «Ready».'),
                card,
              ),
            ),
            'night-1': Scene(
              opening: [
                Say('s2', t('Siamo noi due. Nessuno deve saperlo.', 'Just the two of us. Nobody can know.'), family: true),
                Say('s2', t('Io dico il 6, Enzo: fa troppe domande. Tu?', 'I say 6, Enzo: too many questions. You?'), family: true),
                const Move(MafiaVote('s2', 's6')),
                const Move(NightAction('s4', 's6')),
                const Move(Pass('s3')),
                const Move(Pass('s5')),
                const Move(Pass('s6')),
              ],
              replies: [t('Ok, il 6.', 'Ok, 6.'), t('Va bene, Enzo stanotte.', 'Fine, Enzo tonight.')],
              answer: [Say('s2', t('Perfetto. Tocca il 6.', 'Perfect. Tap 6.'), family: true)],
              expect: {'s6'},
              coach: TutorialCoach(t('Di notte la Famiglia parla in segreto. Rispondi a Vito.', 'At night the Family talks in secret. Answer Vito.'), chat),
              answered: TutorialCoach(t('Ora tocca Enzo, il 6: è il tuo voto.', 'Now tap Enzo, seat 6: that is your vote.'), seat('s6')),
              acted: TutorialCoach(t('Due voti su Enzo: la Famiglia è d\'accordo.', 'Two votes on Enzo: the Family agrees.'), table),
            ),
            'dawnFilms-1': Scene(coach: dawnFilm),
            'dawn-1': Scene(
              coach: TutorialCoach(t('Enzo è vivo: il Dottore l\'ha salvato. Si riprova.', 'Enzo lives: the Doctor saved him. Try again later.'), ready),
            ),
            'discussion-1': Scene(
              opening: [
                Say('s5', t('Stanotte qualcuno è entrato da Enzo.', 'Someone went to Enzo\'s tonight.')),
                Say('s6', t('Sono vivo per miracolo. Chi è stato?', 'Alive by a miracle. Who was it?')),
                Say('s3', t('Il 1 ieri sera girava per strada. L\'ho visto io.', '1 was out on the street last night. I saw him.')),
                const Toss('s3', 's1', TableGesture.eye),
                Say('s6', t('Allora, 1? Parla.', 'Well, 1? Talk.')),
                Say('s2', t('Calma, il 1 era al bar con me.', 'Easy, 1 was at the bar with me.')),
              ],
              replies: [
                t('Bruno accusa per primo: chi accusa per primo nasconde qualcosa.', 'Bruno accuses first: whoever accuses first hides something.'),
                t('Io dormivo. Ma il 3 sa troppe cose, no?', 'I was asleep. But 3 knows a lot, no?'),
              ],
              answer: [
                Say('s4', t('In effetti Bruno ha fretta.', 'Bruno is in a hurry, indeed.')),
                Say('s2', t('Lo dicevo io. Il 3 è strano.', 'Told you. 3 is weird.')),
                const Toss('s2', 's3', TableGesture.cigar),
                Say('s3', t('Ma che dite?! Sono pulito!', 'What?! I am clean!')),
              ],
              coach: TutorialCoach(t('Ti accusano. Non difenderti: sposta i sospetti su Bruno, il 3.', 'They accuse you. Do not defend: shift it onto Bruno, seat 3.'), chat),
              answered: TutorialCoach(t('Ha funzionato. «Pronto», e si vota.', 'It worked. «Ready», and we vote.'), ready),
            ),
            'vote-1': Scene(
              opening: [
                const Move(DayVote('s3', 's1')),
                const Move(DayVote('s6', 's1')),
                const Move(DayVote('s5', 's1')),
                const Move(DayVote('s2', 's3')),
                const Move(DayVote('s4', 's3')),
                Say('s5', t('Ho cambiato idea: il 3.', 'Changed my mind: 3.')),
                const Move(DayVote('s5', 's3')),
              ],
              expect: {'s3'},
              coach: TutorialCoach(t('Le mani si muovono. Vota Bruno, il 3, con loro.', 'Hands are moving. Vote Bruno, seat 3, with them.'), seat('s3')),
            ),
            'verdict-1': Scene(
              coach: TutorialCoach(t('Bruno era innocente. Tu sei salvo, per oggi.', 'Bruno was innocent. You are safe, for today.'), verdict),
            ),
            'night-2': Scene(
              opening: [
                Say('s2', t('Il Dottore ha salvato Enzo. Scommetto che è la 4.', 'The Doctor saved Enzo. I bet it is 4.'), family: true),
                Say('s2', t('Stanotte lei. Ci stai?', 'Her tonight. You in?'), family: true),
                const Move(MafiaVote('s2', 's4')),
                const Move(NightAction('s4', 's5')),
                const Move(Pass('s5')),
                const Move(Pass('s6')),
              ],
              replies: [t('Ci sto: la 4.', 'I am in: 4.'), t('D\'accordo, Carmela.', 'Fine, Carmela.')],
              answer: [Say('s2', t('Andiamo.', 'Let\'s go.'), family: true)],
              expect: {'s4'},
              coach: TutorialCoach(t('Vito ha un\'idea. Rispondigli.', 'Vito has an idea. Answer him.'), chat),
              answered: TutorialCoach(t('Tocca Carmela, la 4.', 'Tap Carmela, seat 4.'), seat('s4')),
            ),
            'dawnFilms-2': Scene(coach: dawnFilm),
            'dawn-2': Scene(
              coach: TutorialCoach(t('Due contro due: la città non può più vincere.', 'Two against two: the town can no longer win.')),
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
          winLine: t(
            'Chi gioca da solo ha un obiettivo suo: il Fesso vince se lo linciano, e la partita continua senza di lui.',
            'Solo players have their own goal: the Fool wins if lynched, and the game goes on without him.',
          ),
          scenes: {
            'reveal-1': Scene(
              coach: TutorialCoach(
                t('Giochi da solo: sei il Fesso, vinci se ti linciano. Tieni premuta la carta.', 'You play alone: the Fool wins if lynched. Hold the card.'),
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
              coach: TutorialCoach(t('Il Fesso non ha poteri: tocca chi vuoi per far finta.', 'The Fool has no power: tap anyone to pretend.'), table),
              acted: TutorialCoach(t('Di notte non fai niente. Il tuo lavoro è di giorno.', 'At night you do nothing. Your work is by day.'), table),
            ),
            'dawnFilms-1': Scene(coach: dawnFilm),
            'dawn-1': Scene(coach: TutorialCoach(t('Bruno non c\'è più. Ora si parla.', 'Bruno is gone. Now we talk.'), ready)),
            'discussion-1': Scene(
              opening: [
                Say('s5', t('Bruno è morto. Qualcuno ha visto qualcosa?', 'Bruno is dead. Anyone see anything?')),
                Say('s2', t('Io dormivo. Il 1 invece stanotte era sveglio.', 'I was asleep. 1 was up all night though.')),
                Say('s6', t('Già, il 1 non mi convince.', 'Yeah, 1 does not convince me.')),
                const Toss('s6', 's1', TableGesture.eye),
                Say('s4', t('Diamogli una possibilità. Allora, 1?', 'Give him a chance. So, 1?')),
              ],
              replies: [
                t('Bruno? Uno in meno. Non piangerò.', 'Bruno? One less. I won\'t cry.'),
                t('Non dico niente. Votatemi, se avete coraggio.', 'I say nothing. Vote me, if you dare.'),
              ],
              answer: [
                Say('s2', t('Avete sentito? Confessa quasi!', 'You heard that? Nearly a confession!')),
                const Toss('s2', 's1', TableGesture.cigar),
                Say('s5', t('Il 1 è strano forte. Io voto lui.', '1 is seriously weird. I vote him.')),
                Say('s4', t('Mi dispiace, 1: hai fatto tutto da solo.', 'Sorry, 1: you did it all yourself.')),
              ],
              coach: TutorialCoach(t('Fai il sospetto: di\' qualcosa che un innocente non direbbe.', 'Act shady: say something no innocent would.'), chat),
              answered: TutorialCoach(t('Ci sono cascati. «Pronto», e si vota.', 'They fell for it. «Ready», and we vote.'), ready),
            ),
            'vote-1': Scene(
              opening: [
                const Move(DayVote('s5', 's1')),
                const Move(DayVote('s2', 's6')),
                const Move(DayVote('s6', 's1')),
                const Move(DayVote('s4', 's2')),
                Say('s2', t('Va be\', anch\'io il 1.', 'Fine, me too: 1.')),
                const Move(DayVote('s2', 's1')),
                const Move(DayVote('s4', 's1')),
              ],
              coach: TutorialCoach(t('Tutti puntano te. Vota chi vuoi: non conta.', 'Everyone points at you. Vote anyone: it does not matter.'), table),
            ),
            'verdict-1': Scene(
              coach: TutorialCoach(t('Ti hanno linciato: proprio quello che volevi.', 'They lynched you: exactly what you wanted.'), verdict),
            ),
          },
        );
    }
  }
}
