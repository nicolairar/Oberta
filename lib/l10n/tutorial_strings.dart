import 'package:flutter/widgets.dart';

import '../tutorial/tutorial_story.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// I testi intorno alle mani di prova (la scelta, la fine, le voci per
/// rifarle). Le battute dei bot e del narratore sono nel copione.
class TutorialStrings {
  final AppLanguage language;

  const TutorialStrings(this.language);

  static TutorialStrings of(BuildContext context) => TutorialStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get you => _t('Tu', 'You');
  String get skip => _t('Salta', 'Skip');
  String get exit => _t('Esci', 'Leave');
  String get exitTitle => _t('Lasciare la mano di prova?', 'Leave the practice hand?');
  String get exitBody => _t('Non conta come fatta: la potrai rifare quando vuoi.', 'It will not count as done: you can play it again any time.');
  String get stay => _t('Resta', 'Stay');

  // Il biglietto sul vicolo, e le voci per rifarlo.
  String get hint => _t('Prima volta? Tre mani di prova, una per colore.', 'First time? Three practice hands, one per colour.');
  String get hintGo => _t('Prova', 'Try');
  String get replay => _t('Tutorial', 'Tutorial');
  String get replayHint => _t('Tre mani di prova contro i bot.', 'Three practice hands against the bots.');
  String get deskButton => _t('Tutorial', 'Tutorial');

  // La scelta.
  String get choose => _t('Scegli da che parte imparare', 'Pick a side to learn');
  String get chooseSub => _t('Una mano contro cinque bot, sul tavolo vero.', 'One hand against five bots, on the real table.');
  String faction(TutorialStory story) => switch (story) {
    TutorialStory.family => _t('Famiglia', 'Family'),
    TutorialStory.city => _t('Città', 'Town'),
    TutorialStory.solo => _t('Da solo', 'On your own'),
  };
  String pitch(TutorialStory story) => switch (story) {
    TutorialStory.family => _t('Uccidi di notte, menti di giorno.', 'Kill by night, lie by day.'),
    TutorialStory.city => _t('Indaga e smaschera la Famiglia.', 'Investigate, unmask the Family.'),
    TutorialStory.solo => _t('Fatti linciare e vinci da solo.', 'Get lynched and win alone.'),
  };
  String get done => _t('Fatto', 'Done');

  // La fine.
  String get ready => _t('Ora sei pronto', 'Now you are ready');
  String get toTheTable => _t('Al tavolo', 'To the table');
  String get nextHand => _t('Un\'altra mano', 'Another hand');
}
