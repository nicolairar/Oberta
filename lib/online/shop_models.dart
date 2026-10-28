import 'dart:ui' show Color;

import '../l10n/app_language.dart';
import 'online_models.dart';

/// Le classi della bottega. Il prezzo lo decide la classe, ed è lo stesso
/// sul server (vincolo su `shop_items.price_coins`). Le monete si
/// guadagnano solo giocando: i prezzi sono tarati su quanto si gioca
/// (docs/economia.md): un comune in due partite, un raro in una settimana
/// da giocatore occasionale, un leggendario in uno-due mesi.
enum ShopRarity {
  /// Il corredo di tutti: costa niente e lo si possiede già.
  base(0),
  comune(120),
  raro(700),
  epico(1100),
  leggendario(2900);

  /// Il prezzo della classe (per i pezzi dei posti profondi, il minimo).
  final int price;

  const ShopRarity(this.price);

  /// Il prezzo di un pezzo profondo da quello di listino con cui è nato:
  /// i leggendari ×1,6 alla cinquantina (il riequilibrio senza acquisti,
  /// `20261122100000_earn_only_missions.sql`), gli altri restano.
  static int earned(ShopRarity rarity, int listed) =>
      rarity == leggendario ? (listed * 8 / 5 / 50).round() * 50 : listed;

  static ShopRarity parse(String? name) =>
      values.firstWhere((rarity) => rarity.name == name, orElse: () => ShopRarity.comune);
}

/// Le case di moda della bottega: nomi e marchi inventati, ognuno con il suo
/// segno disegnato a mano ([LookPainter.brandMark]). L'id è quello della
/// colonna `shop_items.brand`.
enum ShopBrand {
  /// Bauli e valigie da viaggio: tela color cuoio e ottone. Il marchio: la
  /// placca della serratura con il buco della chiave.
  vaugirard('Vaugirard & Fils', Color(0xFFC89A5A)),

  /// Sartoria milanese morbida, greige e blu notte. Il marchio: un tondo
  /// sottile tagliato da un orizzonte.
  arminio('Arminio Milano', Color(0xFFBDB3A1)),

  /// Pelletteria fiorentina: la fascia verde-ambra-verde e la staffa d'ottone.
  cuccioli('Cuccioli Firenze', Color(0xFFD89A2B)),

  /// Il barocco: nero e oro, volute. Il marchio: una rosa d'oro a otto petali.
  versalli('Versalli', Color(0xFFE2B54A)),

  /// Alta moda parigina in bianco e nero, con le perle: un fiocco e una perla.
  chanterelle('Maison Chanterelle', Color(0xFFF2EEE6)),

  /// Sport d'anteguerra, nero e arancio: un'ala a tre penne.
  nikea('Nikea Sport', Color(0xFFE8742A)),

  /// Atletica dei due fratelli, blu e bianco: due stelle affiancate.
  adelphi('Adelphi Atletica', Color(0xFF5B9BE0));

  final String label;
  final Color color;

  const ShopBrand(this.label, this.color);

  static ShopBrand? byId(String? id) => values.where((brand) => brand.name == id).firstOrNull;
}

/// Le collezioni dello scaffale delle stramberie. L'id è quello della
/// colonna `shop_items.collection`.
enum ShopCollection {
  /// Il tendone: il clown, il forzuto, il prestigiatore, il mimo.
  circo('Circo', 'Circus'),

  /// I costumi e gli scherzi: il pirata, il cuoco, il gallo, le ali.
  carnevale('Carnevale', 'Carnival'),

  /// L'assurdo: teste di pesce, razzi, piccioni, torte in testa.
  assurdo('Assurdo', 'Absurd'),

  /// Il calcio: le maglie, le sciarpe e i fumogeni delle curve.
  calcio('Calcio', 'Football');

  final String it;
  final String en;

  const ShopCollection(this.it, this.en);

  static ShopCollection? byId(String? id) => values.where((c) => c.name == id).firstOrNull;
}

/// Un pezzo del catalogo. [id] è `slot.lookId`; [lookId] è quello che il
/// profilo salva per quel posto (per la faccia, il segno: `walrus`).
class ShopItem {
  final String id;
  final String slot;
  final String lookId;
  final ShopRarity rarity;
  final int price;
  final String nameIt;
  final String nameEn;
  final DateTime releasedOn;
  final int sort;

  /// La casa che lo firma, o null per i pezzi della bottega.
  final ShopBrand? brand;

  /// La collezione delle stramberie, o null.
  final ShopCollection? collection;

  /// L'obiettivo che lo regala, o null. Un pezzo con [unlock] non si
  /// compra: si sblocca solo riscuotendo quella missione (prezzo zero).
  final String? unlock;

  const ShopItem({
    required this.id,
    required this.slot,
    required this.lookId,
    required this.rarity,
    required this.price,
    required this.nameIt,
    required this.nameEn,
    required this.releasedOn,
    this.sort = 0,
    this.brand,
    this.collection,
    this.unlock,
  });

  /// Un pezzo che non si vende: lo regala l'obiettivo [unlock].
  ShopItem.exclusive(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, String this.unlock)
    : id = '$slot.$lookId',
      price = 0,
      releasedOn = DateTime.utc(2026, 11, 22),
      brand = null,
      collection = null;

  /// Un pezzo del catalogo di partenza, con il prezzo della sua classe.
  ShopItem.seed(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, {this.brand})
    : id = '$slot.$lookId',
      unlock = null,
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 17),
      collection = null;

  /// Un pezzo della seconda consegna (le case di moda e il resto).
  ShopItem.drop(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, {this.brand})
    : id = '$slot.$lookId',
      unlock = null,
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 18),
      collection = null;

  /// Un pezzo della terza consegna: una casa e basta.
  ShopItem.house(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, ShopBrand this.brand)
    : id = '$slot.$lookId',
      unlock = null,
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 18),
      collection = null;

  /// Una stramberia: il circo e il carnevale.
  ShopItem.oddity(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, ShopCollection this.collection)
    : id = '$slot.$lookId',
      unlock = null,
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 18),
      brand = null;

  /// Un pezzo da stadio: la squadra la dice l'id ([CalcioTeam.of]).
  ShopItem.calcio(this.slot, this.lookId, this.nameIt, this.nameEn, this.sort)
    : id = '$slot.$lookId',
      unlock = null,
      rarity = ShopRarity.leggendario,
      price = ShopRarity.leggendario.price,
      releasedOn = DateTime.utc(2026, 10, 23),
      brand = null,
      collection = ShopCollection.calcio;

  /// Un pezzo dei posti più cari (la scena, le spalle, gli effetti, le mani,
  /// i ritocchi alla faccia): il prezzo è il suo, sopra quello della classe.
  ShopItem.deep(this.slot, this.lookId, this.rarity, int listed, this.nameIt, this.nameEn, this.sort)
    : id = '$slot.$lookId',
      unlock = null,
      price = ShopRarity.earned(rarity, listed),
      releasedOn = DateTime.utc(2026, 11, 20),
      brand = null,
      collection = null;

  /// Una cornice o un inchiostro per il nome: si indossano intorno.
  ShopItem.around(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort)
    : id = '$slot.$lookId',
      unlock = null,
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 24),
      brand = null,
      collection = null;

  /// Un gesto da lanciare al tavolo ([TableGesture]).
  ShopItem.gesture(this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort)
    : id = 'gesture.$lookId',
      unlock = null,
      slot = 'gesture',
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 11, 9),
      brand = null,
      collection = null;

  /// Non si porta addosso ma intorno: la cornice del posto o il nome.
  bool get around => slot == 'border' || slot == 'nameStyle';

  /// Non si porta affatto: si lancia al tavolo.
  bool get isGesture => slot == 'gesture';

  bool get free => rarity == ShopRarity.base;

  /// Non si vende: lo regala una missione.
  bool get exclusive => unlock != null;

  String name(AppLanguage language) => language == AppLanguage.it ? nameIt : nameEn;

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: json['id'] as String,
    slot: json['slot'] as String,
    lookId: json['look_id'] as String,
    rarity: ShopRarity.parse(json['rarity'] as String?),
    price: (json['price_coins'] as num).toInt(),
    nameIt: json['name_it'] as String,
    nameEn: json['name_en'] as String,
    releasedOn: DateTime.tryParse(json['released_on'] as String? ?? '') ?? DateTime.utc(2026, 10, 17),
    sort: (json['sort'] as num?)?.toInt() ?? 0,
    brand: ShopBrand.byId(json['brand'] as String?),
    collection: ShopCollection.byId(json['collection'] as String?),
    unlock: json['unlock'] as String?,
  );
}

/// Un pezzo in vetrina, da [startsAt] a [endsAt].
class ShopFeature {
  final String itemId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int sort;

  const ShopFeature({required this.itemId, required this.startsAt, required this.endsAt, this.sort = 0});

  bool liveAt(DateTime now) => !now.isBefore(startsAt) && now.isBefore(endsAt);

  factory ShopFeature.fromJson(Map<String, dynamic> json) => ShopFeature(
    itemId: json['item_id'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: DateTime.parse(json['ends_at'] as String),
    sort: (json['sort'] as num?)?.toInt() ?? 0,
  );
}

/// Un pacchetto: pezzi del catalogo venduti insieme, con lo sconto. Ogni
/// pezzo si compra anche da solo, ma il pacchetto conviene. Il prezzo lo fa
/// il server (`bundle_price`): la somma dei pezzi che mancano, meno lo
/// sconto, arrotondata per difetto alla decina. [price] fa lo stesso conto,
/// solo per mostrarlo.
class ShopBundle {
  final String id;

  /// `set` o `premium`: i pacchetti di lusso stanno in cima ai prezzi.
  final String tier;
  final int discountPct;
  final String nameIt;
  final String nameEn;
  final String taglineIt;
  final String taglineEn;
  final int sort;
  final List<String> itemIds;

  const ShopBundle({
    required this.id,
    required this.tier,
    required this.discountPct,
    required this.nameIt,
    required this.nameEn,
    required this.taglineIt,
    required this.taglineEn,
    required this.itemIds,
    this.sort = 0,
  });

  bool get premium => tier == 'premium';

