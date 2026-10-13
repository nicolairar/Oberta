import 'narration_pack.dart';
import 'picker.dart';

/// Una morte notturna girata come la scena di un film, composta a strati:
/// dove siamo, cosa succede, come si chiude. Tre battute brevi.
/// Ogni strato si pesca per conto suo, quindi due morti uguali sono rarissime.
class DeathStory {
  final StoryPiece scene;
  final StoryPiece method;
  final StoryPiece epilogue;

  const DeathStory({
    required this.scene,
    required this.method,
    required this.epilogue,
  });

  factory DeathStory.compose(Picker picker, NarrationPack pack, CitySetting city) => DeathStory(
        scene: picker.pick('death.scene', city.scenes),
        method: picker.pick('death.method', pack.methods),
        epilogue: picker.pick('death.epilogue', pack.epilogues),
      );

  /// Le tre battute della scena, con i segnaposto ancora da riempire.
  List<String> get paragraphs => [scene.text, method.text, epilogue.text];
}
