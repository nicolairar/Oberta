import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../online/online_models.dart' show Profile, WornLooks;
import '../../online/shop_models.dart' show ShopBrand;
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
  bool get dame =>
      hat == AvatarHead.bob || hat == AvatarHead.bun || hat == AvatarHead.wideBrim || hat == AvatarHead.cloche;

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
  imperial,
  // La seconda consegna.
  chevron,
  horseshoe,
  vandyke,
  muttonChops,
  fullBeard,
  // Le stramberie.
  curledMoustache,
  giantMoustache,
  mimeFace;

  /// I baffi: chi li porta ha bisogno del pelo, non del rossetto.
  bool get moustache => this == mustache || (index >= pencil.index && this != mimeFace);
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

enum AvatarGlasses {
  none,
  round,
  monocle,
  shades,
  pinceNez,
  tortoise,
  aviator,
  // La seconda consegna.
  goldRims,
  browline,
  catEye,
  delacroixShades,
  ricciMonocle,
  // Le stramberie.
  noseDisguise,
  heartGlasses,
  hypnoGlasses,
  eyePatch,
  giantGlasses,
  giantShades;

  /// Le lenti scure: gli occhi non si vedono.
  bool get dark => this == shades || this == aviator || this == delacroixShades || this == hypnoGlasses || this == giantShades;
}

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
  cravat,
  // La seconda consegna.
  stripeTie,
  knitTie,
  polkaBowTie,
  whiteCarnation,
  suspenders,
  cigaretteHolder,
  ricciChain,
  ricciTiePin,
  ricciWatch,
  delacroixScarf,
  delacroixAscot,
  // Le case.
  vaugirardStrap,
  chanterellePearls,
  // Le stramberie.
  clownNose,
  parrot,
  rubberDuck,
  accordion,
  baguetteCigar,
  angelWings,
  batWings,
  butterflyWings;

  /// Quello che fumano: il fumo sale da qui.
  bool get smokes =>
      this == cigar || this == cigarette || this == pipe || this == cigaretteHolder || this == baguetteCigar;
}

/// Il disegno della stoffa.
enum CoatPattern {
  plain,
  pinstripe,
  check,
  doubleBreasted,
  chalkstripe,
  trench,
  brocade,
  // La seconda consegna.
  windowpane,
  herringbone,
  sharkskin,
  tuxedo,
  velvet,
  cape,
  track,
  cardigan,
  // Le case.
  canvas,
  baroque,
  // Le stramberie: costumi, non giacche.
  clown,
  leotard,
  breton,
  chef,
  banana;

  /// I costumi della bottega delle stramberie: niente camicia, niente cravatta.
  bool get costume => index >= clown.index;

  /// Giacche senza risvolti a punta: hanno il loro collo.
  bool get ownCollar => this == cape || this == track || this == cardigan || costume;
}

/// L'abito: il colore della giacca, la stoffa, la camicia e il colore del
/// vezzo (la cravatta, il fazzoletto, il fondo del ritratto).
@immutable
class AvatarOutfit {
  final String id;
  final Color coat;
  final CoatPattern pattern;
  final Color shirt;
  final Color accent;

  /// I risvolti di raso lucido, da sera.
  final bool satin;

  /// La casa che la firma: la sua toppa ricamata sul petto.
  final ShopBrand? brand;

