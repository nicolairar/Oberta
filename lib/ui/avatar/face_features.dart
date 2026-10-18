import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// La forma della testa, vista di fronte.
enum FaceShape { oval, round, square, long, heart, diamond, pear, chiselled }

/// Il taglio degli occhi.
enum EyeShape { almond, round, hooded, narrow, upturned, downturned, monolid, sleepy, wide, catEye, deepSet, doe }

/// Il colore dell'iride.
enum EyeColor {
  dark(Color(0xFF2A1A12)),
  brown(Color(0xFF5A3A22)),
  hazel(Color(0xFF7A6232)),
  amber(Color(0xFFA8742A)),
  green(Color(0xFF4E7A3A)),
  teal(Color(0xFF3A7470)),
  blue(Color(0xFF4A72A6)),
  grey(Color(0xFF7E8890));

  final Color color;

  const EyeColor(this.color);
}

enum BrowShape { straight, arched, thick, thin, angled, rounded, bushy, pencil, sloped, furrowed }

enum NoseShape { straight, button, roman, broad, pointed, snub, wide, crooked, small, long }

/// La bocca. Le ultime due portano il rossetto anche senza averlo scelto.
enum MouthShape {
  neutral,
  smile,
  smirk,
  full,
  thin,
  stern,
  grin,
  pout,
  cupid,
  wide,
  lipstick,
  lipstickSmile;

  bool get painted => this == lipstick || this == lipstickSmile;
}

/// La pettinatura, che si vede senza cappello (e un poco sotto).
enum HairStyle {
  bald,
  slicked,
  sidePart,
  crewCut,
  curly,
  wavy,
  afro,
  bun,
  bob,
  long,
  pompadour,
  quiff,
  ducktail,
  flatTop,
  middlePart,
  receding,
  coils,
  fingerWaves,
  victoryRolls,
  pinCurls,
  pageboy,
  ponytail,
  braids,
  updo;

  /// I capelli che scendono oltre le orecchie: si vedono anche sotto la tesa.
  bool get falls => const {bob, long, wavy, curly, afro, victoryRolls, pinCurls, pageboy, braids}.contains(this);

  /// Le pettinature da signora.
  bool get dame => const {bob, bun, long, fingerWaves, victoryRolls, pinCurls, pageboy, ponytail, braids, updo}.contains(this);
}

enum HairColor {
  black(Color(0xFF14100E)),
  darkBrown(Color(0xFF2E1E15)),
  brown(Color(0xFF5A3B24)),
  chestnut(Color(0xFF7A4526)),
  blonde(Color(0xFFC9A464)),
  platinum(Color(0xFFE4D9BC)),
  strawberry(Color(0xFFB8693F)),
  red(Color(0xFF8E3A1E)),
  auburn(Color(0xFF5E2618)),
  saltPepper(Color(0xFF5C5955)),
  grey(Color(0xFF8A8580)),
  white(Color(0xFFDCD6CC));

  final Color color;

  const HairColor(this.color);
}

/// Un segno sulla pelle, facoltativo.
enum FaceDetail { none, freckles, beautyMark, scar, dimples, rosyCheeks, cheekScar, mole }

/// Le rughe.
enum FaceAge { none, lines, deep }

/// Il rossetto, facoltativo.
enum LipColor {
  none(Color(0x00000000)),
  red(Color(0xFFC0272D)),
  crimson(Color(0xFF8E1B2B)),
  coral(Color(0xFFD9604A)),
  rose(Color(0xFFC46A78)),
  plum(Color(0xFF6E2A45)),
  wine(Color(0xFF5A1A22));

  final Color color;

  const LipColor(this.color);
}

/// L'ombretto e la matita, facoltativi.
enum EyeShadow {
  none(Color(0x00000000)),
  liner(Color(0xFF14100E)),
  smoky(Color(0xFF3A3236)),
  bronze(Color(0xFF8A5A32)),
  rose(Color(0xFFA85A66)),
  teal(Color(0xFF2E6A6A)),
  plum(Color(0xFF5E3352));

  final Color color;

  const EyeShadow(this.color);
}

/// I lineamenti di una faccia: gratis, si scelgono nello specchio del
/// barbiere. Si salvano nella colonna `avatar` dei profili con chiavi piatte
/// (`"shape": "oval"`, `"eyes": "almond"`...) accanto ai pezzi della bottega.
///
/// Gli id della prima versione sono tutti rimasti: i look salvati prima si
/// rileggono uguali. [_aliases] traduce i nomi che altrove si usano diversi.
@immutable
class FaceFeatures {
  final FaceShape shape;
  final EyeShape eyes;
  final EyeColor eyeColor;
  final BrowShape brows;
  final NoseShape nose;
  final MouthShape mouth;
  final HairStyle hair;
  final HairColor hairColor;
  final FaceDetail detail;
  final FaceAge age;
  final LipColor lips;
  final EyeShadow shadow;

  const FaceFeatures({
    this.shape = FaceShape.oval,
    this.eyes = EyeShape.almond,
    this.eyeColor = EyeColor.brown,
    this.brows = BrowShape.straight,
    this.nose = NoseShape.straight,
    this.mouth = MouthShape.neutral,
    this.hair = HairStyle.slicked,
    this.hairColor = HairColor.black,
    this.detail = FaceDetail.none,
    this.age = FaceAge.none,
    this.lips = LipColor.none,
    this.shadow = EyeShadow.none,
  });

