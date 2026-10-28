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

  /// Il fiammifero del Piromane.
  static const fireId = 'incendio';

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

  /// La scorta del Presidente respinge l'attentato (il suo filmato).
  static const escortId = 'scorta';

  /// Gli agguati della famiglia che lasciano chi era nel mirino steso sulla
  /// strada, dove il Dottore può inginocchiarsi: chi finisce appeso, sotto
  /// un pianoforte o in un furgone, il Dottore non lo raggiunge.
  static const _bullets = {'silenziatore', 'violino', 'lupara', 'raffica', 'trombone', 'rose'};
  static const _blades = {'pugnale', 'buio', 'pescespada', 'tango'};
  static const _onTheStreet = {
    ..._bullets,
    ..._blades,
    'auto',
    'pacco',
    'sigaro',
    'veleno',
    'mazza',
    'garrota',
    'vaso',
    'bacio',
    'boccia',
    'torta',
  };

  /// Le varianti del Dottore che sanno rimediare all'agguato [methodId]:
  /// le pinze solo dove c'è un proiettile, ago e filo solo dove c'è una
  /// ferita. Vuoto se il Dottore lì non arriva.
  static List<String> rescuesFor(String methodId) => [
        if (_onTheStreet.contains(methodId)) ...[
          rescueId,
          defibrillatorId,
          ambulanceId,
          if (_bullets.contains(methodId) || _blades.contains(methodId)) stitchesId,
          if (_bullets.contains(methodId)) pliersId,
        ],
      ];

  /// I colpi di fortuna che sanno mandare a vuoto l'agguato [methodId]:
  /// la fiaschetta e la Bibbia fermano un colpo dritto al petto, l'arma
  /// inceppata fa clic, sulla buccia di banana scivola chi arriva di corsa,
  /// il gatto nero salta sul braccio di chi prende la mira. Vuoto se
  /// nessuno ha senso.
  static List<String> luckFor(String methodId) => switch (methodId) {
        'silenziatore' => luckyIds,
        'pugnale' => const [luckyId, bibleId, bananaId],
        'lupara' => const [luckyId, bibleId, jamId, blackCatId],
        'violino' => const [jamId, blackCatId],
        'trombone' => const [luckyId, bibleId, jamId],
        'mazza' => const [bananaId],
        _ => const [],
      };

  final StoryPiece scene;
  final StoryPiece method;

  /// L'agguato della famiglia che è andato a vuoto: il filmato lo mette in
  /// scena prima di [method], che dice come è andato a vuoto. Manca negli
  /// agguati andati a segno.
  final StoryPiece? attack;

  /// Lo stacco finale. Manca quando nessuno è morto: lì chiude il fatto.
  final StoryPiece? epilogue;

  /// La frase chiara che chiude il racconto: chi è morto, o chi l'ha scampata.
  final String fact;

  const DeathStory({
    required this.scene,
    required this.method,
    required this.epilogue,
    required this.fact,
    this.attack,
  });

  /// [method] arriva di solito dal mazzo della serata; se manca si pesca qui.
  factory DeathStory.compose(Picker picker, NarrationPack pack, CitySetting city, {StoryPiece? method}) => DeathStory(
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

  /// Il rogo del Piromane: stessa città, stesso finale, il fuoco.
  factory DeathStory.fire(Picker picker, NarrationPack pack, CitySetting city) => DeathStory(
    scene: picker.pick('death.scene', city.scenes),
    method: StoryPiece(fireId, picker.pick('death.fire', pack.fires)),
    epilogue: picker.pick('death.epilogue', pack.epilogues),
    fact: pack.burnedFact,
  );

  /// L'agguato andato a vuoto perché il Dottore è arrivato in tempo. Con
  /// [attack] (di solito dal mazzo della serata) si vede proprio
  /// quell'agguato, e il Dottore arriva con un rimedio adatto; senza, è un
  /// colpo di pistola qualunque.
  factory DeathStory.rescue(Picker picker, NarrationPack pack, CitySetting city, {StoryPiece? attack}) => DeathStory(
        scene: picker.pick('death.scene', city.scenes),
    method: _variant(picker, 'death.rescue', pack.rescues, only: attack == null ? null : rescuesFor(attack.id)),
        epilogue: null,
        fact: pack.savedFact,
        attack: attack,
      );

  /// L'agguato andato a vuoto da solo: il colpo c'è stato, ma chi era nel
  /// mirino ha la pelle dura e resta in piedi. Con [attack] si vede
  /// quell'agguato, e la fortuna che lo ferma.
  factory DeathStory.lucky(Picker picker, NarrationPack pack, CitySetting city, {StoryPiece? attack}) => DeathStory(
        scene: picker.pick('death.scene', city.scenes),
    method: _variant(picker, 'death.lucky', pack.shrugs, only: attack == null ? null : luckFor(attack.id)),
        epilogue: null,
        fact: pack.shruggedFact,
        attack: attack,
      );

  /// L'attentato al Presidente respinto dalla scorta: si vede l'agguato
  /// ([attack]), poi la scorta che lo para.
  factory DeathStory.escort(Picker picker, NarrationPack pack, CitySetting city, {StoryPiece? attack}) => DeathStory(
    scene: picker.pick('death.scene', city.scenes),
    method: StoryPiece(escortId, picker.pick('death.escort', pack.escorts)),
    epilogue: null,
    fact: pack.escortFact,
    attack: attack,
  );

  /// Prima si sorteggia la variante (il filmato), poi una delle sue battute:
  /// l'id del pezzo è quello della variante, così film, suoni e racconto
  /// mettono in scena la stessa cosa. Le varianti pesano tutte uguale, anche
  /// quelle con meno battute, e la stessa non torna subito. Con [only] si
  /// pesca solo fra quelle che vanno con l'agguato.
  static StoryPiece _variant(Picker picker, String pool, Map<String, List<String>> lines, {List<String>? only}) {
    final id = picker.pick(
      '$pool.variant',
      lines.keys.toList(),
      where: only == null || only.isEmpty ? null : only.contains,
    );
    return StoryPiece(id, picker.pick('$pool.$id', lines[id]!));
  }

  /// Vero se chi era nel mirino è ancora in gioco.
  bool get survived => epilogue == null;

  /// Le battute della scena, con i segnaposto ancora da riempire.
  List<String> get paragraphs => [scene.text, method.text, if (epilogue != null) epilogue!.text];
}
