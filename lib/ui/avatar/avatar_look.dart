import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../online/online_models.dart' show Profile, WornLooks;
import '../../online/shop_models.dart' show CalcioTeam, ShopBrand;
import '../widgets/cosmetics/cosmetic_ids.dart';
import '../widgets/noir_avatar.dart' show AvatarHead, avatarTints, avatarTraitsFor;
import 'deep_slots.dart';
import 'face_features.dart';

export '../widgets/cosmetics/cosmetic_ids.dart';
export 'deep_slots.dart';
export 'face_features.dart';

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

  /// I lineamenti, gratis: la forma della testa, gli occhi, i capelli.
  final FaceFeatures features;

  /// Una pettinatura stravagante della bottega: se c'è, copre quella gratis.
  final Hairdo hairdo;

  /// Un tatuaggio della bottega, dove si vede la pelle.
  final Tattoo tattoo;

  /// La cornice del posto al tavolo, della bottega.
  final SeatBorder border;

  /// Il colore del nome sulla targhetta e in chat, della bottega.
  final NameStyle nameStyle;

  // --- I posti più cari (deep_slots.dart): tutti vuoti, se non comprati.

  /// La scena dietro la persona.
  final Aura aura;

  /// Quello che porta sulle spalle (le ali comprese).
  final BackItem back;

  /// L'effetto in testa, o il bagliore intorno ai capelli.
  final HeadFx headFx;

  /// I segni sulla faccia, fino a [FaceExtra.most], nell'ordine in cui li ha messi.
  final List<FaceExtra> faceExtras;

  /// La luce negli occhi.
  final EyeShine eyeShine;

  /// La tinta dei capelli.
  final HairDye hairDye;

  /// Quello che tiene a sinistra e a destra del ritratto. Una cosa da tenere
  /// con due mani sta a sinistra, e la destra resta vuota.
  final HeldItem heldL;
  final HeldItem heldR;

  /// L'effetto davanti a tutto.
  final FrontFx frontFx;

  const AvatarLook({
    required this.base,
    required this.hat,
    required this.glasses,
    required this.outfit,
    required this.accessory,
    this.features = FaceFeatures.standard,
    this.hairdo = Hairdo.none,
    this.tattoo = Tattoo.none,
    this.border = SeatBorder.none,
    this.nameStyle = NameStyle.plain,
    this.aura = Aura.none,
    this.back = BackItem.none,
    this.headFx = HeadFx.none,
    this.faceExtras = const [],
    this.eyeShine = EyeShine.none,
    this.hairDye = HairDye.none,
    this.heldL = HeldItem.none,
    this.heldR = HeldItem.none,
    this.frontFx = FrontFx.none,
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
      features: featuresFor(seed, tone: tone, hat: traits.head, dame: dame),
    );
  }

  /// I lineamenti di chi non li ha scelti, da [seed]: un terzo conto, così
  /// aggiungerli non ha cambiato cappelli e abiti di nessuno.
  static FaceFeatures featuresFor(String seed, {required SkinTone tone, required AvatarHead hat, required bool dame}) {
    var hash = stableHash('face:$seed');
    hash = (hash ^ (hash >> 15)) * 0x2C1B3C6D & 0xFFFFFFFF;
    int take(int options) {
      final value = hash % options;
      hash = hash ~/ options + 0x3A5F;
      return value;
    }

    T one<T>(List<T> options) => options[take(options.length)];
    final light = tone.light;
    final age = one(const [FaceAge.none, FaceAge.none, FaceAge.none, FaceAge.lines, FaceAge.deep]);
    final hair = switch (hat) {
      AvatarHead.slicked => HairStyle.slicked,
      AvatarHead.bob => HairStyle.bob,
      AvatarHead.bun => HairStyle.bun,
      _ when dame => one(const [
          HairStyle.bob,
          HairStyle.bun,
          HairStyle.long,
          HairStyle.fingerWaves,
          HairStyle.victoryRolls,
          HairStyle.pinCurls,
          HairStyle.pageboy,
          HairStyle.updo,
        ]),
      _ => one(const [
          HairStyle.slicked,
          HairStyle.sidePart,
          HairStyle.crewCut,
          HairStyle.wavy,
          HairStyle.curly,
          HairStyle.sidePart,
          HairStyle.afro,
          HairStyle.bald,
          HairStyle.pompadour,
          HairStyle.quiff,
          HairStyle.receding,
          HairStyle.middlePart,
        ]),
    };
    final hairColor = age == FaceAge.deep && take(2) == 0
        ? one(const [HairColor.grey, HairColor.white])
        : light
            ? one(const [HairColor.black, HairColor.darkBrown, HairColor.brown, HairColor.blonde, HairColor.red, HairColor.auburn])
            : one(const [HairColor.black, HairColor.black, HairColor.darkBrown, HairColor.brown]);
    return FaceFeatures(
      shape: one(FaceShape.values),
      eyes: one(EyeShape.values),
      eyeColor: light ? one(EyeColor.values) : one(const [EyeColor.dark, EyeColor.brown, EyeColor.brown, EyeColor.hazel]),
      brows: dame ? one(const [BrowShape.arched, BrowShape.thin, BrowShape.straight]) : one(BrowShape.values),
      nose: one(NoseShape.values),
      mouth: one([for (final m in MouthShape.values) if (dame || !m.painted) m]),
      hair: hair,
      hairColor: hairColor,
      detail: one(const [FaceDetail.none, FaceDetail.none, FaceDetail.none, FaceDetail.freckles, FaceDetail.beautyMark, FaceDetail.none]),
      age: age,
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

    // Le ali erano un vezzo: chi le portava prima che passassero sulle
    // spalle le ritrova lì (il server ha già spostato quelle salvate).
    final oldWings = json['back'] == null ? _byName(BackItem.values, '${json['accessory']}') : null;
    var heldL = pick(Hand.left.key, (id) => _byName(HeldItem.values, id), fallback.heldL);
    var heldR = pick(Hand.right.key, (id) => _byName(HeldItem.values, id), fallback.heldR);
    if (heldL.twoHanded) {
      heldR = HeldItem.none;
    } else if (heldR.twoHanded) {
      (heldL, heldR) = (heldR, HeldItem.none);
    }
    final extras = json['faceExtras'];
    return AvatarLook(
      base: pick('base', AvatarBase.byId, fallback.base),
      hat: pick('hat', (id) => _byName(AvatarHead.values, id), fallback.hat),
      glasses: pick('glasses', (id) => _byName(AvatarGlasses.values, id), fallback.glasses),
      outfit: pick('outfit', AvatarOutfit.byId, fallback.outfit),
      accessory: pick('accessory', (id) => _byName(AvatarAccessory.values, id), fallback.accessory),
      features: FaceFeatures.fromJson(json, fallback: fallback.features),
      hairdo: pick('hairdo', (id) => _byName(Hairdo.values, id), fallback.hairdo),
      tattoo: pick('tattoo', (id) => _byName(Tattoo.values, id), fallback.tattoo),
      border: pick('border', (id) => _byName(SeatBorder.values, id), fallback.border),
      nameStyle: pick('nameStyle', (id) => _byName(NameStyle.values, id), fallback.nameStyle),
      aura: pick('aura', (id) => _byName(Aura.values, id), fallback.aura),
      back: oldWings != null && oldWings.wing ? oldWings : pick('back', (id) => _byName(BackItem.values, id), fallback.back),
      headFx: pick('headFx', (id) => _byName(HeadFx.values, id), fallback.headFx),
      faceExtras: extras is String ? parseExtras(extras) : fallback.faceExtras,
      eyeShine: pick('eyeShine', (id) => _byName(EyeShine.values, id), fallback.eyeShine),
      hairDye: pick('hairDye', (id) => _byName(HairDye.values, id), fallback.hairDye),
      heldL: heldL,
      heldR: heldR,
      frontFx: pick('frontFx', (id) => _byName(FrontFx.values, id), fallback.frontFx),
    );
  }

  /// I segni sulla faccia come li salva il profilo: `blush+tear`, o `none`.
  /// Quelli che il catalogo non conosce si lasciano, e se ne tengono due.
  static List<FaceExtra> parseExtras(String id) {
    final extras = <FaceExtra>[];
    for (final part in id.split('+')) {
      final extra = _byName(FaceExtra.values, part);
      if (extra != null && !extras.contains(extra)) extras.add(extra);
    }
    return List.unmodifiable(extras.length > FaceExtra.most ? extras.sublist(extras.length - FaceExtra.most) : extras);
  }

  /// I segni sulla faccia come li salva il profilo.
  static String extrasId(List<FaceExtra> extras) => extras.isEmpty ? 'none' : extras.map((e) => e.name).join('+');

  Map<String, String> toJson() => {
    'base': base.id,
    'hat': hat.name,
    'glasses': glasses.name,
    'outfit': outfit.id,
    'accessory': accessory.name,
    ...features.toJson(),
    'hairdo': hairdo.name,
    'tattoo': tattoo.name,
    'border': border.name,
    'nameStyle': nameStyle.name,
    'aura': aura.name,
    'back': back.name,
    'headFx': headFx.name,
    'faceExtras': extrasId(faceExtras),
    'eyeShine': eyeShine.name,
    'hairDye': hairDye.name,
    Hand.left.key: heldL.name,
    Hand.right.key: heldR.name,
    'frontFx': frontFx.name,
  };

  AvatarLook copyWith({
    AvatarBase? base,
    AvatarHead? hat,
    AvatarGlasses? glasses,
    AvatarOutfit? outfit,
    AvatarAccessory? accessory,
    FaceFeatures? features,
    Hairdo? hairdo,
    Tattoo? tattoo,
    SeatBorder? border,
    NameStyle? nameStyle,
    Aura? aura,
    BackItem? back,
    HeadFx? headFx,
    List<FaceExtra>? faceExtras,
    EyeShine? eyeShine,
    HairDye? hairDye,
    HeldItem? heldL,
    HeldItem? heldR,
    FrontFx? frontFx,
  }) => AvatarLook(
    base: base ?? this.base,
    hat: hat ?? this.hat,
    glasses: glasses ?? this.glasses,
    outfit: outfit ?? this.outfit,
    accessory: accessory ?? this.accessory,
    features: features ?? this.features,
    hairdo: hairdo ?? this.hairdo,
    tattoo: tattoo ?? this.tattoo,
    border: border ?? this.border,
    nameStyle: nameStyle ?? this.nameStyle,
    aura: aura ?? this.aura,
    back: back ?? this.back,
    headFx: headFx ?? this.headFx,
    faceExtras: faceExtras ?? this.faceExtras,
    eyeShine: eyeShine ?? this.eyeShine,
    hairDye: hairDye ?? this.hairDye,
    heldL: heldL ?? this.heldL,
    heldR: heldR ?? this.heldR,
    frontFx: frontFx ?? this.frontFx,
  );

  /// Quello che tiene in [hand].
  HeldItem held(Hand hand) => hand == Hand.left ? heldL : heldR;

  /// La cosa tenuta con tutte e due le mani, se c'è.
  HeldItem? get heldBoth => heldL.twoHanded ? heldL : (heldR.twoHanded ? heldR : null);

  /// Lo stesso look con [item] in mano. Una cosa da due mani le prende
  /// tutte e due; una da una mano va in [hand] (o in quella libera, la
  /// destra se lo sono tutte e due) e lascia la cosa da due mani che c'era.
  AvatarLook holding(HeldItem item, {Hand? hand}) {
    if (item == HeldItem.none) return copyWith(heldL: HeldItem.none, heldR: HeldItem.none);
    if (item.twoHanded) return copyWith(heldL: item, heldR: HeldItem.none);
    final into = hand ?? (heldR == HeldItem.none || heldL != HeldItem.none ? Hand.right : Hand.left);
    final keep = heldBoth != null ? HeldItem.none : held(into.other);
    return into == Hand.left ? copyWith(heldL: item, heldR: keep) : copyWith(heldL: keep, heldR: item);
  }

  /// Lo stesso look con un segno in più sulla faccia (il più vecchio cede il
  /// posto se ce ne sono già [FaceExtra.most]); con [toggle], un segno che
  /// c'è già si toglie.
  AvatarLook marked(FaceExtra extra, {bool toggle = false}) =>
      faceExtras.contains(extra) && !toggle ? this : copyWith(faceExtras: toggledExtras(faceExtras, extra));

  /// [worn] con [extra] tolto se c'è, o aggiunto (e il più vecchio fuori,
  /// oltre [FaceExtra.most]): come fa il server (`equip_item`).
  static List<FaceExtra> toggledExtras(List<FaceExtra> worn, FaceExtra extra) {
    if (worn.contains(extra)) return List.unmodifiable([for (final e in worn) if (e != extra) e]);
    final next = [...worn, extra];
    return List.unmodifiable(next.length > FaceExtra.most ? next.sublist(next.length - FaceExtra.most) : next);
  }

  /// Porta qualcosa che chiede spazio nel ritratto: le cose in mano e quelle
  /// sulle spalle (le ali di sempre no, hanno già il loro).
  bool get roomy => back.roomy || heldL != HeldItem.none || heldR != HeldItem.none;

  /// L'id indossato in [slot], come lo vende la bottega: per la faccia è il
  /// segno (`walrus`), la pelle non si compra.
  String idIn(LookSlot slot) => switch (slot) {
    LookSlot.hat => hat.name,
    LookSlot.face => base.mark.name,
    LookSlot.glasses => glasses.name,
    LookSlot.outfit => outfit.id,
    LookSlot.accessory => accessory.name,
    LookSlot.hairdo => hairdo.name,
    LookSlot.tattoo => tattoo.name,
    LookSlot.border => border.name,
    LookSlot.nameStyle => nameStyle.name,
    LookSlot.aura => aura.name,
    LookSlot.back => back.name,
    LookSlot.headFx => headFx.name,
    LookSlot.faceExtras => extrasId(faceExtras),
    LookSlot.eyeShine => eyeShine.name,
    LookSlot.hairDye => hairDye.name,
    LookSlot.held => (heldBoth ?? (heldR != HeldItem.none ? heldR : heldL)).name,
    LookSlot.frontFx => frontFx.name,
  };

  /// Se porta [id] in [slot]: per le mani in una delle due, per i segni
  /// della faccia tra quelli che ha.
  bool wears(LookSlot slot, String id) => switch (slot) {
    LookSlot.held => id == 'none' ? heldL == HeldItem.none && heldR == HeldItem.none : heldL.name == id || heldR.name == id,
    LookSlot.faceExtras => id == 'none' ? faceExtras.isEmpty : faceExtras.any((e) => e.name == id),
    _ => idIn(slot) == id,
  };

  /// Lo stesso look con [id] indossato in [slot], o null se il catalogo
  /// dell'app non lo conosce (un pezzo arrivato con una versione nuova).
  /// Per le mani, [hand] dice quale ([holding]); un segno della faccia si
  /// aggiunge a quelli che ha ([marked]).
  AvatarLook? wearing(LookSlot slot, String id, {Hand? hand}) => switch (slot) {
    LookSlot.hat => _byName(AvatarHead.values, id).let((v) => copyWith(hat: v)),
    LookSlot.face => _byName(FaceMark.values, id).let((v) => copyWith(base: AvatarBase.of(base.tone, v))),
    LookSlot.glasses => _byName(AvatarGlasses.values, id).let((v) => copyWith(glasses: v)),
    LookSlot.outfit => AvatarOutfit.byId(id).let((v) => copyWith(outfit: v)),
    LookSlot.accessory => _byName(AvatarAccessory.values, id).let((v) => copyWith(accessory: v)),
    LookSlot.hairdo => _byName(Hairdo.values, id).let((v) => copyWith(hairdo: v)),
    LookSlot.tattoo => _byName(Tattoo.values, id).let((v) => copyWith(tattoo: v)),
    LookSlot.border => _byName(SeatBorder.values, id).let((v) => copyWith(border: v)),
    LookSlot.nameStyle => _byName(NameStyle.values, id).let((v) => copyWith(nameStyle: v)),
    LookSlot.aura => _byName(Aura.values, id).let((v) => copyWith(aura: v)),
    LookSlot.back => _byName(BackItem.values, id).let((v) => copyWith(back: v)),
    LookSlot.headFx => _byName(HeadFx.values, id).let((v) => copyWith(headFx: v)),
    LookSlot.faceExtras => id == 'none' ? copyWith(faceExtras: const []) : _byName(FaceExtra.values, id).let(marked),
    LookSlot.eyeShine => _byName(EyeShine.values, id).let((v) => copyWith(eyeShine: v)),
    LookSlot.hairDye => _byName(HairDye.values, id).let((v) => copyWith(hairDye: v)),
    LookSlot.held => _byName(HeldItem.values, id).let((v) => holding(v, hand: hand)),
    LookSlot.frontFx => _byName(FrontFx.values, id).let((v) => copyWith(frontFx: v)),
  };

  /// Una signora: cambia il taglio delle spalle e dove cade la luce sui capelli.
  /// Chi ha scelto «Uomo» o «Donna» nello specchio decide lui; gli altri
  /// (e i look ricavati dal nome) seguono il cappello e la pettinatura.
  bool get dame => switch (features.presentation) {
    Presentation.woman => true,
    Presentation.man => false,
    Presentation.other => _dameByLook,
  };

  bool get _dameByLook =>
      hat == AvatarHead.bob ||
      hat == AvatarHead.bun ||
      hat == AvatarHead.wideBrim ||
      hat == AvatarHead.cloche ||
      features.hair.dame;

  /// Senza cappello: si vede la pettinatura scelta nello specchio.
  /// (`slicked`, `bob` e `bun` sono le teste nude del catalogo.)
  bool get bareHead => hat == AvatarHead.slicked || hat == AvatarHead.bob || hat == AvatarHead.bun;

  /// La pelle, come la si vede: il mimo se la dipinge di bianco.
  Color get skin => base.skin;

  @override
  bool operator ==(Object other) =>
      other is AvatarLook &&
      other.base == base &&
      other.hat == hat &&
      other.glasses == glasses &&
      other.outfit == outfit &&
      other.accessory == accessory &&
      other.features == features &&
      other.hairdo == hairdo &&
      other.tattoo == tattoo &&
      other.border == border &&
      other.nameStyle == nameStyle &&
      other.aura == aura &&
      other.back == back &&
      other.headFx == headFx &&
      listEquals(other.faceExtras, faceExtras) &&
      other.eyeShine == eyeShine &&
      other.hairDye == hairDye &&
      other.heldL == heldL &&
      other.heldR == heldR &&
      other.frontFx == frontFx;

  @override
  int get hashCode => Object.hash(
    base,
    hat,
    glasses,
    outfit,
    accessory,
    features,
    hairdo,
    tattoo,
    border,
    nameStyle,
    Object.hash(aura, back, headFx, Object.hashAll(faceExtras), eyeShine, hairDye, heldL, heldR, frontFx),
  );

  @override
  String toString() => 'AvatarLook(${toJson()})';
}

