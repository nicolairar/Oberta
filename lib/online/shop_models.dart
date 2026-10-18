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
  /// Alta sartoria milanese: smoking, gessati, doppiopetti. Il marchio: una V
  /// dentro un rombo.
  vanetti('Casa Vanetti', Color(0xFFD9B45A)),

  /// Cappellai dal 1908: il marchio è una tesa sopra due iniziali.
  moretti('Fratelli Moretti', Color(0xFFC08E5E)),

  /// Abiti da sera parigini, sciarpe e foulard: una falce di luna e una stella.
  delacroix('Maison Delacroix', Color(0xFFCFC6E2)),

  /// Abbigliamento sportivo d'anteguerra: un fulmine in un tondo.
  fulmine('Atletica Fulmine', Color(0xFFE2563F)),

  /// Oro, catene e orologi: una gemma sfaccettata.
  ricci('Gioielleria Ricci', Color(0xFFF0CF6A));

  final String label;
  final Color color;

  const ShopBrand(this.label, this.color);

  static ShopBrand? byId(String? id) => values.where((brand) => brand.name == id).firstOrNull;
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
  });

  /// Un pezzo del catalogo di partenza, con il prezzo della sua classe.
  ShopItem.seed(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, {this.brand})
    : id = '$slot.$lookId',
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 17);

  /// Un pezzo della seconda consegna (le case di moda e il resto).
  ShopItem.drop(this.slot, this.lookId, this.rarity, this.nameIt, this.nameEn, this.sort, {this.brand})
    : id = '$slot.$lookId',
      price = rarity.price,
      releasedOn = DateTime.utc(2026, 10, 18);

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
/// `supabase/migrations/20261018120000_shop_brands.sql` (un test li
/// confronta): la bottega finta lo usa, quella vera lo legge dal server.
final List<ShopItem> initialShopCatalog = [..._firstDrop, ...brandDrop];

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
  ShopItem.drop('hat', 'morettiFedora', ShopRarity.epico, 'Fedora Moretti', 'Moretti fedora', 130, brand: ShopBrand.moretti),
  ShopItem.drop('hat', 'morettiPanama', ShopRarity.epico, 'Panama Moretti', 'Moretti panama', 131, brand: ShopBrand.moretti),
  ShopItem.drop(
    'hat',
    'morettiHomburg',
    ShopRarity.leggendario,
    'Homburg da sera Moretti',
    'Moretti evening homburg',
    132,
    brand: ShopBrand.moretti,
  ),
  ShopItem.drop('hat', 'fulmineCap', ShopRarity.epico, 'Berretto da ciclista Fulmine', 'Fulmine cycling cap', 133, brand: ShopBrand.fulmine),
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
    'Occhiali fumé Delacroix',
    'Delacroix smoked glasses',
    330,
    brand: ShopBrand.delacroix,
  ),
  ShopItem.drop(
    'glasses',
    'ricciMonocle',
    ShopRarity.epico,
    'Monocolo con brillante Ricci',
    'Ricci diamond monocle',
    331,
    brand: ShopBrand.ricci,
  ),
  // Abiti.
  ShopItem.drop('outfit', 'charcoal_windowpane', ShopRarity.raro, 'Finestrato antracite', 'Charcoal windowpane', 440),
  ShopItem.drop('outfit', 'tan_herringbone', ShopRarity.raro, 'Spina di pesce tabacco', 'Tan herringbone', 441),
  ShopItem.drop('outfit', 'steel_sharkskin', ShopRarity.raro, 'Fresco di lana acciaio', 'Steel sharkskin', 442),
  ShopItem.drop('outfit', 'oxblood_double', ShopRarity.raro, 'Doppiopetto sangue di bue', 'Oxblood double-breasted', 443),
  ShopItem.drop('outfit', 'vanetti_pinstripe', ShopRarity.epico, 'Gessato Vanetti', 'Vanetti pinstripe', 450, brand: ShopBrand.vanetti),
  ShopItem.drop(
    'outfit',
    'vanetti_tuxedo',
    ShopRarity.leggendario,
    'Smoking di raso Vanetti',
    'Vanetti satin tuxedo',
    451,
    brand: ShopBrand.vanetti,
  ),
  ShopItem.drop(
    'outfit',
    'vanetti_ivory',
    ShopRarity.leggendario,
    'Smoking avorio Vanetti',
    'Vanetti ivory dinner jacket',
    452,
    brand: ShopBrand.vanetti,
  ),
  ShopItem.drop(
    'outfit',
    'delacroix_velvet',
    ShopRarity.epico,
    'Giacca da camera Delacroix',
    'Delacroix velvet smoking jacket',
    453,
    brand: ShopBrand.delacroix,
  ),
  ShopItem.drop(
    'outfit',
    'delacroix_cape',
    ShopRarity.leggendario,
    "Mantello d'opera Delacroix",
    'Delacroix opera cape',
    454,
    brand: ShopBrand.delacroix,
  ),
  ShopItem.drop('outfit', 'fulmine_track', ShopRarity.epico, 'Tuta Fulmine', 'Fulmine track jacket', 455, brand: ShopBrand.fulmine),
  ShopItem.drop(
    'outfit',
    'fulmine_cardigan',
    ShopRarity.epico,
    'Cardigan da squadra Fulmine',
    'Fulmine team cardigan',
    456,
    brand: ShopBrand.fulmine,
  ),
  // Vezzi.
  ShopItem.drop('accessory', 'stripeTie', ShopRarity.comune, 'Cravatta a righe', 'Striped tie', 520),
  ShopItem.drop('accessory', 'knitTie', ShopRarity.comune, 'Cravatta di maglia', 'Knit tie', 521),
  ShopItem.drop('accessory', 'polkaBowTie', ShopRarity.comune, 'Papillon a pois', 'Polka-dot bow tie', 522),
  ShopItem.drop('accessory', 'whiteCarnation', ShopRarity.comune, 'Garofano bianco', 'White carnation', 523),
  ShopItem.drop('accessory', 'suspenders', ShopRarity.raro, 'Bretelle', 'Braces', 524),
  ShopItem.drop('accessory', 'cigaretteHolder', ShopRarity.raro, 'Bocchino', 'Cigarette holder', 525),
  ShopItem.drop('accessory', 'ricciChain', ShopRarity.epico, "Catena d'oro Ricci", 'Ricci gold chain', 530, brand: ShopBrand.ricci),
  ShopItem.drop(
    'accessory',
    'ricciTiePin',
    ShopRarity.epico,
    'Fermacravatta Ricci',
    'Ricci tie pin',
    531,
    brand: ShopBrand.ricci,
  ),
  ShopItem.drop(
    'accessory',
    'ricciWatch',
    ShopRarity.leggendario,
    "Cipolla d'oro Ricci",
    'Ricci gold pocket watch',
    532,
    brand: ShopBrand.ricci,
  ),
  ShopItem.drop(
    'accessory',
    'delacroixScarf',
    ShopRarity.epico,
    'Sciarpa da sera Delacroix',
    'Delacroix evening scarf',
    533,
    brand: ShopBrand.delacroix,
  ),
  ShopItem.drop(
    'accessory',
    'delacroixAscot',
    ShopRarity.epico,
    'Foulard Delacroix',
    'Delacroix ascot',
    534,
    brand: ShopBrand.delacroix,
  ),
];

/// La vetrina di adesso, come nella migrazione delle case: la collezione
/// Casa Vanetti, con un cappello e un orologio da abbinare.
final List<ShopFeature> initialShopFeatured = [
  for (final (i, id) in brandFeatured.indexed)
    ShopFeature(itemId: id, startsAt: DateTime.utc(2026, 10, 18), endsAt: DateTime.utc(2026, 11, 8), sort: i),
];

const brandFeatured = [
  'outfit.vanetti_tuxedo',
  'outfit.vanetti_pinstripe',
  'outfit.vanetti_ivory',
  'hat.morettiHomburg',
  'accessory.ricciWatch',
];
