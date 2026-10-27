// La revisione del guardaroba: ogni pezzo della bottega e ogni lineamento
// dello specchio, sul ritratto grande (256), su quello piccolo (48), nel posto
// ad arco del tavolo e nella scheda della bottega.
// `OUT=build/render/cosmetics_audit/after flutter test tool/render/cosmetics_audit_render_test.dart`
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/widgets/cosmetics/seat_preview.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;
import 'package:oberta/ui/widgets/player_avatar.dart';

final out = Platform.environment['OUT'] ?? 'build/render/cosmetics_audit/after';

Future<void> _loadFonts() async {
  final loader = FontLoader('Roboto');
  for (final file in ['Supplemental/Arial.ttf', 'Supplemental/Arial Bold.ttf']) {
    final f = File('/System/Library/Fonts/$file');
    if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

/// Un uomo e una donna di riferimento, a testa nuda.
final man = AvatarLook.fallback('Vito').copyWith(
  hat: AvatarHead.slicked,
  glasses: AvatarGlasses.none,
  accessory: AvatarAccessory.tie,
  outfit: AvatarOutfit.byId('charcoal_pinstripe'),
  base: AvatarBase.of(SkinTone.olive, FaceMark.clean),
  features: const FaceFeatures(hair: HairStyle.sidePart, hairColor: HairColor.darkBrown, presentation: Presentation.man),
);

final woman = AvatarLook.fallback('Rosa').copyWith(
  hat: AvatarHead.slicked,
  glasses: AvatarGlasses.none,
  accessory: AvatarAccessory.pearls,
  outfit: AvatarOutfit.byId('rose_dress'),
  base: AvatarBase.of(SkinTone.porcelain, FaceMark.clean),
  features: const FaceFeatures(
    hair: HairStyle.long,
    hairColor: HairColor.chestnut,
    presentation: Presentation.woman,
    mouth: MouthShape.lipstick,
    lips: LipColor.red,
  ),
);

AvatarLook _hair(AvatarLook l, HairStyle h, {FaceShape? shape}) =>
    l.copyWith(features: l.features.copyWith(hair: h, shape: shape ?? l.features.shape));

enum _Mode { bust, head, seat, card }

Widget _cell(String label, AvatarLook look, double size, _Mode mode, int i) {
  final Widget art = switch (mode) {
    _Mode.bust => CustomPaint(size: Size.square(size), painter: AvatarBustPainter(look)),
    // La testa da vicino: il ritratto ingrandito due volte sulla faccia.
    _Mode.head => ClipRect(
        child: SizedBox.square(
          dimension: size,
          child: OverflowBox(
            maxWidth: size * 1.7,
            maxHeight: size * 1.7,
            alignment: const Alignment(0, -0.2),
            child: CustomPaint(size: Size.square(size * 1.7), painter: AvatarBustPainter(look)),
          ),
        ),
      ),
    _Mode.seat => _Arch(look: look, width: size, name: 'p$i'),
    // La scheda della bottega: un riquadro un poco più largo che alto.
    _Mode.card => Container(
        width: size,
        height: size * 0.92,
        color: const Color(0xFF241812),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: CustomPaint(painter: AvatarBustPainter(look), child: const SizedBox.expand()),
      ),
  };
  return SizedBox(
    width: size + 4,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        art,
        if (size >= 64)
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFBFAF95), fontSize: 11, fontFamily: 'Roboto')),
      ],
    ),
  );
}

/// Il posto ad arco del tavolo, come in partita.
class _Arch extends StatelessWidget {
  final AvatarLook look;
  final double width;
  final String name;

  const _Arch({required this.look, required this.width, required this.name});

  @override
  Widget build(BuildContext context) {
    final arch = BorderRadius.vertical(top: Radius.circular(width / 2), bottom: Radius.circular(width * 0.12));
    return SizedBox(
      width: width,
      height: width * 1.2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: arch,
          border: Border.all(color: const Color(0xFF8A6A2E), width: 1.4),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A2A1E), Color(0xFF120C08)],
          ),
        ),
        child: ClipRRect(
          borderRadius: arch,
          child: Align(
            alignment: const Alignment(0, -0.1),
            child: PlayerAvatar(seed: name, look: look, size: width * 0.86),
          ),
        ),
      ),
    );
  }
}

