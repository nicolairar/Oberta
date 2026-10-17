import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../online/online_models.dart' show Profile, WornLooks;
import '../widgets/noir_avatar.dart' show AvatarHead, avatarTints, avatarTraitsFor;

/// Come si presenta un giocatore: la faccia, il cappello, gli occhiali,
/// l'abito e un vezzo. Ogni pezzo ha un id di catalogo che non cambia mai,
/// perché è quello che si salva nella colonna `avatar` dei profili
/// (`{"base": ..., "hat": ..., "glasses": ..., "outfit": ..., "accessory": ...}`).
///
/// Chi non ha un profilo (il gioco su un telefono solo, l'elenco dei
/// giocatori) riceve un look ricavato dal nome con [AvatarLook.fallback]:
/// sempre lo stesso, e quasi sempre diverso da quello degli altri.
@immutable
class AvatarLook {
  final AvatarBase base;
  final AvatarHead hat;
  final AvatarGlasses glasses;
  final AvatarOutfit outfit;
  final AvatarAccessory accessory;

  const AvatarLook({
    required this.base,
    required this.hat,
    required this.glasses,
    required this.outfit,
    required this.accessory,
  });

  /// Il look di chi non ha scelto niente: si ricava da [seed] (di solito il
  /// nome) con lo stesso conto del ritratto disegnato ([avatarTraitsFor]),
  /// così cappello, occhiali e cravatta sono quelli della sua moneta.
  factory AvatarLook.fallback(String seed) {
    final traits = avatarTraitsFor(seed);
    // Un secondo conto, indipendente dal primo, per quello che la moneta non
    // mostra: il colore della pelle e i segni sulla faccia.
    var hash = 0x9747B28C;
    for (final unit in seed.codeUnits.reversed) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    hash = (hash ^ (hash >> 13)) & 0xFFFFFFFF;
    int take(int options) {
      final value = hash % options;
      hash = hash ~/ options + 0x5BD1;
      return value;
    }

    final tone = SkinTone.values[take(SkinTone.values.length)];
    final dame = traits.head == AvatarHead.bob || traits.head == AvatarHead.bun || traits.head == AvatarHead.wideBrim;
    final mark = switch (traits.face) {
      'mustache' => dame ? FaceMark.mole : FaceMark.mustache,
      'lips' => FaceMark.lips,
      'scar' => FaceMark.scar,
      _ => dame
          ? const [FaceMark.lips, FaceMark.mole, FaceMark.clean][take(3)]
          : const [FaceMark.clean, FaceMark.stubble, FaceMark.goatee, FaceMark.mustache][take(4)],
    };
    final glasses = switch (traits.face) {
      'glasses' => AvatarGlasses.round,
      'monocle' => AvatarGlasses.monocle,
      'shades' => AvatarGlasses.shades,
      _ => AvatarGlasses.none,
    };
    final accessory = switch (traits.extra) {
      'cigarette' => AvatarAccessory.cigarette,
      'toothpick' => AvatarAccessory.toothpick,
      'none2' when !dame => AvatarAccessory.cigar,
      'earring' when dame => const [AvatarAccessory.pearls, AvatarAccessory.cigarette][take(2)],
      'earring' => AvatarAccessory.carnation,
      _ => switch (traits.collar) {
          'bowTie' => AvatarAccessory.bowTie,
          'pearls' => dame ? AvatarAccessory.pearls : AvatarAccessory.tie,
          'scarf' => AvatarAccessory.scarf,
          _ => dame
              ? const [AvatarAccessory.pearls, AvatarAccessory.carnation, AvatarAccessory.scarf, AvatarAccessory.none][take(4)]
              : AvatarAccessory.tie,
        },
    };
    return AvatarLook(
      base: AvatarBase.of(tone, mark),
      hat: traits.head,
      glasses: glasses,
      outfit: AvatarOutfit.catalog[traits.tint.clamp(0, AvatarOutfit.catalog.length - 1)],
      accessory: accessory,
    );
  }

  /// Quello che indossa chi si chiama [name]: il look salvato sul suo profilo
  /// online, se lo si è visto passare ([WornLooks]), o quello del suo nome.
  factory AvatarLook.of(String name) {
    final fallback = AvatarLook.fallback(name);
    final worn = WornLooks.of(name);
    return worn == null ? fallback : AvatarLook.fromJson(worn, fallback: fallback);
  }

  /// Dalla colonna `avatar`: quello che manca o che il catalogo non conosce
  /// (un pezzo ritirato, una versione nuova dell'app) viene da [fallback].
  factory AvatarLook.fromJson(Map<String, Object?> json, {required AvatarLook fallback}) {
    T pick<T>(String key, T? Function(String id) find, T otherwise) {
      final id = json[key];
      return id is String ? find(id) ?? otherwise : otherwise;
    }

    return AvatarLook(
      base: pick('base', AvatarBase.byId, fallback.base),
      hat: pick('hat', (id) => _byName(AvatarHead.values, id), fallback.hat),
      glasses: pick('glasses', (id) => _byName(AvatarGlasses.values, id), fallback.glasses),
      outfit: pick('outfit', AvatarOutfit.byId, fallback.outfit),
      accessory: pick('accessory', (id) => _byName(AvatarAccessory.values, id), fallback.accessory),
    );
  }

