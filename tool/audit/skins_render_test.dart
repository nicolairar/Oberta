// The skin audit's contact sheets: every suit, vice, football piece and
// whole look of the shop, worn by three players (a light-skinned man, a
// dark-skinned woman, a bearded man with another face), as the shop's hero
// bust, as its round thumbnail and on the table's 74 pt seat card.
//
//   flutter test tool/audit/skins_render_test.dart
//
// writes build/audit/skins/<sheet>_<n>.png (OUT= to change it, DPR= for the
// pixel ratio, 3 by default as on an iPhone). Each row is one item, its id
// on the left; the hero is drawn at half the phone's 413 pt (the same
// framing, the price tag's band shaded where it covers the bust), the
// thumbnails at the dial's 73 and 53 pt, the seat card at its real 74 pt.
// `ONLY=id,id` renders just those items, for a second look.
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
import 'package:oberta/ui/screens/shop/shop_screen.dart' show rarityColor;
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

final out = Platform.environment['OUT'] ?? 'build/audit/skins';
final dpr = double.tryParse(Platform.environment['DPR'] ?? '') ?? 3;
final only = Platform.environment['ONLY']?.split(',').toSet();

Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Georgia', ['Georgia.ttf', 'Georgia Bold.ttf']),
    ('Roboto', ['Arial.ttf', 'Arial Bold.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('/System/Library/Fonts/Supplemental/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
}

/// The three players: names short and long enough to test the plate.
final players = <(String, AvatarLook)>[
  (
    'vito',
    AvatarLook.fallback('vito').copyWith(
      hat: AvatarHead.slicked,
      glasses: AvatarGlasses.none,
      accessory: AvatarAccessory.tie,
      outfit: AvatarOutfit.byId('charcoal_pinstripe'),
      base: AvatarBase.of(SkinTone.porcelain, FaceMark.clean),
      features: const FaceFeatures(shape: FaceShape.oval, hair: HairStyle.sidePart, hairColor: HairColor.darkBrown, presentation: Presentation.man),
    ),
  ),
  (
    'rosalinda',
    AvatarLook.fallback('rosalinda').copyWith(
      hat: AvatarHead.slicked,
      glasses: AvatarGlasses.none,
      accessory: AvatarAccessory.pearls,
      outfit: AvatarOutfit.byId('rose_dress'),
      base: AvatarBase.of(SkinTone.espresso, FaceMark.clean),
      features: const FaceFeatures(
        shape: FaceShape.round,
        hair: HairStyle.long,
        hairColor: HairColor.black,
        presentation: Presentation.woman,
        mouth: MouthShape.lipstick,
        lips: LipColor.red,
      ),
    ),
  ),
  (
    'tano',
    AvatarLook.fallback('tano').copyWith(
      hat: AvatarHead.slicked,
      glasses: AvatarGlasses.none,
      accessory: AvatarAccessory.none,
      outfit: AvatarOutfit.byId('charcoal_pinstripe'),
      base: AvatarBase.of(SkinTone.sienna, FaceMark.fullBeard),
      features: const FaceFeatures(shape: FaceShape.square, hair: HairStyle.curly, hairColor: HairColor.black, presentation: Presentation.man),
    ),
  ),
];

/// One row of a sheet: its label and what each player wears.
class _Row {
  final String id;
  final String slot;
  final ShopRarity rarity;
  final AvatarLook Function(AvatarLook) dress;
  const _Row(this.id, this.slot, this.rarity, this.dress);
}

AvatarLook _wear(AvatarLook look, String slot, String lookId) => look.wearing(LookSlot.values.byName(slot), lookId) ?? look;

/// Where the thumbnail zooms (shop_parts.dart, _focusOf).
Rect _focus(String slot, [String id = '']) {
  final vice = slot == 'accessory' ? AvatarAccessory.values.where((a) => 'accessory.${a.name}' == id).firstOrNull : null;
  if (vice != null && LookPainter.beside(vice)) return const Rect.fromLTWH(0, 0, 1, 1);
  return _slotFocus(slot);
}

Rect _slotFocus(String slot) => switch (slot) {
  'bundle' => const Rect.fromLTWH(0.1, 0.06, 0.8, 0.8),
  'hat' => const Rect.fromLTWH(0.12, 0.0, 0.76, 0.6),
  'face' => const Rect.fromLTWH(0.2, 0.22, 0.6, 0.55),
  'outfit' => const Rect.fromLTWH(0.0, 0.58, 1.0, 0.45),
  _ => const Rect.fromLTWH(0.06, 0.12, 0.88, 0.88),
};

/// How the hero frames the bust (shop_phone.dart, _heroFrame).
Rect _frame(String slot) =>
    slot == 'bundle' || slot == 'outfit' || slot == 'accessory' ? const Rect.fromLTWH(-0.3, -0.12, 1.6, 1.6) : const Rect.fromLTWH(-0.15, -0.08, 1.3, 1.3);

class _Zoom extends CustomPainter {
  final AvatarLook look;
  final Rect focus;
  const _Zoom(this.look, this.focus);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = max(size.width / focus.width, size.height / focus.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2 - focus.center.dx * scale, size.height / 2 - focus.center.dy * scale);
    LookPainter.bust(canvas, look, scale);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Zoom old) => true;
}

