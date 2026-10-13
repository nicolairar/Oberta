import 'narration_pack.dart';
import 'picker.dart';

/// Un agguato notturno girato come la scena di un film, composto a strati:
/// dove siamo, cosa succede, come si chiude. Tre battute brevi.
/// Ogni strato si pesca per conto suo, quindi due scene uguali sono rarissime.
class DeathStory {
  /// L'azione del Cecchino e quella di chi viene salvato dal Dottore: non
  /// stanno nel mazzo della famiglia, ma hanno anche loro una scena.
  static const sniperId = 'cecchino';
  static const rescueId = 'dottore';

  final StoryPiece scene;
  final StoryPiece method;

  /// Lo stacco finale. Manca quando nessuno è morto: lì chiude il fatto.
  final StoryPiece? epilogue;

  /// La frase chiara che chiude il racconto: chi è morto, o chi l'ha scampata.
  final String fact;

  const DeathStory({
    required this.scene,
    required this.method,
    required this.epilogue,
    required this.fact,
  });

  /// [method] arriva di solito dal mazzo della serata; se manca si pesca qui.
  factory DeathStory.compose(Picker picker, NarrationPack pack, CitySetting city, {StoryPiece? method}) =>
      DeathStory(
        scene: picker.pick('death.scene', city.scenes),
        method: method ?? picker.pick('death.method', pack.methods),
        epilogue: picker.pick('death.epilogue', pack.epilogues),
        fact: pack.victimFact,
      );

  /// Il colpo del Cecchino: stessa città, stesso finale, un'azione tutta sua.
  factory DeathStory.sniper(Picker picker, NarrationPack pack, CitySetting city) => DeathStory(
        scene: picker.pick('death.scene', city.scenes),
        method: StoryPiece(sniperId, picker.pick('death.sniper', pack.sniperShots)),
        epilogue: picker.pick('death.epilogue', pack.epilogues),
        fact: pack.victimFact,
      );

  /// L'agguato andato a vuoto perché il Dottore è arrivato in tempo.
  factory DeathStory.rescue(Picker picker, NarrationPack pack, CitySetting city) => DeathStory(
        scene: picker.pick('death.scene', city.scenes),
        method: StoryPiece(rescueId, picker.pick('death.rescue', pack.rescues)),
        epilogue: null,
        fact: pack.savedFact,
      );

  /// Vero se chi era nel mirino è ancora in gioco.
  bool get survived => epilogue == null;

  /// Le battute della scena, con i segnaposto ancora da riempire.
  List<String> get paragraphs => [scene.text, method.text, if (epilogue != null) epilogue!.text];
}
