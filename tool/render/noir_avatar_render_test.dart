// The cartoon-noir avatars on one contact sheet: a wide cast of shop and
// barber looks as 256 px busts and in the real seat card at table size, plus
// the worst cases (the biggest hairstyles under every kind of hat).
// `flutter test tool/render/noir_avatar_render_test.dart` writes
// build/render/noir/{busts_256,table,worst}.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/online_models.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

final out = Platform.environment['OUT'] ?? 'build/render/noir';

Future<void> _fonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  for (final family in ['Georgia', 'Roboto']) {
    final loader = FontLoader(family);
    for (final file in ['Georgia.ttf', 'Georgia Bold.ttf']) {
      final f = File('$dir/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
}

AvatarLook _look(
  String seed, {
  SkinTone tone = SkinTone.olive,
  FaceMark mark = FaceMark.clean,
  AvatarHead hat = AvatarHead.slicked,
  AvatarGlasses glasses = AvatarGlasses.none,
  String outfit = 'charcoal_pinstripe',
  AvatarAccessory accessory = AvatarAccessory.tie,
  FaceFeatures? features,
  Hairdo hairdo = Hairdo.none,
  Tattoo tattoo = Tattoo.none,
}) =>
    AvatarLook.fallback(seed).copyWith(
      base: AvatarBase.of(tone, mark),
      hat: hat,
      glasses: glasses,
      outfit: AvatarOutfit.byId(outfit) ?? AvatarOutfit.catalog.first,
      accessory: accessory,
      features: features,
      hairdo: hairdo,
      tattoo: tattoo,
    );

const _man = Presentation.man;
const _woman = Presentation.woman;

final cast = <(String, AvatarLook)>[
  ('Vito', _look('Vito', hat: AvatarHead.fedora, mark: FaceMark.mustache, accessory: AvatarAccessory.cigar, features: const FaceFeatures(hair: HairStyle.slicked, hairColor: HairColor.saltPepper, presentation: _man, shape: FaceShape.square))),
  ('Rosa', _look('Rosa', tone: SkinTone.tan, outfit: 'rose_dress', accessory: AvatarAccessory.pearls, features: const FaceFeatures(hair: HairStyle.fingerWaves, hairColor: HairColor.black, presentation: _woman, mouth: MouthShape.lipstick, lips: LipColor.red, shape: FaceShape.heart))),
  ('Tano', _look('Tano', tone: SkinTone.umber, mark: FaceMark.fullBeard, outfit: 'navy_double', features: const FaceFeatures(hair: HairStyle.crewCut, presentation: _man, shape: FaceShape.chiselled))),
  ('Lucia', _look('Lucia', tone: SkinTone.porcelain, hat: AvatarHead.cloche, outfit: 'emerald_dress', accessory: AvatarAccessory.cigaretteHolder, features: const FaceFeatures(hair: HairStyle.bob, hairColor: HairColor.red, presentation: _woman, detail: FaceDetail.freckles, eyeColor: EyeColor.green))),
  ('Nino', _look('Nino', tone: SkinTone.rose, hat: AvatarHead.bowler, glasses: AvatarGlasses.round, mark: FaceMark.pencil, outfit: 'cream_dinner', accessory: AvatarAccessory.bowTie, features: const FaceFeatures(hair: HairStyle.sidePart, presentation: _man, shape: FaceShape.long))),
  ('Mara', _look('Mara', tone: SkinTone.sienna, hat: AvatarHead.cloche, glasses: AvatarGlasses.shades, outfit: 'black_dress', accessory: AvatarAccessory.cigarette, features: const FaceFeatures(hair: HairStyle.bob, presentation: _woman, mouth: MouthShape.lipstick, lips: LipColor.crimson))),
  ('Ottavio', _look('Ottavio', tone: SkinTone.espresso, hat: AvatarHead.panama, glasses: AvatarGlasses.monocle, mark: FaceMark.fullBeard, outfit: 'tan_herringbone', accessory: AvatarAccessory.carnation, features: const FaceFeatures(hair: HairStyle.receding, hairColor: HairColor.white, presentation: _man, age: FaceAge.deep, shape: FaceShape.round))),
  ('Gigi', _look('Gigi', tone: SkinTone.honey, mark: FaceMark.mustache, outfit: 'azzurri_kit', features: const FaceFeatures(hair: HairStyle.pompadour, presentation: _man))),
  ('Nora', _look('Nora', tone: SkinTone.ivory, hat: AvatarHead.bun, outfit: 'midnight_double', accessory: AvatarAccessory.carnation, features: const FaceFeatures(hair: HairStyle.bun, hairColor: HairColor.platinum, presentation: _woman, eyeColor: EyeColor.blue, mouth: MouthShape.lipstick, lips: LipColor.wine))),
  ('Oro', _look('Oro', tone: SkinTone.honey, hat: AvatarHead.topHat, outfit: 'gold_brocade', accessory: AvatarAccessory.cigar, features: const FaceFeatures(hair: HairStyle.curly, hairColor: HairColor.blonde, presentation: _man))),
  ('Ada', _look('Ada', tone: SkinTone.ebony, outfit: 'ivory_blouse', accessory: AvatarAccessory.none, features: const FaceFeatures(hair: HairStyle.afro, presentation: _woman, eyes: EyeShape.doe, mouth: MouthShape.full, lips: LipColor.plum))),
  ('Bruno', _look('Bruno', tone: SkinTone.tan, hat: AvatarHead.coppola, mark: FaceMark.handlebar, outfit: 'rust_tweed', accessory: AvatarAccessory.pipe, features: const FaceFeatures(hair: HairStyle.curly, hairColor: HairColor.brown, presentation: _man, shape: FaceShape.pear))),
  ('Carla', _look('Carla', tone: SkinTone.olive, hat: AvatarHead.wideBrim, outfit: 'wine_silk', glasses: AvatarGlasses.catEye, features: const FaceFeatures(hair: HairStyle.long, hairColor: HairColor.darkBrown, presentation: _woman, shadow: EyeShadow.smoky))),
  ('Dino', _look('Dino', tone: SkinTone.porcelain, hat: AvatarHead.trilby, glasses: AvatarGlasses.aviator, mark: FaceMark.stubble, outfit: 'trench_coat', accessory: AvatarAccessory.toothpick, features: const FaceFeatures(hair: HairStyle.quiff, hairColor: HairColor.chestnut, presentation: _man))),
  ('Elio', _look('Elio', tone: SkinTone.umber, hat: AvatarHead.borsalino, mark: FaceMark.walrus, outfit: 'oxblood_double', accessory: AvatarAccessory.pocketWatch, features: const FaceFeatures(hair: HairStyle.coils, presentation: _man, shape: FaceShape.diamond))),
  ('Gina', _look('Gina', tone: SkinTone.rose, hairdo: Hairdo.beehive, outfit: 'powder_blouse', accessory: AvatarAccessory.chanterellePearls, features: const FaceFeatures(hair: HairStyle.updo, presentation: _woman, mouth: MouthShape.lipstickSmile, lips: LipColor.coral))),
  ('Ugo', _look('Ugo', tone: SkinTone.sienna, hat: AvatarHead.sombrero, mark: FaceMark.giantMoustache, outfit: 'clown_suit', accessory: AvatarAccessory.clownNose, features: const FaceFeatures(hair: HairStyle.flatTop, presentation: _man))),
  ('Pia', _look('Pia', tone: SkinTone.espresso, hat: AvatarHead.angelHalo, outfit: 'delacroix_cape', accessory: AvatarAccessory.angelWings, features: const FaceFeatures(hair: HairStyle.braids, presentation: _woman))),
  ('Teo', _look('Teo', tone: SkinTone.olive, hat: AvatarHead.devilHorns, mark: FaceMark.goatee, outfit: 'versalli_baroque', accessory: AvatarAccessory.batWings, glasses: AvatarGlasses.ricciMonocle, features: const FaceFeatures(hair: HairStyle.ducktail, presentation: _man))),
  ('Zeno', _look('Zeno', tone: SkinTone.ivory, hat: AvatarHead.astronautHelmet, outfit: 'banana_suit', features: const FaceFeatures(hair: HairStyle.wavy, hairColor: HairColor.auburn, presentation: _man))),
  ('Iris', _look('Iris', tone: SkinTone.honey, hat: AvatarHead.catOnHead, outfit: 'emerald_dress', glasses: AvatarGlasses.heartGlasses, accessory: AvatarAccessory.parrot, features: const FaceFeatures(hair: HairStyle.ponytail, presentation: _woman))),
  ('Leo', _look('Leo', tone: SkinTone.tan, hat: AvatarHead.rossoneriCap, outfit: 'rossoneri_kit', mark: FaceMark.vandyke, features: const FaceFeatures(hair: HairStyle.middlePart, presentation: _man))),
  ('Sara', _look('Sara', tone: SkinTone.porcelain, hairdo: Hairdo.punkSpikes, outfit: 'black_dress', tattoo: Tattoo.teardrop, glasses: AvatarGlasses.eyePatch, features: const FaceFeatures(presentation: _woman))),
  ('Furio', _look('Furio', tone: SkinTone.umber, hat: AvatarHead.fishHead, outfit: 'grey_flannel', accessory: AvatarAccessory.rubberDuck, features: const FaceFeatures(presentation: _man))),
  ('Mimo', _look('Mimo', mark: FaceMark.mimeFace, hat: AvatarHead.beret, outfit: 'mime_stripes', features: const FaceFeatures(hair: HairStyle.slicked, presentation: _man))),
  ('Vera', _look('Vera', tone: SkinTone.ebony, hat: AvatarHead.pearlFedora, outfit: 'vanetti_ivory', accessory: AvatarAccessory.delacroixScarf, glasses: AvatarGlasses.delacroixShades, features: const FaceFeatures(hair: HairStyle.pageboy, presentation: _woman, mouth: MouthShape.lipstick, lips: LipColor.red))),
  ('Aldo', _look('Aldo', tone: SkinTone.rose, hat: AvatarHead.magicianHat, mark: FaceMark.curledMoustache, outfit: 'magician_cape', features: const FaceFeatures(hair: HairStyle.bald, presentation: _man, age: FaceAge.lines))),
  ('Kiko', _look('Kiko', tone: SkinTone.olive, hat: AvatarHead.propellerBeanie, outfit: 'fulmine_track', glasses: AvatarGlasses.googlyEyes, features: const FaceFeatures(hair: HairStyle.curly, presentation: _man, shape: FaceShape.round))),
  ('Bea', _look('Bea', tone: SkinTone.sienna, hairdo: Hairdo.spaceBuns, outfit: 'rose_dress', tattoo: Tattoo.cheekStar, features: const FaceFeatures(presentation: _woman, eyes: EyeShape.catEye))),
  ('Rino', _look('Rino', tone: SkinTone.espresso, hat: AvatarHead.chefToque, mark: FaceMark.vikingBeard, outfit: 'cream_linen', accessory: AvatarAccessory.baguetteCigar, features: const FaceFeatures(hair: HairStyle.crewCut, presentation: _man))),
  ('Olga', _look('Olga', tone: SkinTone.ivory, hat: AvatarHead.tricorn, glasses: AvatarGlasses.eyePatch, outfit: 'oxblood_double', accessory: AvatarAccessory.parrot, features: const FaceFeatures(hair: HairStyle.victoryRolls, hairColor: HairColor.strawberry, presentation: _woman))),
  ('Max', _look('Max', tone: SkinTone.tan, hat: AvatarHead.ufoHat, outfit: 'strongman_leotard', mark: FaceMark.chevron, features: const FaceFeatures(hair: HairStyle.afro, presentation: _man))),
];

const _bigHair = [HairStyle.afro, HairStyle.coils, HairStyle.curly, HairStyle.bun, HairStyle.updo, HairStyle.pompadour, HairStyle.long, HairStyle.victoryRolls, HairStyle.ponytail, HairStyle.braids];

Future<void> _save(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _busts(List<AvatarLook> looks, double side, int cols, String path) async {
  const gap = 8.0;
  final rows = (looks.length / cols).ceil();
  final size = Size(cols * (side + gap) + gap, rows * (side + gap) + gap);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF14110F));
  for (var i = 0; i < looks.length; i++) {
    final at = Offset(gap + (i % cols) * (side + gap), gap + (i ~/ cols) * (side + gap));
    final tile = RRect.fromRectAndRadius(at & Size.square(side), Radius.circular(side * 0.07));
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const RadialGradient(center: Alignment(0, -0.3), colors: [Color(0xFF3A2A1E), Color(0xFF120C08)]).createShader(tile.outerRect),
    );
    canvas.save();
    canvas.clipRRect(tile);
    canvas.translate(at.dx, at.dy);
    LookPainter.bust(canvas, looks[i], side);
    canvas.restore();
  }
  final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
  await _save(image, path);
}

void main() {
  test('noir busts', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _fonts();
    await _busts([for (final (_, l) in cast) l], 256, 8, '$out/busts_256.png');
    final worst = <AvatarLook>[];
    for (final hat in AvatarHead.values) {
      if (hat == AvatarHead.slicked || hat == AvatarHead.bob || hat == AvatarHead.bun) continue;
      for (final hair in _bigHair) {
        worst.add(_look('w$hat$hair', hat: hat, features: FaceFeatures(hair: hair, hairColor: HairColor.auburn, shape: FaceShape.values[(hat.index + hair.index) % 8])));
      }
    }
    await _busts(worst, 72, 30, '$out/worst.png');
  });

  testWidgets('noir seat cards', (tester) async {
    await _fonts();
    for (final (name, look) in cast) {
      WornLooks.remember(Profile(id: name, handle: name, avatar: look.toJson()));
    }
    addTearDown(WornLooks.clear);
    tester.view.physicalSize = const Size(8 * 96 + 16, 4 * 120 + 16) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF123A28),
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 22,
              runSpacing: 22,
              children: [for (final (name, _) in cast) SeatCard(name: name, width: 74)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await _save(await boundary.toImage(pixelRatio: 3), '$out/table.png');
    });
  });
}