  const AvatarOutfit(
    this.id,
    this.coat,
    this.pattern,
    this.accent, {
    this.shirt = const Color(0xFFEDE4D6),
    this.satin = false,
    this.brand,
  });

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
    const AvatarOutfit(
      'black_tuxedo',
      Color(0xFF18171B),
      CoatPattern.plain,
      Color(0xFF18171B),
      shirt: Color(0xFFF6F0E4),
      satin: true,
    ),
    // Dalla sartoria della bottega.
    const AvatarOutfit('navy_chalkstripe', Color(0xFF1B2440), CoatPattern.chalkstripe, Color(0xFF9B2335)),
    const AvatarOutfit('grey_flannel', Color(0xFF5A5A5E), CoatPattern.plain, Color(0xFF2E4A6B)),
    const AvatarOutfit('brown_pinstripe', Color(0xFF4A3222), CoatPattern.pinstripe, Color(0xFFC08A3E)),
    const AvatarOutfit('cream_linen', Color(0xFFD8CCAE), CoatPattern.plain, Color(0xFF7A2E2A), shirt: Color(0xFFF6F0E4)),
    const AvatarOutfit('midnight_double', Color(0xFF14182A), CoatPattern.doubleBreasted, Color(0xFFB8963E)),
    const AvatarOutfit(
      'white_dinner',
      Color(0xFFEDE6D6),
      CoatPattern.plain,
      Color(0xFF18171B),
      shirt: Color(0xFFFFFFFF),
      satin: true,
    ),
    const AvatarOutfit('trench_coat', Color(0xFF9A8158), CoatPattern.trench, Color(0xFF3A2A1C)),
    const AvatarOutfit(
      'gold_brocade',
      Color(0xFF2A1A12),
      CoatPattern.brocade,
      Color(0xFFE2B54A),
      shirt: Color(0xFFF6F0E4),
      satin: true,
    ),
    // La seconda consegna.
    const AvatarOutfit('charcoal_windowpane', Color(0xFF2F3137), CoatPattern.windowpane, Color(0xFF8E1D28)),
    const AvatarOutfit('tan_herringbone', Color(0xFF7E6244), CoatPattern.herringbone, Color(0xFF2E4A2E)),
    const AvatarOutfit('steel_sharkskin', Color(0xFF4C5766), CoatPattern.sharkskin, Color(0xFF16213E)),
    const AvatarOutfit('oxblood_double', Color(0xFF4A181D), CoatPattern.doubleBreasted, Color(0xFFC9A04A)),
    // Arminio Milano: la sartoria morbida, greige e blu notte, senza spalle.
    const AvatarOutfit('vanetti_pinstripe', Color(0xFF232B3E), CoatPattern.plain, Color(0xFF9A907E), brand: ShopBrand.arminio),
    const AvatarOutfit(
      'vanetti_tuxedo',
      Color(0xFF131929),
      CoatPattern.tuxedo,
      Color(0xFF131929),
      shirt: Color(0xFFF2EEE6),
      satin: true,
      brand: ShopBrand.arminio,
    ),
    const AvatarOutfit(
      'vanetti_ivory',
      Color(0xFFA89E8C),
      CoatPattern.plain,
      Color(0xFF2A3246),
      shirt: Color(0xFFF2EEE6),
      brand: ShopBrand.arminio,
    ),
    // Maison Chanterelle: nero e bianco, il bordo intrecciato e le perle.
    const AvatarOutfit(
      'delacroix_velvet',
      Color(0xFF151417),
      CoatPattern.velvet,
      Color(0xFFF2EEE6),
      shirt: Color(0xFFF6F2EA),
      brand: ShopBrand.chanterelle,
    ),
    const AvatarOutfit(
      'delacroix_cape',
      Color(0xFF111015),
      CoatPattern.cape,
      Color(0xFFF2EEE6),
      shirt: Color(0xFFFAF6EC),
      brand: ShopBrand.chanterelle,
    ),
    // Nikea Sport: nero, panna e arancio da pista.
    const AvatarOutfit(
      'fulmine_track',
      Color(0xFF1A1A1E),
      CoatPattern.track,
      Color(0xFFE8742A),
      shirt: Color(0xFFF2E6CF),
      brand: ShopBrand.nikea,
    ),
    const AvatarOutfit(
      'fulmine_cardigan',
      Color(0xFFE6DDC8),
      CoatPattern.cardigan,
      Color(0xFFE8742A),
      shirt: Color(0xFFF2E6CF),
      brand: ShopBrand.nikea,
    ),
    // Vaugirard & Fils: la tela da baule color cuoio, l'ottone.
    const AvatarOutfit(
      'vaugirard_travel',
      Color(0xFF8E6A40),
      CoatPattern.canvas,
      Color(0xFF4A2E1A),
      brand: ShopBrand.vaugirard,
    ),
    // Cuccioli Firenze: il blazer color avena, la fascia verde-ambra.
    const AvatarOutfit(
      'cuccioli_blazer',
      Color(0xFFC8B48C),
      CoatPattern.plain,
      Color(0xFF1F6B63),
      shirt: Color(0xFFF6F0E4),
      brand: ShopBrand.cuccioli,
    ),
    // Versalli: nero e oro, volute barocche.
    const AvatarOutfit(
      'versalli_baroque',
      Color(0xFF121014),
      CoatPattern.baroque,
      Color(0xFFE2B54A),
      shirt: Color(0xFF121014),
      satin: true,
      brand: ShopBrand.versalli,
    ),
    // Adelphi Atletica: blu e bianco, il carré a due toni.
    const AvatarOutfit(
      'adelphi_track',
      Color(0xFF1B2D55),
      CoatPattern.track,
      Color(0xFFF2EEE6),
      shirt: Color(0xFFF2E6CF),
      brand: ShopBrand.adelphi,
    ),
    const AvatarOutfit(
      'adelphi_cardigan',
      Color(0xFF2C5A3A),
      CoatPattern.cardigan,
      Color(0xFFF2EEE6),
      shirt: Color(0xFFF2E6CF),
      brand: ShopBrand.adelphi,
    ),
    // Le stramberie: il circo e il carnevale.
    const AvatarOutfit('clown_suit', Color(0xFFE9C23A), CoatPattern.clown, Color(0xFFD23A2E), shirt: Color(0xFFF8F4EA)),
    const AvatarOutfit('strongman_leotard', Color(0xFFB0262A), CoatPattern.leotard, Color(0xFFF2E6CF)),
    const AvatarOutfit('mime_stripes', Color(0xFFF2EEE6), CoatPattern.breton, Color(0xFFC8282E)),
    const AvatarOutfit(
      'magician_cape',
      Color(0xFF121016),
      CoatPattern.cape,
      Color(0xFFB0202C),
      shirt: Color(0xFFF6F0E4),
      satin: true,
    ),
    const AvatarOutfit('chef_whites', Color(0xFFEDE9E0), CoatPattern.chef, Color(0xFFC8282E)),
    const AvatarOutfit('banana_suit', Color(0xFFF0CB2E), CoatPattern.banana, Color(0xFF5A3A1A)),
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