const _hero = 413.5 / 2;
const _labelW = 150.0;

Widget _heroCell(AvatarLook look, String slot) => SizedBox.square(
  dimension: _hero,
  child: Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(decoration: BoxDecoration(color: Color(0xFF0E0A0C))),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.15),
            radius: 0.62,
            colors: [const Color(0xFFFFC46B).withValues(alpha: 0.3), const Color(0x00FFC46B)],
          ),
        ),
      ),
      CustomPaint(painter: _Zoom(look, _frame(slot))),
      // The price tag and the dial cover the bottom 130 pt of 413.
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: _hero * 130 / 413.5,
        child: const DecoratedBox(decoration: BoxDecoration(color: Color(0x99000000))),
      ),
    ],
  ),
);

Widget _thumb(AvatarLook look, String slot, String id, ShopRarity rarity, double side) => Container(
  width: side,
  height: side,
  padding: const EdgeInsets.all(2.5),
  decoration: BoxDecoration(shape: BoxShape.circle, color: rarityColor(rarity).withValues(alpha: 0.85)),
  child: ClipOval(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color.lerp(const Color(0xFF3A2A1E), rarityColor(rarity), 0.35)!, const Color(0xFF120C08)],
        ),
      ),
      child: CustomPaint(painter: _Zoom(look, _focus(slot, id)), child: const SizedBox.expand()),
    ),
  ),
);

