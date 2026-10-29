// The skin audit as a player lives it: the real app, on the test backend,
// at an iPhone's size. Into the Bottega from the alley, through the Window,
// the Scene, the Shoulders, the Hands, the Frame and the Gestures, turning
// the dial over every piece in bust and on the seat card, the hands in both
// hands, the mission-only pieces, a few bought and worn; then a seat at a
// table with short and long names, and gestures thrown across it.
//
//   flutter test integration_test/bottega_walk_test.dart -d macos
//   flutter test integration_test/bottega_walk_test.dart -d <iPhone simulator id>
//
// Every step is a screenshot at the device's size (393×852 points, 3x);
// they go, with labelled contact sheets, to `<temp>/oberta_audit/<run>`,
// the path printed at the end (in the app's container on macOS).
// `DESK=true` (a --dart-define) walks the desktop shop instead.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/main.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

import '../test/support/manual_clock.dart';

const _desk = bool.fromEnvironment('DESK');

/// Two pieces per shelf only: to try the walk itself, headless.
const _quick = bool.fromEnvironment('QUICK');

late final Directory _out;
final _sheets = <String, List<(String, ui.Image)>>{};
var _shot = 0;

/// The screen as the player sees it, at the device's pixels: the root
/// layer already scales by the pixel ratio.
Future<ui.Image> _grab(WidgetTester tester) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  return layer.toImage(Offset.zero & tester.view.physicalSize);
}

/// One step: the full screenshot to its own file, a copy for [sheet].
Future<void> snap(WidgetTester tester, String sheet, String label) async {
  final image = await _grab(tester);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final name = '${(++_shot).toString().padLeft(3, '0')}_${sheet}_${label.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')}.png';
  File('${_out.path}/shots/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  (_sheets[sheet] ??= []).add((label, image));
}

