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

  /// Venti persone diverse: uomini e donne, di ogni età e di ogni parte.
  static const all = [
    FacePreset('rosa', SkinTone.porcelain, FaceFeatures(
      shape: FaceShape.heart, eyes: EyeShape.almond, eyeColor: EyeColor.green, brows: BrowShape.arched,
      nose: NoseShape.button, mouth: MouthShape.cupid, hair: HairStyle.victoryRolls, hairColor: HairColor.red,
      detail: FaceDetail.freckles, lips: LipColor.red, shadow: EyeShadow.liner)),
    FacePreset('vito', SkinTone.olive, FaceFeatures(
      shape: FaceShape.square, eyes: EyeShape.hooded, eyeColor: EyeColor.brown, brows: BrowShape.thick,
      nose: NoseShape.roman, mouth: MouthShape.stern, hair: HairStyle.slicked, hairColor: HairColor.black,
      age: FaceAge.lines)),
    FacePreset('amara', SkinTone.ebony, FaceFeatures(
      shape: FaceShape.oval, eyes: EyeShape.upturned, eyeColor: EyeColor.dark, brows: BrowShape.arched,
      nose: NoseShape.broad, mouth: MouthShape.smile, hair: HairStyle.updo, hairColor: HairColor.black,
      detail: FaceDetail.beautyMark, lips: LipColor.wine, shadow: EyeShadow.bronze)),
    FacePreset('kenji', SkinTone.honey, FaceFeatures(
      shape: FaceShape.long, eyes: EyeShape.monolid, eyeColor: EyeColor.dark, brows: BrowShape.straight,
      nose: NoseShape.straight, mouth: MouthShape.smirk, hair: HairStyle.sidePart, hairColor: HairColor.black)),
    FacePreset('lucia', SkinTone.tan, FaceFeatures(
      shape: FaceShape.round, eyes: EyeShape.doe, eyeColor: EyeColor.hazel, brows: BrowShape.rounded,
      nose: NoseShape.small, mouth: MouthShape.lipstickSmile, hair: HairStyle.pinCurls, hairColor: HairColor.darkBrown,
      lips: LipColor.coral, detail: FaceDetail.dimples)),
    FacePreset('ottavio', SkinTone.rose, FaceFeatures(
      shape: FaceShape.oval, eyes: EyeShape.downturned, eyeColor: EyeColor.blue, brows: BrowShape.bushy,
      nose: NoseShape.pointed, mouth: MouthShape.thin, hair: HairStyle.bald, hairColor: HairColor.grey,
      age: FaceAge.deep)),
    FacePreset('farida', SkinTone.sienna, FaceFeatures(
      shape: FaceShape.heart, eyes: EyeShape.catEye, eyeColor: EyeColor.amber, brows: BrowShape.angled,
      nose: NoseShape.roman, mouth: MouthShape.full, hair: HairStyle.long, hairColor: HairColor.black,
      lips: LipColor.plum, shadow: EyeShadow.smoky)),
    FacePreset('theo', SkinTone.espresso, FaceFeatures(
      shape: FaceShape.chiselled, eyes: EyeShape.almond, eyeColor: EyeColor.dark, brows: BrowShape.straight,
      nose: NoseShape.wide, mouth: MouthShape.grin, hair: HairStyle.afro, hairColor: HairColor.black)),
    FacePreset('greta', SkinTone.ivory, FaceFeatures(
      shape: FaceShape.long, eyes: EyeShape.sleepy, eyeColor: EyeColor.grey, brows: BrowShape.pencil,
      nose: NoseShape.straight, mouth: MouthShape.lipstick, hair: HairStyle.fingerWaves, hairColor: HairColor.platinum,
      lips: LipColor.crimson, shadow: EyeShadow.smoky, detail: FaceDetail.beautyMark)),
    FacePreset('mateo', SkinTone.umber, FaceFeatures(
      shape: FaceShape.round, eyes: EyeShape.round, eyeColor: EyeColor.brown, brows: BrowShape.thick,
      nose: NoseShape.button, mouth: MouthShape.smile, hair: HairStyle.curly, hairColor: HairColor.darkBrown)),
    FacePreset('mei', SkinTone.porcelain, FaceFeatures(
      shape: FaceShape.oval, eyes: EyeShape.monolid, eyeColor: EyeColor.dark, brows: BrowShape.straight,
      nose: NoseShape.small, mouth: MouthShape.pout, hair: HairStyle.pageboy, hairColor: HairColor.black,
      lips: LipColor.rose, detail: FaceDetail.rosyCheeks)),
    FacePreset('nonna', SkinTone.olive, FaceFeatures(
      shape: FaceShape.round, eyes: EyeShape.downturned, eyeColor: EyeColor.hazel, brows: BrowShape.thin,
      nose: NoseShape.pointed, mouth: MouthShape.smile, hair: HairStyle.bun, hairColor: HairColor.white,
      age: FaceAge.deep)),
    FacePreset('dino', SkinTone.rose, FaceFeatures(
      shape: FaceShape.chiselled, eyes: EyeShape.deepSet, eyeColor: EyeColor.blue, brows: BrowShape.furrowed,
      nose: NoseShape.crooked, mouth: MouthShape.smirk, hair: HairStyle.quiff, hairColor: HairColor.brown,
      detail: FaceDetail.cheekScar)),
    FacePreset('celeste', SkinTone.umber, FaceFeatures(
      shape: FaceShape.diamond, eyes: EyeShape.wide, eyeColor: EyeColor.brown, brows: BrowShape.arched,
      nose: NoseShape.snub, mouth: MouthShape.lipstick, hair: HairStyle.bob, hairColor: HairColor.chestnut,
      lips: LipColor.red, shadow: EyeShadow.plum)),
    FacePreset('bruno', SkinTone.tan, FaceFeatures(
      shape: FaceShape.pear, eyes: EyeShape.narrow, eyeColor: EyeColor.dark, brows: BrowShape.bushy,
      nose: NoseShape.broad, mouth: MouthShape.wide, hair: HairStyle.receding, hairColor: HairColor.saltPepper,
      age: FaceAge.lines, detail: FaceDetail.mole)),
    FacePreset('ingrid', SkinTone.ivory, FaceFeatures(
      shape: FaceShape.oval, eyes: EyeShape.wide, eyeColor: EyeColor.blue, brows: BrowShape.rounded,
      nose: NoseShape.snub, mouth: MouthShape.smile, hair: HairStyle.braids, hairColor: HairColor.blonde,
      detail: FaceDetail.rosyCheeks, lips: LipColor.rose)),
    FacePreset('sal', SkinTone.honey, FaceFeatures(
      shape: FaceShape.square, eyes: EyeShape.almond, eyeColor: EyeColor.green, brows: BrowShape.angled,
      nose: NoseShape.long, mouth: MouthShape.neutral, hair: HairStyle.pompadour, hairColor: HairColor.auburn)),
    FacePreset('josephine', SkinTone.espresso, FaceFeatures(
      shape: FaceShape.heart, eyes: EyeShape.doe, eyeColor: EyeColor.dark, brows: BrowShape.pencil,
      nose: NoseShape.small, mouth: MouthShape.cupid, hair: HairStyle.fingerWaves, hairColor: HairColor.black,
      lips: LipColor.crimson, shadow: EyeShadow.liner)),
    FacePreset('rocco', SkinTone.sienna, FaceFeatures(
      shape: FaceShape.chiselled, eyes: EyeShape.hooded, eyeColor: EyeColor.hazel, brows: BrowShape.straight,
      nose: NoseShape.straight, mouth: MouthShape.smirk, hair: HairStyle.ducktail, hairColor: HairColor.darkBrown)),
    FacePreset('vera', SkinTone.porcelain, FaceFeatures(
      shape: FaceShape.diamond, eyes: EyeShape.catEye, eyeColor: EyeColor.teal, brows: BrowShape.arched,
      nose: NoseShape.pointed, mouth: MouthShape.lipstick, hair: HairStyle.ponytail, hairColor: HairColor.strawberry,
      lips: LipColor.red, shadow: EyeShadow.teal)),
  ];

  /// Una faccia a caso, ma da ritratto: i colori si accordano con la pelle,
  /// signori e signore hanno ciascuno le loro pettinature, il trucco va con
  /// il rossetto e i capelli bianchi con le rughe.
  static AvatarLook randomize(AvatarLook look, Random random) {
    T one<T>(List<T> values) => values[random.nextInt(values.length)];
    bool chance(double p) => random.nextDouble() < p;
    final tone = one(SkinTone.values);
    final dame = chance(0.5);
    final old = chance(0.15);
    final hairColor = old
        ? one(const [HairColor.grey, HairColor.white, HairColor.saltPepper])
        : tone.light
            ? one(const [
                HairColor.black, HairColor.darkBrown, HairColor.brown, HairColor.chestnut, HairColor.blonde, //
                HairColor.platinum, HairColor.strawberry, HairColor.red, HairColor.auburn,
              ])
            : one(const [HairColor.black, HairColor.black, HairColor.darkBrown, HairColor.darkBrown, HairColor.brown, HairColor.chestnut]);
    final warm = hairColor == HairColor.red || hairColor == HairColor.strawberry || hairColor == HairColor.auburn;
    final eyeColor = tone.light
        ? one(warm ? const [EyeColor.green, EyeColor.hazel, EyeColor.amber, EyeColor.blue, EyeColor.teal] : EyeColor.values)
        : one(const [EyeColor.dark, EyeColor.brown, EyeColor.brown, EyeColor.hazel, EyeColor.amber]);
    final hair = dame
        ? one([for (final h in HairStyle.values) if (h.dame || h == HairStyle.wavy || h == HairStyle.curly || h == HairStyle.coils) h])
        : one(old
            ? const [HairStyle.bald, HairStyle.receding, HairStyle.slicked, HairStyle.sidePart, HairStyle.crewCut]
            : const [
                HairStyle.slicked, HairStyle.sidePart, HairStyle.crewCut, HairStyle.curly, HairStyle.wavy, HairStyle.afro, //
                HairStyle.pompadour, HairStyle.quiff, HairStyle.ducktail, HairStyle.flatTop, HairStyle.middlePart, HairStyle.coils,
              ]);
    // Il rossetto e l'ombretto si scelgono insieme, come in un manifesto.
    final made = dame && chance(0.75);
    final (lips, shadow) = made
        ? one(const [
            (LipColor.red, EyeShadow.liner),
            (LipColor.crimson, EyeShadow.smoky),
            (LipColor.coral, EyeShadow.bronze),
            (LipColor.rose, EyeShadow.rose),
            (LipColor.plum, EyeShadow.plum),
            (LipColor.wine, EyeShadow.smoky),
            (LipColor.red, EyeShadow.teal),
            (LipColor.rose, EyeShadow.none),
          ])
        : (LipColor.none, EyeShadow.none);
    return look.copyWith(
      base: AvatarBase.of(tone, look.base.mark),
      features: FaceFeatures(
        shape: one(dame ? const [FaceShape.oval, FaceShape.heart, FaceShape.round, FaceShape.diamond, FaceShape.long] : FaceShape.values),
        eyes: one(dame ? EyeShape.values : [for (final e in EyeShape.values) if (e != EyeShape.doe && e != EyeShape.catEye) e]),
        eyeColor: eyeColor,
        brows: one(dame
            ? const [BrowShape.arched, BrowShape.thin, BrowShape.rounded, BrowShape.pencil, BrowShape.angled, BrowShape.straight]
            : const [BrowShape.straight, BrowShape.thick, BrowShape.bushy, BrowShape.angled, BrowShape.furrowed, BrowShape.sloped]),
        nose: one(dame
            ? const [NoseShape.straight, NoseShape.button, NoseShape.small, NoseShape.snub, NoseShape.pointed, NoseShape.broad]
            : NoseShape.values),
        mouth: one(dame
            ? (made
                ? const [MouthShape.cupid, MouthShape.full, MouthShape.smile, MouthShape.pout, MouthShape.lipstick, MouthShape.lipstickSmile]
                : const [MouthShape.smile, MouthShape.neutral, MouthShape.full, MouthShape.smirk, MouthShape.grin])
            : const [MouthShape.neutral, MouthShape.smile, MouthShape.smirk, MouthShape.stern, MouthShape.thin, MouthShape.grin, MouthShape.wide]),
        hair: hair,
        hairColor: hairColor,
        detail: chance(0.35)
            ? one(dame
                ? const [FaceDetail.freckles, FaceDetail.beautyMark, FaceDetail.dimples, FaceDetail.rosyCheeks]
                : const [FaceDetail.freckles, FaceDetail.scar, FaceDetail.cheekScar, FaceDetail.mole, FaceDetail.dimples])
            : FaceDetail.none,
        age: old ? one(const [FaceAge.lines, FaceAge.deep]) : (chance(0.12) ? FaceAge.lines : FaceAge.none),
        lips: lips,
        shadow: shadow,
      ),
    );
  }
}
