import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/rules_strings.dart';
import 'package:oberta/narration/voice_lines.dart';

/// I capoversi delle regole che i pacchetti non dicono già.
Iterable<String> _rulesLines(AppLanguage language) {
  final said = {for (final segment in voiceSegments(language.pack)) segment.text};
  return {
    for (final text in RulesStrings(language).spoken)
      if (!said.contains(normalizeVoiceText(text))) normalizeVoiceText(text),
  };
}

/// Scrive in `tool/voice/lines.json` tutto quello che la voce del narratore
/// può dover dire, lingua per lingua: è il copione da cui `generate.py`
/// incide le clip. Si lancia da `tool/voice/regenerate.sh`, o a mano:
///
///     flutter test tool/voice/dump_lines_test.dart
void main() {
  test('scrive il copione della voce', () {
    final dump = <String, Object>{
      for (final language in AppLanguage.values)
        language.name: [
          for (final segment in voiceSegments(language.pack))
            {'key': voiceKey(language.name, segment.text), 'kind': segment.kind, 'text': segment.text},
          // Le regole del gioco lette dalla voce del narratore («Fammela leggere»).
          for (final text in _rulesLines(language))
            {'key': voiceKey(language.name, text), 'kind': 'rules', 'text': text},
        ],
    };
    final file = File('tool/voice/lines.json');
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(dump)}\n');
    for (final language in AppLanguage.values) {
      final count = (dump[language.name]! as List).length;
      // ignore: avoid_print
      print('${language.name}: $count segmenti');
      expect(count, greaterThan(100));
    }
  });
}
