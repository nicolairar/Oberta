import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/build_flags.dart';

void main() {
  test('in debug e nei test gli strumenti di prova ci sono, la classificata resta chiusa', () {
    expect(BuildFlags.testTools, isTrue);
    expect(BuildFlags.testBuild, isFalse);
  });

  // Una build da negozio è pulita solo se ogni interruttore di prova passa da
  // lib/build_flags.dart: un `fromEnvironment('..._DEBUG')` sparso altrove
  // sarebbe un secondo interruttore da ricordarsi.
  test('nessun dart-define di prova fuori da lib/build_flags.dart', () {
    final debugDefine = RegExp(r'''fromEnvironment\(\s*['"][A-Z_]*(DEBUG|TEST|BOTS)[A-Z_]*['"]''');
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') && !file.path.endsWith('build_flags.dart'))
          if (debugDefine.hasMatch(file.readAsStringSync())) file.path,
    ];
    expect(offenders, isEmpty);
  });
}
