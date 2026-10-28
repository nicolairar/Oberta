// The dearest shelf: the scene, the shoulders, the head effects, the face
// marks, the eye shine, the dye, the hands and the front effects. The saved
// look reads back from old and new profiles; each piece paints where it
// belongs in the z order; the shop buys, wears and takes them off.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/look_painter.dart';

const _side = 200;

Future<Uint8List> _paint(void Function(Canvas c) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(_side, _side);
  final bytes = await image.toByteData();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

int _alpha(Uint8List rgba, int x, int y) => rgba[(y * _side + x) * 4 + 3];

(int, int, int, int) _pixel(Uint8List rgba, int x, int y) {
  final i = (y * _side + x) * 4;
  return (rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]);
}

/// The painted pixels' bounding box (alpha over 40), or null.
Rect? _bounds(Uint8List rgba) {
  int? l, t, r, b;
  for (var y = 0; y < _side; y++) {
    for (var x = 0; x < _side; x++) {
      if (_alpha(rgba, x, y) > 40) {
        l = l == null || x < l ? x : l;
        r = r == null || x > r ? x : r;
        t ??= y;
        b = y;
      }
    }
  }
  return l == null ? null : Rect.fromLTRB(l.toDouble(), t!.toDouble(), r!.toDouble(), b!.toDouble());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ada = AvatarLook.fallback('Ada');

  group('il look salvato', () {
    test('un profilo di prima non porta niente dei posti nuovi', () {
      final old = {'base': 'olive_clean', 'hat': 'fedora', 'glasses': 'none', 'outfit': 'black_tuxedo', 'accessory': 'tie'};
      final look = AvatarLook.fromJson(old, fallback: ada);
      expect(look.aura, Aura.none);
      expect(look.back, BackItem.none);
      expect(look.headFx, HeadFx.none);
      expect(look.faceExtras, isEmpty);
      expect(look.eyeShine, EyeShine.none);
      expect(look.hairDye, HairDye.none);
      expect((look.heldL, look.heldR), (HeldItem.none, HeldItem.none));
      expect(look.frontFx, FrontFx.none);
    });

    test('i posti nuovi si salvano con chiavi piatte e si rileggono uguali', () {
      final look = ada.copyWith(
        aura: Aura.vesuvio,
        back: BackItem.violinCase,
        headFx: HeadFx.rainCloud,
        faceExtras: const [FaceExtra.blush, FaceExtra.goldTooth],
        eyeShine: EyeShine.lira,
        hairDye: HairDye.tricolore,
        heldL: HeldItem.rose,
        heldR: HeldItem.moka,
        frontFx: FrontFx.musicNotes,
      );
      final json = look.toJson();
      expect(json, containsPair('faceExtras', 'blush+goldTooth'));
      expect(json, containsPair('heldL', 'rose'));
      expect(json, containsPair('heldR', 'moka'));
      expect(json.values.every((v) => v.isNotEmpty), isTrue);
      expect(AvatarLook.fromJson(json, fallback: AvatarLook.fallback('altro')), look);
    });

    test('gli id che il catalogo non conosce lasciano il posto vuoto', () {
      final look = AvatarLook.fromJson(
        {'aura': 'mars', 'back': 'cape', 'headFx': 7, 'faceExtras': 'tattooX+blush+freckles+tear+scar', 'eyeShine': 'laser', 'hairDye': 'plaid', 'heldL': 'sword', 'heldR': 'grappa', 'frontFx': 'snow'},
        fallback: ada,
      );
      expect(look.aura, Aura.none);
      expect(look.back, BackItem.none);
      expect(look.headFx, HeadFx.none);
      expect(look.faceExtras, [FaceExtra.blush, FaceExtra.tear], reason: 'due al massimo, quelli conosciuti');
      expect(look.eyeShine, EyeShine.none);
      expect(look.hairDye, HairDye.none);
      expect((look.heldL, look.heldR), (HeldItem.none, HeldItem.grappa));
      expect(look.frontFx, FrontFx.none);
    });

    test('le ali portate come vezzo passano sulle spalle', () {
      final look = AvatarLook.fromJson({'accessory': 'batWings'}, fallback: ada);
      expect(look.back, BackItem.batWings);
      expect(look.accessory, ada.accessory, reason: 'al collo torna il vezzo del nome');
      expect(AvatarLook.fromJson({'accessory': 'batWings', 'back': 'parasol'}, fallback: ada).back, BackItem.parasol);
    });

    test('una cosa da due mani prende tutte e due le mani', () {
      expect(AvatarLook.fromJson({'heldL': 'rose', 'heldR': 'cat'}, fallback: ada).heldL, HeldItem.cat);
      expect(AvatarLook.fromJson({'heldL': 'rose', 'heldR': 'cat'}, fallback: ada).heldR, HeldItem.none);
      final both = ada.holding(HeldItem.teddy);
      expect((both.heldL, both.heldR), (HeldItem.teddy, HeldItem.none));
      final one = both.holding(HeldItem.revolver, hand: Hand.right);
      expect((one.heldL, one.heldR), (HeldItem.none, HeldItem.revolver), reason: "l'orsetto lascia il posto");
      final two = one.holding(HeldItem.rose, hand: Hand.left);
      expect((two.heldL, two.heldR), (HeldItem.rose, HeldItem.revolver));
      expect(two.wears(LookSlot.held, 'rose'), isTrue);
      expect(two.wears(LookSlot.held, 'revolver'), isTrue);
    });

    test('i segni sulla faccia: due al massimo, il più vecchio cede', () {
      final a = ada.marked(FaceExtra.blush).marked(FaceExtra.tear).marked(FaceExtra.plaster);
      expect(a.faceExtras, [FaceExtra.tear, FaceExtra.plaster]);
      expect(a.marked(FaceExtra.tear, toggle: true).faceExtras, [FaceExtra.plaster]);
      expect(a.wearing(LookSlot.faceExtras, 'none')!.faceExtras, isEmpty);
    });
  });

  group('dove si dipinge', () {
    final base = ada.copyWith(features: ada.features.copyWith(presentation: Presentation.man));

    test('la scena sta dietro a tutto e riempie il ritratto', () async {
      final plain = await _paint((c) => LookPainter.bust(c, base, _side.toDouble()));
      final scene = await _paint((c) => LookPainter.bust(c, base.copyWith(aura: Aura.vault), _side.toDouble()));
      // The corners: empty without, painted with.
      for (final (x, y) in [(2, 2), (_side - 3, 2)]) {
        expect(_alpha(plain, x, y), 0);
        expect(_alpha(scene, x, y), 255);
      }
      // The face in the middle is the same face: the scene is behind it.
      final a = LookPainter.bustAnchors(base, _side.toDouble());
      final nose = Offset((a.leftEye.dx + a.rightEye.dx) / 2, a.nose - 4);
      expect(_pixel(scene, nose.dx.round(), nose.dy.round()), _pixel(plain, nose.dx.round(), nose.dy.round()));
    });

    test('le cose in mano stanno nelle mani, ai lati in basso', () async {
      for (final item in HeldItem.values.skip(1)) {
        for (final hand in Hand.values) {
          if (item.twoHanded && hand == Hand.left) continue;
          final look = base.holding(item, hand: hand);
          final held = await _paint((c) => LookPainter.bustLayers(c, look, _side.toDouble(), {LookLayer.held}));
          final bounds = _bounds(held)!;
          final a = LookPainter.bustAnchors(look, _side.toDouble());
          expect(bounds.bottom, greaterThan(_side * 0.9), reason: '$item: the arm rises from the bottom edge');
          // Never over the face: the eyes, the nose and the mouth stay clear.
          final cx = ((a.leftEye.dx + a.rightEye.dx) / 2).round();
          for (final (x, y) in [(a.leftEye.dx.round(), a.leftEye.dy.round()), (a.rightEye.dx.round(), a.rightEye.dy.round()), (cx, a.nose.round()), (cx, a.mouth.round())]) {
            expect(_alpha(held, x, y), 0, reason: '$item in the $hand hand covers the face at ($x, $y)');
          }
          if (!item.twoHanded) {
            final centre = bounds.center.dx;
            expect(hand == Hand.left ? centre < _side * 0.36 : centre > _side * 0.64, isTrue, reason: '$item in the $hand hand, centred at $centre');
          }
        }
      }
    });

    test('quello sulle spalle sta dietro il busto', () async {
      expect(LookLayer.values.indexOf(LookLayer.back), lessThan(LookLayer.values.indexOf(LookLayer.body)));
      for (final item in BackItem.values.skip(1)) {
        final look = base.copyWith(back: item);
        final plain = await _paint((c) => LookPainter.bust(c, base.copyWith(heldL: HeldItem.none).copyWith(back: BackItem.none), _side.toDouble()));
        final worn = await _paint((c) => LookPainter.bust(c, look, _side.toDouble()));
        final only = await _paint((c) => LookPainter.bustLayers(c, look, _side.toDouble(), {LookLayer.back}));
        expect(_bounds(only), isNotNull, reason: '$item paints something');
        // The middle of the chest shows the suit, not the piece behind it.
        if (!item.roomy) {
          expect(_pixel(worn, _side ~/ 2 + 12, (_side * 0.95).round()), _pixel(plain, _side ~/ 2 + 12, (_side * 0.95).round()), reason: '$item');
        }
      }
    });

    test('la cornice del posto sta sopra il ritratto', () {
      expect(LookLayer.values.last, LookLayer.frontFx, reason: 'nel ritratto, davanti a tutto c’è l’effetto; la cornice è del posto, sopra');
    });
  });

  group('la bottega', () {
    late FakeOnline online;

    setUp(() {
      WornLooks.clear();
      online = FakeOnline()..signInReady(handle: 'anna');
    });

    test('una cosa in mano va nella mano scelta, una da due mani le prende tutte', () async {
      final shop = online.shop;
      online.award('me', coins: 20000);
      for (final id in ['held.rose', 'held.revolver', 'held.cat']) {
        await shop.buy(id);
      }
      var me = await shop.equip('held.rose', hand: 'left');
      me = await shop.equip('held.revolver', hand: 'right', current: me.avatar);
      expect((me.look.heldL, me.look.heldR), (HeldItem.rose, HeldItem.revolver));
      me = await shop.equip('held.cat', current: me.avatar);
      expect((me.look.heldL, me.look.heldR), (HeldItem.cat, HeldItem.none));
      me = await shop.equip('held.rose', hand: 'right', current: me.avatar);
      expect((me.look.heldL, me.look.heldR), (HeldItem.none, HeldItem.rose));
      me = await shop.unequip('held', current: me.avatar);
      expect((me.look.heldL, me.look.heldR), (HeldItem.none, HeldItem.none));
    });

    test('i segni sulla faccia si mettono e si tolgono uno alla volta', () async {
      final shop = online.shop;
      online.award('me', coins: 20000);
      for (final id in ['faceExtras.blush', 'faceExtras.tear', 'faceExtras.plaster']) {
        await shop.buy(id);
      }
      var me = await shop.equip('faceExtras.blush');
      me = await shop.equip('faceExtras.tear');
      me = await shop.equip('faceExtras.plaster');
      expect(me.look.faceExtras, [FaceExtra.tear, FaceExtra.plaster]);
      me = await shop.equip('faceExtras.tear');
      expect(me.look.faceExtras, [FaceExtra.plaster], reason: 'quello che si porta già si toglie');
    });

    test("quello che non si possiede non passa nel look mandato dall'app", () async {
      final shop = online.shop;
      final me = await shop.equip('hat.fedora', current: {...AvatarLook.fallback('anna').toJson(), 'aura': 'vault', 'heldR': 'cat'});
      expect(me.look.aura, Aura.none);
      expect(me.look.heldR, HeldItem.none);
    });

    test('le scene costano più di ogni leggendario di prima', () {
      final scenes = initialShopCatalog.where((item) => item.slot == 'aura' && !item.free);
      final oldBest = initialShopCatalog.where((item) => !deepDrop.contains(item)).map((item) => item.price).reduce((a, b) => a > b ? a : b);
      expect(scenes, isNotEmpty);
      expect(scenes.every((item) => item.price > oldBest), isTrue);
      for (final slot in const ['aura', 'back', 'headFx', 'faceExtras', 'eyeShine', 'hairDye', 'held', 'frontFx']) {
        final items = initialShopCatalog.where((item) => item.slot == slot && !item.free);
        expect(items.length, greaterThanOrEqualTo(6), reason: slot);
        expect(items.every((item) => item.rarity.index >= ShopRarity.epico.index), isTrue, reason: slot);
        expect(deepDrop.where((item) => item.slot == slot && item.free).map((item) => item.lookId), ['none'], reason: slot);
      }
    });
  });
}