Widget _rowWidget(_Row row, int number) {
  final looks = [for (final (name, look) in players) (name, row.dress(look))];
  return Container(
    height: _hero + 8,
    padding: const EdgeInsets.symmetric(vertical: 4),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF3A3028))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _labelW,
          child: Text(
            '$number. ${row.id}',
            style: const TextStyle(color: Color(0xFFEADBC0), fontSize: 13, fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          ),
        ),
        for (final (_, look) in looks) Padding(padding: const EdgeInsets.only(right: 4), child: _heroCell(look, row.slot)),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _thumb(looks[0].$2, row.slot, row.id, row.rarity, 73),
            const SizedBox(height: 6),
            Row(children: [_thumb(looks[1].$2, row.slot, row.id, row.rarity, 53), const SizedBox(width: 4), _thumb(looks[2].$2, row.slot, row.id, row.rarity, 53)]),
          ],
        ),
        const SizedBox(width: 14),
        // The seat cards on the felt, as at the table.
        Container(
          color: const Color(0xFF173A26),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(
            children: [
              for (final (i, (name, _)) in looks.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SeatCard(name: '$name$number', number: i + 3, width: 74),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _register(List<_Row> rows) {
  WornLooks.clear();
  for (final (n, row) in rows.indexed) {
    for (final (name, look) in players) {
      WornLooks.remember(Profile(id: '$name${n + 1}', handle: '$name${n + 1}', avatar: row.dress(look).toJson()));
    }
  }
}

Future<void> _sheet(WidgetTester tester, String file, List<_Row> rows, {int offset = 0}) async {
  _register([...List.filled(offset, rows.first), ...rows]);
  const width = _labelW + 3 * (_hero + 4) + 8 + 73 + 14 + 3 * 90 + 28 + 80;
  final height = rows.length * (_hero + 8) + 20;
  tester.view.physicalSize = Size(width, height) * dpr;
  tester.view.devicePixelRatio = dpr;
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            color: const Color(0xFF14110F),
            padding: const EdgeInsets.all(10),
            alignment: Alignment.topLeft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final (i, row) in rows.indexed) _rowWidget(row, offset + i + 1)]),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: dpr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$file')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// What the audit covers: the suits (Abito), the vices (Vizio), every
/// football piece, the gold statue with its crown, and the whole looks.
Map<String, List<_Row>> _auditRows() {
  final items = [
    for (final item in initialShopCatalog)
      if (item.slot == 'outfit' || item.slot == 'accessory' || item.collection == ShopCollection.calcio) item,
  ];
  _Row of(ShopItem item) => _Row(item.id, item.slot, item.rarity, (look) => _wear(look, item.slot, item.lookId));
  final calcio = [
    for (final item in items)
      if (item.collection == ShopCollection.calcio) of(item),
  ];
  final outfits = [
    for (final item in items)
      if (item.slot == 'outfit' && item.collection != ShopCollection.calcio) of(item),
  ];
  final vices = [
    for (final item in items)
      if (item.slot == 'accessory' && item.collection != ShopCollection.calcio) of(item),
  ];
  final byId = {for (final item in initialShopCatalog) item.id: item};
  AvatarLook bundle(ShopBundle b, AvatarLook look) {
    final used = <String>{};
    for (final id in b.itemIds) {
      final item = byId[id];
      if (item == null || !used.add(item.slot)) continue;
      look = _wear(look, item.slot, item.lookId);
    }
    return look;
  }

  final bundles = [
    for (final b in initialShopBundles)
      if (!framesBundles.contains(b) && !gestureBundles.contains(b))
        _Row('bundle.${b.id}', 'bundle', b.premium ? ShopRarity.leggendario : ShopRarity.epico, (look) => bundle(b, look)),
    // The gold statue alone, with its crown, and over a suit and a vice.
    _Row('face.goldStatue', 'face', ShopRarity.leggendario, (look) => _wear(look, 'face', 'goldStatue')),
    _Row('goldStatue+crown', 'bundle', ShopRarity.leggendario, (look) => _wear(_wear(look, 'face', 'goldStatue'), 'hat', 'crown')),
    _Row(
      'goldStatue+tux+cigar',
      'bundle',
      ShopRarity.leggendario,
      (look) => _wear(_wear(_wear(look, 'face', 'goldStatue'), 'outfit', 'vanetti_tuxedo'), 'accessory', 'cigar'),
    ),
    _Row(
      'goldStatue+rossoneri',
      'bundle',
      ShopRarity.leggendario,
      (look) => _wear(_wear(_wear(look, 'face', 'goldStatue'), 'outfit', 'rossoneri_kit'), 'accessory', 'rossoneriScarf'),
    ),
  ];
  return {'abito': outfits, 'vizio': vices, 'calcio': calcio, 'looks': bundles};
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('skin audit sheets', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(WornLooks.clear);
    const per = 20;
    for (final MapEntry(key: name, value: all) in _auditRows().entries) {
      final rows = only == null
          ? all
          : [
              for (final row in all)
                if (only!.contains(row.id)) row,
            ];
      for (var i = 0; i * per < rows.length; i++) {
        final chunk = rows.skip(i * per).take(per).toList();
        await _sheet(tester, '${name}_${i + 1}.png', chunk, offset: i * per);
      }
    }
  });
}
