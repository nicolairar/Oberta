import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// La forma della testa, vista di fronte.
enum FaceShape { oval, round, square, long, heart }

/// Il taglio degli occhi.
enum EyeShape { almond, round, hooded, narrow, upturned, downturned }

/// Il colore dell'iride.
enum EyeColor {
  dark(Color(0xFF2A1A12)),
  brown(Color(0xFF5A3A22)),
  hazel(Color(0xFF7A6232)),
  green(Color(0xFF4E6E3A)),
  blue(Color(0xFF4A6E96)),
  grey(Color(0xFF7A8088));

  final Color color;

  const EyeColor(this.color);
}

enum BrowShape { straight, arched, thick, thin, angled }

enum NoseShape { straight, button, roman, broad, pointed }

enum MouthShape { neutral, smile, smirk, full, thin, stern }

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
  long;

  /// I capelli che scendono oltre le orecchie: si vedono anche sotto la tesa.
  bool get falls => this == bob || this == long || this == wavy || this == curly || this == afro;
}

enum HairColor {
  black(Color(0xFF14100E)),
  darkBrown(Color(0xFF2E1E15)),
  brown(Color(0xFF5A3B24)),
  blonde(Color(0xFFC9A464)),
  red(Color(0xFF8E3A1E)),
  auburn(Color(0xFF5E2618)),
  grey(Color(0xFF8A8580)),
  white(Color(0xFFDCD6CC));

  final Color color;

  const HairColor(this.color);
}

/// Un segno sulla pelle, facoltativo.
enum FaceDetail { none, freckles, beautyMark, scar }

/// Le rughe.
enum FaceAge { none, lines, deep }

/// I lineamenti di una faccia: gratis, si scelgono nello specchio del
/// barbiere. Si salvano nella colonna `avatar` dei profili con chiavi piatte
/// (`"shape": "oval"`, `"eyes": "almond"`...) accanto ai pezzi della bottega.
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
  });

  static const standard = FaceFeatures();

  /// Le chiavi della colonna `avatar`, nell'ordine dello specchio. Le stesse
  /// che la migrazione `save_face` controlla.
  static const keys = ['shape', 'eyes', 'eyeColor', 'brows', 'nose', 'mouth', 'hair', 'hairColor', 'detail', 'age'];

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
  };

  /// Quello che manca, o che questa versione non conosce, viene da [fallback].
  factory FaceFeatures.fromJson(Map<String, Object?> json, {required FaceFeatures fallback}) {
    T pick<T extends Enum>(String key, List<T> values, T otherwise) {
      final id = json[key];
      if (id is! String) return otherwise;
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
  );

  /// Lo stesso id in [key], o null se non si conosce.
  FaceFeatures? withId(String key, String id) {
    if (!(options[key]?.contains(id) ?? false)) return null;
    return FaceFeatures.fromJson({...toJson(), key: id}, fallback: this);
  }

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
      other.age == age;

  @override
  int get hashCode => Object.hash(shape, eyes, eyeColor, brows, nose, mouth, hair, hairColor, detail, age);
}
