// Le medaglie del gioco, pronte per Steamworks: lo stesso catalogo di
// lib/online/game/progress.dart, con nomi e descrizioni in italiano e inglese.
// `flutter test tool/render/steam_achievements_render_test.dart` riscrive
// steam/store/achievements.csv e steam/store/achievements.md.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/progress_strings.dart';
import 'package:oberta/online/game/progress.dart';

String _csv(String value) => value.contains(RegExp('[",\n]')) ? '"${value.replaceAll('"', '""')}"' : value;

void main() {
  test('le medaglie per Steamworks', () {
    const it = ProgressStrings(AppLanguage.it);
    const en = ProgressStrings(AppLanguage.en);
    final csv = StringBuffer('api_name,name_en,name_it,description_en,description_it,hidden\n');
    final md = StringBuffer()
      ..writeln('# Steam achievements')
      ..writeln()
      ..writeln('Generated from `lib/online/game/progress.dart` by '
          '`tool/render/steam_achievements_render_test.dart`: ${achievements.length} achievements.')
      ..writeln('The API name is the in-game id: never rename it. None is hidden: the game shows them all.')
      ..writeln('Icons (64×64 achieved / unachieved) still to make.')
      ..writeln()
      ..writeln('| API name | Name (EN) | Name (IT) | Description (EN) | Description (IT) | Hidden |')
      ..writeln('|---|---|---|---|---|---|');
    for (final a in achievements) {
      final (nameIt, descIt) = it.achievement(a.id);
      final (nameEn, descEn) = en.achievement(a.id);
      expect(descEn, isNotEmpty, reason: a.id);
      csv.writeln([a.id, nameEn, nameIt, descEn, descIt, 'no'].map(_csv).join(','));
      md.writeln('| `${a.id}` | $nameEn | $nameIt | $descEn | $descIt | no |');
    }
    File('steam/store/achievements.csv')
      ..createSync(recursive: true)
      ..writeAsStringSync(csv.toString());
    File('steam/store/achievements.md').writeAsStringSync(md.toString());
  });
}
