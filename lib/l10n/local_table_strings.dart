import 'app_language.dart';

/// The words of the one-phone table that the online table does not have:
/// the curtain between two hands, the night pick that waits for a confirm,
/// the vote out loud where one taps the verdict, and the secret vote where
/// the phone goes round, one ballot each.
class LocalTableStrings {
  final AppLanguage language;

  const LocalTableStrings(this.language);

  /// The text under `localTable.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('localTable.$key', args);

  // ---- The night.
  String pickedConfirm(String name) =>
      _m('pickedConfirm', {'name': name});
  /// Under a seat, what an investigation said about them.
  String get familyNote => _m('familyNote');
  String get cleanNote => _m('cleanNote');

  // ---- The day.
  String get discuss => _m('discuss');
  String get undo => _m('undo');

  // ---- How the square votes, chosen before the deal.
  String get voteTitle => _m('voteTitle');
  String get voteHeadline => _m('voteHeadline');
  String get voteIntro => _m('voteIntro');
  String get secretVote => _m('secretVote');
  String get voiceVoteHint => _m('voiceVoteHint');
  String get secretVoteHint => _m('secretVoteHint');
  String get voteNext => _m('voteNext');

  // ---- The vote out loud: the table talks, one taps the verdict.
  String get voiceVoteTitle => _m('voiceVoteTitle');
  String get voiceVote => _m('voiceVote');
  String get tieRule => _m('tieRule');
  String condemnConfirm(String name) => _m('condemnConfirm', {'name': name});
  String get tieNobody => _m('tieNobody');
  String condemn(String name) => _m('condemn', {'name': name});
  String get backToTalk => _m('backToTalk');

  // ---- The secret vote: the phone goes round, one ballot each.
  String mustVote(String name) => _m('mustVote', {'name': name});
  String get secretBallot => _m('secretBallot');
  String votePicked(String name) => _m('votePicked', {'name': name});
  String get castVote => _m('castVote');
}
