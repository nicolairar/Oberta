import 'dart:math';

import 'package:flutter/foundation.dart';

import 'avatar_look.dart';

/// Una faccia pronta da cui partire nello specchio del barbiere: la pelle e
/// i lineamenti, non i pezzi della bottega.
@immutable
class FacePreset {
  final String id;
  final SkinTone tone;
  final FaceFeatures features;

  const FacePreset(this.id, this.tone, this.features);

  AvatarLook applyTo(AvatarLook look) =>
      look.copyWith(base: AvatarBase.of(tone, look.base.mark), features: features);

  /// Dodici persone diverse: uomini e donne, di ogni età e di ogni parte.
  static const all = [
    FacePreset('rosa', SkinTone.porcelain, FaceFeatures(
      shape: FaceShape.heart, eyes: EyeShape.almond, eyeColor: EyeColor.green, brows: BrowShape.arched,
      nose: NoseShape.button, mouth: MouthShape.full, hair: HairStyle.bob, hairColor: HairColor.red,
      detail: FaceDetail.freckles)),
    FacePreset('vito', SkinTone.olive, FaceFeatures(
      shape: FaceShape.square, eyes: EyeShape.hooded, eyeColor: EyeColor.brown, brows: BrowShape.thick,
      nose: NoseShape.roman, mouth: MouthShape.stern, hair: HairStyle.slicked, hairColor: HairColor.black,
      age: FaceAge.lines)),
    FacePreset('amara', SkinTone.ebony, FaceFeatures(
      shape: FaceShape.oval, eyes: EyeShape.upturned, eyeColor: EyeColor.dark, brows: BrowShape.arched,
      nose: NoseShape.broad, mouth: MouthShape.smile, hair: HairStyle.bun, hairColor: HairColor.black,
      detail: FaceDetail.beautyMark)),
    FacePreset('kenji', SkinTone.honey, FaceFeatures(
      shape: FaceShape.long, eyes: EyeShape.narrow, eyeColor: EyeColor.dark, brows: BrowShape.straight,
      nose: NoseShape.straight, mouth: MouthShape.neutral, hair: HairStyle.sidePart, hairColor: HairColor.black)),
    FacePreset('lucia', SkinTone.tan, FaceFeatures(
      shape: FaceShape.round, eyes: EyeShape.round, eyeColor: EyeColor.hazel, brows: BrowShape.thin,
      nose: NoseShape.straight, mouth: MouthShape.smirk, hair: HairStyle.wavy, hairColor: HairColor.darkBrown)),
    FacePreset('ottavio', SkinTone.rose, FaceFeatures(
      shape: FaceShape.oval, eyes: EyeShape.downturned, eyeColor: EyeColor.blue, brows: BrowShape.thick,
      nose: NoseShape.pointed, mouth: MouthShape.thin, hair: HairStyle.bald, hairColor: HairColor.grey,
      age: FaceAge.deep)),
    FacePreset('farida', SkinTone.sienna, FaceFeatures(
      shape: FaceShape.heart, eyes: EyeShape.almond, eyeColor: EyeColor.brown, brows: BrowShape.angled,
      nose: NoseShape.roman, mouth: MouthShape.full, hair: HairStyle.long, hairColor: HairColor.black)),
    FacePreset('theo', SkinTone.espresso, FaceFeatures(
      shape: FaceShape.square, eyes: EyeShape.almond, eyeColor: EyeColor.dark, brows: BrowShape.straight,
      nose: NoseShape.broad, mouth: MouthShape.smirk, hair: HairStyle.afro, hairColor: HairColor.black)),
    FacePreset('greta', SkinTone.ivory, FaceFeatures(
      shape: FaceShape.long, eyes: EyeShape.hooded, eyeColor: EyeColor.grey, brows: BrowShape.thin,
      nose: NoseShape.straight, mouth: MouthShape.neutral, hair: HairStyle.bob, hairColor: HairColor.blonde)),
    FacePreset('mateo', SkinTone.umber, FaceFeatures(
      shape: FaceShape.round, eyes: EyeShape.round, eyeColor: EyeColor.brown, brows: BrowShape.thick,
      nose: NoseShape.button, mouth: MouthShape.smile, hair: HairStyle.curly, hairColor: HairColor.darkBrown)),
    FacePreset('mei', SkinTone.porcelain, FaceFeatures(
      shape: FaceShape.oval, eyes: EyeShape.upturned, eyeColor: EyeColor.dark, brows: BrowShape.straight,
      nose: NoseShape.button, mouth: MouthShape.full, hair: HairStyle.long, hairColor: HairColor.black)),
    FacePreset('nonna', SkinTone.olive, FaceFeatures(
      shape: FaceShape.round, eyes: EyeShape.downturned, eyeColor: EyeColor.hazel, brows: BrowShape.thin,
      nose: NoseShape.pointed, mouth: MouthShape.smile, hair: HairStyle.bun, hairColor: HairColor.white,
      age: FaceAge.deep)),
  ];

  /// Una faccia a caso, con ogni lineamento estratto da [random].
  static AvatarLook randomize(AvatarLook look, Random random) {
    T one<T>(List<T> values) => values[random.nextInt(values.length)];
    final tone = one(SkinTone.values);
    return look.copyWith(
      base: AvatarBase.of(tone, look.base.mark),
      features: FaceFeatures(
        shape: one(FaceShape.values),
        eyes: one(EyeShape.values),
        eyeColor: one(EyeColor.values),
        brows: one(BrowShape.values),
        nose: one(NoseShape.values),
        mouth: one(MouthShape.values),
        hair: one(HairStyle.values),
        hairColor: one(HairColor.values),
        detail: random.nextInt(3) == 0 ? one(FaceDetail.values) : FaceDetail.none,
        age: random.nextInt(3) == 0 ? one(FaceAge.values) : FaceAge.none,
      ),
    );
  }
}