  String name(AppLanguage language) => language == AppLanguage.it ? nameIt : nameEn;
  String tagline(AppLanguage language) => language == AppLanguage.it ? taglineIt : taglineEn;

  /// I pezzi a pagamento che [owned] non ha ancora.
  List<ShopItem> missing(Map<String, ShopItem> catalog, Set<String> owned) => [
    for (final id in itemIds)
      if (catalog[id] case final item? when !item.free && !owned.contains(id)) item,
  ];

  /// Quanto costerebbero i pezzi che mancano, presi uno a uno.
  int singles(Map<String, ShopItem> catalog, Set<String> owned) =>
      missing(catalog, owned).fold(0, (sum, item) => sum + item.price);

  /// Il prezzo del pacchetto per chi possiede [owned]: 0 se ha già tutto.
  int price(Map<String, ShopItem> catalog, Set<String> owned) =>
      singles(catalog, owned) * (100 - discountPct) ~/ 100 ~/ 10 * 10;

  factory ShopBundle.fromJson(Map<String, dynamic> json) => ShopBundle(
    id: json['id'] as String,
    tier: json['tier'] as String? ?? 'set',
    discountPct: (json['discount_pct'] as num).toInt(),
    nameIt: json['name_it'] as String,
    nameEn: json['name_en'] as String,
    taglineIt: json['tagline_it'] as String? ?? '',
    taglineEn: json['tagline_en'] as String? ?? '',
    sort: (json['sort'] as num?)?.toInt() ?? 0,
    itemIds: [
      for (final row in (json['shop_bundle_items'] as List? ?? const [])) (row as Map)['item_id'] as String,
    ],
  );
}

/// La bottega vista dal telefono. Il saldo, l'inventario e il look indossato
/// li scrive solo il server: qui si chiede, e si riceve il profilo nuovo.
abstract class ShopRepository {
  /// Tutto il catalogo acceso, base compresa, in ordine.
  Future<List<ShopItem>> catalog();

  /// La vetrina di adesso.
  Future<List<ShopFeature>> featured();

  /// Gli id dei pezzi comprati (quelli di base si possiedono sempre).
  Future<Set<String>> owned();

  /// Compra con le monete: [OnlineFailure.notEnoughCoins],
  /// [OnlineFailure.alreadyOwned] o [OnlineFailure.itemNotFound] se non si può.
  Future<Profile> buy(String itemId);

  /// I pacchetti accesi, in ordine.
  Future<List<ShopBundle>> bundles();

  /// Compra i pezzi che mancano di un pacchetto, al prezzo del pacchetto:
  /// [OnlineFailure.alreadyOwned] se si ha già tutto.
  Future<Profile> buyBundle(String bundleId);

  /// Indossa un pezzo posseduto ([OnlineFailure.notOwned] altrimenti).
  /// [tone] è la pelle che l'app mostra, per chi non ha mai salvato un look:
  /// serve solo ai baffi.
  /// [current] è tutto il look che l'app mostra: il server lo salva sotto
  /// quello già salvato (solo i pezzi posseduti), così cambia solo il pezzo
  /// scelto. [hand] (`left` o `right`) dice in che mano va una cosa da
  /// tenere; un segno della faccia già portato si toglie.
  Future<Profile> equip(String itemId, {String? tone, Map<String, String>? current, String? hand});

