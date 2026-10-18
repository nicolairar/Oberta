import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/face_presets.dart';
import 'package:oberta/ui/screens/avatar/barber_mirror_screen.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart';

const _names = ['Ada', 'Bruno', 'Carla', 'Dino', 'Elio', 'Fabio', 'Gina', 'Ugo', 'Rosa', 'Vito', 'Lucia', 'Nino'];

void main() {
  group('i lineamenti', () {
    test('dal nome: sempre gli stessi, e diversi tra loro', () {
      for (final name in _names) {
        expect(AvatarLook.fallback(name).features, AvatarLook.fallback(name).features);
      }
      final faces = {for (final name in _names) AvatarLook.fallback(name).features};
      expect(faces.length, greaterThanOrEqualTo(_names.length - 1));
      expect({for (final name in _names) AvatarLook.fallback(name).features.shape}.length, greaterThan(2));
      expect({for (final name in _names) AvatarLook.fallback(name).features.hair}.length, greaterThan(2));
    });

    test('un look salvato prima dello specchio prende i lineamenti dal nome', () {
      final ada = AvatarLook.fallback('Ada');
      final old = AvatarLook.fromJson(const {'base': 'tan_walrus', 'hat': 'bob'}, fallback: ada);
      expect(old.features, ada.features);
      expect(old.base.mark, FaceMark.walrus);
      expect(AvatarLook.fallback('x').copyWith(hat: AvatarHead.bob).bareHead, isTrue);
    });

    test('si salvano per id e si rileggono uguali; gli id sconosciuti non contano', () {
      for (final preset in FacePreset.all) {
        final look = preset.applyTo(AvatarLook.fallback('Ada'));
        expect(AvatarLook.fromJson(look.toJson(), fallback: AvatarLook.fallback('z')), look);
      }
      final ada = AvatarLook.fallback('Ada');
      expect(AvatarLook.fromJson({...ada.toJson(), 'hair': 'mohawk', 'eyes': 3}, fallback: ada), ada);
    });

    test('venti facce pronte, tutte diverse', () {
      expect(FacePreset.all, hasLength(20));
      expect({for (final p in FacePreset.all) p.id}, hasLength(20));
      expect({for (final p in FacePreset.all) (p.tone, p.features)}, hasLength(20));
    });

    test('le scelte: quante ne promette lo specchio', () {
      expect(FaceFeatures.options.map((k, v) => MapEntry(k, v.length)), {
        'shape': 8, 'eyes': 12, 'eyeColor': 8, 'brows': 10, 'nose': 10, 'mouth': 12, //
        'hair': 24, 'hairColor': 12, 'detail': 8, 'age': 3, 'lips': 7, 'shadow': 7,
      });
      expect(FaceFeatures.keys, FaceFeatures.options.keys.toList());
    });

    test('gli id della prima versione si leggono ancora, e i nomi di comodo pure', () {
      const old = {
        'shape': ['oval', 'round', 'square', 'long', 'heart'],
        'eyes': ['almond', 'round', 'hooded', 'narrow', 'upturned', 'downturned'],
        'eyeColor': ['dark', 'brown', 'hazel', 'green', 'blue', 'grey'],
        'brows': ['straight', 'arched', 'thick', 'thin', 'angled'],
        'nose': ['straight', 'button', 'roman', 'broad', 'pointed'],
        'mouth': ['neutral', 'smile', 'smirk', 'full', 'thin', 'stern'],
        'hair': ['bald', 'slicked', 'sidePart', 'crewCut', 'curly', 'wavy', 'afro', 'bun', 'bob', 'long'],
        'hairColor': ['black', 'darkBrown', 'brown', 'blonde', 'red', 'auburn', 'grey', 'white'],
        'detail': ['none', 'freckles', 'beautyMark', 'scar'],
        'age': ['none', 'lines', 'deep'],
      };
      for (final MapEntry(:key, :value) in old.entries) {
        for (final id in value) {
          expect(FaceFeatures.standard.withId(key, id)?.toJson()[key], id, reason: '$key.$id');
        }
      }
      final saved = FaceFeatures.fromJson(const {'hair': 'rockabilly', 'hairColor': 'gray'}, fallback: FaceFeatures.standard);
      expect(saved.hair, HairStyle.quiff);
      expect(saved.hairColor, HairColor.grey);
      // Chi ha salvato prima del trucco resta senza.
      expect(FaceFeatures.fromJson(const {'hair': 'bob'}, fallback: FaceFeatures.standard).lips, LipColor.none);
    });

    test('a caso: sempre facce valide, signori e signore', () {
      final random = Random(7);
      final looks = [for (var i = 0; i < 200; i++) FacePreset.randomize(AvatarLook.fallback('Ada'), random)];
      for (final look in looks) {
        final f = look.features;
        if (f.mouth.painted) expect(f.lips, isNot(LipColor.none));
        if (f.shadow != EyeShadow.none) expect(f.lips, isNot(LipColor.none));
      }
      expect({for (final l in looks) l.features.hair}.length, greaterThan(18));
    });

    test('gli id sono gli stessi della migrazione', () {
      final sql = File('supabase/migrations/20261019120000_face_options.sql').readAsStringSync();
      for (final MapEntry(:key, :value) in FaceFeatures.options.entries) {
        expect(sql, contains("'$key', jsonb_build_array(${value.map((v) => "'$v'").join(', ')})"), reason: key);
      }
      for (final tone in SkinTone.values) {
        expect(sql, contains("'${tone.name}'"));
      }
    });
  });

  group('salvare la faccia', () {
    late FakeOnline online;

    setUp(() {
      WornLooks.clear();
      online = FakeOnline()..signInReady(handle: 'anna');
    });

    test('solo i lineamenti e la pelle: i baffi pagati restano', () async {
      online.award('me', coins: 350);
      await online.shop.buy('face.walrus');
      await online.shop.equip('face.walrus', tone: 'tan');
      await online.shop.equip('hat.bowler');
      final face = FacePreset.all.first.features.toJson();
      final me = await online.profiles.saveFace(face, tone: 'honey', mark: 'clean');
      expect(me.avatar['base'], 'honey_walrus');
      expect(me.avatar['hat'], 'bowler');
      expect(me.look.features, FacePreset.all.first.features);
      expect(me.look.base.tone, SkinTone.honey);
    });

    test('un segno non salvato vale solo se è di base; gli id sconosciuti no', () async {
      var me = await online.profiles.saveFace(const {'hair': 'afro'}, tone: 'ebony', mark: 'walrus');
      expect(me.avatar['base'], 'ebony_clean');
      online = FakeOnline()..signInReady(handle: 'bea');
      me = await online.profiles.saveFace(const {'hair': 'afro'}, tone: 'ebony', mark: 'mustache');
      expect(me.avatar['base'], 'ebony_mustache');
      await expectLater(online.profiles.saveFace(const {'hair': 'mohawk'}, tone: 'ebony'), throwsA(isA<OnlineException>()));
      await expectLater(online.profiles.saveFace(const {'hat': 'topHat'}, tone: 'ebony'), throwsA(isA<OnlineException>()));
      await expectLater(online.profiles.saveFace(const {}, tone: 'green'), throwsA(isA<OnlineException>()));
    });
  });

  testWidgets('lo specchio: una faccia pronta, a caso, e si salva', (tester) async {
    tester.view.physicalSize = const Size(400, 860) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    WornLooks.clear();
    final online = FakeOnline()..signInReady(handle: 'anna');
    final profile = await online.profiles.me();
    Profile? saved;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => saved = await BarberMirrorScreen.open(context, services: online.services, profile: profile),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('mirror.preset.amara')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mirror.random')));
    await tester.tap(find.byKey(const Key('mirror.preset.amara')));
    await tester.tap(find.byKey(const Key('mirror.hat')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mirror.save')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(saved, isNotNull);
    final amara = FacePreset.all.firstWhere((p) => p.id == 'amara');
    expect(saved!.look.features, amara.features);
    expect(saved!.look.base.tone, amara.tone);
  });
}
