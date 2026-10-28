import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/seated_character.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart';
import 'package:oberta/ui/widgets/player_avatar.dart';

const _names = ['Ada', 'Bruno', 'Carla', 'Dino', 'Elio', 'Fabio', 'Gina', 'Ugo', 'Rosa', 'Vito', 'Lucia', 'Nino'];

void main() {
  group('il look', () {
    test('chi non ha scelto niente riceve dal nome sempre lo stesso look', () {
      for (final name in _names) {
        expect(AvatarLook.fallback(name), AvatarLook.fallback(name));
      }
      final looks = {for (final name in _names) AvatarLook.fallback(name)};
      expect(looks, hasLength(_names.length), reason: 'ognuno si veste a modo suo');
    });

    test('il cappello è quello della sua moneta, come nei filmati', () {
      for (final name in _names) {
        expect(AvatarLook.fallback(name).hat, avatarHeadFor(name), reason: name);
      }
    });

    test('si salva per id nella colonna avatar e si rilegge uguale', () {
      for (final name in _names) {
        final look = AvatarLook.fallback(name);
        final json = look.toJson();
        expect(json.keys, containsAll(['base', 'hat', 'glasses', 'outfit', 'accessory']));
        expect(AvatarLook.fromJson(json, fallback: AvatarLook.fallback('altro')), look);
      }
      final ada = AvatarLook.fallback('Ada');
      expect(
        AvatarLook.fromJson({'hat': 'fedora', 'glasses': 'shades', 'outfit': 'black_tuxedo'}, fallback: ada).toJson(),
        {...ada.toJson(), 'hat': 'fedora', 'glasses': 'shades', 'outfit': 'black_tuxedo'},
      );
    });

    test('un pezzo che il catalogo non conosce lascia quello di prima', () {
      final ada = AvatarLook.fallback('Ada');
      final look = AvatarLook.fromJson(
        {'base': 'martian_green', 'hat': 'jetpackHelmet', 'glasses': 7, 'outfit': 'spacesuit', 'accessory': 'hoverboard'},
        fallback: ada,
      );
      expect(look, ada);
      expect(AvatarLook.fromJson(const {}, fallback: ada), ada);
    });

    test('gli id del catalogo non si ripetono', () {
      final bases = AvatarBase.catalog.map((base) => base.id).toList();
      final outfits = AvatarOutfit.catalog.map((outfit) => outfit.id).toList();
      expect(bases.toSet(), hasLength(bases.length));
      expect(outfits.toSet(), hasLength(outfits.length));
      for (final id in bases) {
        expect(AvatarBase.byId(id)!.id, id);
      }
    });
  });

  testWidgets('la stessa persona seduta, in moneta e da morta, a ogni misura', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Wrap(
            children: [
              for (final name in _names) ...[
                SeatedCharacter(look: AvatarLook.fallback(name), size: 24, seed: name),
                SeatedCharacter(look: AvatarLook.fallback(name), size: 140, seed: name),
                PlayerAvatar(seed: name, size: 40),
                PlayerAvatar(seed: name, size: 40, fallen: true),
              ],
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse, reason: 'senza animazioni nessuno respira');
  });

  test('uomo o donna decide il busto; pettinature e tatuaggi della bottega si salvano', () {
    final base = AvatarLook.fallback('Ada');
    final woman = base.copyWith(features: base.features.copyWith(presentation: Presentation.woman, hair: HairStyle.crewCut));
    final man = base.copyWith(hat: AvatarHead.bob, features: base.features.copyWith(presentation: Presentation.man, hair: HairStyle.bob));
    expect(woman.dame, isTrue);
    expect(man.dame, isFalse);
    final styled = base.copyWith(hairdo: Hairdo.glitterAfro, tattoo: Tattoo.koi);
    expect(AvatarLook.fromJson(styled.toJson(), fallback: base), styled);
    expect(base.wearing(LookSlot.hairdo, 'beehive')?.hairdo, Hairdo.beehive);
    expect(base.wearing(LookSlot.tattoo, 'anchor')?.tattoo, Tattoo.anchor);
    expect(base.hairdo, Hairdo.none, reason: 'dal nome nessuno riceve una pettinatura pagata');
  });
}