  /// Si toglie quello che porta in [slot]: torna il pezzo che gli spetta dal nome.
  Future<Profile> unequip(String slot, {String? tone, Map<String, String>? current});
}

/// Il catalogo, lo stesso delle migrazioni
/// `supabase/migrations/20261017221000_shop.sql` e
/// `supabase/migrations/20261018120000_shop_brands.sql` e seguenti (un test li
/// confronta): la bottega finta lo usa, quella vera lo legge dal server.
final List<ShopItem> initialShopCatalog = [..._firstDrop, ...brandDrop, ...houseDrop, ...odditiesDrop, ...barberDrop, ...calcioDrop, ...framesDrop, ...gestureDrop, ...deepDrop, ...missionDrop];

/// I pezzi che hanno cambiato posto (`supabase/migrations/20261121090000_shop_deep_slots.sql`):
/// le ali erano un vezzo e ora stanno sulle spalle. Le righe vecchie restano
/// spente sul server, per i conti delle monete già spese.
const retiredShopItems = {
  'accessory.angelWings': 'back.angelWings',
  'accessory.batWings': 'back.batWings',
  'accessory.butterflyWings': 'back.butterflyWings',
  'accessory.dragonWings': 'back.dragonWings',
};

/// I posti più cari, la classe più alta: le scene (un quadro intero) costano
/// più di ogni leggendario di prima; le spalle, gli effetti e le cose da due
/// mani poco meno; le mani, le tinte, gli occhi e i segni sono epici, sopra
/// gli epici di prima.
final List<ShopItem> deepDrop = [
  ShopItem.deep('aura', 'none', ShopRarity.base, 0, 'Nessuna scena', 'No scene', 1000),
  ShopItem.deep('aura', 'inferno', ShopRarity.leggendario, 3000, "Fiamme dell'inferno", 'Hellfire', 1001),
  ShopItem.deep('aura', 'harbourMoon', ShopRarity.leggendario, 3000, 'Luna sul porto', 'Moon over the harbour', 1002),
  ShopItem.deep('aura', 'sunburst', ShopRarity.leggendario, 3000, 'Raggiera déco', 'Deco sunburst', 1003),
  ShopItem.deep('aura', 'neonAlley', ShopRarity.leggendario, 3000, 'Vicolo al neon', 'Neon alley', 1004),
  ShopItem.deep('aura', 'cardRoomSmoke', ShopRarity.leggendario, 3000, 'Fumo della bisca', 'Card-room smoke', 1005),
  ShopItem.deep('aura', 'varietyCurtain', ShopRarity.leggendario, 3000, 'Sipario del varietà', 'Variety curtain', 1006),
  ShopItem.deep('aura', 'vault', ShopRarity.leggendario, 3000, 'Il caveau', 'The vault', 1007),
  ShopItem.deep('aura', 'vesuvio', ShopRarity.leggendario, 3000, 'Vesuvio al tramonto', 'Vesuvius at sunset', 1008),
  ShopItem.deep('aura', 'spaghettiStorm', ShopRarity.leggendario, 3000, 'Tempesta di spaghetti', 'Spaghetti storm', 1009),
  ShopItem.deep('back', 'none', ShopRarity.base, 0, 'Spalle libere', 'Nothing on the back', 1100),
  ShopItem.deep('back', 'violinCase', ShopRarity.leggendario, 2400, 'Custodia da violino', 'Violin case', 1101),
  ShopItem.deep('back', 'gildedWings', ShopRarity.leggendario, 2400, 'Ali dorate déco', 'Gilded deco wings', 1102),
  ShopItem.deep('back', 'skeleton', ShopRarity.leggendario, 2400, "Scheletro nell'armadio", 'Skeleton in the closet', 1103),
  ShopItem.deep('back', 'parasol', ShopRarity.leggendario, 2400, 'Parasole di pizzo', 'Lace parasol', 1104),
  ShopItem.deep('back', 'saxophone', ShopRarity.leggendario, 2400, 'Sassofono del night', 'Nightclub saxophone', 1105),
  ShopItem.deep('headFx', 'none', ShopRarity.base, 0, 'Niente in testa', 'Nothing overhead', 1200),
  ShopItem.deep('headFx', 'halo', ShopRarity.leggendario, 2200, 'Aureola del santo', "Saint's halo", 1201),
  ShopItem.deep('headFx', 'starOrbit', ShopRarity.leggendario, 2200, 'Giro di stelle', 'Ring of stars', 1202),
  ShopItem.deep('headFx', 'sparks', ShopRarity.leggendario, 2200, 'Scintille', 'Sparks', 1203),
  ShopItem.deep('headFx', 'hearts', ShopRarity.leggendario, 2200, 'Cuori in testa', 'Head over heels', 1204),
  ShopItem.deep('headFx', 'coins', ShopRarity.leggendario, 2200, 'Giro di monete', 'Orbiting coins', 1205),
  ShopItem.deep('headFx', 'rainCloud', ShopRarity.leggendario, 2200, 'Nuvoletta della sfiga', 'Bad-luck cloud', 1206),
  ShopItem.deep('headFx', 'dizzyBirds', ShopRarity.leggendario, 2200, 'Uccellini del cazzotto', 'Knockout birdies', 1207),
  ShopItem.deep('headFx', 'ghostGlow', ShopRarity.leggendario, 2200, 'Alone del fantasma', 'Ghostly glow', 1208),
  ShopItem.deep('headFx', 'emberGlow', ShopRarity.leggendario, 2200, 'Alone di brace', 'Ember glow', 1209),
  ShopItem.deep('faceExtras', 'none', ShopRarity.base, 0, 'Faccia pulita', 'Clean face', 1300),
  ShopItem.deep('faceExtras', 'blush', ShopRarity.epico, 1200, 'Guance rosse', 'Rosy cheeks', 1301),
  ShopItem.deep('faceExtras', 'tear', ShopRarity.epico, 1200, 'Lacrima di coccodrillo', 'Crocodile tear', 1302),
  ShopItem.deep('faceExtras', 'stitchScar', ShopRarity.epico, 1200, 'Cicatrice cucita', 'Stitched scar', 1303),
  ShopItem.deep('faceExtras', 'skullPaint', ShopRarity.epico, 1200, 'Trucco da teschio', 'Skull paint', 1304),
  ShopItem.deep('faceExtras', 'beautyStar', ShopRarity.epico, 1200, 'Neo a stella', 'Star beauty mark', 1305),
  ShopItem.deep('faceExtras', 'goldTooth', ShopRarity.epico, 1200, "Dente d'oro", 'Gold tooth', 1306),
  ShopItem.deep('faceExtras', 'blackEye', ShopRarity.epico, 1200, 'Occhio nero', 'Black eye', 1307),
  ShopItem.deep('faceExtras', 'lipstickKiss', ShopRarity.epico, 1200, 'Bacio col rossetto', 'Lipstick kiss', 1308),
  ShopItem.deep('faceExtras', 'plaster', ShopRarity.epico, 1200, 'Cerotto a croce', 'Cross plaster', 1309),
  ShopItem.deep('eyeShine', 'none', ShopRarity.base, 0, 'Occhi normali', 'Plain eyes', 1400),
  ShopItem.deep('eyeShine', 'glint', ShopRarity.epico, 1300, 'Luccichio', 'Glint', 1401),
  ShopItem.deep('eyeShine', 'star', ShopRarity.epico, 1300, 'Occhi da diva', 'Star-struck', 1402),
  ShopItem.deep('eyeShine', 'heart', ShopRarity.epico, 1300, 'Occhi innamorati', 'Love-struck', 1403),
  ShopItem.deep('eyeShine', 'spiral', ShopRarity.epico, 1300, 'Ipnosi', 'Hypnotised', 1404),
  ShopItem.deep('eyeShine', 'lira', ShopRarity.epico, 1300, 'Occhi a lire', 'Lira eyes', 1405),
  ShopItem.deep('eyeShine', 'flame', ShopRarity.epico, 1300, 'Occhi di fuoco', 'Eyes of fire', 1406),
  ShopItem.deep('eyeShine', 'diamond', ShopRarity.epico, 1300, 'Occhi di brillante', 'Diamond eyes', 1407),
  ShopItem.deep('eyeShine', 'crosshair', ShopRarity.epico, 1300, 'Occhio da sicario', "Hitman's eye", 1408),
  ShopItem.deep('hairDye', 'none', ShopRarity.base, 0, 'Nessuna tinta', 'No dye', 1500),
  ShopItem.deep('hairDye', 'midnight', ShopRarity.epico, 1400, 'Tinta mezzanotte', 'Midnight dye', 1501),
  ShopItem.deep('hairDye', 'neonPop', ShopRarity.epico, 1400, 'Tinta neon', 'Neon dye', 1502),
  ShopItem.deep('hairDye', 'sunset', ShopRarity.epico, 1400, 'Tinta tramonto', 'Sunset dye', 1503),
  ShopItem.deep('hairDye', 'cherry', ShopRarity.epico, 1400, 'Tinta ciliegia', 'Cherry dye', 1504),
  ShopItem.deep('hairDye', 'frost', ShopRarity.epico, 1400, 'Tinta brina', 'Frost dye', 1505),
  ShopItem.deep('hairDye', 'tricolore', ShopRarity.leggendario, 2000, 'Tinta tricolore', 'Tricolore dye', 1506),
  ShopItem.deep('hairDye', 'goldLeaf', ShopRarity.leggendario, 2000, "Capelli d'oro", 'Golden locks', 1507),
  ShopItem.deep('held', 'none', ShopRarity.base, 0, 'Mani libere', 'Empty hands', 1600),
  ShopItem.deep('held', 'grappa', ShopRarity.epico, 1500, 'Bottiglia di grappa', 'Bottle of grappa', 1601),
  ShopItem.deep('held', 'rose', ShopRarity.epico, 1500, 'Rosa rossa', 'Red rose', 1602),
  ShopItem.deep('held', 'revolver', ShopRarity.epico, 1500, 'Rivoltella', 'Revolver', 1603),
  ShopItem.deep('held', 'cards', ShopRarity.epico, 1500, 'Mano di poker', 'Poker hand', 1604),
  ShopItem.deep('held', 'coupe', ShopRarity.epico, 1500, 'Coppa di spumante', 'Glass of bubbly', 1605),
  ShopItem.deep('held', 'candle', ShopRarity.epico, 1500, 'Candela', 'Candle', 1606),
  ShopItem.deep('held', 'cannolo', ShopRarity.epico, 1500, 'Cannolo gigante', 'Giant cannolo', 1607),
  ShopItem.deep('held', 'moka', ShopRarity.epico, 1500, 'Moka del caffè', 'Coffee moka', 1608),
  ShopItem.deep('held', 'fish', ShopRarity.epico, 1500, 'Pesce nel giornale', 'Fish in a newspaper', 1609),
  ShopItem.deep('held', 'cat', ShopRarity.leggendario, 2400, 'Il gatto del padrino', "The godfather's cat", 1610),
  ShopItem.deep('held', 'teddy', ShopRarity.leggendario, 2400, 'Orsetto del boss', "The boss's teddy", 1611),
  ShopItem.deep('frontFx', 'none', ShopRarity.base, 0, 'Niente davanti', 'Nothing in front', 1700),
  ShopItem.deep('frontFx', 'smokeRings', ShopRarity.leggendario, 2200, 'Anelli di fumo', 'Smoke rings', 1701),
  ShopItem.deep('frontFx', 'petals', ShopRarity.leggendario, 2200, 'Petali di rosa', 'Rose petals', 1702),
  ShopItem.deep('frontFx', 'sparkles', ShopRarity.leggendario, 2200, 'Scintillio', 'Twinkles', 1703),
  ShopItem.deep('frontFx', 'bats', ShopRarity.leggendario, 2200, 'Pipistrelli', 'Bats', 1704),
  ShopItem.deep('frontFx', 'yarn', ShopRarity.leggendario, 2200, 'Gomitolo', 'Ball of yarn', 1705),
  ShopItem.deep('frontFx', 'banknotes', ShopRarity.leggendario, 2200, 'Pioggia di lire', 'Raining lire', 1706),
  ShopItem.deep('frontFx', 'musicNotes', ShopRarity.leggendario, 2200, 'Serenata', 'Serenade', 1707),
  ShopItem.deep('frontFx', 'fireflies', ShopRarity.leggendario, 2200, 'Lucciole', 'Fireflies', 1708),
];

final List<ShopItem> _firstDrop = [
  ShopItem.seed('hat', 'fedora', ShopRarity.base, 'Fedora', 'Fedora', 100),
  ShopItem.seed('hat', 'bowler', ShopRarity.base, 'Bombetta', 'Bowler', 101),
  ShopItem.seed('hat', 'coppola', ShopRarity.base, 'Coppola', 'Flat cap', 102),
  ShopItem.seed('hat', 'slicked', ShopRarity.base, 'Brillantina', 'Slicked back', 103),
  ShopItem.seed('hat', 'bob', ShopRarity.base, 'Caschetto', 'Bob', 104),
  ShopItem.seed('hat', 'bun', ShopRarity.base, 'Chignon', 'Chignon', 105),
  ShopItem.seed('hat', 'wideBrim', ShopRarity.base, 'Tesa larga', 'Wide brim', 106),
  ShopItem.seed('hat', 'borsalino', ShopRarity.raro, 'Borsalino', 'Borsalino', 110),
  ShopItem.seed('hat', 'panama', ShopRarity.raro, 'Panama', 'Panama', 111),
  ShopItem.seed('hat', 'trilby', ShopRarity.raro, 'Trilby', 'Trilby', 112),
  ShopItem.seed('hat', 'homburg', ShopRarity.raro, 'Homburg', 'Homburg', 113),
  ShopItem.seed('hat', 'boater', ShopRarity.raro, 'Paglietta', 'Boater', 114),
  ShopItem.seed('hat', 'topHat', ShopRarity.raro, 'Cilindro', 'Top hat', 115),
  ShopItem.seed('face', 'clean', ShopRarity.base, 'Sbarbato', 'Clean shaven', 200),
  ShopItem.seed('face', 'mustache', ShopRarity.base, 'Baffi', 'Moustache', 201),
  ShopItem.seed('face', 'lips', ShopRarity.base, 'Rossetto', 'Red lips', 202),
  ShopItem.seed('face', 'scar', ShopRarity.base, 'Cicatrice', 'Scar', 203),
  ShopItem.seed('face', 'stubble', ShopRarity.base, 'Barba di tre giorni', 'Stubble', 204),
  ShopItem.seed('face', 'goatee', ShopRarity.base, 'Pizzetto', 'Goatee', 205),
  ShopItem.seed('face', 'mole', ShopRarity.base, 'Neo', 'Beauty mark', 206),
  ShopItem.seed('face', 'pencil', ShopRarity.comune, 'Baffetto a matita', 'Pencil moustache', 210),
  ShopItem.seed('face', 'handlebar', ShopRarity.comune, 'Baffi a manubrio', 'Handlebar moustache', 211),
  ShopItem.seed('face', 'walrus', ShopRarity.comune, 'Baffoni a tricheco', 'Walrus moustache', 212),
  ShopItem.seed('face', 'imperial', ShopRarity.comune, "Baffi all'imperiale", 'Imperial', 213),
  ShopItem.seed('glasses', 'none', ShopRarity.base, 'Niente occhiali', 'No glasses', 300),
  ShopItem.seed('glasses', 'round', ShopRarity.base, 'Occhiali tondi', 'Round glasses', 301),
  ShopItem.seed('glasses', 'monocle', ShopRarity.base, 'Monocolo', 'Monocle', 302),
  ShopItem.seed('glasses', 'shades', ShopRarity.base, 'Occhiali scuri', 'Dark glasses', 303),
  ShopItem.seed('glasses', 'pinceNez', ShopRarity.raro, 'Pince-nez', 'Pince-nez', 310),
  ShopItem.seed('glasses', 'tortoise', ShopRarity.raro, 'Occhiali di tartaruga', 'Tortoiseshell glasses', 311),
  ShopItem.seed('glasses', 'aviator', ShopRarity.raro, 'Occhiali da aviatore', 'Aviators', 312),
  ShopItem.seed('outfit', 'charcoal_pinstripe', ShopRarity.base, 'Gessato antracite', 'Charcoal pinstripe', 400),
  ShopItem.seed('outfit', 'navy_double', ShopRarity.base, 'Doppiopetto blu', 'Navy double-breasted', 401),
  ShopItem.seed('outfit', 'bottle_green', ShopRarity.base, 'Verde bottiglia', 'Bottle green', 402),
  ShopItem.seed('outfit', 'camel_check', ShopRarity.base, 'Quadretti cammello', 'Camel check', 403),
  ShopItem.seed('outfit', 'plum_velvet', ShopRarity.base, 'Velluto prugna', 'Plum velvet', 404),
  ShopItem.seed('outfit', 'cream_dinner', ShopRarity.base, 'Giacca da sera crema', 'Cream dinner jacket', 405),
  ShopItem.seed('outfit', 'slate_check', ShopRarity.base, 'Quadretti ardesia', 'Slate check', 406),
  ShopItem.seed('outfit', 'wine_silk', ShopRarity.base, 'Seta vinaccia', 'Wine silk', 407),
  ShopItem.seed('outfit', 'rust_tweed', ShopRarity.base, 'Tweed ruggine', 'Rust tweed', 408),
  ShopItem.seed('outfit', 'olive_pinstripe', ShopRarity.base, 'Gessato oliva', 'Olive pinstripe', 409),
  ShopItem.seed('outfit', 'black_tuxedo', ShopRarity.base, 'Smoking nero', 'Black tuxedo', 410),
  ShopItem.seed('outfit', 'rose_dress', ShopRarity.base, 'Abito rosa antico', 'Dusty rose dress', 411),
  ShopItem.seed('outfit', 'black_dress', ShopRarity.base, 'Tubino nero', 'Little black dress', 412),
  ShopItem.seed('outfit', 'emerald_dress', ShopRarity.base, 'Abito smeraldo', 'Emerald dress', 413),
  ShopItem.seed('outfit', 'ivory_blouse', ShopRarity.base, 'Camicetta avorio', 'Ivory blouse', 414),
  ShopItem.seed('outfit', 'powder_blouse', ShopRarity.base, 'Camicetta celeste', 'Powder blue blouse', 415),
  ShopItem.seed('outfit', 'navy_chalkstripe', ShopRarity.epico, 'Gessato blu', 'Navy chalk stripe', 420),
  ShopItem.seed('outfit', 'grey_flannel', ShopRarity.epico, 'Flanella grigia', 'Grey flannel', 421),
  ShopItem.seed('outfit', 'brown_pinstripe', ShopRarity.epico, 'Gessato marrone', 'Brown pinstripe', 422),
  ShopItem.seed('outfit', 'cream_linen', ShopRarity.epico, 'Lino crema', 'Cream linen', 423),
  ShopItem.seed('outfit', 'midnight_double', ShopRarity.epico, 'Doppiopetto notte', 'Midnight double-breasted', 424),
  ShopItem.seed('outfit', 'white_dinner', ShopRarity.epico, 'Smoking bianco', 'White dinner jacket', 425),
  ShopItem.seed(
    'outfit',
    'trench_coat',
    ShopRarity.leggendario,
    'Impermeabile del detective',
    "Detective's trench coat",
    430,
  ),
  ShopItem.seed(
    'outfit',
    'gold_brocade',
    ShopRarity.leggendario,
    "Smoking di broccato d'oro",
    'Gold brocade tuxedo',
    431,
  ),
  ShopItem.seed('accessory', 'none', ShopRarity.base, 'Collo aperto', 'Open collar', 500),
  ShopItem.seed('accessory', 'tie', ShopRarity.base, 'Cravatta', 'Tie', 501),
  ShopItem.seed('accessory', 'bowTie', ShopRarity.base, 'Papillon', 'Bow tie', 502),
  ShopItem.seed('accessory', 'pearls', ShopRarity.base, 'Perle', 'Pearls', 503),
  ShopItem.seed('accessory', 'scarf', ShopRarity.base, 'Sciarpa', 'Scarf', 504),
  ShopItem.seed('accessory', 'carnation', ShopRarity.base, 'Garofano', 'Carnation', 505),
  ShopItem.seed('accessory', 'cigar', ShopRarity.base, 'Sigaro', 'Cigar', 506),
  ShopItem.seed('accessory', 'cigarette', ShopRarity.base, 'Sigaretta', 'Cigarette', 507),
  ShopItem.seed('accessory', 'toothpick', ShopRarity.base, 'Stuzzicadenti', 'Toothpick', 508),
  ShopItem.seed('accessory', 'polkaTie', ShopRarity.comune, 'Cravatta a pois', 'Polka-dot tie', 510),
  ShopItem.seed('accessory', 'cravat', ShopRarity.comune, 'Foulard di seta', 'Silk cravat', 511),
  ShopItem.seed('accessory', 'pocketSquare', ShopRarity.comune, 'Fazzoletto da taschino', 'Pocket square', 512),
  ShopItem.seed('accessory', 'pipe', ShopRarity.comune, 'Pipa', 'Pipe', 513),
  ShopItem.seed('accessory', 'pocketWatch', ShopRarity.comune, "Catena d'orologio", 'Watch chain', 514),
];

/// La seconda consegna: le case di moda (in cima ai prezzi) e tanta
/// varietà per le tasche di tutti.
final List<ShopItem> brandDrop = [
  // Cappelli.
  ShopItem.drop('hat', 'porkPie', ShopRarity.comune, 'Pork pie', 'Pork pie', 120),
  ShopItem.drop('hat', 'beret', ShopRarity.comune, 'Basco', 'Beret', 121),
  ShopItem.drop('hat', 'pearlFedora', ShopRarity.comune, 'Fedora grigio perla', 'Pearl grey fedora', 122),
  ShopItem.drop('hat', 'cloche', ShopRarity.raro, 'Cloche', 'Cloche', 123),
  ShopItem.drop('hat', 'morettiFedora', ShopRarity.epico, 'Fedora a fascia Cuccioli', 'Cuccioli banded fedora', 130, brand: ShopBrand.cuccioli),
  ShopItem.drop('hat', 'morettiPanama', ShopRarity.epico, 'Panama Cuccioli', 'Cuccioli panama', 131, brand: ShopBrand.cuccioli),
  ShopItem.drop(
    'hat',
    'morettiHomburg',
    ShopRarity.leggendario,
    'Homburg con staffa Cuccioli',
    'Cuccioli stirrup homburg',
    132,
    brand: ShopBrand.cuccioli,
  ),
  ShopItem.drop('hat', 'fulmineCap', ShopRarity.epico, 'Berretto da corsa Nikea', 'Nikea running cap', 133, brand: ShopBrand.nikea),
  // Baffi e barbe.
  ShopItem.drop('face', 'chevron', ShopRarity.comune, 'Baffi a spazzola', 'Chevron moustache', 220),
  ShopItem.drop('face', 'horseshoe', ShopRarity.comune, 'Baffi a ferro di cavallo', 'Horseshoe moustache', 221),
  ShopItem.drop('face', 'vandyke', ShopRarity.comune, 'Pizzo alla moschettiera', 'Musketeer goatee', 222),
  ShopItem.drop('face', 'muttonChops', ShopRarity.raro, 'Basettoni', 'Mutton chops', 223),
  ShopItem.drop('face', 'fullBeard', ShopRarity.raro, 'Barba da capitano', "Captain's beard", 224),
  // Occhiali.
  ShopItem.drop('glasses', 'goldRims', ShopRarity.comune, 'Montatura dorata', 'Gold rims', 320),
  ShopItem.drop('glasses', 'browline', ShopRarity.comune, 'Occhiali da ragioniere', "Accountant's glasses", 321),
  ShopItem.drop('glasses', 'catEye', ShopRarity.raro, 'Occhiali a gatto', 'Cat-eye glasses', 322),
  ShopItem.drop(
    'glasses',
    'delacroixShades',
    ShopRarity.epico,
    'Occhiali bianchi Chanterelle',
    'Chanterelle white-rim glasses',
    330,
    brand: ShopBrand.chanterelle,
  ),
  ShopItem.drop(
    'glasses',
    'ricciMonocle',
    ShopRarity.epico,
    'Monocolo barocco Versalli',
    'Versalli baroque monocle',
    331,
    brand: ShopBrand.versalli,
  ),
  // Abiti.
  ShopItem.drop('outfit', 'charcoal_windowpane', ShopRarity.raro, 'Finestrato antracite', 'Charcoal windowpane', 440),
  ShopItem.drop('outfit', 'tan_herringbone', ShopRarity.raro, 'Spina di pesce tabacco', 'Tan herringbone', 441),
  ShopItem.drop('outfit', 'steel_sharkskin', ShopRarity.raro, 'Fresco di lana acciaio', 'Steel sharkskin', 442),
  ShopItem.drop('outfit', 'oxblood_double', ShopRarity.raro, 'Doppiopetto sangue di bue', 'Oxblood double-breasted', 443),
  ShopItem.drop('outfit', 'vanetti_pinstripe', ShopRarity.epico, 'Completo morbido Arminio', 'Arminio soft suit', 450, brand: ShopBrand.arminio),
  ShopItem.drop(
    'outfit',
    'vanetti_tuxedo',
    ShopRarity.leggendario,
    'Smoking blu notte Arminio',
    'Arminio midnight tuxedo',
    451,
    brand: ShopBrand.arminio,
  ),
  ShopItem.drop(
    'outfit',
    'vanetti_ivory',
    ShopRarity.leggendario,
    'Giacca greige Arminio',
    'Arminio greige jacket',
    452,
    brand: ShopBrand.arminio,
  ),
  ShopItem.drop(
    'outfit',
    'delacroix_velvet',
    ShopRarity.epico,
    'Giacca bordata Chanterelle',
    'Chanterelle braided jacket',
    453,
    brand: ShopBrand.chanterelle,
  ),
  ShopItem.drop(
    'outfit',
    'delacroix_cape',
    ShopRarity.leggendario,
    'Mantello bianco e nero Chanterelle',
    'Chanterelle black-and-white cape',
    454,
    brand: ShopBrand.chanterelle,
  ),
  ShopItem.drop('outfit', 'fulmine_track', ShopRarity.epico, 'Giacca da pista Nikea', 'Nikea track top', 455, brand: ShopBrand.nikea),
  ShopItem.drop(
    'outfit',
    'fulmine_cardigan',
    ShopRarity.epico,
    'Cardigan atletico Nikea',
    'Nikea athletic cardigan',
    456,
    brand: ShopBrand.nikea,
  ),
  // Vezzi.
  ShopItem.drop('accessory', 'stripeTie', ShopRarity.comune, 'Cravatta a righe', 'Striped tie', 520),
  ShopItem.drop('accessory', 'knitTie', ShopRarity.comune, 'Cravatta di maglia', 'Knit tie', 521),
  ShopItem.drop('accessory', 'polkaBowTie', ShopRarity.comune, 'Papillon a pois', 'Polka-dot bow tie', 522),
  ShopItem.drop('accessory', 'whiteCarnation', ShopRarity.comune, 'Garofano bianco', 'White carnation', 523),
  ShopItem.drop('accessory', 'suspenders', ShopRarity.raro, 'Bretelle', 'Braces', 524),
  ShopItem.drop('accessory', 'cigaretteHolder', ShopRarity.raro, 'Bocchino', 'Cigarette holder', 525),
  ShopItem.drop('accessory', 'ricciChain', ShopRarity.epico, 'Catena barocca Versalli', 'Versalli baroque chain', 530, brand: ShopBrand.versalli),
  ShopItem.drop(
    'accessory',
    'ricciTiePin',
    ShopRarity.epico,
    'Fermacravatta Versalli',
    'Versalli tie pin',
    531,
    brand: ShopBrand.versalli,
  ),
  ShopItem.drop(
    'accessory',
    'ricciWatch',
    ShopRarity.leggendario,
    "Cipolla d'oro Versalli",
    'Versalli gold pocket watch',
    532,
    brand: ShopBrand.versalli,
  ),
  ShopItem.drop(
    'accessory',
    'delacroixScarf',
    ShopRarity.epico,
    'Sciarpa da sera Chanterelle',
    'Chanterelle evening scarf',
    533,
    brand: ShopBrand.chanterelle,
  ),
  ShopItem.drop(
    'accessory',
    'delacroixAscot',
    ShopRarity.epico,
    'Foulard a fiocchi Chanterelle',
    'Chanterelle bow ascot',
    534,
    brand: ShopBrand.chanterelle,
  ),
];

/// La terza consegna: le due case nuove e un pezzo in più per le altre.
final List<ShopItem> houseDrop = [
  ShopItem.house('hat', 'vaugirardCap', ShopRarity.epico, 'Coppola da viaggio Vaugirard', 'Vaugirard travel cap', 134, ShopBrand.vaugirard),
  ShopItem.house('hat', 'adelphiCap', ShopRarity.epico, 'Berretto da tennis Adelphi', 'Adelphi tennis cap', 135, ShopBrand.adelphi),
  ShopItem.house('outfit', 'vaugirard_travel', ShopRarity.leggendario, 'Spolverino da viaggio Vaugirard', 'Vaugirard travel coat', 457, ShopBrand.vaugirard),
  ShopItem.house('outfit', 'cuccioli_blazer', ShopRarity.epico, 'Blazer a fascia Cuccioli', 'Cuccioli banded blazer', 458, ShopBrand.cuccioli),
  ShopItem.house('outfit', 'versalli_baroque', ShopRarity.leggendario, 'Giacca barocca Versalli', 'Versalli baroque jacket', 459, ShopBrand.versalli),
  ShopItem.house('outfit', 'adelphi_track', ShopRarity.epico, 'Giacca da pista Adelphi', 'Adelphi track top', 460, ShopBrand.adelphi),
  ShopItem.house('outfit', 'adelphi_cardigan', ShopRarity.epico, 'Maglia da squadra Adelphi', 'Adelphi team cardigan', 461, ShopBrand.adelphi),
  ShopItem.house('accessory', 'vaugirardStrap', ShopRarity.epico, 'Tracolla Vaugirard', 'Vaugirard satchel strap', 535, ShopBrand.vaugirard),
  ShopItem.house('accessory', 'chanterellePearls', ShopRarity.leggendario, 'Perle lunghe Chanterelle', 'Chanterelle long pearls', 536, ShopBrand.chanterelle),
];

/// Le stramberie: il circo e il carnevale, per lo scaffale delle stranezze.
final List<ShopItem> odditiesDrop = [
  ShopItem.oddity('hat', 'clownWig', ShopRarity.leggendario, 'Parrucca arcobaleno', 'Rainbow clown wig', 140, ShopCollection.circo),
  ShopItem.oddity('hat', 'magicianHat', ShopRarity.leggendario, 'Cilindro del prestigiatore', "Magician's top hat", 141, ShopCollection.circo),
  ShopItem.oddity('hat', 'chefToque', ShopRarity.raro, 'Toque da cuoco', "Chef's toque", 142, ShopCollection.carnevale),
  ShopItem.oddity('hat', 'sombrero', ShopRarity.raro, 'Sombrero con i pompon', 'Pompom sombrero', 143, ShopCollection.carnevale),
  ShopItem.oddity('hat', 'tricorn', ShopRarity.epico, 'Tricorno del pirata', 'Pirate tricorn', 144, ShopCollection.carnevale),
  ShopItem.oddity('hat', 'operaHelmet', ShopRarity.epico, 'Elmo della prima donna', 'Opera horned helmet', 145, ShopCollection.carnevale),
  ShopItem.oddity('hat', 'beekeeper', ShopRarity.raro, "Cappello dell'apicoltore", "Beekeeper's veil hat", 146, ShopCollection.carnevale),
  ShopItem.oddity('hat', 'roosterHead', ShopRarity.leggendario, 'Testa da gallo', 'Rooster costume head', 147, ShopCollection.carnevale),
  ShopItem.oddity('hat', 'propellerBeanie', ShopRarity.comune, "Zucchetto con l'elica", 'Propeller beanie', 148, ShopCollection.carnevale),
  ShopItem.oddity('hat', 'angelHalo', ShopRarity.epico, "Aureola d'angelo", 'Angel halo', 149, ShopCollection.carnevale),
  ShopItem.oddity('hat', 'devilHorns', ShopRarity.epico, 'Cornetti del diavolo', 'Devil horns', 150, ShopCollection.carnevale),
  ShopItem.oddity('face', 'curledMoustache', ShopRarity.raro, 'Baffi a ricciolo', 'Curled moustache', 220, ShopCollection.circo),
  ShopItem.oddity('face', 'giantMoustache', ShopRarity.comune, 'Baffone finto', 'Giant fake moustache', 221, ShopCollection.carnevale),
  ShopItem.oddity('face', 'mimeFace', ShopRarity.raro, 'Trucco da mimo', 'Mime face paint', 222, ShopCollection.circo),
  ShopItem.oddity('glasses', 'noseDisguise', ShopRarity.comune, 'Naso e baffi finti', 'Nose-and-moustache disguise', 340, ShopCollection.carnevale),
  ShopItem.oddity('glasses', 'heartGlasses', ShopRarity.comune, 'Occhiali a cuore', 'Heart glasses', 341, ShopCollection.carnevale),
  ShopItem.oddity('glasses', 'hypnoGlasses', ShopRarity.raro, "Occhiali dell'ipnotista", 'Hypnotist glasses', 342, ShopCollection.circo),
  ShopItem.oddity('glasses', 'eyePatch', ShopRarity.comune, 'Benda da pirata', 'Pirate eye patch', 343, ShopCollection.carnevale),
  ShopItem.oddity('glasses', 'giantGlasses', ShopRarity.epico, 'Occhialoni', 'Giant novelty glasses', 344, ShopCollection.carnevale),
  ShopItem.oddity('glasses', 'giantShades', ShopRarity.leggendario, 'Occhialoni da sole', 'Giant sunglasses', 345, ShopCollection.carnevale),
  ShopItem.oddity('outfit', 'clown_suit', ShopRarity.leggendario, 'Costume da clown a pois', 'Polka-dot clown suit', 470, ShopCollection.circo),
  ShopItem.oddity('outfit', 'strongman_leotard', ShopRarity.epico, 'Canottiera del forzuto', "Strongman's leotard", 471, ShopCollection.circo),
  ShopItem.oddity('outfit', 'mime_stripes', ShopRarity.raro, 'Maglia a righe del mimo', "Mime's striped shirt", 472, ShopCollection.circo),
  ShopItem.oddity('outfit', 'magician_cape', ShopRarity.epico, 'Mantello del prestigiatore', "Magician's cape", 473, ShopCollection.circo),
  ShopItem.oddity('outfit', 'chef_whites', ShopRarity.raro, 'Giacca da cuoco', "Chef's whites", 474, ShopCollection.carnevale),
  ShopItem.oddity('outfit', 'banana_suit', ShopRarity.leggendario, 'Costume da banana', 'Banana costume', 475, ShopCollection.carnevale),
  ShopItem.oddity('accessory', 'clownNose', ShopRarity.leggendario, 'Naso da clown', 'Clown nose', 540, ShopCollection.circo),
  ShopItem.oddity('accessory', 'parrot', ShopRarity.leggendario, 'Pappagallo sulla spalla', 'Shoulder parrot', 541, ShopCollection.carnevale),
  ShopItem.oddity('accessory', 'rubberDuck', ShopRarity.comune, 'Paperella nel taschino', 'Pocket rubber duck', 542, ShopCollection.carnevale),
  ShopItem.oddity('accessory', 'accordion', ShopRarity.epico, 'Fisarmonica', 'Accordion', 543, ShopCollection.carnevale),
  ShopItem.oddity('accessory', 'baguetteCigar', ShopRarity.raro, 'Sigaro a filone', 'Baguette-size cigar', 544, ShopCollection.carnevale),
  ShopItem.oddity('back', 'angelWings', ShopRarity.leggendario, "Ali d'angelo", 'Angel wings', 545, ShopCollection.carnevale),
  ShopItem.oddity('back', 'batWings', ShopRarity.leggendario, 'Ali da diavoletto', 'Devil bat wings', 546, ShopCollection.carnevale),
  ShopItem.oddity('back', 'butterflyWings', ShopRarity.leggendario, 'Ali di farfalla', 'Butterfly wings', 547, ShopCollection.carnevale),
  // L'assurdo.
  ShopItem.oddity('hat', 'fishHead', ShopRarity.leggendario, 'Testa di pesce', 'Fish head mask', 151, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'dinoHood', ShopRarity.leggendario, 'Cappuccio da dinosauro', 'Dinosaur hood', 152, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'astronautHelmet', ShopRarity.leggendario, 'Casco da astronauta', 'Astronaut bubble helmet', 153, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'unicornHorn', ShopRarity.epico, 'Corno da unicorno', 'Unicorn horn headband', 154, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'spaghettiHat', ShopRarity.epico, 'Piatto di spaghetti', 'Spaghetti plate hat', 155, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'octopusHat', ShopRarity.leggendario, 'Polpo in testa', 'Octopus hat', 156, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'ufoHat', ShopRarity.leggendario, 'Disco volante', 'UFO hat with alien', 157, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'birthdayCake', ShopRarity.epico, 'Torta di compleanno', 'Birthday cake hat', 158, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'rainbowAfro', ShopRarity.leggendario, 'Afro arcobaleno', 'Rainbow afro', 159, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'flamingHair', ShopRarity.leggendario, 'Capelli in fiamme', 'Flaming hair', 160, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'starHalo', ShopRarity.epico, 'Giro di stelle', 'Halo of stars', 161, ShopCollection.assurdo),
  ShopItem.oddity('hat', 'catOnHead', ShopRarity.leggendario, 'Gatto in testa', 'Cat on the head', 162, ShopCollection.assurdo),
  ShopItem.oddity('face', 'vikingBeard', ShopRarity.leggendario, 'Barba del vichingo', 'Braided viking beard', 223, ShopCollection.assurdo),
  // La statua d'oro e la sua corona, dal cartoon noir.
  ShopItem(
    id: 'face.goldStatue',
    slot: 'face',
    lookId: 'goldStatue',
    rarity: ShopRarity.leggendario,
    price: ShopRarity.leggendario.price,
    nameIt: "Statua d'oro",
    nameEn: 'Gold statue',
    releasedOn: DateTime.utc(2026, 10, 28),
    sort: 224,
    collection: ShopCollection.assurdo,
  ),
  ShopItem(
    id: 'hat.crown',
    slot: 'hat',
    lookId: 'crown',
    rarity: ShopRarity.leggendario,
    price: ShopRarity.leggendario.price,
    nameIt: 'Corona del re',
    nameEn: "King's crown",
    releasedOn: DateTime.utc(2026, 10, 28),
    sort: 163,
    collection: ShopCollection.assurdo,
  ),
  ShopItem.oddity('glasses', 'googlyEyes', ShopRarity.raro, 'Occhi mobili', 'Googly-eye glasses', 346, ShopCollection.assurdo),
  ShopItem.oddity('glasses', 'glasses3d', ShopRarity.raro, 'Occhialini 3D', '3D glasses', 347, ShopCollection.assurdo),
  ShopItem.oddity('glasses', 'bulbMonocle', ShopRarity.epico, "Monocolo dell'idea", 'Lightbulb monocle', 348, ShopCollection.assurdo),
  ShopItem.oddity('outfit', 'pizza_suit', ShopRarity.leggendario, 'Costume da pizza', 'Pizza slice costume', 476, ShopCollection.assurdo),
  ShopItem.oddity('outfit', 'cactus_suit', ShopRarity.leggendario, 'Costume da cactus', 'Cactus costume', 477, ShopCollection.assurdo),
  ShopItem.oddity('outfit', 'ghost_sheet', ShopRarity.epico, 'Lenzuolo da fantasma', 'Ghost sheet', 478, ShopCollection.assurdo),
  ShopItem.oddity('outfit', 'mummy_wraps', ShopRarity.epico, 'Bende da mummia', 'Mummy wraps', 479, ShopCollection.assurdo),
  ShopItem.oddity('accessory', 'snailShell', ShopRarity.epico, 'Guscio di lumaca', 'Snail shell backpack', 548, ShopCollection.assurdo),
  ShopItem.oddity('accessory', 'jetpack', ShopRarity.leggendario, 'Zaino a razzo', 'Jetpack', 549, ShopCollection.assurdo),
  ShopItem.oddity('back', 'dragonWings', ShopRarity.leggendario, 'Ali di drago', 'Dragon wings', 550, ShopCollection.assurdo),
  ShopItem.oddity('accessory', 'balloons', ShopRarity.leggendario, 'Mazzo di palloncini', 'Balloon bunch', 551, ShopCollection.assurdo),
  ShopItem.oddity('accessory', 'giantBowTie', ShopRarity.raro, 'Papillon gigante', 'Giant bow tie', 552, ShopCollection.assurdo),
  ShopItem.oddity('accessory', 'pigeon', ShopRarity.raro, 'Piccione sulla spalla', 'Shoulder pigeon', 553, ShopCollection.assurdo),
  ShopItem.oddity('accessory', 'plungerSword', ShopRarity.epico, 'Spada sturalavandini', 'Plunger sword', 554, ShopCollection.assurdo),
];

/// La vetrina di adesso, come nella migrazione delle case: la collezione
/// Vaugirard & Fils, la casa dei bauli.
final List<ShopFeature> initialShopFeatured = [
  for (final (i, id) in brandFeatured.indexed)
    ShopFeature(itemId: id, startsAt: DateTime.utc(2026, 10, 18, 18), endsAt: DateTime.utc(2026, 11, 15), sort: i),
  for (final (i, id) in odditiesFeatured.indexed)
    ShopFeature(itemId: id, startsAt: DateTime.utc(2026, 10, 18, 20), endsAt: DateTime.utc(2026, 11, 15), sort: 3 + i),
];

/// Il clown in vetrina accanto ai bauli.
const odditiesFeatured = ['outfit.clown_suit', 'hat.clownWig', 'accessory.clownNose'];

const brandFeatured = [
  'outfit.vaugirard_travel',
  'hat.vaugirardCap',
  'accessory.vaugirardStrap',
];

/// Dal barbiere e dal tatuatore: le pettinature stravaganti e i tatuaggi
/// alla marinara (`supabase/migrations/20261020090000_barber_presentation.sql`).
final List<ShopItem> barberDrop = [
  ShopItem.drop('hairdo', 'none', ShopRarity.base, 'I tuoi capelli', 'Your own hair', 600),
  ShopItem.drop('hairdo', 'beehive', ShopRarity.epico, 'Alveare gigante', 'Giant beehive', 601),
  ShopItem.drop('hairdo', 'punkSpikes', ShopRarity.epico, 'Creste punk al neon', 'Neon-pink punk spikes', 602),
  ShopItem.drop('hairdo', 'spaceBuns', ShopRarity.raro, 'Due chignon spaziali', 'Double space buns', 603),
  ShopItem.drop('hairdo', 'toweringPompadour', ShopRarity.epico, 'Ciuffo a torre col ricciolo', 'Towering pompadour with a curl', 604),
  ShopItem.drop('hairdo', 'flowerCrown', ShopRarity.raro, 'Corona di trecce e fiori', 'Braided crown with flowers', 605),
  ShopItem.drop('hairdo', 'mermaidWaves', ShopRarity.epico, 'Onde da sirena ghiaccio', 'Ice-blue mermaid waves', 606),
  ShopItem.drop('hairdo', 'flameBouffant', ShopRarity.epico, 'Cotonatura rosso fiamma', 'Flame-red bouffant', 607),
  ShopItem.drop('hairdo', 'glitterAfro', ShopRarity.leggendario, 'Afro di brillantini', 'Glitter afro', 608),
  ShopItem.drop('hairdo', 'samuraiTopknot', ShopRarity.raro, 'Codino da samurai', 'Samurai topknot', 609),
  ShopItem.drop('hairdo', 'stripedUndercut', ShopRarity.raro, 'Rasato a strisce', 'Striped undercut', 610),
  ShopItem.drop('hairdo', 'rainbowPonytail', ShopRarity.leggendario, 'Coda arcobaleno lunghissima', 'Extra-long rainbow ponytail', 611),
  ShopItem.drop('hairdo', 'birdNestMane', ShopRarity.leggendario, 'Criniera con uccellino', 'Curly mane with a hidden bird', 612),
  ShopItem.drop('tattoo', 'none', ShopRarity.base, 'Pelle pulita', 'No tattoo', 700),
  ShopItem.drop('tattoo', 'anchor', ShopRarity.comune, 'Ancora', 'Anchor', 701),
  ShopItem.drop('tattoo', 'swallow', ShopRarity.comune, 'Rondine', 'Swallow', 702),
  ShopItem.drop('tattoo', 'roseDagger', ShopRarity.raro, 'Rosa e pugnale', 'Rose and dagger', 703),
  ShopItem.drop('tattoo', 'mammaHeart', ShopRarity.raro, 'Cuore MAMMA', 'MAMMA heart banner', 704),
  ShopItem.drop('tattoo', 'spiderWeb', ShopRarity.epico, 'Ragnatela sul collo', 'Spider web on the neck', 705),
  ShopItem.drop('tattoo', 'teardrop', ShopRarity.comune, 'Lacrima', 'Teardrop', 706),
  ShopItem.drop('tattoo', 'cheekStar', ShopRarity.comune, 'Stellina sulla guancia', 'Star on the cheek', 707),
  ShopItem.drop('tattoo', 'koi', ShopRarity.epico, 'Carpa koi sul collo', 'Koi on the neck', 708),
  ShopItem.drop('tattoo', 'playingCards', ShopRarity.raro, 'Carte da gioco', 'Playing cards', 709),
  ShopItem.drop('tattoo', 'skullTopHat', ShopRarity.raro, 'Teschio col cilindro', 'Skull in a top hat', 710),
  ShopItem.drop('tattoo', 'familyCrest', ShopRarity.epico, 'Stemma di famiglia', 'Family crest', 711),
];

/// I pacchetti, gli stessi di `supabase/migrations/20261022120000_shop_bundles.sql`
/// (un test li confronta).
final List<ShopBundle> initialShopBundles = [
  ShopBundle(id: 'ragioniere', tier: 'set', discountPct: 30, nameIt: 'Il Ragioniere', nameEn: 'The Bookkeeper', taglineIt: 'Conti in ordine, baffo in ordine.', taglineEn: 'Neat books, neat moustache.', sort: 10, itemIds: ['glasses.browline', 'face.pencil', 'accessory.knitTie', 'hat.porkPie']),
  ShopBundle(id: 'detective', tier: 'set', discountPct: 35, nameIt: 'Il Detective', nameEn: 'The Private Eye', taglineIt: 'Impermeabile, trilby e una pipa che pensa.', taglineEn: 'Trench coat, trilby and a thinking pipe.', sort: 20, itemIds: ['outfit.trench_coat', 'hat.trilby', 'face.pencil', 'accessory.pipe']),
  ShopBundle(id: 'padrino', tier: 'set', discountPct: 35, nameIt: 'Il Padrino', nameEn: 'The Godfather', taglineIt: "Un'offerta che non potrai rifiutare.", taglineEn: "An offer you can't refuse.", sort: 30, itemIds: ['hat.borsalino', 'outfit.midnight_double', 'face.walrus', 'accessory.pocketWatch', 'accessory.whiteCarnation']),
  ShopBundle(id: 'pirata', tier: 'set', discountPct: 38, nameIt: 'Il Pirata', nameEn: 'The Pirate', taglineIt: 'Tricorno, benda, barba e pappagallo.', taglineEn: 'Tricorn, patch, beard and parrot.', sort: 40, itemIds: ['hat.tricorn', 'glasses.eyePatch', 'face.fullBeard', 'accessory.parrot']),
  ShopBundle(id: 'nikea', tier: 'set', discountPct: 35, nameIt: 'Squadra Nikea', nameEn: 'Team Nikea', taglineIt: 'Tutto il guardaroba da pista.', taglineEn: 'The whole track wardrobe.', sort: 50, itemIds: ['hat.fulmineCap', 'outfit.fulmine_track', 'outfit.fulmine_cardigan']),
  ShopBundle(id: 'adelphi', tier: 'set', discountPct: 35, nameIt: 'Squadra Adelphi', nameEn: 'Team Adelphi', taglineIt: 'Il campo dei due fratelli.', taglineEn: "The two brothers' squad.", sort: 60, itemIds: ['hat.adelphiCap', 'outfit.adelphi_track', 'outfit.adelphi_cardigan']),
  ShopBundle(id: 'vaugirard', tier: 'set', discountPct: 35, nameIt: 'Il Viaggiatore', nameEn: 'The Traveller', taglineIt: 'La collezione Vaugirard al completo.', taglineEn: 'The full Vaugirard collection.', sort: 70, itemIds: ['outfit.vaugirard_travel', 'hat.vaugirardCap', 'accessory.vaugirardStrap']),
  ShopBundle(id: 'versalli', tier: 'premium', discountPct: 40, nameIt: 'Casa Versalli', nameEn: 'House of Versalli', taglineIt: "Tutto l'oro del barocco, in un colpo.", taglineEn: 'All the baroque gold, in one go.', sort: 100, itemIds: ['outfit.versalli_baroque', 'glasses.ricciMonocle', 'accessory.ricciChain', 'accessory.ricciTiePin', 'accessory.ricciWatch']),
  ShopBundle(id: 'chanterelle', tier: 'premium', discountPct: 40, nameIt: 'Maison Chanterelle', nameEn: 'Maison Chanterelle', taglineIt: "L'alta moda intera, perle comprese.", taglineEn: 'The whole couture line, pearls included.', sort: 110, itemIds: ['outfit.delacroix_cape', 'outfit.delacroix_velvet', 'glasses.delacroixShades', 'accessory.delacroixScarf', 'accessory.delacroixAscot', 'accessory.chanterellePearls']),
  ShopBundle(id: 'ali', tier: 'premium', discountPct: 40, nameIt: 'Paradiso e Inferno', nameEn: 'Heaven and Hell', taglineIt: "Aureola, cornetti e quattro paia d'ali.", taglineEn: 'Halo, horns and four pairs of wings.', sort: 120, itemIds: ['hat.angelHalo', 'hat.devilHorns', 'back.angelWings', 'back.batWings', 'back.butterflyWings', 'back.dragonWings']),
  ShopBundle(id: 'tendone', tier: 'premium', discountPct: 45, nameIt: 'Il Grande Tendone', nameEn: 'The Big Top', taglineIt: 'Il circo intero: clown, mimo, forzuto e mago.', taglineEn: 'The whole circus: clown, mime, strongman and magician.', sort: 130, itemIds: ['hat.clownWig', 'hat.magicianHat', 'face.curledMoustache', 'face.mimeFace', 'glasses.hypnoGlasses', 'outfit.clown_suit', 'outfit.strongman_leotard', 'outfit.mime_stripes', 'outfit.magician_cape', 'accessory.clownNose']),
  ShopBundle(id: 'leggende', tier: 'premium', discountPct: 40, nameIt: 'Le Leggende', nameEn: 'The Legends', taglineIt: "Dieci pezzi leggendari: il guardaroba di un boss.", taglineEn: "Ten legendary pieces: a boss's wardrobe.", sort: 140, itemIds: ['outfit.trench_coat', 'outfit.gold_brocade', 'hat.morettiHomburg', 'outfit.vanetti_tuxedo', 'outfit.vanetti_ivory', 'outfit.delacroix_cape', 'accessory.ricciWatch', 'outfit.vaugirard_travel', 'outfit.versalli_baroque', 'accessory.chanterellePearls']),
  ...calcioBundles,
  ...framesBundles,
  ...gestureBundles,
];

/// Come veste la maglia: le righe verticali, tinta unita, la fascia
/// trasversale o le due metà.
enum CalcioKit { stripes, plain, sash, halves }

/// Il segno inventato sul petto: niente stemmi veri, solo figure semplici.
enum CalcioEmblem { comet, sun, moon, bolt, anchor, star, compass, horseshoe, laurel, volcano }

/// Il pezzo forte della curva, con l'alone nei colori della squadra.
enum CalcioProp {
  flare('Fumogeno', 'smoke flare'),
  megaphone('Megafono', 'megaphone'),
  trophy('Coppa', 'trophy'),
  flag('Bandiera', 'flag');

