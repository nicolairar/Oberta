import '../online/shop_models.dart';

/// I testi della bottega: il bancone, lo specchio e il guardaroba. Come
/// [OnlineStrings], ogni lingua dice tutto e ogni testo finisce nel [catalog].
/// I nomi dei pezzi arrivano dal catalogo del server, in tutte e due le lingue.
abstract class ShopStrings {
  const ShopStrings();

  String get title;
  String get subtitle;
  String get greeting;
  String get coinsHint;
  String get featured;
  String endsIn(int days);
  String get counterTab;
  String get wardrobeTab;
  String slot(String slot);
  String rarity(ShopRarity rarity);
  String get owned;
  String get worn;
  String get free;
  String get buy;
  String get wear;
  String get takeOff;
  String get tryingOn;
  String confirmTitle(String item);
  String confirmBody(int price, int left);
  String get confirmYes;
  String get notNow;
  String bought(String item);
  String missing(int coins);
  String get emptyWardrobe;
  String get unavailable;

  /// La targhetta delle case di moda, accanto a quelle dei posti.
  String get brands;
  String get allBrands;

  /// La targhetta delle stramberie.
  String get oddities;
  String brandTagline(ShopBrand brand);

  Map<String, String> get catalog => {
    'title': title,
    'subtitle': subtitle,
    'greeting': greeting,
    'coinsHint': coinsHint,
    'featured': featured,
    'endsIn': endsIn(3),
    'counterTab': counterTab,
    'wardrobeTab': wardrobeTab,
    for (final s in const ['hat', 'face', 'glasses', 'outfit', 'accessory']) 'slot.$s': slot(s),
    for (final r in ShopRarity.values) 'rarity.${r.name}': rarity(r),
    'owned': owned,
    'worn': worn,
    'free': free,
    'buy': buy,
    'wear': wear,
    'takeOff': takeOff,
    'tryingOn': tryingOn,
    'confirmTitle': confirmTitle('Borsalino'),
    'confirmBody': confirmBody(700, 300),
    'confirmYes': confirmYes,
    'notNow': notNow,
    'bought': bought('Borsalino'),
    'missing': missing(50),
    'emptyWardrobe': emptyWardrobe,
    'unavailable': unavailable,
    'brands': brands,
    'allBrands': allBrands,
    'oddities': oddities,
    for (final b in ShopBrand.values) 'brand.${b.name}': brandTagline(b),
  };
}

class ItalianShopStrings extends ShopStrings {
  const ItalianShopStrings();

  @override
  String get title => 'LA BOTTEGA';
  @override
  String get subtitle => 'Sartoria e cappelleria · dal 1946';
  @override
  String get greeting => 'Provi pure, lo specchio non mente mai.';
  @override
  String get coinsHint => 'Le monete arrivano salendo di livello: si sale vincendo.';
  @override
  String get featured => 'IN VETRINA';
  @override
  String endsIn(int days) => days <= 1 ? 'Ultimo giorno' : 'Ancora $days giorni';
  @override
  String get counterTab => 'BANCONE';
  @override
  String get wardrobeTab => 'GUARDAROBA';
  @override
  String slot(String slot) => switch (slot) {
    'hat' => 'Cappelli',
    'face' => 'Baffi',
    'glasses' => 'Occhiali',
    'outfit' => 'Abiti',
    _ => 'Vezzi',
  };
  @override
  String rarity(ShopRarity rarity) => switch (rarity) {
    ShopRarity.base => 'Di casa',
    ShopRarity.comune => 'Comune',
    ShopRarity.raro => 'Raro',
    ShopRarity.epico => 'Epico',
    ShopRarity.leggendario => 'Leggendario',
  };
  @override
  String get owned => 'TUO';
  @override
  String get worn => 'INDOSSATO';
  @override
  String get free => 'GRATIS';
  @override
  String get buy => 'COMPRA';
  @override
  String get wear => 'INDOSSA';
  @override
  String get takeOff => 'TOGLI';
  @override
  String get tryingOn => 'In prova';
  @override
  String confirmTitle(String item) => 'Comprare $item?';
  @override
  String confirmBody(int price, int left) => 'Costa $price monete. Te ne restano $left.';
  @override
  String get confirmYes => 'Affare fatto';
  @override
  String get notNow => 'Non ora';
  @override
  String bought(String item) => 'È tuo: $item.';
  @override
  String missing(int coins) => 'Ti mancano $coins monete.';
  @override
  String get emptyWardrobe => 'Qui c\'è solo quello che hai già.';
  @override
  String get unavailable => 'La bottega è chiusa: entra con il tuo account.';
  @override
  String get brands => 'Firme';
  @override
  String get allBrands => 'Tutte';
  @override
  String get oddities => 'Stramberie';
  @override
  String brandTagline(ShopBrand brand) => switch (brand) {
    ShopBrand.vaugirard => 'Bauli e valigie · Parigi',
    ShopBrand.arminio => 'Sartoria morbida · Milano',
    ShopBrand.cuccioli => 'Pelletteria · Firenze',
    ShopBrand.versalli => 'Oro e barocco · Reggio',
    ShopBrand.chanterelle => 'Alta moda · Parigi',
    ShopBrand.nikea => 'Corsa e atletica',
    ShopBrand.adelphi => 'Atletica dei due fratelli',
  };
}