/// The labelled contact sheets, twenty screens each, at 40%.
Future<void> _writeSheets() async {
  const scale = 0.4;
  for (final MapEntry(key: name, value: cells) in _sheets.entries) {
    for (var p = 0; p * 20 < cells.length; p++) {
      final page = cells.skip(p * 20).take(20).toList();
      final cw = page.first.$2.width * scale;
      final ch = page.first.$2.height * scale;
      const gap = 12.0, label = 30.0;
      final cols = min(5, page.length);
      final rows = (page.length / cols).ceil();
      final size = Size(cols * (cw + gap) + gap, rows * (ch + label + gap) + gap);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawRect(Offset.zero & size, Paint()..color = const Color(0xFF141012));
      for (final (i, (text, image)) in page.indexed) {
        final at = Offset(gap + (i % cols) * (cw + gap), gap + (i ~/ cols) * (ch + label + gap));
        final tp = TextPainter(
          text: TextSpan(text: text, style: const TextStyle(fontSize: 20, color: Color(0xFFFFE7A8), fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: cw);
        tp.paint(canvas, at);
        canvas.drawImageRect(image, Offset.zero & Size(image.width.toDouble(), image.height.toDouble()), (at + const Offset(0, label)) & Size(cw, ch), Paint()..filterQuality = FilterQuality.medium);
      }
      final sheet = await recorder.endRecording().toImage(size.width.ceil(), size.height.ceil());
      final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
      File('${_out.path}/${name}_${p + 1}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }
  }
}

/// Real time goes by: animations, the server's answers.
Future<void> wait(WidgetTester tester, [int ms = 500]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tap(WidgetTester tester, Finder finder, {int settle = 600}) async {
  await tester.ensureVisible(finder.first);
  await wait(tester, 200);
  await tester.tap(finder.first, warnIfMissed: false);
  await wait(tester, settle);
}

/// The thumbnails on the dial (or in the desk's case), by key.
Map<String, Rect> _thumbs(WidgetTester tester) => {
  for (final element in find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && (k.value.startsWith('shop.item.') || (k.value.startsWith('shop.bundle.') && k.value != 'shop.bundle.buy'));
  }).evaluate())
    if ((element.renderObject! as RenderBox).hasSize)
      (element.widget.key! as ValueKey<String>).value.replaceFirst(RegExp(r'^shop\.(item|bundle)\.'), ''):
          (element.renderObject! as RenderBox).localToGlobal(Offset.zero) & (element.renderObject! as RenderBox).size,
};

/// The phone's dial, from the first piece to the last: the player taps the
/// next one on the rim each time.
Future<List<String>> walkDial(WidgetTester tester, String sheet, {String suffix = ''}) async {
  final seen = <String>[];
  while (true) {
    await wait(tester, 450);
    final all = _thumbs(tester);
    if (all.isEmpty) break;
    final picked = all.entries.reduce((a, b) => a.value.width >= b.value.width ? a : b);
    if (seen.contains(picked.key) || _quick && seen.length == 2) break;
    seen.add(picked.key);
    await snap(tester, sheet, '${picked.key}$suffix');
    final next = all.entries.where((e) => e.value.center.dx > picked.value.center.dx + 20).toList()
      ..sort((a, b) => a.value.center.dx.compareTo(b.value.center.dx));
    if (next.isEmpty) break;
    await tester.tapAt(next.first.value.center);
  }
  return seen;
}

/// The desk's case: every card in the grid, in order, scrolling as needed.
Future<List<String>> walkCase(WidgetTester tester, String sheet, List<String> ids) async {
  for (final id in ids) {
    final card = find.byKey(Key(id.contains('.') ? 'shop.item.$id' : 'shop.bundle.$id'));
    if (card.evaluate().isEmpty) {
      await tester.scrollUntilVisible(card, 160, scrollable: find.descendant(of: find.byKey(const Key('shop.grid')), matching: find.byType(Scrollable)));
    }
    await tap(tester, card, settle: 500);
    await snap(tester, sheet, id);
  }
  return ids;
}

Future<void> openDept(WidgetTester tester, String dept) => tap(tester, find.byKey(Key('shop.dept.$dept')));

Future<void> view(WidgetTester tester, {required bool card}) async {
  final toggle = find.byKey(Key(card ? 'shop.view.card' : 'shop.view.bust'));
  if (toggle.evaluate().isNotEmpty) await tap(tester, toggle, settle: 300);
}

/// Picks [id] on the shelf: by turning the dial on the phone.
Future<void> pickItem(WidgetTester tester, String id) async {
  final key = find.byKey(Key('shop.item.$id'));
  for (var i = 0; i < 40 && key.hitTestable().evaluate().isEmpty; i++) {
    if (_desk) {
      await tester.scrollUntilVisible(key, 160, scrollable: find.descendant(of: find.byKey(const Key('shop.grid')), matching: find.byType(Scrollable)));
      break;
    }
    await tester.drag(find.byKey(const Key('shop.dial')), const Offset(-90, 0));
    await wait(tester, 400);
  }
  await tap(tester, key.hitTestable());
}

/// Buys [id] (and wears it, unless it is a gesture), as the player does.
Future<void> buyAndWear(WidgetTester tester, String dept, String id) async {
  await openDept(tester, dept);
  if (id.startsWith('held.')) await tap(tester, find.byKey(const Key('shop.hand.left')));
  await pickItem(tester, id);
  await tap(tester, find.byKey(const Key('shop.action')));
  await snap(tester, 'buy', '$id receipt');
  await tap(tester, find.byKey(const Key('shop.confirm')), settle: 900);
  await snap(tester, 'buy', '$id bought');
  if (!id.startsWith('gesture.')) {
    await tap(tester, find.byKey(const Key('shop.action')), settle: 900);
    await snap(tester, 'buy', '$id worn');
  }
}

AvatarLook _look(String seed, {bool woman = false}) => AvatarLook.fallback(seed).copyWith(
  hat: woman ? AvatarHead.slicked : AvatarHead.fedora,
  outfit: AvatarOutfit.byId(woman ? 'rose_dress' : 'charcoal_pinstripe'),
  accessory: woman ? AvatarAccessory.pearls : AvatarAccessory.tie,
  features: woman
      ? const FaceFeatures(hair: HairStyle.long, hairColor: HairColor.chestnut, presentation: Presentation.woman, mouth: MouthShape.lipstick, lips: LipColor.red)
      : const FaceFeatures(hair: HairStyle.sidePart, hairColor: HairColor.darkBrown, presentation: Presentation.man),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a player walks the Bottega, buys, sits at the table and throws gestures', (tester) async {
    _out = Directory('${Directory.systemTemp.path}/oberta_audit/${_desk ? 'desk' : 'phone'}_${DateTime.now().millisecondsSinceEpoch}')..createSync(recursive: true);
    DesktopPlatform.debugOverride = _desk;
    // The owner's phone: in Italian, and no debug ribbon over the corner.
    AppSettings.instance = AppSettings(MemorySettingsStore())..language = AppLanguage.it;
    WidgetsApp.debugAllowBannerOverride = false;
    if (_desk) {
      tester.view.physicalSize = const Size(1600, 900) * 2;
      tester.view.devicePixelRatio = 2;
    } else {
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    }
    addTearDown(tester.view.reset);

    // The table's time goes by at the test's command: from the card to the
    // first day, where gestures fly.
    final clock = ManualClock();
    final online = FakeOnline(clock: clock, random: Random(3))..signInReady(handle: 'massimiliano', coins: 99999);
    // The others at the table, dressed from the same shelves.
    online.addPlayer('ugo', handle: 'ugo', avatar: _look('ugo').copyWith(aura: Aura.vesuvio, border: SeatBorder.suits, nameStyle: NameStyle.goldFoil, frontFx: FrontFx.petals).toJson());
    online.addPlayer('eva', handle: 'eva', avatar: _look('eva', woman: true).copyWith(back: BackItem.angelWings, border: SeatBorder.neonPulse, nameStyle: NameStyle.siren).holding(HeldItem.cat).toJson());
    online.addPlayer('massimiliana', handle: 'massimiliana', avatar: _look('massimiliana', woman: true).copyWith(aura: Aura.inferno, border: SeatBorder.flame, nameStyle: NameStyle.inferno, frontFx: FrontFx.fireflies).toJson());
    online.addPlayer('bartolomeo', handle: 'bartolomeo12', avatar: _look('bartolomeo').copyWith(back: BackItem.dragonWings, border: SeatBorder.artDeco, nameStyle: NameStyle.bloodInk).holding(HeldItem.revolver, hand: Hand.right).toJson());
    OnlineServices.instance = online.services;

    await tester.pumpWidget(const ObertaApp());
    await wait(tester, 2500);
    await snap(tester, 'street', 'alley');

    // Into the Bottega, from the alley's sign.
    await tap(tester, find.byKey(const Key('home.shopSign')), settle: 2500);
    await snap(tester, 'street', 'bottega');

    // The Window: the pieces of the week, the sets, the luxe bundles.
    for (final section in ['featured', 'sets', 'luxe']) {
      final chip = find.byKey(Key('shop.section.$section'));
      if (chip.evaluate().isEmpty) continue;
      await tap(tester, chip);
      if (_desk) {
        await walkCase(tester, 'window_$section', _thumbs(tester).keys.toList());
      } else {
        await walkDial(tester, 'window_$section');
      }
    }

    // Every shelf in scope: in bust and on the seat card; the hands in both.
    for (final dept in ['scene', 'back', 'hands', 'frames', 'gestures']) {
      final hands = dept == 'hands' ? ['right', 'left'] : [null];
      // Gestures and frames have no bust/card toggle: one pass.
      for (final card in dept == 'gestures' || dept == 'frames' || _desk ? [null] : [false, true]) {
        for (final hand in hands) {
          await openDept(tester, dept);
          if (hand != null) await tap(tester, find.byKey(Key('shop.hand.$hand')));
          if (card != null) await view(tester, card: card);
          final sheet = '$dept${card == null ? '' : card ? '_card' : '_bust'}${hand == null ? '' : '_$hand'}';
          if (_desk) {
            final ids = [for (final item in initialShopCatalog) if ({'scene': ['aura', 'frontFx'], 'back': ['back'], 'hands': ['held'], 'frames': ['border', 'nameStyle'], 'gestures': ['gesture']}[dept]!.contains(item.slot)) item.id];
            await walkCase(tester, sheet, ids);
          } else {
            await walkDial(tester, sheet, suffix: hand == null ? '' : ' ${hand[0].toUpperCase()}');
          }
        }
      }
    }

    // The mission-only pieces: no price, the small line that says how.
    await openDept(tester, 'frames');
    for (final id in [for (final item in initialShopCatalog) if (item.unlock != null && {'border', 'nameStyle'}.contains(item.slot)) item.id]) {
      await pickItem(tester, id);
      expect(find.textContaining('Si sblocca con'), findsWidgets, reason: '$id says how it unlocks');
      await snap(tester, 'locked', id);
    }

    // A few bought and worn, as a player would.
    for (final (dept, id) in [
      ('scene', 'aura.harbourMoon'),
      ('scene', 'frontFx.musicNotes'),
      ('back', 'back.gildedWings'),
      ('hands', 'held.rose'),
      ('frames', 'border.neonPink'),
      ('frames', 'nameStyle.shimmer'),
      ('gestures', 'gesture.horse'),
      ('gestures', 'gesture.tommy'),
      ('gestures', 'gesture.rose'),
    ]) {
      await buyAndWear(tester, dept, id);
    }
    await openDept(tester, 'window');
    await snap(tester, 'buy', 'worn, back in the window');
    await tap(tester, find.byKey(const Key('shop.back')), settle: 2000);
    await snap(tester, 'street', 'alley, dressed');

    // A table: Ugo's room, the long names, two bots.
    final room = online.openRoomAs('ugo', LobbyLanguage.it);
    for (final id in ['eva', 'massimiliana', 'bartolomeo', 'me']) {
      online.joinAs(id, room.code);
    }
    await online.gameAs('ugo').setBots(room.id, 2);
    await online.gameAs('ugo').startGame(room.id);
    final me = await online.services.profiles.me();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.push(MaterialPageRoute<void>(builder: (_) => OnlineGameScreen(services: online.services, room: online.roomOf(room.id)!, me: me, clock: clock)));
    await wait(tester, 1500);
    await snap(tester, 'table', 'sat down');
    for (var i = 0; i < 30 && find.byKey(const Key('gestures.button')).hitTestable().evaluate().isEmpty; i++) {
      // The card, the night: the clock runs on to the day.
      clock.elapse(const Duration(seconds: 15));
      await wait(tester, 900);
      if (i % 3 == 0) await snap(tester, 'table', 'to the day ${i + 1}');
    }
    await snap(tester, 'table', 'the day');
    // Gestures, each at a different seat: the bought legendaries and a
    // free one, frame by frame where they land.
    final throws = ['horse', 'tommy', 'rose', 'toast'];
    for (final (i, gesture) in throws.indexed) {
      final button = find.byKey(const Key('gestures.button')).hitTestable();
      if (button.evaluate().isEmpty) break;
      await tap(tester, button, settle: 700);
      await snap(tester, 'gestures', '$gesture: whom');
      final targets = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('gestures.target-'));
      if (targets.evaluate().isEmpty) break;
      await tap(tester, targets.at(i % targets.evaluate().length), settle: 700);
      await snap(tester, 'gestures', '$gesture: drawer');
      await tap(tester, find.byKey(Key('gestures.$gesture')), settle: 0);
      for (final ms in [250, 400, 400, 600, 800]) {
        await wait(tester, ms);
        await snap(tester, 'gestures', '$gesture +$ms');
      }
      // The table's gestures wait a moment between two throws.
      // (eight seconds, on the phone's own clock and on the server's).
      clock.elapse(const Duration(seconds: 9));
      await wait(tester, 6500);
    }
    await wait(tester, 1500);
    await snap(tester, 'table', 'end');

    await _writeSheets();
    debugPrint('AUDIT_OUT=${_out.path}');
  }, timeout: const Timeout(Duration(minutes: 50)));
}
