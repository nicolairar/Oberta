import 'package:flutter/widgets.dart';

import '../online/safety.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// Dove scrivere per le segnalazioni urgenti.
const safetyContactEmail = 'niko.tana@outlook.com';

/// I testi di segnalazioni, blocchi e regole della community.
class SafetyStrings {
  final AppLanguage language;

  const SafetyStrings(this.language);

  static SafetyStrings of(BuildContext context) => SafetyStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get report => _t('Segnala', 'Report');
  String get block => _t('Blocca', 'Block');
  String get unblock => _t('Sblocca', 'Unblock');
  String get cancel => _t('Annulla', 'Cancel');
  String get send => _t('Invia segnalazione', 'Send report');

  String reportTitle(String name) => _t('Segnala $name', 'Report $name');
  String get reportWhy => _t('Che cosa è successo?', 'What happened?');
  String reason(ReportReason reason) => switch (reason) {
        ReportReason.language => _t('Linguaggio offensivo', 'Offensive language'),
        ReportReason.cheating => _t('Bara o abbandona le partite', 'Cheating or abandoning games'),
        ReportReason.identity => _t('Nome o aspetto inappropriato', 'Inappropriate username or look'),
        ReportReason.spam => _t('Spam', 'Spam'),
        ReportReason.other => _t('Altro', 'Other'),
      };
  String get noteHint => _t('Dettagli (facoltativo)', 'Details (optional)');
  String get reportPrivate => _t(
        'La segnalazione è anonima: il giocatore non saprà chi l\'ha fatta.',
        'Reports are anonymous: the player will not know who sent it.',
      );
  String get reportSent => _t('Segnalazione inviata. Grazie.', 'Report sent. Thank you.');
  String get reportedMessage => _t('Messaggio segnalato', 'Reported message');

  String blockTitle(String name) => _t('Bloccare $name?', 'Block $name?');
  String get blockBody => _t(
        'Non vedrai più i suoi messaggi, non sarete più amici, e non potrà chiederti l\'amicizia né entrare nelle tue '
            'stanze. In classificata si cercherà di non mettervi allo stesso tavolo. Puoi sbloccarlo dalle impostazioni.',
        'You will no longer see their messages, you will stop being friends, and they cannot send you friend requests '
            'or join your rooms. Ranked will try to keep you at different tables. You can unblock them in Settings.',
      );
  String blocked(String name) => _t('$name è bloccato.', '$name is blocked.');
  String unblocked(String name) => _t('$name è sbloccato.', '$name is unblocked.');

  String get blockedPlayers => _t('Giocatori bloccati', 'Blocked players');
  String get blockedHint => _t('Chi hai bloccato, e come sbloccarlo.', 'Who you blocked, and how to unblock them.');
  String get noneBlocked => _t('Non hai bloccato nessuno.', 'You have not blocked anyone.');

  String get rulesTitle => _t('Regole della community', 'Community rules');
  String get rulesHint => _t('Come si sta al tavolo.', 'How we behave at the table.');
  List<String> get rules => _en
      ? const [
          'Lie in the game, not to people. Bluffing is part of Obertà; insults, threats and harassment are not.',
          'No hate speech, slurs, sexual content or attacks on anyone\'s origin, religion, gender, orientation or disability.',
          'Usernames and looks must be decent: no offensive names, no pretending to be staff or another player.',
          'Play your game to the end. Abandoning, throwing on purpose or teaming up outside the game spoils it for everyone.',
          'No spam, ads, links or personal data: never share phone numbers, addresses or social accounts.',
          'Be kind to new players. Everyone was new once.',
        ]
      : const [
          'Si mente nel gioco, non alle persone. Il bluff fa parte di Obertà; insulti, minacce e molestie no.',
          'Niente odio, insulti razziali, contenuti sessuali o attacchi a origine, religione, genere, orientamento o disabilità.',
          'Nomi e aspetto decenti: niente nomi offensivi, niente finti membri dello staff o finti altri giocatori.',
          'Gioca la partita fino in fondo. Abbandonare, perdere apposta o accordarsi fuori dal gioco la rovina a tutti.',
          'Niente spam, pubblicità, link o dati personali: mai numeri di telefono, indirizzi o profili social.',
          'Sii gentile con chi è nuovo. Lo siamo stati tutti.',
        ];
  String get rulesEnforcement => _t(
        'Puoi segnalare un giocatore tenendo premuto il suo posto o un suo messaggio. Le segnalazioni vengono esaminate: '
            'chi non rispetta le regole può perdere la chat, la classificata o l\'account. I messaggi e i nomi '
            'offensivi vengono bloccati in automatico.',
        'You can report a player by long-pressing their seat or one of their messages. Every report is reviewed: '
            'players who break the rules can lose chat, ranked or their account. Offensive messages and names '
            'are blocked automatically.',
      );
  String get rulesContact => _t('Per segnalazioni urgenti scrivi a', 'For urgent reports, email');
}
