// The visual audit of the shop's Scene, Shoulders, Hands, Frame (frames and
// name inks), Gestures and Window departments: every piece as the shop's
// phone hero shows it (bust and seat card), its dial thumbnail, the real
// 74 px table seat with a short and a long name, the gestures in flight at
// key frames, and the desktop case with the mission-only pieces.
//
// `flutter test tool/audit/skins_scena_cornice_gesti_render_test.dart`
// writes labelled contact sheets to build/audit/skins_scena_cornice_gesti
// (`OUT=` for another folder, `ONLY=scene,frames` for some sheets only).
import 'dart:io';
import 'dart:math';
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
import 'package:oberta/ui/desktop/desktop_canvas.dart';
import 'package:oberta/ui/screens/online/game/noir_ui.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/screens/online/game/table_gestures.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

final out = Platform.environment['OUT'] ?? 'build/audit/skins_scena_cornice_gesti';
final _only = Platform.environment['ONLY']?.split(',').toSet();
bool _wants(String name) => _only?.contains(name) ?? true;

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
  final material = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts';
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

ThemeData _theme() {
  final theme = buildAppTheme();
  const label = WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, letterSpacing: 1.6, fontSize: 14));
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    elevatedButtonTheme: ElevatedButtonThemeData(style: theme.elevatedButtonTheme.style!.copyWith(textStyle: label)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: theme.outlinedButtonTheme.style!.copyWith(textStyle: label)),
    textButtonTheme: const TextButtonThemeData(style: ButtonStyle(textStyle: label)),
  );
}

final _key = GlobalKey();

Widget _app(Widget home, {AppLanguage language = AppLanguage.it}) => RepaintBoundary(
  key: _key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    locale: language.locale,
    supportedLocales: AppLanguage.locales,
    localizationsDelegates: const [AppStrings.delegate, GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
    home: home,
  ),
);

/// One picture on a sheet, with what it is.
typedef _Cell = ({String label, ui.Image image});

Future<ui.Image> _grab(WidgetTester tester, {double ratio = 3}) async =>
    (await tester.runAsync(() => (_key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: ratio)))!;

/// [logical] of a [ratio]x grab, drawn at [scale] pixels per point.
Future<ui.Image> _crop(WidgetTester tester, ui.Image src, Rect logical, {double ratio = 3, double scale = 1.5}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final dst = Offset.zero & (logical.size * scale);
  canvas.drawImageRect(src, Rect.fromLTRB(logical.left * ratio, logical.top * ratio, logical.right * ratio, logical.bottom * ratio), dst, Paint()..filterQuality = FilterQuality.high);
  final picture = recorder.endRecording();
  return (await tester.runAsync(() => picture.toImage(dst.width.ceil(), dst.height.ceil())))!;
}

