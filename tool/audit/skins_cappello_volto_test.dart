// The visual audit of the Cappello and Volto departments and of the barber:
// every piece and every option, on three players, as the shop hero on a
// phone (393×852), as the shop thumbnail on the dial, and on the table seat
// card (74 px, dpr 3). One set of sheets per twenty items, each cell
// labelled with the item id.
//
//   flutter test tool/audit/skins_cappello_volto_test.dart
//   ONLY=hat.sombrero,face.walrus flutter test tool/audit/skins_cappello_volto_test.dart
//
// writes build/audit/cappello_volto/<group>_<n>_{hero,thumb,seat}.png and
// hair_colours_<n>.png.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/online_models.dart';
import 'package:oberta/online/shop_models.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/screens/shop/shop_focus.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart' show rarityColor;
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;
import 'package:oberta/ui/widgets/player_avatar.dart';

final out = Platform.environment['OUT'] ?? 'build/audit/cappello_volto';
final only = Platform.environment['ONLY']?.split(',').toSet();

/// The width of a hero cell (ZOOM=393 for the phone's own size).
final heroWidth = double.parse(Platform.environment['ZOOM'] ?? '170');

Future<void> _loadFonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  for (final (family, files) in [
    ('Georgia', ['Georgia.ttf', 'Georgia Bold.ttf']),
    ('Roboto', ['Arial.ttf', 'Arial Bold.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$dir/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
}

/// The three players: a light-skinned man with short hair, a dark-skinned
/// woman with a huge afro, an olive woman with long hair.
final bases = <(String, AvatarLook)>[
  (
    'Vito',
    AvatarLook.fallback('Vito').copyWith(
      hat: AvatarHead.slicked,
      glasses: AvatarGlasses.none,
      accessory: AvatarAccessory.tie,
      outfit: AvatarOutfit.byId('charcoal_pinstripe'),
      base: AvatarBase.of(SkinTone.porcelain, FaceMark.clean),
      features: const FaceFeatures(hair: HairStyle.crewCut, hairColor: HairColor.darkBrown, shape: FaceShape.square, presentation: Presentation.man),
    ),
  ),
  (
    'Nadia',
    AvatarLook.fallback('Nadia').copyWith(
      hat: AvatarHead.slicked,
      glasses: AvatarGlasses.none,
      accessory: AvatarAccessory.none,
      outfit: AvatarOutfit.byId('black_dress'),
      base: AvatarBase.of(SkinTone.ebony, FaceMark.clean),
      features: const FaceFeatures(
        hair: HairStyle.afro,
        hairColor: HairColor.black,
        shape: FaceShape.round,
        eyes: EyeShape.doe,
        brows: BrowShape.arched,
        mouth: MouthShape.lipstick,
        lips: LipColor.wine,
        presentation: Presentation.woman,
      ),
    ),
  ),
  (
    'Rosalinda',
    AvatarLook.fallback('Rosalinda').copyWith(
      hat: AvatarHead.slicked,
      glasses: AvatarGlasses.none,
      accessory: AvatarAccessory.pearls,
      outfit: AvatarOutfit.byId('rose_dress'),
      base: AvatarBase.of(SkinTone.olive, FaceMark.clean),
      features: const FaceFeatures(
        hair: HairStyle.long,
        hairColor: HairColor.chestnut,
        shape: FaceShape.heart,
        brows: BrowShape.thin,
        mouth: MouthShape.lipstickSmile,
        lips: LipColor.red,
        presentation: Presentation.woman,
      ),
    ),
  ),
];

/// One thing to check: its id, the zoom of its thumbnail, its rarity, and
/// how it goes on a player.
class _Item {
  final String id;
  final String focusSlot;
  final ShopRarity rarity;
  final AvatarLook? Function(AvatarLook) wear;
  const _Item(this.id, this.focusSlot, this.rarity, this.wear);
}

const scopeSlots = ['hat', 'hairdo', 'headFx', 'face', 'glasses', 'tattoo', 'faceExtras', 'eyeShine', 'hairDye'];

List<_Item> _shopItems(String slot) => [
  for (final item in initialShopCatalog)
    if (item.slot == slot) _Item(item.id, slot, item.rarity, (l) => l.wearing(LookSlot.values.byName(slot), item.lookId)),
];

_Item _barber<T extends Enum>(String key, T value, FaceFeatures Function(FaceFeatures, T) set, {String focus = 'face'}) =>
    _Item('barber.$key.${value.name}', focus, ShopRarity.base, (l) => l.copyWith(features: set(l.features, value)));

final barber = <String, List<_Item>>{
  'barber_hair': [for (final v in HairStyle.values) _barber('hair', v, (f, v) => f.copyWith(hair: v), focus: 'hairdo')],
  'barber_eyes': [
    for (final v in EyeShape.values) _barber('eyes', v, (f, v) => f.copyWith(eyes: v)),
    for (final v in EyeSize.values) _barber('eyeSize', v, (f, v) => f.copyWith(eyeSize: v)),
    for (final v in EyeColor.values) _barber('eyeColor', v, (f, v) => f.copyWith(eyeColor: v)),
    for (final v in EyeShadow.values) _barber('shadow', v, (f, v) => f.copyWith(shadow: v)),
  ],
  'barber_brows_nose': [
    for (final v in BrowShape.values) _barber('brows', v, (f, v) => f.copyWith(brows: v)),
    for (final v in NoseShape.values) _barber('nose', v, (f, v) => f.copyWith(nose: v)),
  ],
  'barber_mouth': [
    for (final v in MouthShape.values) _barber('mouth', v, (f, v) => f.copyWith(mouth: v)),
    for (final v in LipColor.values) _barber('lips', v, (f, v) => f.copyWith(lips: v)),
  ],
  'barber_face': [
    for (final v in FaceShape.values) _barber('shape', v, (f, v) => f.copyWith(shape: v)),
    for (final v in FaceDetail.values) _barber('detail', v, (f, v) => f.copyWith(detail: v)),
    for (final v in FaceAge.values) _barber('age', v, (f, v) => f.copyWith(age: v)),
  ],
};

/// The thumbnail zoom of the shop (shop_parts.dart, _focusOf).
Rect _focus(String slot) => switch (slot) {
  'hat' => const Rect.fromLTWH(0.12, 0.0, 0.76, 0.6),
  'hairdo' || 'hairDye' => const Rect.fromLTWH(0.06, 0.0, 0.88, 0.7),
  'headFx' => const Rect.fromLTWH(0.06, -0.04, 0.88, 0.72),
  'face' || 'glasses' || 'tattoo' || 'faceExtras' => const Rect.fromLTWH(0.2, 0.22, 0.6, 0.55),
  'eyeShine' => const Rect.fromLTWH(0.26, 0.3, 0.48, 0.34),
  _ => const Rect.fromLTWH(0.06, 0.12, 0.88, 0.88),
};

class _Zoom extends CustomPainter {
  final AvatarLook look;
  final Rect focus;
  final Offset shift;
  const _Zoom(this.look, this.focus, {this.shift = Offset.zero});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(shift.dx, shift.dy);
    final side = size.width - 2 * shift.dx;
    final scale = max(side / focus.width, side / focus.height);
    canvas.translate(side / 2 - focus.center.dx * scale, side / 2 - focus.center.dy * scale);
    LookPainter.bust(canvas, look, scale);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Zoom old) => true;
}

/// The phone hero (shop_phone.dart, _heroFrame): a 432 square, centred on the 393 screen (so 19.6 px fall
/// off each side), with the view toggle at its top right and the price tag
/// over it from 302 down.
const _heroSide = 432.0;
const _heroWindow = Size(393, 330);

Widget _hero(AvatarLook look, String slot) => SizedBox.fromSize(
  size: _heroWindow,
  child: Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFF3A1A14))),
      Positioned(
        left: (_heroWindow.width - _heroSide) / 2,
        top: 0,
        width: _heroSide,
        height: _heroSide,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.62,
                  colors: [const Color(0xFFFFC46B).withValues(alpha: 0.3), const Color(0x00FFC46B)],
                ),
              ),
            ),
            CustomPaint(painter: _Zoom(look, slot == 'tattoo' ? const Rect.fromLTWH(-0.3, -0.12, 1.6, 1.6) : const Rect.fromLTWH(-0.15, -0.08, 1.3, 1.3))),
          ],
        ),
      ),
      // The bust / card toggle.
      Positioned(
        right: 10,
        top: 4,
        width: 80,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC0C0907),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF8C6A26)),
          ),
        ),
      ),
      // The price tag.
      Positioned(
        left: 12,
        right: 12,
        top: 302,
        height: 84,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xEE0C0907),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF8C6A26)),
          ),
        ),
      ),
    ],
  ),
);