  final String it;
  final String en;

  const CalcioProp(this.it, this.en);

  String get suffix => '${name[0].toUpperCase()}${name.substring(1)}';
}

/// Le squadre della curva: soprannomi e colori di città, niente nomi veri,
/// niente stemmi né divise ufficiali. L'id fa da prefisso ai pezzi:
/// `outfit.<id>_kit`, `hat.<id>Cap`, `accessory.<id>Scarf`,
/// `accessory.<id><Prop>`.
enum CalcioTeam {
  blaugrana('Blaugrana', 'Blu e granata, a righe.', 'Blue and garnet stripes.', Color(0xFF1F3F94), Color(0xFF9A1B3F), Color(0xFFE9C23A), Color(0xFF6E1A3C), CalcioKit.stripes, CalcioEmblem.comet, CalcioProp.flare),
  merengues('Merengues', 'Bianco candido e oro.', 'Spotless white and gold.', Color(0xFFF4F1EA), Color(0xFFD4A93A), Color(0xFF5B3A8E), Color(0xFF4E3C80), CalcioKit.sash, CalcioEmblem.sun, CalcioProp.trophy),
  celesti('Celesti', 'Il celeste del cielo sopra le fabbriche.', 'Sky blue over the factory chimneys.', Color(0xFF8EC6EE), Color(0xFFF4F1EA), Color(0xFF1C2C4C), Color(0xFF2C5C8E), CalcioKit.plain, CalcioEmblem.moon, CalcioProp.megaphone),
  diavoli('Diavoli Rossi', 'Rosso fuoco, collo nero.', 'Fire red, black collar.', Color(0xFFC8202A), Color(0xFF16151A), Color(0xFFF4F1EA), Color(0xFF3C3A46), CalcioKit.plain, CalcioEmblem.bolt, CalcioProp.flare),
  reds('Reds del Porto', 'Rosso dal porto, e cantano sempre.', 'Harbour red, and always singing.', Color(0xFFB81C2C), Color(0xFFF4F1EA), Color(0xFFE9C23A), Color(0xFF9A3A22), CalcioKit.plain, CalcioEmblem.anchor, CalcioProp.megaphone),
  rossoneri('Rossoneri', 'Righe rosse e nere.', 'Red and black stripes.', Color(0xFFC8202A), Color(0xFF16151A), Color(0xFFF4F1EA), Color(0xFF7A1A1E), CalcioKit.stripes, CalcioEmblem.star, CalcioProp.flare),
  nerazzurri('Nerazzurri', 'Righe nere e azzurre.', 'Black and blue stripes.', Color(0xFF1E4FB0), Color(0xFF141418), Color(0xFFE9C23A), Color(0xFF1C3C7C), CalcioKit.stripes, CalcioEmblem.compass, CalcioProp.flag),
  bianconeri('Bianconeri', "Bianco e nero, nient'altro.", 'Black and white, nothing else.', Color(0xFFF4F1EA), Color(0xFF16151A), Color(0xFFE9C23A), Color(0xFF66666E), CalcioKit.stripes, CalcioEmblem.horseshoe, CalcioProp.trophy),
  giallorossi('Giallorossi', 'Porpora e oro, a metà.', 'Maroon and gold, halved.', Color(0xFF8A1C2C), Color(0xFFF0B42A), Color(0xFFF0B42A), Color(0xFFB07A1E), CalcioKit.halves, CalcioEmblem.laurel, CalcioProp.flare),
  azzurri('Azzurri del Golfo', "L'azzurro del golfo e del vulcano.", 'The blue of the bay and the volcano.', Color(0xFF2F8FD8), Color(0xFFF4F1EA), Color(0xFF14306E), Color(0xFF1E5A9A), CalcioKit.plain, CalcioEmblem.volcano, CalcioProp.flag);

