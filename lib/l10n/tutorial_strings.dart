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

  /// The text under `tutorial.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('tutorial.$key', args);

  String get you => _m('you');
  String get skip => _m('skip');
  String get exit => _m('exit');
  String get exitTitle => _m('exitTitle');
  String get exitBody => _m('exitBody');
  String get stay => _m('stay');

  // Il biglietto sul vicolo, e le voci per rifarlo.
  String get hint => _m('hint');
  String get hintGo => _m('hintGo');
  String get replay => _m('replay');
  String get replayHint => _m('replayHint');
  String get deskButton => _m('deskButton');

  // La scelta.
  String get choose => _m('choose');
  String get chooseSub => _m('chooseSub');
  String faction(TutorialStory story) => switch (story) {
    TutorialStory.family => _m('faction.family'),
    TutorialStory.city => _m('faction.city'),
    TutorialStory.solo => _m('faction.solo'),
  };
  String pitch(TutorialStory story) => switch (story) {
    TutorialStory.family => _m('pitch.family'),
    TutorialStory.city => _m('pitch.city'),
    TutorialStory.solo => _m('pitch.solo'),
  };
  String get done => _m('done');

  // La fine.
  String get ready => _m('ready');
  String get toTheTable => _m('toTheTable');
  String get nextHand => _m('nextHand');
}