Future<void> _sheet(
  WidgetTester tester,
  String file,
  List<(String, AvatarLook)> items, {
  double size = 256,
  int cols = 6,
  _Mode mode = _Mode.bust,
  double ratio = 1,
}) async {
  final cellH = switch (mode) {
    _Mode.bust || _Mode.head => size,
    _Mode.seat => size * 1.2,
    _Mode.card => size * 0.92,
  } + (size >= 64 ? 16 : 0);
  final rows = (items.length / cols).ceil();
  final width = cols * (size + 4 + 6) + 20;
  final height = rows * (cellH + 6) + 20;
  tester.view.physicalSize = Size(width, height) * ratio;
  tester.view.devicePixelRatio = ratio;
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFF14110F),
          padding: const EdgeInsets.all(10),
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final (i, (label, look)) in items.indexed) _cell(label, look, size, mode, i)],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$file')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  final hats = [
    for (final h in AvatarHead.values) (h.name, man.copyWith(hat: h)),
  ];
  final hatsWoman = [
    for (final h in AvatarHead.values) (h.name, woman.copyWith(hat: h)),
  ];
  final hairMan = [for (final h in HairStyle.values) (h.name, _hair(man, h))];
  final hairWoman = [for (final h in HairStyle.values) (h.name, _hair(woman, h))];
  final shapes = FaceShape.values;
  List<(String, AvatarLook)> hairByShape(AvatarLook base, Iterable<HairStyle> styles) => [
        for (final h in styles)
          for (final s in shapes) ('${h.name}/${s.name}', _hair(base, h, shape: s)),
      ];
  final glasses = [for (final g in AvatarGlasses.values) (g.name, man.copyWith(glasses: g))];
  final marks = [for (final m in FaceMark.values) (m.name, man.copyWith(base: AvatarBase.of(SkinTone.olive, m)))];
  final skins = [
    for (final t in SkinTone.ordered) ...[
      ('${t.name} m', man.copyWith(base: AvatarBase.of(t, FaceMark.clean))),
      ('${t.name} w', woman.copyWith(base: AvatarBase.of(t, FaceMark.clean))),
    ],
  ];
  final noses = [
    for (final n in NoseShape.values)
      for (final s in [FaceShape.oval, FaceShape.round, FaceShape.long, FaceShape.diamond])
        ('${n.name}/${s.name}', man.copyWith(features: man.features.copyWith(nose: n, shape: s))),
  ];
  final outfits = [for (final o in AvatarOutfit.catalog) (o.id, man.copyWith(outfit: o))];
  final outfitsWoman = [for (final o in AvatarOutfit.catalog) (o.id, woman.copyWith(outfit: o))];
  final accessories = [for (final a in AvatarAccessory.values) (a.name, man.copyWith(accessory: a))];
  final hairdos = [for (final h in Hairdo.values) (h.name, man.copyWith(hairdo: h))];
  final hairdosWoman = [for (final h in Hairdo.values) (h.name, woman.copyWith(hairdo: h))];
  final tattoos = [for (final t in Tattoo.values) (t.name, man.copyWith(tattoo: t, outfit: AvatarOutfit.byId('strongman_leotard')))];
  final borders = [for (final b in SeatBorder.values) (b.name, man.copyWith(border: b))];
  // Le facce con barba sotto il colletto e i cappelli sopra i capelli.
  final layering = [
    ('beard+tie', man.copyWith(base: AvatarBase.of(SkinTone.tan, FaceMark.fullBeard))),
    ('beard+bow', man.copyWith(base: AvatarBase.of(SkinTone.tan, FaceMark.fullBeard), accessory: AvatarAccessory.bowTie)),
    ('viking+scarf', man.copyWith(base: AvatarBase.of(SkinTone.rose, FaceMark.vikingBeard), accessory: AvatarAccessory.scarf)),
    ('afro+fedora', _hair(man, HairStyle.afro).copyWith(hat: AvatarHead.fedora)),
    ('pomp+topHat', _hair(man, HairStyle.pompadour).copyWith(hat: AvatarHead.topHat)),
    ('long+cloche', woman.copyWith(hat: AvatarHead.cloche)),
    ('bun+beret', _hair(woman, HairStyle.bun).copyWith(hat: AvatarHead.beret)),
    ('braids+boater', _hair(woman, HairStyle.braids).copyWith(hat: AvatarHead.boater)),
    ('curly+halo', _hair(man, HairStyle.curly).copyWith(hat: AvatarHead.angelHalo)),
    ('quiff+horns', _hair(man, HairStyle.quiff).copyWith(hat: AvatarHead.devilHorns)),
    ('afro+cat', _hair(man, HairStyle.afro).copyWith(hat: AvatarHead.catOnHead)),
    ('long+astro', woman.copyWith(hat: AvatarHead.astronautHelmet)),
  ];

  testWidgets('revisione del guardaroba', (tester) async {
    addTearDown(tester.view.reset);
    // 256: ogni pezzo sul ritratto grande.
    await _sheet(tester, 'hats_man_256.png', hats, cols: 8);
    await _sheet(tester, 'hats_woman_256.png', hatsWoman, cols: 8);
    await _sheet(tester, 'hair_man_256.png', hairMan);
    await _sheet(tester, 'hair_woman_256.png', hairWoman);
    await _sheet(tester, 'hair_shapes_a_head.png', hairByShape(man, HairStyle.values.take(12)), size: 150, cols: 8, mode: _Mode.head);
    await _sheet(tester, 'hair_shapes_b_head.png', hairByShape(woman, HairStyle.values.skip(12)), size: 150, cols: 8, mode: _Mode.head);
    await _sheet(tester, 'glasses_256.png', glasses, cols: 7);
    await _sheet(tester, 'marks_256.png', marks, cols: 7);
    await _sheet(tester, 'skins_256.png', skins, cols: 8);
    await _sheet(tester, 'skins_head.png', skins, size: 150, cols: 10, mode: _Mode.head);
    await _sheet(tester, 'marks_head.png', marks, size: 150, cols: 10, mode: _Mode.head);
    await _sheet(tester, 'glasses_head.png', glasses, size: 150, cols: 11, mode: _Mode.head);
    await _sheet(tester, 'noses_head.png', noses, size: 150, cols: 8, mode: _Mode.head);
    await _sheet(tester, 'outfits_man_a_256.png', outfits.take(36).toList(), cols: 9);
    await _sheet(tester, 'outfits_man_b_256.png', outfits.skip(36).toList(), cols: 9);
    await _sheet(tester, 'outfits_woman_a_256.png', outfitsWoman.take(36).toList(), cols: 9);
    await _sheet(tester, 'outfits_woman_b_256.png', outfitsWoman.skip(36).toList(), cols: 9);
    await _sheet(tester, 'accessories_a_256.png', accessories.take(32).toList(), cols: 8);
    await _sheet(tester, 'accessories_b_256.png', accessories.skip(32).toList(), cols: 8);
    await _sheet(tester, 'hairdos_256.png', [...hairdos, ...hairdosWoman], cols: 9);
    await _sheet(tester, 'tattoos_256.png', tattoos, cols: 6);
    await _sheet(tester, 'layering_256.png', layering, cols: 6);
    // 48, come al tavolo del telefono (a due pixel per punto).
    final everything = [
      ...hats, ...hatsWoman, ...hairMan, ...hairWoman, ...glasses, ...marks, ...skins, ...outfits, ...accessories, //
      ...hairdos, ...tattoos, ...layering,
    ];
    await _sheet(tester, 'all_48.png', everything, size: 48, cols: 24, ratio: 2);
    // Nel posto ad arco del tavolo e nella scheda della bottega.
    await _sheet(tester, 'seat_hats_120.png', [...hats, ...hatsWoman.take(16)], size: 120, cols: 12, mode: _Mode.seat);
    await _sheet(tester, 'seat_mix_120.png', [...hairWoman, ...accessories.skip(30), ...layering], size: 120, cols: 12, mode: _Mode.seat);
    await _sheet(tester, 'card_mix_170.png', [...hats.skip(22).take(20), ...outfits.skip(40).take(12), ...accessories.skip(26).take(16)],
        size: 170, cols: 8, mode: _Mode.card);
    // Le cornici, nel posto della bottega.
    tester.view.physicalSize = const Size(900, 560) * 2;
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(
          color: const Color(0xFF14110F),
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 16, runSpacing: 16, children: [
            for (final (name, look) in borders) SizedBox(width: 120, child: SeatPreview(look: look, name: name)),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/borders_seat.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