class EnglishShopStrings extends ShopStrings {
  const EnglishShopStrings();

  @override
  String get title => 'THE TAILOR\'S';
  @override
  String get subtitle => 'Tailor and hatter · since 1946';
  @override
  String get greeting => 'Go ahead, try it on. The mirror never lies.';
  @override
  String get coinsHint => 'Coins come with every level, and levels come from winning.';
  @override
  String get featured => 'IN THE WINDOW';
  @override
  String endsIn(int days) => days <= 1 ? 'Last day' : '$days days left';
  @override
  String get counterTab => 'COUNTER';
  @override
  String get wardrobeTab => 'WARDROBE';
  @override
  String slot(String slot) => switch (slot) {
    'hat' => 'Hats',
    'face' => 'Moustaches',
    'glasses' => 'Glasses',
    'outfit' => 'Suits',
    _ => 'Accessories',
  };
  @override
  String rarity(ShopRarity rarity) => switch (rarity) {
    ShopRarity.base => 'House',
    ShopRarity.comune => 'Common',
    ShopRarity.raro => 'Rare',
    ShopRarity.epico => 'Epic',
    ShopRarity.leggendario => 'Legendary',
  };
  @override
  String get owned => 'OWNED';
  @override
  String get worn => 'WORN';
  @override
  String get free => 'FREE';
  @override
  String get buy => 'BUY';
  @override
  String get wear => 'WEAR';
  @override
  String get takeOff => 'TAKE OFF';
  @override
  String get tryingOn => 'Trying on';
  @override
  String confirmTitle(String item) => 'Buy the $item?';
  @override
  String confirmBody(int price, int left) => 'It costs $price coins. You\'ll have $left left.';
  @override
  String get confirmYes => 'Deal';
  @override
  String get notNow => 'Not now';
  @override
  String bought(String item) => 'The $item is yours.';
  @override
  String missing(int coins) => 'You need $coins more coins.';
  @override
  String get emptyWardrobe => 'Only what you already own hangs here.';
  @override
  String get unavailable => 'The shop is closed: sign in with your account.';
  @override
  String get brands => 'Labels';
  @override
  String get allBrands => 'All';
  @override
  String get oddities => 'Oddities';
  @override
  String brandTagline(ShopBrand brand) => switch (brand) {
    ShopBrand.vaugirard => 'Trunks and luggage · Paris',
    ShopBrand.arminio => 'Soft tailoring · Milan',
    ShopBrand.cuccioli => 'Leather goods · Florence',
    ShopBrand.versalli => 'Gold and baroque · Reggio',
    ShopBrand.chanterelle => 'Couture · Paris',
    ShopBrand.nikea => 'Running and athletics',
    ShopBrand.adelphi => 'Athletics of two brothers',
  };
}
