import 'narration_pack.dart';
import 'picker.dart';

/// Una morte notturna girata come la scena di un film, composta a strati:
/// dove siamo, come inquadra la cinepresa, cosa succede, come si chiude.
/// Ogni strato si pesca per conto suo, quindi due morti uguali sono rarissime.
class DeathStory {
  final StoryPiece scene;
  final StoryPiece shot;
  final StoryPiece method;
  final StoryPiece epilogue;

  const DeathStory({
    required this.scene,
    required this.shot,
    required this.method,
    required this.epilogue,
  });

  factory DeathStory.compose(Picker picker, NarrationPack pack, CitySetting city) => DeathStory(
        scene: picker.pick('death.scene', city.scenes),
        shot: picker.pick('death.shot', pack.shots),
        method: picker.pick('death.method', pack.methods),
        epilogue: picker.pick('death.epilogue', pack.epilogues),
      );

  /// I quattro paragrafi della scena, con i segnaposto ancora da riempire.
  List<String> get paragraphs => [scene.text, shot.text, method.text, epilogue.text];
}