/// Writes [cells] as labelled sheets of [per] cells, [cols] across:
/// `<name>_1.png`, `<name>_2.png`...
Future<void> _sheets(WidgetTester tester, String name, List<_Cell> cells, {int cols = 5, int per = 20, Color ground = const Color(0xFF141012)}) async {
  if (cells.isEmpty) return;
  final pages = (cells.length / per).ceil();
  for (var p = 0; p < pages; p++) {
    final page = cells.skip(p * per).take(per).toList();
    final cw = page.map((c) => c.image.width).reduce(max).toDouble();
    final ch = page.map((c) => c.image.height).reduce(max).toDouble();
    const gap = 14.0;
    const label = 34.0;
    final across = min(cols, page.length);
    final rows = (page.length / across).ceil();
    final size = Size(across * (cw + gap) + gap, rows * (ch + label + gap) + gap);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    for (final (i, cell) in page.indexed) {
      final at = Offset(gap + (i % across) * (cw + gap), gap + (i ~/ across) * (ch + label + gap));
      final tp = TextPainter(
        text: TextSpan(text: cell.label, style: const TextStyle(fontFamily: 'Roboto', fontSize: 22, color: Color(0xFFFFE7A8), fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: cw);
      tp.paint(canvas, at);
      tp.dispose();
      canvas.drawImage(cell.image, at + const Offset(0, label), Paint());
      canvas.drawRect((at + const Offset(0, label)) & Size(cell.image.width.toDouble(), cell.image.height.toDouble()), Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x553A3A3A));
    }
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(size.width.ceil(), size.height.ceil());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/${name}_${p + 1}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
  for (final c in cells) {
    c.image.dispose();
  }
}

// --- The phone shop ------------------------------------------------------

/// The thumbnails on the dial now, by key.
Map<String, Rect> _thumbs(WidgetTester tester) {
  final found = <String, Rect>{};
  for (final element in find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && (k.value.startsWith('shop.item.') || (k.value.startsWith('shop.bundle.') && k.value != 'shop.bundle.buy'));
  }).evaluate()) {
    final k = (element.widget.key! as ValueKey<String>).value;
    final box = element.renderObject! as RenderBox;
    if (!box.hasSize) continue;
    found[k.replaceFirst(RegExp(r'^shop\.(item|bundle)\.'), '')] = box.localToGlobal(Offset.zero) & box.size;
  }
  return found;
}

/// Walks the dial from its first piece to its last: for each, the hero and
/// the price tag ([heroes]) and the picked thumbnail ([thumbs]).
Future<void> _walk(WidgetTester tester, {required List<_Cell> heroes, List<_Cell>? thumbs, String suffix = '', bool once = false}) async {
  final seen = <String>{};
  final top = tester.getRect(find.byKey(const Key('shop.dept.window'))).bottom + 4;
  while (true) {
    await tester.pump(const Duration(milliseconds: 500));
    final all = _thumbs(tester);
    if (all.isEmpty) return;
    // The picked one is the big one under the notch.
    final picked = all.entries.reduce((a, b) => a.value.width >= b.value.width ? a : b);
    if (!seen.add(picked.key)) return;
    final shot = await _grab(tester);
    final w = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    heroes.add((label: '${picked.key}$suffix', image: await _crop(tester, shot, Rect.fromLTRB(0, top, w, picked.value.bottom + 8))));
    thumbs?.add((label: picked.key, image: await _crop(tester, shot, picked.value.inflate(6), scale: 3)));
    shot.dispose();
    if (once) return;
    final next = all.entries.where((e) => e.value.center.dx > picked.value.center.dx + 20).toList()
      ..sort((a, b) => a.value.center.dx.compareTo(b.value.center.dx));
    if (next.isEmpty) return;
    await tester.tapAt(next.first.value.center);
  }
}

