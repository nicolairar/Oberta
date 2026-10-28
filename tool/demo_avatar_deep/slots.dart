// The proposed deep-customisation slot system, as data: every slot the bust
// is composed of, back to front, which ones already exist in the live
// AvatarLook and which ones this demo adds. DEMO ONLY: nothing in lib/ uses
// this yet.
import 'package:flutter/painting.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';

/// Who paints a slot today.
enum SlotOwner { live, extended, added }

/// The slots, in paint order (z = index). [owner] says whether the live
/// painter already draws it, the demo extends a live slot, or it is new.
enum DeepSlot {
  aura(SlotOwner.added, 'Background / aura behind the whole figure'),
  backItem(SlotOwner.added, 'Back item: wings, cases, a looming shadow (live wings move here from accessory)'),
  headGlowBack(SlotOwner.added, 'Head effect, back half: glow outline, halo ring behind the head'),
  hairBack(SlotOwner.live, 'Hair behind the head'),
  body(SlotOwner.live, 'Outfit'),
  neck(SlotOwner.live, 'Shirt, tie, neckwear'),
  face(SlotOwner.live, 'Head, ears, nose, mouth'),
  faceExtras(SlotOwner.added, 'Face extras: blush, freckles, tears, scars, makeup'),
  eyes(SlotOwner.extended, 'Eyes, plus an eye-shine style (heart, star, spiral, dollar)'),
  brows(SlotOwner.live, 'Brows'),
  beard(SlotOwner.live, 'Beard, moustache'),
  hairFront(SlotOwner.extended, 'Front hair, plus a hair dye (solid or two-tone gradient)'),
  glasses(SlotOwner.live, 'Glasses'),
  headEffect(SlotOwner.added, 'Head effect, front: halo, horns, orbiting stars, sparks'),
  hat(SlotOwner.live, 'Hat or hairdo (statement hats stay here)'),
  heldLeft(SlotOwner.added, 'Held item, left hand (or one two-handed item)'),
  heldRight(SlotOwner.added, 'Held item, right hand'),
  frontEffect(SlotOwner.added, 'Front effect: smoke rings, petals, coins, bats, in front of everything'),
  frame(SlotOwner.extended, 'Frame: the live seat border, extended to the shop bust');

  final SlotOwner owner;
  final String about;
  const DeepSlot(this.owner, this.about);
}

/// A hair dye: one colour, or two blended top to bottom.
class HairDye {
  final Color top;
  final Color bottom;
  const HairDye(this.top, this.bottom);
}

/// A fully kitted showcase character: the live look plus every new slot.
class DeepLook {
  final String name;
  final AvatarLook look;
  final String aura;
  final String? back;
  final String? headFx;

  /// A glow outline around hair and head (the back half of the head effect).
  final Color? glow;
  final HairDye? dye;
  final Set<String> faceExtras;
  final String? eyeShine;
  final String? heldLeft;
  final String? heldRight;

  /// One item held in both hands (the cat, the teddy): replaces left/right.
  final String? heldBoth;
  final String? frontFx;
  final String frame;

  const DeepLook({
    required this.name,
    required this.look,
    required this.aura,
    this.back,
    this.headFx,
    this.glow,
    this.dye,
    this.faceExtras = const {},
    this.eyeShine,
    this.heldLeft,
    this.heldRight,
    this.heldBoth,
    this.frontFx,
    required this.frame,
  });

  /// The new keys this would add to the profile `avatar` JSON.
  Map<String, Object?> get newJson => {
    'aura': aura,
    if (back != null) 'back': back,
    if (headFx != null) 'headFx': headFx,
    if (dye != null) 'hairDye': 'custom',
    if (faceExtras.isNotEmpty) 'faceExtras': faceExtras.toList(),
    if (eyeShine != null) 'eyeShine': eyeShine,
    if (heldLeft != null) 'heldL': heldLeft,
    if (heldRight != null) 'heldR': heldRight,
    if (heldBoth != null) 'heldL': heldBoth,
    if (frontFx != null) 'frontFx': frontFx,
    'border': frame,
  };
}