  Map<String, String> toJson() => {
    'base': base.id,
    'hat': hat.name,
    'glasses': glasses.name,
    'outfit': outfit.id,
    'accessory': accessory.name,
  };

  AvatarLook copyWith({
    AvatarBase? base,
    AvatarHead? hat,
    AvatarGlasses? glasses,
    AvatarOutfit? outfit,
    AvatarAccessory? accessory,
  }) => AvatarLook(
    base: base ?? this.base,
    hat: hat ?? this.hat,
    glasses: glasses ?? this.glasses,
    outfit: outfit ?? this.outfit,
    accessory: accessory ?? this.accessory,
  );

  /// L'id indossato in [slot], come lo vende la bottega: per la faccia è il
  /// segno (`walrus`), la pelle non si compra.
  String idIn(LookSlot slot) => switch (slot) {
    LookSlot.hat => hat.name,
    LookSlot.face => base.mark.name,
    LookSlot.glasses => glasses.name,
    LookSlot.outfit => outfit.id,
    LookSlot.accessory => accessory.name,
  };

  /// Lo stesso look con [id] indossato in [slot], o null se il catalogo
  /// dell'app non lo conosce (un pezzo arrivato con una versione nuova).
  AvatarLook? wearing(LookSlot slot, String id) => switch (slot) {
    LookSlot.hat => _byName(AvatarHead.values, id).let((v) => copyWith(hat: v)),
    LookSlot.face => _byName(FaceMark.values, id).let((v) => copyWith(base: AvatarBase.of(base.tone, v))),
    LookSlot.glasses => _byName(AvatarGlasses.values, id).let((v) => copyWith(glasses: v)),
    LookSlot.outfit => AvatarOutfit.byId(id).let((v) => copyWith(outfit: v)),
    LookSlot.accessory => _byName(AvatarAccessory.values, id).let((v) => copyWith(accessory: v)),
  };

  /// Una signora: cambia il taglio delle spalle e dove cade la luce sui capelli.
  bool get dame => hat == AvatarHead.bob || hat == AvatarHead.bun || hat == AvatarHead.wideBrim;

  @override
  bool operator ==(Object other) =>
      other is AvatarLook &&
      other.base == base &&
      other.hat == hat &&
      other.glasses == glasses &&
      other.outfit == outfit &&
      other.accessory == accessory;

  @override
  int get hashCode => Object.hash(base, hat, glasses, outfit, accessory);

  @override
  String toString() => 'AvatarLook(${toJson()})';
}

/// I posti dove si indossa qualcosa, come li chiama il catalogo della
/// bottega (`shop_items.slot`).
enum LookSlot { hat, face, glasses, outfit, accessory }

extension _Let<T extends Object> on T? {
  R? let<R>(R Function(T value) f) {
    final value = this;
    return value == null ? null : f(value);
  }
}