/// I posti dove si indossa qualcosa, come li chiama il catalogo della
/// bottega (`shop_items.slot`).
enum LookSlot {
  hat,
  face,
  glasses,
  outfit,
  accessory,
  hairdo,
  tattoo,
  border,
  nameStyle,
  // I posti più cari (deep_slots.dart).
  aura,
  back,
  headFx,
  faceExtras,
  eyeShine,
  hairDye,

  /// Le mani: un pezzo solo nel catalogo, che si tiene a sinistra o a
  /// destra (le chiavi `heldL` e `heldR` del profilo).
  held,
  frontFx;

  /// Non si indossano addosso ma intorno: la cornice del posto e il nome.
  bool get around => this == border || this == nameStyle;

  /// Chiedono il ritratto intero, non un primo piano: la scena, le spalle,
  /// le mani e quello che sta davanti.
  bool get wide => this == aura || this == back || this == held || this == frontFx;
}

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
  ebony(Color(0xFF4F3424)),
  // Lo specchio del barbiere: altre quattro pelli.
  ivory(Color(0xFFF6DFC8)),
  honey(Color(0xFFD9A774)),
  sienna(Color(0xFF94603E)),
  espresso(Color(0xFF3A2519));

  final Color color;

  const SkinTone(this.color);

  /// Dalla più chiara alla più scura, per lo specchio.
  static const ordered = [ivory, porcelain, rose, honey, olive, tan, sienna, umber, ebony, espresso];

  /// Le pelli chiare: occhi e capelli di ogni colore.
  bool get light => this == ivory || this == porcelain || this == rose || this == honey;
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
  mimeFace,
  // L'assurdo.
  vikingBeard,
  // La statua d'oro: la pelle, i capelli e il riflesso, tutto in foglia d'oro.
  goldStatue;

  /// I baffi: chi li porta ha bisogno del pelo, non del rossetto.
  bool get moustache => this == mustache || (index >= pencil.index && this != mimeFace && this != goldStatue);
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
  giantShades,
  // L'assurdo.
  googlyEyes,
  glasses3d,
  bulbMonocle;

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
  // L'assurdo. (Le ali sono passate sulle spalle: [BackItem].)
  snailShell,
  jetpack,
  balloons,
  giantBowTie,
  pigeon,
  plungerSword,
  // Il calcio.
  blaugranaScarf,
  blaugranaFlare,
  merenguesScarf,
  merenguesTrophy,
  celestiScarf,
  celestiMegaphone,
  diavoliScarf,
  diavoliFlare,
  redsScarf,
  redsMegaphone,
  rossoneriScarf,
  rossoneriFlare,
  nerazzurriScarf,
  nerazzurriFlag,
  bianconeriScarf,
  bianconeriTrophy,
  giallorossiScarf,
  giallorossiFlare,
  azzurriScarf,
  azzurriFlag;

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
  // Per le signore, gratis: l'abito intero e la camicetta.
  dress,
  blouse,
  // Le stramberie: costumi, non giacche.
  clown,
  leotard,
  breton,
  chef,
  banana,
  // L'assurdo.
  pizza,
  cactus,
  ghost,
  mummy,
  // Il calcio: la maglia d'epoca col collo allacciato.
  jersey;

  /// I costumi della bottega delle stramberie: niente camicia, niente cravatta.
  bool get costume => index >= clown.index;

  /// Giacche senza risvolti a punta: hanno il loro collo.
  bool get ownCollar => this == cape || this == track || this == cardigan || feminine || costume;

  /// Abiti e camicette: lo scollo morbido, senza risvolti.
  bool get feminine => this == dress || this == blouse;
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
    // Per le signore, gratis anche questi: abiti e camicette.
    const AvatarOutfit('rose_dress', Color(0xFF9E4A5A), CoatPattern.dress, Color(0xFFF2D7C9)),
    const AvatarOutfit('black_dress', Color(0xFF1A171C), CoatPattern.dress, Color(0xFFE2C46A)),
    const AvatarOutfit('emerald_dress', Color(0xFF1F5A44), CoatPattern.dress, Color(0xFFF2E6CF)),
    const AvatarOutfit('ivory_blouse', Color(0xFFEDE4D2), CoatPattern.blouse, Color(0xFF7A2E3A), shirt: Color(0xFF2A2C3E)),
    const AvatarOutfit('powder_blouse', Color(0xFFA9BCD3), CoatPattern.blouse, Color(0xFF1F2B48), shirt: Color(0xFF3A2A24)),
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
    // L'assurdo.
    const AvatarOutfit('pizza_suit', Color(0xFFF2C24A), CoatPattern.pizza, Color(0xFFC8282E)),
    const AvatarOutfit('cactus_suit', Color(0xFF3E8E3E), CoatPattern.cactus, Color(0xFFE85A9A)),
    const AvatarOutfit('ghost_sheet', Color(0xFFF4F2EC), CoatPattern.ghost, Color(0xFF1B1B22)),
    const AvatarOutfit('mummy_wraps', Color(0xFFE6DCC2), CoatPattern.mummy, Color(0xFF8A7A58)),
    // Il calcio: la maglia nel colore della squadra, il fondo della sua città.
    for (final team in CalcioTeam.values)
      AvatarOutfit(team.kitId, team.primary, CoatPattern.jersey, team.backdrop, shirt: team.trim),
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

/// Le pettinature stravaganti della bottega: si comprano, e indossate coprono
/// quella scelta nello specchio (e tolgono il cappello).
enum Hairdo {
  none,
  beehive,
  punkSpikes,
  spaceBuns,
  toweringPompadour,
  flowerCrown,
  mermaidWaves,
  flameBouffant,
  glitterAfro,
  samuraiTopknot,
  stripedUndercut,
  rainbowPonytail,
  birdNestMane,
}

/// I tatuaggi della bottega, alla marinara: dove si vede la pelle.
enum Tattoo {
  none,
  anchor,
  swallow,
  roseDagger,
  mammaHeart,
  spiderWeb,
  teardrop,
  cheekStar,
  koi,
  playingCards,
  skullTopHat,
  familyCrest,
}
