// La bottega, per guardarla senza telefono:
// `flutter test tool/render/shop_render_test.dart` scrive i PNG in OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/player_avatar.dart';

final out = Platform.environment['OUT'] ?? 'build/render/shop';

const _fonts = {
  'Georgia': ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf'],
  'serif': ['Georgia.ttf', 'Georgia Bold.ttf'],
  'Courier': ['Courier New.ttf', 'Courier New Bold.ttf'],
};

Future<void> _loadFonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  for (final MapEntry(key: family, value: files) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$dir/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
  final material =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}'
      '/bin/cache/artifacts/material_fonts';
  for (final (family, files) in [
    ('MaterialIcons', ['MaterialIcons-Regular.otf']),
    ('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Italic.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$material/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
}

final _key = GlobalKey();

/// Il tema dell'app, con i caratteri caricati anche dove i test non li mettono.
ThemeData _theme() {
  final theme = buildAppTheme();
  const label = WidgetStatePropertyAll(
    TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, letterSpacing: 1.6, fontSize: 14),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    elevatedButtonTheme: ElevatedButtonThemeData(style: theme.elevatedButtonTheme.style!.copyWith(textStyle: label)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: theme.outlinedButtonTheme.style!.copyWith(textStyle: label)),
    textButtonTheme: const TextButtonThemeData(style: ButtonStyle(textStyle: label)),
  );
}

Future<void> _shot(WidgetTester tester, String name, {bool settle = true}) async {
  if (settle) await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('bottega', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    final online = FakeOnline()..signInReady(handle: 'anna', coins: 3800);
    await tester.runAsync(() async {
      await online.shop.buy('hat.borsalino');
      await online.shop.equip('hat.borsalino');
      await online.shop.buy('face.handlebar');
      await online.shop.equip('face.handlebar', tone: 'olive');
    });
    final account = OnlineAccount(online.services);
    Widget app(Widget home, {AppLanguage language = AppLanguage.it}) => RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        locale: language.locale,
        supportedLocales: AppLanguage.locales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: home,
      ),
    );
    await tester.pumpWidget(app(ShopScreen(account: account, shop: online.shop)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _shot(tester, '00_counter');
    await tester.tap(find.byKey(const Key('shop.featured.outfit.vaugirard_travel')));
    await _shot(tester, '01_try_trench');
    await tester.tap(find.byKey(const Key('shop.action')));
    await _shot(tester, '02_receipt');
    await tester.tap(find.byKey(const Key('shop.confirm')));
    await _shot(tester, '03_bought');
    await tester.tap(find.byKey(const Key('shop.tab.wardrobe')));
    await tester.tap(find.byKey(const Key('shop.slot.face')));
    await _shot(tester, '04_wardrobe');
    await tester.tap(find.byKey(const Key('shop.tab.counter')));
    await tester.tap(find.byKey(const Key('shop.slot.brands')));
    await tester.pump();
    final pick = find.byKey(const Key('shop.item.accessory.chanterellePearls'));
    if (pick.evaluate().isNotEmpty) await tester.tap(pick);
    await _shot(tester, '06_brands');
    await tester.tap(find.byKey(const Key('shop.slot.oddities')));
    await tester.pump();
    await _shot(tester, '07_oddities');

    // I pezzi della seconda consegna (e quelli ritoccati), uno per moneta.
    final base = AvatarLook.fallback('anna');
    tester.view.physicalSize = const Size(97.0 * 8, 118.0 * 5) * 3;
    const fixed = {'face.pencil', 'face.imperial', 'accessory.pocketWatch', 'outfit.black_tuxedo'};
    final items = Platform.environment['SHEET'] == 'houses'
        ? [
            for (final item in initialShopCatalog)
              if (fixed.contains(item.id)) item,
            for (final item in [...brandDrop, ...houseDrop])
              if (item.brand != null) item,
          ]
        : odditiesDrop;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: AppColors.background,
            child: Wrap(
              children: [
                for (final item in items)
                  SizedBox(
                    width: 97,
                    height: 118,
                    child: Column(
                      children: [
                        PlayerAvatar(
                          seed: 'x',
                          size: 92,
                          look: base.wearing(LookSlot.values.byName(item.slot), item.lookId),
                        ),
                        Text(
                          item.nameEn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 9, color: rarityColor(item.rarity)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await _shot(tester, '05_items');
  });
}