/// The rim thumbnail of the dial (shop_phone.dart, _RimThumb): 80 px, a
/// ring in the class colour, the zoomed bust inside.
Widget _thumb(AvatarLook look, _Item item) => Container(
  width: 80,
  height: 80,
  padding: const EdgeInsets.all(2.5),
  decoration: BoxDecoration(shape: BoxShape.circle, color: rarityColor(item.rarity).withValues(alpha: 0.85)),
  child: ClipOval(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color.lerp(const Color(0xFF3A2A1E), rarityColor(item.rarity), 0.35)!, const Color(0xFF120C08)],
        ),
      ),
      child: CustomPaint(painter: _Zoom(look, pieceFocus[item.id] ?? _focus(item.focusSlot), shift: const Offset(1.0, 1.0)), child: const SizedBox.expand()),
    ),
  ),
);

/// The real seat card of the table, with its seat number.
Widget _seat(String name) => Padding(
  padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
  child: SeatCard(name: name, width: 74, number: 7),
);

/// The shop hero, the dial thumbnail, the table seat card, and the round
/// portrait of the barber's mirror and the home (for the head pieces).
enum _View { hero, thumb, seat, coin }

/// One seat card, painted alone at dpr 3: the card reads the look of its
/// player by name ([WornLooks]), so each one gets its own pump.
Future<ui.Image> _seatImage(WidgetTester tester, String name, AvatarLook look) async {
  WornLooks.clear();
  WornLooks.remember(Profile(id: name, handle: name, avatar: look.toJson()));
  tester.view.physicalSize = const Size(90, 74 * 1.32 + 8) * 3;
  tester.view.devicePixelRatio = 3;
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(key: key, child: ColoredBox(color: const Color(0xFF123A28), child: _seat(name))),
      ),
    ),
  );
  return (await tester.runAsync(() => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 3)))!;
}

