import 'narration_pack.dart';
import 'picker.dart';

/// Un agguato notturno girato come la scena di un film, composto a strati:
/// dove siamo, cosa succede, come si chiude. Tre battute brevi.
/// Ogni strato si pesca per conto suo, quindi due scene uguali sono rarissime.
class DeathStory {
  /// L'azione del Cecchino, quella di chi viene salvato dal Dottore e quella
  /// del colpo che si ferma sulla fiaschetta: non stanno nel mazzo della
  /// famiglia, ma hanno anche loro una scena.
  static const sniperId = 'cecchino';
  static const rescueId = 'dottore';
  static const luckyId = 'fiaschetta';

  /// Le varianti del colpo del Cecchino: ognuna ha il suo filmato e le sue
  /// battute, e l'id dice quale.
  static const belfryId = 'cecchino-campanile';
  static const phoneBoothId = 'cecchino-cabina';
  static const carDoorId = 'cecchino-auto';
  static const sniperIds = [sniperId, belfryId, phoneBoothId, carDoorId];

  /// Le varianti del Dottore che arriva in tempo.
  static const defibrillatorId = 'dottore-defibrillatore';
  static const pliersId = 'dottore-pinze';
  static const ambulanceId = 'dottore-ambulanza';
  static const stitchesId = 'dottore-punti';
  static const rescueIds = [rescueId, defibrillatorId, pliersId, ambulanceId, stitchesId];

  /// Le varianti del colpo andato a vuoto da solo.
  static const bibleId = 'bibbia';
  static const jamId = 'inceppata';
  static const bananaId = 'banana';
  static const blackCatId = 'gatto-nero';
  static const luckyIds = [luckyId, bibleId, jamId, bananaId, blackCatId];

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
        method: _variant(picker, 'death.sniper', pack.sniperShots),
        epilogue: picker.pick('death.epilogue', pack.epilogues),
        fact: pack.victimFact,
      );

  /// L'agguato andato a vuoto perché il Dottore è arrivato in tempo.
  factory DeathStory.rescue(Picker picker, NarrationPack pack, CitySetting city) => DeathStory(
        scene: picker.pick('death.scene', city.scenes),
        method: _variant(picker, 'death.rescue', pack.rescues),
        epilogue: null,
        fact: pack.savedFact,
      );

  /// L'agguato andato a vuoto da solo: il colpo c'è stato, ma chi era nel
  /// mirino ha la pelle dura e resta in piedi.
  factory DeathStory.lucky(Picker picker, NarrationPack pack, CitySetting city) => DeathStory(
        scene: picker.pick('death.scene', city.scenes),
        method: _variant(picker, 'death.lucky', pack.shrugs),
        epilogue: null,
        fact: pack.shruggedFact,
      );

  /// Prima si sorteggia la variante (il filmato), poi una delle sue battute:
  /// l'id del pezzo è quello della variante, così film, suoni e racconto
  /// mettono in scena la stessa cosa. Le varianti pesano tutte uguale, anche
  /// quelle con meno battute, e la stessa non torna subito.
  static StoryPiece _variant(Picker picker, String pool, Map<String, List<String>> lines) {
    final id = picker.pick('$pool.variant', lines.keys.toList());
    return StoryPiece(id, picker.pick('$pool.$id', lines[id]!));
  }

  /// Vero se chi era nel mirino è ancora in gioco.
  bool get survived => epilogue == null;

  /// Le battute della scena, con i segnaposto ancora da riempire.
  List<String> get paragraphs => [scene.text, method.text, if (epilogue != null) epilogue!.text];
}
