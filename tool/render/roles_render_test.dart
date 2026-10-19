// Il foglio dei ruoli e una carta scoperta, per leggerli senza telefono:
// `flutter test tool/render/roles_render_test.dart` scrive i PNG in OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/widgets/flip_role_card.dart';
import 'package:oberta/ui/widgets/roles_sheet.dart';

import '../../test/support/languages.dart';

final out = Platform.environment['OUT'] ?? 'build/render/roles';

Future<void> _loadFonts() async {
  final material =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts';
  const supplemental = '/System/Library/Fonts/Supplemental';
  for (final (family, files) in [
    ('Roboto', ['$material/Roboto-Regular.ttf', '$material/Roboto-Bold.ttf', '$material/Roboto-Black.ttf']),
    ('Georgia', ['$supplemental/Georgia.ttf', '$supplemental/Georgia Bold.ttf', '$supplemental/Georgia Italic.ttf']),
    ('serif', ['$supplemental/Georgia.ttf', '$supplemental/Georgia Bold.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final path in files) {
      final file = File(path);
      if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }
}

final _key = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _frame(AppLanguage language, Widget child) => RepaintBoundary(
      key: _key,
      child: appIn(language, DefaultTextStyle.merge(style: const TextStyle(fontFamily: 'Roboto'), child: child)),
    );

void main() {
  setUpAll(_loadFonts);

  for (final language in AppLanguage.values) {
    testWidgets('foglio dei ruoli, ${language.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 1700 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_frame(
        language,
        const Scaffold(
          body: RolesSheet(
            deck: {Role.padrino: 1, Role.mafioso: 2, Role.detective: 1, Role.medico: 1, Role.cacciatore: 1, Role.cittadino: 3},
            revealed: [(role: Role.mafioso, name: 'Marco')],
          ),
        ),
      ));
      await _shot(tester, 'sheet_${language.name}');
    });

    testWidgets('carta scoperta, ${language.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_frame(
        language,
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.fromLTRB(24, 80, 24, 120),
            child: FlipRoleCard(role: Role.padrino, teammates: [Player(id: 'a', name: 'Francesca')]),
          ),
        ),
      ));
      final hold = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
      await tester.pumpAndSettle();
      await _shot(tester, 'card_${language.name}');
      await hold.up();
    });
  }
}