  final String label;
  final String taglineIt;
  final String taglineEn;

  /// La maglia, le righe (o la fascia, o la seconda metà) e il colletto.
  final Color primary;
  final Color secondary;
  final Color trim;

  /// Il fondo del ritratto.
  final Color backdrop;
  final CalcioKit kit;
  final CalcioEmblem emblem;
  final CalcioProp prop;

  const CalcioTeam(this.label, this.taglineIt, this.taglineEn, this.primary, this.secondary, this.trim, this.backdrop, this.kit, this.emblem, this.prop);

  String get kitId => '${name}_kit';
  String get capId => '${name}Cap';
  String get scarfId => '${name}Scarf';
  String get propId => '$name${prop.suffix}';

  String tagline(AppLanguage language) => language == AppLanguage.it ? taglineIt : taglineEn;

  /// I quattro pezzi, come li vende la bottega.
  List<String> get itemIds => ['outfit.$kitId', 'hat.$capId', 'accessory.$scarfId', 'accessory.$propId'];

  /// La squadra di un pezzo (un id di look o di catalogo), o null.
  static CalcioTeam? of(String id) {
    final look = id.contains('.') ? id.substring(id.indexOf('.') + 1) : id;
    for (final team in values) {
      if (look == team.kitId || look == team.capId || look == team.scarfId || look == team.propId) return team;
    }
    return null;
  }
}

/// Il calcio (`supabase/migrations/20261023090000_shop_calcio.sql`): quattro
/// pezzi leggendari per squadra.
final List<ShopItem> calcioDrop = [
  for (final (i, team) in CalcioTeam.values.indexed) ...[
    ShopItem.calcio('outfit', team.kitId, 'Maglia ${team.label}', '${team.label} jersey', 480 + i),
    ShopItem.calcio('hat', team.capId, 'Berretto ${team.label}', '${team.label} bobble hat', 170 + i),
    ShopItem.calcio('accessory', team.scarfId, 'Sciarpa ${team.label}', '${team.label} scarf', 560 + 2 * i),
    ShopItem.calcio('accessory', team.propId, '${team.prop.it} ${team.label}', '${team.label} ${team.prop.en}', 561 + 2 * i),
  ],
];

/// Un pacchetto per squadra, e la curva intera.
final List<ShopBundle> calcioBundles = [
  for (final (i, team) in CalcioTeam.values.indexed)
    ShopBundle(
      id: 'curva_${team.name}',
      tier: 'premium',
      discountPct: 40,
      nameIt: 'Curva ${team.label}',
      nameEn: '${team.label} End',
      taglineIt: team.taglineIt,
      taglineEn: team.taglineEn,
      sort: 200 + 10 * i,
      itemIds: team.itemIds,
    ),
  ShopBundle(
    id: 'curva',
    tier: 'premium',
    discountPct: 45,
    nameIt: 'La Curva',
    nameEn: 'The Whole Stand',
    taglineIt: 'Tutte e dieci le squadre: quaranta pezzi leggendari.',
    taglineEn: 'All ten teams: forty legendary pieces.',
    sort: 400,
    itemIds: [for (final team in CalcioTeam.values) ...team.itemIds],
  ),
];

/// Le cornici dei posti e gli inchiostri dei nomi: si indossano intorno.
final List<ShopItem> framesDrop = [
  ShopItem.around('border', 'none', ShopRarity.base, 'Nessuna cornice', 'No frame', 800),
  ShopItem.around('border', 'brass', ShopRarity.comune, "Filigrana d'ottone", 'Brass filigree', 801),
  ShopItem.around('border', 'velvet', ShopRarity.comune, 'Velluto rosso sangue', 'Blood-red velvet', 802),
  ShopItem.around('border', 'mosaic', ShopRarity.raro, 'Mosaico', 'Mosaic', 803),
  ShopItem.around('border', 'filmStrip', ShopRarity.raro, 'Pellicola', 'Film strip', 804),
  ShopItem.around('border', 'suits', ShopRarity.raro, 'Quattro semi', 'Four suits', 805),
  ShopItem.around('border', 'artDeco', ShopRarity.epico, 'Oro art déco', 'Art deco gold', 806),
  ShopItem.around('border', 'barbedWire', ShopRarity.epico, 'Filo spinato', 'Barbed wire', 807),
  ShopItem.around('border', 'roseThorns', ShopRarity.epico, 'Rose e spine', 'Roses and thorns', 808),
  ShopItem.around('border', 'neonPink', ShopRarity.epico, 'Neon rosa', 'Pink neon', 809),
  ShopItem.around('border', 'flame', ShopRarity.leggendario, 'Cornice di fuoco', 'Ring of fire', 810),
  ShopItem.around('border', 'neonPulse', ShopRarity.leggendario, 'Neon pulsante', 'Pulsing neon', 811),
  ShopItem.around('nameStyle', 'plain', ShopRarity.base, 'Inchiostro semplice', 'Plain ink', 900),
  ShopItem.around('nameStyle', 'crimson', ShopRarity.comune, 'Rosso cremisi', 'Crimson', 901),
  ShopItem.around('nameStyle', 'emerald', ShopRarity.comune, 'Verde smeraldo', 'Emerald', 902),
  ShopItem.around('nameStyle', 'sapphire', ShopRarity.comune, 'Blu zaffiro', 'Sapphire', 903),
  ShopItem.around('nameStyle', 'violet', ShopRarity.comune, 'Viola', 'Violet', 904),
  ShopItem.around('nameStyle', 'goldFoil', ShopRarity.raro, "Foglia d'oro", 'Gold foil', 905),
  ShopItem.around('nameStyle', 'silverFoil', ShopRarity.raro, "Foglia d'argento", 'Silver foil', 906),
  ShopItem.around('nameStyle', 'tramonto', ShopRarity.epico, 'Tramonto', 'Sunset', 907),
  ShopItem.around('nameStyle', 'neonGlow', ShopRarity.epico, 'Insegna al neon', 'Neon sign', 908),
  ShopItem.around('nameStyle', 'shimmer', ShopRarity.leggendario, 'Oro scintillante', 'Shimmering gold', 909),
  ShopItem.around('nameStyle', 'inferno', ShopRarity.leggendario, 'Inferno', 'Inferno', 910),
];

/// I pacchetti delle cornici e dei nomi.
final List<ShopBundle> framesBundles = [
  ShopBundle(id: 'insegna_neon', tier: 'set', discountPct: 35, nameIt: 'Insegna al Neon', nameEn: 'Neon Sign', taglineIt: 'Rosa neon intorno, rosa neon nel nome.', taglineEn: 'Pink neon round the seat and in the name.', sort: 500, itemIds: ['border.neonPink', 'nameStyle.neonGlow']),
  ShopBundle(id: 'bisca', tier: 'set', discountPct: 35, nameIt: 'La Bisca', nameEn: 'The Card Den', taglineIt: "Velluto, quattro semi e un nome d'oro.", taglineEn: 'Velvet, four suits and a golden name.', sort: 510, itemIds: ['border.suits', 'border.velvet', 'nameStyle.goldFoil']),
  ShopBundle(id: 'giardino', tier: 'set', discountPct: 30, nameIt: 'Il Giardino', nameEn: 'The Rose Garden', taglineIt: 'Rose, spine e un nome al tramonto.', taglineEn: 'Roses, thorns and a sunset name.', sort: 520, itemIds: ['border.roseThorns', 'nameStyle.tramonto', 'nameStyle.crimson']),
  ShopBundle(id: 'leggenda', tier: 'premium', discountPct: 40, nameIt: 'La Leggenda', nameEn: 'The Legend', taglineIt: 'Fuoco, neon e oro che si muovono: al tavolo ti vedono da lontano.', taglineEn: 'Moving fire, neon and gold: the whole table sees you coming.', sort: 530, itemIds: ['border.flame', 'border.neonPulse', 'border.artDeco', 'nameStyle.shimmer', 'nameStyle.inferno']),
];

/// I gesti del tavolo (`supabase/migrations/20261109090000_table_reactions.sql`):
/// sei di casa, sette in vendita. Si lanciano, non si indossano.
final List<ShopItem> gestureDrop = [
  ShopItem.gesture('cigar', ShopRarity.base, 'Sigaro acceso', 'Lit cigar', 1000),
  ShopItem.gesture('toast', ShopRarity.base, 'Brindisi', 'Whiskey toast', 1001),
  ShopItem.gesture('hatTip', ShopRarity.base, 'Giù il cappello', 'Hat tip', 1002),
  ShopItem.gesture('omerta', ShopRarity.base, 'Omertà', 'Not a word', 1003),
  ShopItem.gesture('eye', ShopRarity.base, "Ti tengo d'occhio", "I'm watching you", 1004),
  ShopItem.gesture('coin', ShopRarity.base, 'Testa o croce', 'Coin flip', 1005),
  ShopItem.gesture('fish', ShopRarity.comune, 'Dorme con i pesci', 'Sleeps with the fishes', 1010),
  ShopItem.gesture('gun', ShopRarity.raro, 'Pistola fumante', 'Smoking gun', 1011),
  ShopItem.gesture('cash', ShopRarity.raro, 'Valigetta di contanti', 'Briefcase of cash', 1012),
  ShopItem.gesture('rose', ShopRarity.epico, 'Rosa sulla bara', 'Rose on the coffin', 1013),
  ShopItem.gesture('kiss', ShopRarity.epico, 'Il baciamano', 'Kiss the ring', 1014),
  ShopItem.gesture('horse', ShopRarity.leggendario, "Un'offerta che non puoi rifiutare", "An offer you can't refuse", 1015),
  ShopItem.gesture('tommy', ShopRarity.leggendario, 'Raffica di mitra', 'Tommy gun burst', 1016),
];

/// Tutti i gesti in vendita, insieme.
final List<ShopBundle> gestureBundles = [
  ShopBundle(
    id: 'repertorio',
    tier: 'premium',
    discountPct: 40,
    nameIt: 'Il Repertorio',
    nameEn: 'The Repertoire',
    taglineIt: 'Tutti i gesti della famiglia: al tavolo si parla anche senza parlare.',
    taglineEn: 'Every gesture of the family: at the table you talk without a word.',
    sort: 600,
    itemIds: [for (final item in gestureDrop) if (!item.free) item.id],
  ),
];

/// I pezzi che non si vendono: li regala solo un obiettivo delle missioni
/// (`MissionDef.item`), riscuotendolo. In bottega si vedono chiusi, con la
/// missione che li sblocca.
final List<ShopItem> missionDrop = [
  ShopItem.exclusive('hat', 'sbirro', ShopRarity.leggendario, 'Berretto da sbirro', "Cop's cap", 160, 'long_detective_wins_5'),
  ShopItem.exclusive('border', 'badge', ShopRarity.epico, 'Il distintivo', 'The badge', 820, 'long_finds_5'),
  ShopItem.exclusive('border', 'noose', ShopRarity.raro, 'Il cappio', 'The noose', 821, 'long_lynch_hits_3'),
  ShopItem.exclusive('border', 'laurel', ShopRarity.leggendario, "Alloro d'oro", 'Golden laurel', 822, 'long_wins_50'),
  ShopItem.exclusive('nameStyle', 'moonlight', ShopRarity.raro, 'Chiaro di luna', 'Moonlight', 920, 'long_nights_10'),
  ShopItem.exclusive('nameStyle', 'bloodInk', ShopRarity.epico, 'Inchiostro di sangue', 'Blood ink', 921, 'long_mafia_wins_10'),
  ShopItem.exclusive('nameStyle', 'siren', ShopRarity.epico, 'Sirena', 'Siren', 922, 'long_town_wins_10'),
];