Future<void> _dept(WidgetTester tester, ShopDept dept) async {
  final key = find.byKey(Key('shop.dept.${dept.name}'));
  await tester.ensureVisible(key);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(key);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _view(WidgetTester tester, {required bool card}) async {
  final toggle = find.byKey(Key(card ? 'shop.view.card' : 'shop.view.bust'));
  if (toggle.evaluate().isEmpty) return;
  await tester.tap(toggle);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _phoneShop(WidgetTester tester, String handle) async {
  WornLooks.clear();
  // A new shop, not the state of the last one.
  await tester.pumpWidget(const SizedBox());
  final online = FakeOnline()..signInReady(handle: handle, coins: 99999);
  tester.view.physicalSize = const Size(393, 852) * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  final account = OnlineAccount(online.services);
  await tester.pumpWidget(_app(ShopScreen(account: account, shop: online.shop)));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// --- The table -------------------------------------------------------------

/// The two reference players: a man in a fedora and a woman bareheaded.
AvatarLook _man(String seed) => AvatarLook.fallback(seed).copyWith(
  hat: AvatarHead.fedora,
  glasses: AvatarGlasses.none,
  accessory: AvatarAccessory.tie,
  outfit: AvatarOutfit.byId('charcoal_pinstripe'),
  base: AvatarBase.of(SkinTone.olive, FaceMark.mustache),
  features: const FaceFeatures(hair: HairStyle.sidePart, hairColor: HairColor.darkBrown, presentation: Presentation.man),
);

AvatarLook _woman(String seed) => AvatarLook.fallback(seed).copyWith(
  hat: AvatarHead.slicked,
  glasses: AvatarGlasses.none,
  accessory: AvatarAccessory.pearls,
  outfit: AvatarOutfit.byId('rose_dress'),
  base: AvatarBase.of(SkinTone.porcelain, FaceMark.clean),
  features: const FaceFeatures(hair: HairStyle.long, hairColor: HairColor.chestnut, presentation: Presentation.woman, mouth: MouthShape.lipstick, lips: LipColor.red),
);

void _remember(String name, AvatarLook look) => WornLooks.remember(Profile(id: name, handle: name, avatar: look.toJson()));

/// Every piece of the audit's shelves, worn: (label, how to wear it).
List<(String, AvatarLook Function(AvatarLook))> _pieces(String slot) => [
  for (final item in initialShopCatalog)
    if (item.slot == slot && !(item.free && item.lookId == 'none'))
      if (slot == 'held' && !HeldItem.values.byName(item.lookId).twoHanded) ...[
        ('${item.id} R', (l) => l.wearing(LookSlot.held, item.lookId, hand: Hand.right)!),
        ('${item.id} L', (l) => l.wearing(LookSlot.held, item.lookId, hand: Hand.left)!),
      ] else
        (item.id, (l) => l.wearing(LookSlot.values.byName(slot), item.lookId)!),
];

/// Four seats in a row on the felt, 74 px wide, each wearing the piece: a
/// man and a woman, with a short and a long (twelve letters, the most a
/// handle has) name.
Widget _seats(AvatarLook Function(AvatarLook) wear, int tag) {
  final seats = [('Ugo', _man('a$tag')), ('Massimiliano', _man('b$tag')), ('Eva', _woman('c$tag')), ('Massimiliana', _woman('d$tag'))];
  for (final (name, look) in seats) {
    _remember(name, wear(look));
  }
  return Container(
    width: 4 * 98.0,
    height: 74 * 1.32 + 30,
    decoration: const BoxDecoration(gradient: RadialGradient(colors: [Saloon.felt, Saloon.feltDeep], radius: 1.2)),
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [for (final (i, (name, _)) in seats.indexed) SeatCard(name: name, number: i + 2, width: 74)],
    ),
  );
}

void main() {
  testWidgets('phone shop: every scene, shoulder, hand, frame, name ink, gesture and bundle', (tester) async {
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.reset);
    for (final (handle, depts) in [
      ('ugo', [ShopDept.scene, ShopDept.back, ShopDept.hands, ShopDept.frames, ShopDept.gestures]),
      ('massimiliano', [ShopDept.frames]),
    ]) {
      for (final dept in depts) {
        if (!_wants(dept.name)) continue;
        await _phoneShop(tester, handle);
        await _dept(tester, dept);
        final tag = handle == 'ugo' ? '' : '_long';
        final hands = dept == ShopDept.hands ? [Hand.right, Hand.left] : [null];
        final thumbs = <_Cell>[];
        for (final card in dept == ShopDept.gestures ? [false] : [false, true]) {
          for (final hand in hands) {
            await _dept(tester, dept);
            if (hand != null) {
              await tester.tap(find.byKey(Key('shop.hand.${hand.name}')).first);
              await tester.pump(const Duration(milliseconds: 300));
            }
            await _view(tester, card: card);
            final heroes = <_Cell>[];
            await _walk(tester, heroes: heroes, thumbs: card || hand == Hand.left ? null : thumbs, suffix: hand == null ? '' : ' ${hand.name[0].toUpperCase()}');
            await _sheets(tester, 'phone_${dept.name}$tag${card ? '_card' : '_bust'}${hand == null ? '' : '_${hand.name}'}', heroes);
          }
        }
        await _sheets(tester, 'thumbs_${dept.name}$tag', thumbs, cols: 10, per: 30);
      }
    }
    // The window: the pieces of the week, the sets and the luxe bundles.
    if (_wants('window')) {
      await _phoneShop(tester, 'ugo');
      // As it opens (each bundle in its own view), and on the seat card.
      for (final card in [null, true]) {
        for (final section in ['featured', 'sets', 'luxe']) {
          await _dept(tester, ShopDept.window);
          final chip = find.byKey(Key('shop.section.$section'));
          if (chip.evaluate().isEmpty) continue;
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 300));
          if (card != null) await _view(tester, card: card);
          final heroes = <_Cell>[];
          await _walk(tester, heroes: heroes);
          await _sheets(tester, 'phone_window_${section}_${card == null ? 'default' : 'card'}', heroes);
        }
      }
    }
  });

  testWidgets('phone shop in English: the mission-only frames and inks', (tester) async {
    if (!_wants('locked')) return;
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.reset);
    WornLooks.clear();
    final online = FakeOnline()..signInReady(handle: 'massimiliano', coins: 99999);
    tester.view.physicalSize = const Size(375, 667) * 3;
    tester.view.devicePixelRatio = 3;
    final account = OnlineAccount(online.services);
    await tester.pumpWidget(_app(ShopScreen(account: account, shop: online.shop, progress: online.services.progress), language: AppLanguage.en));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await _dept(tester, ShopDept.frames);
    final heroes = <_Cell>[];
    await _walk(tester, heroes: heroes);
    await _sheets(tester, 'phone_frames_en_small', heroes);
  });

  testWidgets('desktop shop: the case and the mission-only pieces', (tester) async {
    if (!_wants('desktop')) return;
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.reset);
    WornLooks.clear();
    final online = FakeOnline()..signInReady(handle: 'massimiliano', coins: 99999);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    final account = OnlineAccount(online.services);
    await tester.pumpWidget(_app(DesktopCanvas(child: ShopScreen(account: account, shop: online.shop, progress: online.services.progress))));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final cells = <_Cell>[];
    for (final dept in [ShopDept.scene, ShopDept.back, ShopDept.hands, ShopDept.frames, ShopDept.gestures, ShopDept.window]) {
      await tester.ensureVisible(find.byKey(Key('shop.dept.${dept.name}')).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(Key('shop.dept.${dept.name}')).first);
      await tester.pump(const Duration(milliseconds: 600));
      final ids = [
        for (final item in initialShopCatalog)
          if (item.unlock != null && const {'border', 'nameStyle'}.contains(item.slot) && dept == ShopDept.frames) item.id,
      ];
      for (final id in [null, ...ids]) {
        if (id != null) {
          final f = find.byKey(Key('shop.item.$id'));
          await tester.scrollUntilVisible(f, 200, scrollable: find.descendant(of: find.byKey(const Key('shop.grid')), matching: find.byType(Scrollable)));
          await tester.tap(f);
          await tester.pump(const Duration(milliseconds: 600));
        }
        final shot = await _grab(tester, ratio: 1);
        cells.add((label: '${dept.name}${id == null ? '' : ' $id'}', image: await _crop(tester, shot, const Offset(0, 0) & const Size(1600, 1000), ratio: 1, scale: 1)));
        shot.dispose();
      }
    }
    await _sheets(tester, 'desktop', cells, cols: 2, per: 4);
  });

  testWidgets('the table: every piece on the 74 px seat, Ugo and Massimiliano', (tester) async {
    if (!_wants('table')) return;
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(392, 128) * 3;
    for (final slot in ['aura', 'frontFx', 'back', 'held', 'border', 'nameStyle']) {
      final cells = <_Cell>[];
      for (final (i, (label, wear)) in _pieces(slot).indexed) {
        WornLooks.clear();
        await tester.pumpWidget(_app(Scaffold(backgroundColor: Saloon.feltDeep, body: Align(alignment: Alignment.topLeft, child: _seats(wear, i)))));
        await tester.pump(const Duration(milliseconds: 400));
        final shot = await _grab(tester);
        cells.add((label: label, image: await _crop(tester, shot, const Offset(0, 0) & const Size(392, 128), scale: 2)));
        shot.dispose();
      }
      await _sheets(tester, 'table_$slot', cells, cols: 4, per: 20);
    }
  });

  testWidgets('the gestures: in flight across the table, at key frames', (tester) async {
    if (!_wants('gestures')) return;
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    const size = Size(300, 260);
    tester.view.physicalSize = size * 3;
    WornLooks.clear();
    _remember('Ugo', _man('g1'));
    _remember('Massimiliano', _woman('g2'));
    const card = Size(74, 74 * 1.32);
    const from = Offset(60, 190);
    const to = Offset(230, 80);
    final cells = <_Cell>[];
    for (final gesture in TableGesture.values) {
      final total = GestureLayer.lengthOf(gesture);
      final ages = [0.25, 0.55, 0.85, 1.1, 0.8 + (total - 0.8) * 0.55, total - 0.2];
      for (final age in ages) {
        await tester.pumpWidget(_app(Scaffold(
          backgroundColor: Saloon.feltDeep,
          body: Stack(children: [
            const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(colors: [Saloon.felt, Saloon.feltDeep], radius: 1.1)))),
            Positioned(left: from.dx - card.width / 2, top: from.dy - card.height / 2, child: const SeatCard(name: 'Ugo', number: 2, width: 74)),
            Positioned(left: to.dx - card.width / 2, top: to.dy - card.height / 2, child: const SeatCard(name: 'Massimiliano', number: 5, width: 74)),
            Positioned.fill(child: CustomPaint(painter: _Frame(gesture, from, to, card, age))),
          ]),
        )));
        await tester.pump(const Duration(milliseconds: 100));
        final shot = await _grab(tester);
        cells.add((label: '${gesture.name} ${age.toStringAsFixed(2)}s', image: await _crop(tester, shot, Offset.zero & size, scale: 1.5)));
        shot.dispose();
      }
    }
    await _sheets(tester, 'gestures_flight', cells, cols: 6, per: 24);
    // The shop's thumbnail and hero art, still, at four moments of its loop.
    final art = <_Cell>[];
    tester.view.physicalSize = const Size(140, 140) * 3;
    for (final gesture in TableGesture.values) {
      for (final t in [0.0, 0.3, 0.6, 0.9]) {
        final land = gesture.legendary ? (t < 0.7 ? t / 0.7 : 0.0) : 0.0;
        await tester.pumpWidget(_app(ColoredBox(
          color: const Color(0xFF2A1F17),
          child: Padding(padding: const EdgeInsets.all(14), child: CustomPaint(painter: GestureArt(gesture, t: t, land: land), child: const SizedBox.expand())),
        )));
        await tester.pump();
        final shot = await _grab(tester);
        art.add((label: '${gesture.name} t=$t', image: await _crop(tester, shot, Offset.zero & const Size(140, 140), scale: 2)));
        shot.dispose();
      }
    }
    await _sheets(tester, 'gestures_art', art, cols: 8, per: 24);
  });
}

class _Frame extends CustomPainter {
  final TableGesture gesture;
  final Offset from;
  final Offset to;
  final Size card;
  final double age;
  _Frame(this.gesture, this.from, this.to, this.card, this.age);

  @override
  void paint(Canvas canvas, Size size) => paintFlight(canvas, gesture, from, to, card, age);

  @override
  bool shouldRepaint(_Frame old) => true;
}