Future<void> _sheet(WidgetTester tester, String file, List<_Item> items, _View view) async {
  final cells = <(String, Widget)>[];
  for (final item in items) {
    for (final (b, (name, base)) in bases.indexed) {
      final look = item.wear(base);
      if (look == null) {
        cells.add(('${item.id} ✗', const SizedBox(width: 60, height: 60, child: ColoredBox(color: Colors.red))));
        continue;
      }
      final Widget art = switch (view) {
        _View.hero => FittedBox(child: _hero(look, item.focusSlot)),
        _View.thumb => _thumb(look, item),
        _View.seat => RawImage(image: await _seatImage(tester, name, look), scale: 3),
        _View.coin => PlayerAvatar(seed: name, look: look, size: 80),
      };
      cells.add((b == 0 ? item.id : '', art));
    }
  }
  final (cellW, cellH, ratio) = switch (view) {
    _View.hero => (heroWidth, _heroWindow.height * heroWidth / _heroWindow.width, 1.0),
    _View.thumb => (80.0, 80.0, 2.0),
    _View.seat => (90.0, 74 * 1.32 + 8, 3.0),
    _View.coin => (80.0, 80.0, 2.0),
  };
  final cols = view == _View.hero && heroWidth > 300 ? 3 : 9;
  const labelH = 13.0;
  final rows = (cells.length / cols).ceil();
  final size = Size(cols * (cellW + 6) + 14, rows * (cellH + labelH + 8) + 14);
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: view == _View.seat ? const Color(0xFF123A28) : const Color(0xFF14110F),
          padding: const EdgeInsets.all(7),
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final (i, (label, art)) in cells.indexed)
                SizedBox(
                  width: cellW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: labelH,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: view == _View.hero ? 11 : 7,
                            color: i % 6 < 3 ? const Color(0xFFF2D58A) : const Color(0xFF9FD0FF),
                          ),
                        ),
                      ),
                      SizedBox(width: cellW, height: cellH, child: Center(child: art)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/$file')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Every hair style in every colour, on the bare head of the third player.
Future<void> _colours(WidgetTester tester) async {
  for (final (n, styles) in [(1, HairStyle.values.sublist(0, 12)), (2, HairStyle.values.sublist(12))]) {
    const cell = 110.0;
    final size = Size(13 * (cell + 4) + 14, styles.length * (cell + 4) + 30);
    tester.view.physicalSize = size * 1.5;
    tester.view.devicePixelRatio = 1.5;
    final key = GlobalKey();
    final base = bases[2].$2;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF14110F),
            padding: const EdgeInsets.all(7),
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: cell + 4),
                    for (final c in HairColor.values)
                      SizedBox(width: cell + 4, child: Text(c.name, style: const TextStyle(fontFamily: 'Roboto', fontSize: 11, color: Color(0xFFF2D58A)))),
                  ],
                ),
                for (final s in styles)
                  Row(
                    children: [
                      SizedBox(width: cell + 4, child: Text(s.name, style: const TextStyle(fontFamily: 'Roboto', fontSize: 12, color: Color(0xFFF2D58A)))),
                      for (final c in HairColor.values)
                        Padding(
                          padding: const EdgeInsets.all(2),
                          child: SizedBox.square(
                            dimension: cell,
                            child: CustomPaint(
                              painter: _Zoom(base.copyWith(features: base.features.copyWith(hair: s, hairColor: c)), const Rect.fromLTWH(0.0, -0.04, 1.0, 1.0)),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/hair_colours_$n.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
}

void main() {
  setUpAll(_loadFonts);
  tearDown(WornLooks.clear);

  final groups = <String, List<_Item>>{
    for (final slot in scopeSlots) slot: _shopItems(slot),
    ...barber,
  };

  testWidgets('cappello and volto sheets', (tester) async {
    addTearDown(tester.view.reset);
    for (final MapEntry(key: group, value: all) in groups.entries) {
      final items = only == null ? all : [for (final i in all) if (only!.contains(i.id)) i];
      if (items.isEmpty) continue;
      for (var start = 0, n = 1; start < items.length; start += 20, n++) {
        final chunk = items.sublist(start, min(start + 20, items.length));
        final name = only == null ? '${group}_$n' : 'only_${group}_$n';
        for (final view in _View.values) {
          if (view == _View.coin && !const {'hat', 'hairdo', 'headFx', 'barber_hair'}.contains(group)) continue;
          await _sheet(tester, '${name}_${view.name}.png', chunk, view);
        }
      }
    }
    if (only == null) await _colours(tester);
  });
}
