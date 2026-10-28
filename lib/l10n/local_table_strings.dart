import 'app_language.dart';

/// The words of the one-phone table that the online table does not have:
/// the curtain between two hands, the night pick that waits for a confirm,
/// and the open vote where the phone stays in the middle and every voter
/// takes a turn. Italian and English.
class LocalTableStrings {
  final AppLanguage language;

  const LocalTableStrings(this.language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  // ---- The night.
  String pickedConfirm(String name) =>
      _t('Hai scelto $name. Conferma, o tocca un altro posto.', 'You picked $name. Confirm, or tap another seat.');
  /// Under a seat, what an investigation said about them.
  String get familyNote => _t('famiglia', 'family');
  String get cleanNote => _t('pulito', 'clean');

  // ---- The day.
  String get discuss => _t('Discutete a voce. Poi si vota.', 'Talk it over out loud. Then you vote.');
  String get openVote =>
      _t('Il telefono resta in mezzo: si vota uno alla volta, a viso aperto.', 'The phone stays in the middle: one vote at a time, in the open.');
  String votedLine(String voter, String target) => _t('$voter vota $target.', '$voter votes $target.');
  String abstainedLine(String voter) => _t('$voter si astiene.', '$voter abstains.');
  String get undo => _t('Indietro', 'Back');
  String get notTheMayor => _t('Solo il Sindaco può rivelarsi.', 'Only the Mayor can reveal.');
}
