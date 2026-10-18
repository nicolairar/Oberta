import 'dart:ui' show Color;

import '../l10n/app_language.dart';
import 'online_models.dart';

/// Le classi della bottega. Il prezzo lo decide la classe, ed è lo stesso
/// sul server (vincolo su `shop_items.price_coins`).
enum ShopRarity {
  /// Il corredo di tutti: costa niente e lo si possiede già.
  base(0),
  comune(350),
  raro(700),
  epico(1100),
  leggendario(1800);

  final int price;

  const ShopRarity(this.price);

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
  assurdo('Assurdo', 'Absurd');

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
  });

  /// Un pezzo del catalogo di partenza, con il prezzo della sua classe.
  ShopItem.seed(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, {this.brand})
    : id = '$slot.$lookId',
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 17),
      collection = null;

  /// Un pezzo della seconda consegna (le case di moda e il resto).
  ShopItem.drop(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, {this.brand})
    : id = '$slot.$lookId',
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 18),
      collection = null;

  /// Un pezzo della terza consegna: una casa e basta.
  ShopItem.house(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, ShopBrand this.brand)
    : id = '$slot.$lookId',
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 18),
      collection = null;

  /// Una stramberia: il circo e il carnevale.
  ShopItem.oddity(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, ShopCollection this.collection)
    : id = '$slot.$lookId',
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 18),
      brand = null;

  bool get free => rarity == ShopRarity.base;

  String name(AppLanguage language) => language == AppLanguage.en ? nameEn : nameIt;

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

  /// Indossa un pezzo posseduto ([OnlineFailure.notOwned] altrimenti).
  /// [tone] è la pelle che l'app mostra, per chi non ha mai salvato un look:
  /// serve solo ai baffi.
  /// [current] è tutto il look che l'app mostra: il server lo salva sotto
  /// quello già salvato, così cambia solo il pezzo scelto.
  Future<Profile> equip(String itemId, {String? tone, Map<String, String>? current});

  /// Si toglie quello che porta in [slot]: torna il pezzo che gli spetta dal nome.
  Future<Profile> unequip(String slot, {String? tone, Map<String, String>? current});
}

/// Il catalogo, lo stesso delle migrazioni
/// `supabase/migrations/20261017221000_shop.sql` e
/// `supabase/migrations/20261018120000_shop_brands.sql` e seguenti (un test li
/// confronta): la bottega finta lo usa, quella vera lo legge dal server.
final List<ShopItem> initialShopCatalog = [..._firstDrop, ...brandDrop, ...houseDrop, ...odditiesDrop, ...barberDrop];

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
  ShopItem.oddity('accessory', 'angelWings', ShopRarity.leggendario, "Ali d'angelo", 'Angel wings', 545, ShopCollection.carnevale),
  ShopItem.oddity('accessory', 'batWings', ShopRarity.leggendario, 'Ali da diavoletto', 'Devil bat wings', 546, ShopCollection.carnevale),
  ShopItem.oddity('accessory', 'butterflyWings', ShopRarity.leggendario, 'Ali di farfalla', 'Butterfly wings', 547, ShopCollection.carnevale),
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
  ShopItem.oddity('glasses', 'googlyEyes', ShopRarity.raro, 'Occhi mobili', 'Googly-eye glasses', 346, ShopCollection.assurdo),
  ShopItem.oddity('glasses', 'glasses3d', ShopRarity.raro, 'Occhialini 3D', '3D glasses', 347, ShopCollection.assurdo),
  ShopItem.oddity('glasses', 'bulbMonocle', ShopRarity.epico, "Monocolo dell'idea", 'Lightbulb monocle', 348, ShopCollection.assurdo),
  ShopItem.oddity('outfit', 'pizza_suit', ShopRarity.leggendario, 'Costume da pizza', 'Pizza slice costume', 476, ShopCollection.assurdo),
  ShopItem.oddity('outfit', 'cactus_suit', ShopRarity.leggendario, 'Costume da cactus', 'Cactus costume', 477, ShopCollection.assurdo),
  ShopItem.oddity('outfit', 'ghost_sheet', ShopRarity.epico, 'Lenzuolo da fantasma', 'Ghost sheet', 478, ShopCollection.assurdo),
  ShopItem.oddity('outfit', 'mummy_wraps', ShopRarity.epico, 'Bende da mummia', 'Mummy wraps', 479, ShopCollection.assurdo),
  ShopItem.oddity('accessory', 'snailShell', ShopRarity.epico, 'Guscio di lumaca', 'Snail shell backpack', 548, ShopCollection.assurdo),
  ShopItem.oddity('accessory', 'jetpack', ShopRarity.leggendario, 'Zaino a razzo', 'Jetpack', 549, ShopCollection.assurdo),
  ShopItem.oddity('accessory', 'dragonWings', ShopRarity.leggendario, 'Ali di drago', 'Dragon wings', 550, ShopCollection.assurdo),
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
