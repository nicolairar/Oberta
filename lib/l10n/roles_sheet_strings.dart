import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// I testi del foglio «I ruoli» e delle spiegazioni delle icone di stato:
/// ogni simbolo al tavolo ha la sua parola.
class RolesSheetStrings {
  final String button;
  final String title;
  final String subtitle;
  final String deckEmpty;
  final String legendTitle;
  final String Function(String name) revealedBy;
  final String silenced;
  final String silencedLegend;
  final String offline;
  final String offlineLegend;
  final String dead;
  final String deadLegend;
  final String accused;
  final String accusedLegend;
  final String votes;
  final String votesLegend;
  final String voteNote;
  final String voteNoteLegend;
  final String revealedRole;
  final String revealedRoleLegend;
  final String selected;
  final String meLegend;
  final String teamLabel;
  final String nightLabel;
  final String winLabel;
  final String twistLabel;
  final String teamFamily;
  final String teamTown;
  final String teamAlone;

  const RolesSheetStrings({
    required this.button,
    required this.title,
    required this.subtitle,
    required this.deckEmpty,
    required this.legendTitle,
    required this.revealedBy,
    required this.silenced,
    required this.silencedLegend,
    required this.offline,
    required this.offlineLegend,
    required this.dead,
    required this.deadLegend,
    required this.accused,
    required this.accusedLegend,
    required this.votes,
    required this.votesLegend,
    required this.voteNote,
    required this.voteNoteLegend,
    required this.revealedRole,
    required this.revealedRoleLegend,
    required this.selected,
    required this.meLegend,
    required this.teamLabel,
    required this.nightLabel,
    required this.winLabel,
    required this.twistLabel,
    required this.teamFamily,
    required this.teamTown,
    required this.teamAlone,
  });

  static RolesSheetStrings of(BuildContext context) => forLanguage(AppStrings.of(context).language);

  static RolesSheetStrings forLanguage(AppLanguage language) {
    String m(String key) => language.message('rolesSheet.$key');
    return RolesSheetStrings(
      button: m('button'),
      title: m('title'),
      subtitle: m('subtitle'),
      deckEmpty: m('deckEmpty'),
      legendTitle: m('legendTitle'),
      revealedBy: (name) => language.message('rolesSheet.revealedBy', {'name': name}),
      silenced: m('silenced'),
      silencedLegend: m('silencedLegend'),
      offline: m('offline'),
      offlineLegend: m('offlineLegend'),
      dead: m('dead'),
      deadLegend: m('deadLegend'),
      accused: m('accused'),
      accusedLegend: m('accusedLegend'),
      votes: m('votes'),
      votesLegend: m('votesLegend'),
      voteNote: m('voteNote'),
      voteNoteLegend: m('voteNoteLegend'),
      revealedRole: m('revealedRole'),
      revealedRoleLegend: m('revealedRoleLegend'),
      selected: m('selected'),
      meLegend: m('meLegend'),
      teamLabel: m('teamLabel'),
      nightLabel: m('nightLabel'),
      winLabel: m('winLabel'),
      twistLabel: m('twistLabel'),
      teamFamily: m('teamFamily'),
      teamTown: m('teamTown'),
      teamAlone: m('teamAlone'),
    );
  }
}
