import 'app_language.dart';

/// The words of the one-phone table that the online table does not have:
/// the curtain between two hands, the night pick that waits for a confirm,
/// and the open vote where the phone stays in the middle and every voter
/// takes a turn. Italian and English.
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
  String get openVote =>
      _m('openVote');
  String votedLine(String voter, String target) => _m('votedLine', {'voter': voter, 'target': target});
  String abstainedLine(String voter) => _m('abstainedLine', {'voter': voter});
  String get undo => _m('undo');
  String get notTheMayor => _m('notTheMayor');
}