  static const standard = FaceFeatures();

  /// Le chiavi della colonna `avatar`, nell'ordine dello specchio. Le stesse
  /// che la migrazione `face_options` controlla.
  static const keys = [
    'shape', 'eyes', 'eyeColor', 'brows', 'nose', 'mouth', 'hair', 'hairColor', 'detail', 'age', 'lips', 'shadow', //
  ];

  /// Ogni chiave con i suoi id validi.
  static final Map<String, List<String>> options = {
    'shape': _names(FaceShape.values),
    'eyes': _names(EyeShape.values),
    'eyeColor': _names(EyeColor.values),
    'brows': _names(BrowShape.values),
    'nose': _names(NoseShape.values),
    'mouth': _names(MouthShape.values),
    'hair': _names(HairStyle.values),
    'hairColor': _names(HairColor.values),
    'detail': _names(FaceDetail.values),
    'age': _names(FaceAge.values),
    'lips': _names(LipColor.values),
    'shadow': _names(EyeShadow.values),
  };

  /// Nomi vecchi o di comodo verso gli id di oggi.
  static const Map<String, Map<String, String>> _aliases = {
    'hair': {'longWaves': 'wavy', 'sidepart': 'sidePart', 'crew': 'crewCut', 'rockabilly': 'quiff'},
    'hairColor': {'gray': 'grey', 'ginger': 'red'},
    'eyeColor': {'gray': 'grey'},
    'detail': {'mark': 'beautyMark'},
  };

  static List<String> _names(List<Enum> values) => [for (final v in values) v.name];

  Map<String, String> toJson() => {
    'shape': shape.name,
    'eyes': eyes.name,
    'eyeColor': eyeColor.name,
    'brows': brows.name,
    'nose': nose.name,
    'mouth': mouth.name,
    'hair': hair.name,
    'hairColor': hairColor.name,
    'detail': detail.name,
    'age': age.name,
    'lips': lips.name,
    'shadow': shadow.name,
  };

  /// Quello che manca, o che questa versione non conosce, viene da [fallback].
  factory FaceFeatures.fromJson(Map<String, Object?> json, {required FaceFeatures fallback}) {
    T pick<T extends Enum>(String key, List<T> values, T otherwise) {
      var id = json[key];
      if (id is! String) return otherwise;
      id = _aliases[key]?[id] ?? id;
      for (final v in values) {
        if (v.name == id) return v;
      }
      return otherwise;
    }

    return FaceFeatures(
      shape: pick('shape', FaceShape.values, fallback.shape),
      eyes: pick('eyes', EyeShape.values, fallback.eyes),
      eyeColor: pick('eyeColor', EyeColor.values, fallback.eyeColor),
      brows: pick('brows', BrowShape.values, fallback.brows),
      nose: pick('nose', NoseShape.values, fallback.nose),
      mouth: pick('mouth', MouthShape.values, fallback.mouth),
      hair: pick('hair', HairStyle.values, fallback.hair),
      hairColor: pick('hairColor', HairColor.values, fallback.hairColor),
      detail: pick('detail', FaceDetail.values, fallback.detail),
      age: pick('age', FaceAge.values, fallback.age),
      lips: pick('lips', LipColor.values, fallback.lips),
      shadow: pick('shadow', EyeShadow.values, fallback.shadow),
    );
  }

  FaceFeatures copyWith({
    FaceShape? shape,
    EyeShape? eyes,
    EyeColor? eyeColor,
    BrowShape? brows,
    NoseShape? nose,
    MouthShape? mouth,
    HairStyle? hair,
    HairColor? hairColor,
    FaceDetail? detail,
    FaceAge? age,
    LipColor? lips,
    EyeShadow? shadow,
  }) => FaceFeatures(
    shape: shape ?? this.shape,
    eyes: eyes ?? this.eyes,
    eyeColor: eyeColor ?? this.eyeColor,
    brows: brows ?? this.brows,
    nose: nose ?? this.nose,
    mouth: mouth ?? this.mouth,
    hair: hair ?? this.hair,
    hairColor: hairColor ?? this.hairColor,
    detail: detail ?? this.detail,
    age: age ?? this.age,
    lips: lips ?? this.lips,
    shadow: shadow ?? this.shadow,
  );

  /// Lo stesso id in [key], o null se non si conosce.
  FaceFeatures? withId(String key, String id) {
    if (!(options[key]?.contains(id) ?? false)) return null;
    return FaceFeatures.fromJson({...toJson(), key: id}, fallback: this);
  }

  /// Il colore delle labbra: il rossetto scelto, o quello della bocca dipinta.
  Color? get lipstick => lips != LipColor.none
      ? lips.color
      : mouth.painted
          ? LipColor.red.color
          : null;

  @override
  bool operator ==(Object other) =>
      other is FaceFeatures &&
      other.shape == shape &&
      other.eyes == eyes &&
      other.eyeColor == eyeColor &&
      other.brows == brows &&
      other.nose == nose &&
      other.mouth == mouth &&
      other.hair == hair &&
      other.hairColor == hairColor &&
      other.detail == detail &&
      other.age == age &&
      other.lips == lips &&
      other.shadow == shadow;

  @override
  int get hashCode => Object.hash(shape, eyes, eyeColor, brows, nose, mouth, hair, hairColor, detail, age, lips, shadow);
}
