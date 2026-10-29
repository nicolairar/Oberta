import 'package:flutter/widgets.dart';

import '../online/safety.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// Dove scrivere per le segnalazioni urgenti.
const safetyContactEmail = 'oberta@charliemobile.dev';

/// I testi di segnalazioni, blocchi e regole della community.
class SafetyStrings {
  final AppLanguage language;

  const SafetyStrings(this.language);

  static SafetyStrings of(BuildContext context) => SafetyStrings(AppStrings.of(context).language);

  /// The text under `safety.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('safety.$key', args);

  String get report => _m('report');
  String get block => _m('block');
  String get unblock => _m('unblock');
  String get cancel => _m('cancel');
  String get send => _m('send');

  String reportTitle(String name) => _m('reportTitle', {'name': name});
  String get reportWhy => _m('reportWhy');
  String reason(ReportReason reason) => switch (reason) {
        ReportReason.language => _m('reason.language'),
        ReportReason.cheating => _m('reason.cheating'),
        ReportReason.identity => _m('reason.identity'),
        ReportReason.spam => _m('reason.spam'),
        ReportReason.other => _m('reason.other'),
      };
  String get noteHint => _m('noteHint');
  String get reportPrivate => _m('reportPrivate');
  String get reportSent => _m('reportSent');
  String get reportedMessage => _m('reportedMessage');

  String blockTitle(String name) => _m('blockTitle', {'name': name});
  String get blockBody => _m('blockBody');
  String get muteChat => _m('muteChat');
  String get unmuteChat => _m('unmuteChat');
  String chatMuted(String name) =>
      _m('chatMuted', {'name': name});
  String chatUnmuted(String name) => _m('chatUnmuted', {'name': name});
  String seat(int number) => _m('seat', {'number': number});
  String get atTable => _m('atTable');
  String get outOfGame => _m('outOfGame');
  String get inRoom => _m('inRoom');

  String blocked(String name) => _m('blocked', {'name': name});
  String unblocked(String name) => _m('unblocked', {'name': name});

  String get blockedPlayers => _m('blockedPlayers');
  String get blockedHint => _m('blockedHint');
  String get noneBlocked => _m('noneBlocked');

  String get rulesTitle => _m('rulesTitle');
  String get rulesHint => _m('rulesHint');
  /// The community rules, one per line.
  List<String> get rules => [for (var i = 1; i <= 6; i++) _m('rules.$i')];
  String get rulesEnforcement => _m('rulesEnforcement');
  String get rulesContact => _m('rulesContact');
}