/// Un hash piccolo che dà lo stesso numero su ogni telefono (FNV-1a), a
/// differenza di `String.hashCode`.
int stableHash(String seed) {
  var hash = 0x811C9DC5;
  for (final unit in seed.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

T? _byName<T extends Enum>(List<T> values, String id) {
  for (final value in values) {
    if (value.name == id) return value;
  }
  return null;
}

/// Il colore della pelle, sotto la luce della lampada.
enum SkinTone {
  porcelain(Color(0xFFF0D2BC)),
  rose(Color(0xFFE2B096)),
  olive(Color(0xFFC39868)),
  tan(Color(0xFFA77A4E)),
  umber(Color(0xFF7A5236)),
  ebony(Color(0xFF4F3424));

  final Color color;

  const SkinTone(this.color);
}

/// Quello che si porta in faccia da sempre.
enum FaceMark {
  clean,
  mustache,
  lips,
  scar,
  stubble,
  goatee,
  mole,
  // I baffi della bottega.
  pencil,
  handlebar,
  walrus,
  imperial;

  /// I baffi: chi li porta ha bisogno del pelo, non del rossetto.
  bool get moustache => this == mustache || index >= pencil.index;
}

/// La faccia: pelle e segni. L'id è `pelle_segno`, come `olive_mustache`.
@immutable
class AvatarBase {
  final SkinTone tone;
  final FaceMark mark;

  const AvatarBase._(this.tone, this.mark);

  String get id => '${tone.name}_${mark.name}';
  Color get skin => tone.color;

  static final List<AvatarBase> catalog = [
    for (final tone in SkinTone.values)
      for (final mark in FaceMark.values) AvatarBase._(tone, mark),
  ];

  static AvatarBase of(SkinTone tone, FaceMark mark) => catalog[tone.index * FaceMark.values.length + mark.index];

  static AvatarBase? byId(String id) {
    for (final base in catalog) {
      if (base.id == id) return base;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is AvatarBase && other.tone == tone && other.mark == mark;

  @override
  int get hashCode => Object.hash(tone, mark);
}

enum AvatarGlasses { none, round, monocle, shades, pinceNez, tortoise, aviator }

/// Il vezzo: al collo, all'occhiello o tra i denti.
enum AvatarAccessory {
  none,
  tie,
  bowTie,
  pearls,
  scarf,
  carnation,
  cigar,
  cigarette,
  toothpick,
  // I vezzi della bottega.
  pocketWatch,
  pipe,
  pocketSquare,
  polkaTie,
  cravat;

  /// Quello che fumano: il fumo sale da qui.
  bool get smokes => this == cigar || this == cigarette || this == pipe;
}

/// Il disegno della stoffa.
enum CoatPattern { plain, pinstripe, check, doubleBreasted, chalkstripe, trench, brocade }

/// L'abito: il colore della giacca, la stoffa, la camicia e il colore del
/// vezzo (la cravatta, il fazzoletto, il fondo del ritratto).
@immutable
class AvatarOutfit {
  final String id;
  final Color coat;
  final CoatPattern pattern;
  final Color shirt;
  final Color accent;

  const AvatarOutfit(this.id, this.coat, this.pattern, this.accent, {this.shirt = const Color(0xFFEDE4D6)});

  /// Nell'ordine dei fondali dei ritratti ([avatarTints]): chi riceve un
  /// look dal nome porta la cravatta del colore della sua moneta.
  static final List<AvatarOutfit> catalog = [
    AvatarOutfit('charcoal_pinstripe', const Color(0xFF37363C), CoatPattern.pinstripe, avatarTints[0]),
    AvatarOutfit('navy_double', const Color(0xFF1F2B48), CoatPattern.doubleBreasted, avatarTints[1]),
    AvatarOutfit('bottle_green', const Color(0xFF1F3D30), CoatPattern.plain, avatarTints[2]),
    AvatarOutfit('camel_check', const Color(0xFF80603A), CoatPattern.check, avatarTints[3]),
    AvatarOutfit('plum_velvet', const Color(0xFF3C2544), CoatPattern.plain, avatarTints[4]),
    AvatarOutfit('cream_dinner', const Color(0xFFC9BC9F), CoatPattern.plain, avatarTints[5], shirt: const Color(0xFFF6F0E4)),
    AvatarOutfit('slate_check', const Color(0xFF3A4B55), CoatPattern.check, avatarTints[6]),
    AvatarOutfit('wine_silk', const Color(0xFF5C2238), CoatPattern.plain, avatarTints[7]),
    AvatarOutfit('rust_tweed', const Color(0xFF6B3523), CoatPattern.check, avatarTints[8]),
    AvatarOutfit('olive_pinstripe', const Color(0xFF39442C), CoatPattern.pinstripe, avatarTints[9]),
    const AvatarOutfit('black_tuxedo', Color(0xFF18171B), CoatPattern.plain, Color(0xFF18171B), shirt: Color(0xFFF6F0E4)),
    // Dalla sartoria della bottega.
    const AvatarOutfit('navy_chalkstripe', Color(0xFF1B2440), CoatPattern.chalkstripe, Color(0xFF9B2335)),
    const AvatarOutfit('grey_flannel', Color(0xFF5A5A5E), CoatPattern.plain, Color(0xFF2E4A6B)),
    const AvatarOutfit('brown_pinstripe', Color(0xFF4A3222), CoatPattern.pinstripe, Color(0xFFC08A3E)),
    const AvatarOutfit('cream_linen', Color(0xFFD8CCAE), CoatPattern.plain, Color(0xFF7A2E2A), shirt: Color(0xFFF6F0E4)),
    const AvatarOutfit('midnight_double', Color(0xFF14182A), CoatPattern.doubleBreasted, Color(0xFFB8963E)),
    const AvatarOutfit('white_dinner', Color(0xFFEDE6D6), CoatPattern.plain, Color(0xFF18171B), shirt: Color(0xFFFFFFFF)),
    const AvatarOutfit('trench_coat', Color(0xFF9A8158), CoatPattern.trench, Color(0xFF3A2A1C)),
    const AvatarOutfit('gold_brocade', Color(0xFF2A1A12), CoatPattern.brocade, Color(0xFFE2B54A), shirt: Color(0xFFF6F0E4)),
  ];

  static AvatarOutfit? byId(String id) {
    for (final outfit in catalog) {
      if (outfit.id == id) return outfit;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is AvatarOutfit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Il look di un profilo online: quello salvato, e per i posti vuoti quello
/// del suo nome.
extension ProfileLook on Profile {
  AvatarLook get look => AvatarLook.fromJson(avatar, fallback: AvatarLook.fallback(handle ?? id));
}
