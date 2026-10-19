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

  static RolesSheetStrings forLanguage(AppLanguage language) => switch (language) {
        AppLanguage.it => it,
        AppLanguage.en => en,
      };

  static final it = RolesSheetStrings(
    button: 'RUOLI',
    title: 'I ruoli in gioco',
    subtitle: 'Le carte di questa partita. Chi le ha in mano resta segreto.',
    deckEmpty: 'Il mazzo non è ancora noto.',
    legendTitle: 'Cosa vogliono dire i simboli',
    revealedBy: (name) => 'rivelato: $name',
    silenced: 'zittito',
    silencedLegend: 'zittito dal Sarto: non può scrivere oggi, ma vota',
    offline: 'assente',
    offlineLegend: 'pallino grigio: il giocatore si è scollegato',
    dead: 'morto',
    deadLegend: 'garofano o pugnale: il giocatore è morto',
    accused: 'accusato',
    accusedLegend: 'nastro ACCUSATO: il più votato in questo momento',
    votes: 'voti ricevuti',
    votesLegend: 'cerchio rosso col numero: i voti ricevuti',
    voteNote: 'ha votato',
    voteNoteLegend: 'bigliettino «→ nome»: chi ha votato',
    revealedRole: 'ruolo scoperto',
    revealedRoleLegend: 'icona o nome del ruolo sul posto: ruolo ormai noto a te',
    selected: 'scelto',
    meLegend: 'targhetta dorata: sei tu',
    teamLabel: 'Squadra',
    nightLabel: 'Di notte',
    winLabel: 'Vinci se',
    twistLabel: 'Attenzione',
    teamFamily: 'Famiglia',
    teamTown: 'Città',
    teamAlone: 'Da solo',
  );

  static final en = RolesSheetStrings(
    button: 'ROLES',
    title: 'Roles in play',
    subtitle: "This game's cards. Who holds them stays secret.",
    deckEmpty: 'The deck is not known yet.',
    legendTitle: 'What the symbols mean',
    revealedBy: (name) => 'revealed: $name',
    silenced: 'silenced',
    silencedLegend: 'silenced by the Tailor: cannot write today, can still vote',
    offline: 'away',
    offlineLegend: 'grey dot: the player has disconnected',
    dead: 'dead',
    deadLegend: 'carnation or dagger: the player is dead',
    accused: 'accused',
    accusedLegend: 'ACCUSED ribbon: the most voted right now',
    votes: 'votes received',
    votesLegend: 'red circle with a number: votes received',
    voteNote: 'voted for',
    voteNoteLegend: 'note "→ name": who they voted for',
    revealedRole: 'role revealed',
    revealedRoleLegend: 'role icon or name on a seat: a role known to you',
    selected: 'chosen',
    meLegend: 'gold name plate: that is you',
    teamLabel: 'Team',
    nightLabel: 'At night',
    winLabel: 'You win if',
    twistLabel: 'Watch out',
    teamFamily: 'the Family',
    teamTown: 'the town',
    teamAlone: 'on your own',
  );
}
