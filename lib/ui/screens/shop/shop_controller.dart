import 'package:flutter/foundation.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/shop_strings.dart';

import '../../../online/online_account.dart';
import '../../../online/online_services.dart';
import '../../avatar/avatar_look.dart';

/// Quello che la bottega sa di un pezzo, per chi la guarda adesso.
enum ItemState {
  forSale,
  owned,
  worn,

  /// Non si vende: lo regala solo una missione ([ShopItem.unlock]).
  locked,
}

/// I posti del corpo di ogni reparto.
const deptSlots = <ShopDept, List<String>>{
  ShopDept.window: [],
  ShopDept.hats: ['hat', 'hairdo', 'headFx'],
  ShopDept.face: ['face', 'glasses', 'tattoo', 'faceExtras', 'eyeShine', 'hairDye'],
  ShopDept.outfit: ['outfit'],
  ShopDept.vice: ['accessory'],
  ShopDept.scene: ['aura', 'frontFx'],
  ShopDept.back: ['back'],
  ShopDept.hands: ['held'],
  ShopDept.frames: ['border', 'nameStyle'],
  ShopDept.gestures: ['gesture'],
};

/// Come si stringe uno scaffale: chi possiede, la classe, la casa o la
/// collezione ([ShopBrand] o [ShopCollection]), e le parole cercate.
@immutable
class ShopFilter {
  final ShopOwnership own;
  final ShopRarity? rarity;
  final Object? collection;
  final String query;

  const ShopFilter({this.own = ShopOwnership.all, this.rarity, this.collection, this.query = ''});

  /// Quanti filtri del foglio sono accesi (la classe e la collezione).
  int get extra => (rarity == null ? 0 : 1) + (collection == null ? 0 : 1);

  ShopFilter copyWith({ShopOwnership? own, ShopRarity? Function()? rarity, Object? Function()? collection, String? query}) => ShopFilter(
    own: own ?? this.own,
    rarity: rarity == null ? this.rarity : rarity(),
    collection: collection == null ? this.collection : collection(),
    query: query ?? this.query,
  );

  static Object? collectionOf(ShopItem item) => item.brand ?? item.collection;
}

/// La bottega aperta: il catalogo, la vetrina, quello che si possiede, e il
/// pezzo in prova davanti allo specchio. Comprare e indossare chiedono al
/// server, poi il profilo nuovo torna all'[OnlineAccount], così il
/// cartellino del vicolo e ogni ritratto lo vedono subito.
class ShopController extends ChangeNotifier {
  final ShopRepository shop;
  final OnlineAccount account;

  ShopController({required this.shop, required this.account}) {
    account.addListener(notifyListeners);
  }

  List<ShopItem> catalog = const [];
  List<ShopFeature> featured = const [];
  Set<String> owned = const {};
  List<ShopBundle> bundles = const [];
  bool loading = true;
  Object? error;

  /// Il pezzo in prova, o null: lo specchio mostra il look indossato.
  ShopItem? trying;

  /// La mano in cui si prova e si indossa una cosa da tenere.
  Hand hand = Hand.right;

  void chooseHand(Hand value) {
    hand = value;
    notifyListeners();
  }

  /// Una richiesta al server in corso: i bottoni aspettano.
  bool busy = false;

  Profile? get profile => account.profile;
  int get coins => profile?.coins ?? 0;

  /// Il nome con cui gli altri lo vedono, per provare cornici e inchiostri.
  String get who => profile?.handle ?? '?';

  /// Il look indossato adesso.
  AvatarLook get look => profile?.look ?? AvatarLook.fallback('?');

  /// Quello che mostra lo specchio: il look con il pezzo in prova.
  AvatarLook get mirror {
    final item = trying;
    if (item == null) return look;
    return tryOn(item);
  }

  AvatarLook tryOn(ShopItem item) {
    final slot = slotOf(item);
    return slot == null ? look : look.wearing(slot, item.lookId, hand: hand) ?? look;
  }

  static LookSlot? slotOf(ShopItem? item) => item == null ? null : LookSlot.values.where((slot) => slot.name == item.slot).firstOrNull;

  /// Solo i pezzi che quest'app sa disegnare: quelli di una versione nuova
  /// restano fuori finché non si aggiorna.
  bool drawable(ShopItem item) {
    if (item.isGesture) return TableGesture.byId(item.lookId) != null;
    final slot = slotOf(item);
    return slot != null && look.wearing(slot, item.lookId) != null;
  }

  ShopItem? item(String id) => catalog.where((item) => item.id == id).firstOrNull;

  ItemState stateOf(ShopItem item) {
    final slot = slotOf(item);
    if (slot != null && look.wears(slot, item.lookId) && (item.free || owned.contains(item.id))) return ItemState.worn;
    if (item.free || owned.contains(item.id)) return ItemState.owned;
    if (item.exclusive) return ItemState.locked;
    return ItemState.forSale;
  }

  /// In vendita sul bancone, per posto.
  List<ShopItem> forSale(String slot) => [
    for (final item in catalog)
      if (item.slot == slot && !item.free && drawable(item)) item,
  ];

  /// Le firme: i pezzi delle case di moda, di [brand] o di tutte, in
  /// vendita o (nel guardaroba) già posseduti, dai più cari.
  List<ShopItem> branded(ShopBrand? brand, {required bool wardrobe}) => [
    for (final item in catalog)
      if (item.brand != null &&
          (brand == null || item.brand == brand) &&
          drawable(item) &&
          (!wardrobe || owned.contains(item.id)))
        item,
  ]..sort((a, b) => b.price != a.price ? b.price.compareTo(a.price) : a.sort.compareTo(b.sort));

  /// Lo scaffale delle stramberie: il circo e il carnevale, i più cari prima.
  List<ShopItem> oddities({required bool wardrobe}) => [
    for (final item in catalog)
      if (item.collection != null && drawable(item) && (!wardrobe || owned.contains(item.id))) item,
  ]..sort((a, b) => b.price != a.price ? b.price.compareTo(a.price) : a.sort.compareTo(b.sort));

  /// Nel guardaroba: quello che si possiede, prima i pezzi comprati e poi
  /// quelli di casa.
  List<ShopItem> wardrobe(String slot) => [
    for (final free in [false, true])
      for (final item in catalog)
        if (item.slot == slot && item.free == free && drawable(item) && (free || owned.contains(item.id))) item,
  ];

  /// I pezzi di un reparto che si sanno disegnare, di casa compresi.
  List<ShopItem> deptItems(ShopDept dept) => [
    for (final item in catalog)
      if (deptSlots[dept]!.contains(item.slot) && drawable(item)) item,
  ];

  /// Il pezzo comprato che si porta adesso in un reparto, o null.
  ShopItem? wornIn(ShopDept dept) =>
      deptItems(dept).where((item) => !item.free && !item.isGesture && stateOf(item) == ItemState.worn).firstOrNull;

  /// Le case e le collezioni che hanno pezzi in [items], in ordine.
  static List<Object> collectionsIn(List<ShopItem> items) => [
    for (final brand in ShopBrand.values)
      if (items.any((item) => item.brand == brand)) brand,
    for (final collection in ShopCollection.values)
      if (items.any((item) => item.collection == collection)) collection,
  ];

  /// [items] stretti da [filter].
  List<ShopItem> filtered(List<ShopItem> items, ShopFilter filter, AppLanguage language) {
    final words = filter.query.trim().toLowerCase();
    return [
      for (final item in items)
        if ((filter.rarity == null || item.rarity == filter.rarity) &&
            (filter.collection == null || ShopFilter.collectionOf(item) == filter.collection) &&
            switch (filter.own) {
              ShopOwnership.all => true,
              ShopOwnership.mine => stateOf(item) == ItemState.owned || stateOf(item) == ItemState.worn,
              ShopOwnership.toBuy => stateOf(item) == ItemState.forSale,
            } &&
            (words.isEmpty || item.name(language).toLowerCase().contains(words) || (item.brand?.label.toLowerCase().contains(words) ?? false)))
          item,
    ];
  }

  /// I pezzi in vetrina che non sono ancora scaduti, e quando scade il primo.
  List<(ShopItem, ShopFeature)> liveWindow(DateTime now) => [
    for (final entry in window)
      if (now.isBefore(entry.$2.endsAt)) entry,
  ];

  DateTime? windowEnds(DateTime now) {
    DateTime? first;
    for (final (_, feature) in liveWindow(now)) {
      if (first == null || feature.endsAt.isBefore(first)) first = feature.endsAt;
    }
    return first;
  }

  /// La vetrina di adesso, solo i pezzi che si sanno disegnare.
  List<(ShopItem, ShopFeature)> get window => [
    for (final feature in featured)
      if (item(feature.itemId) case final item? when drawable(item)) (item, feature),
  ];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([shop.catalog(), shop.featured(), shop.owned()]);
      catalog = results[0] as List<ShopItem>;
      featured = results[1] as List<ShopFeature>;
      owned = results[2] as Set<String>;
      // Un server senza pacchetti non chiude la bottega.
      bundles = await shop.bundles().catchError((_) => const <ShopBundle>[]);
    } catch (failure) {
      error = failure;
    }
    loading = false;
    notifyListeners();
  }

  void preview(ShopItem? item) {
    trying = item;
    notifyListeners();
  }

  Future<T> _call<T>(Future<T> Function() call) async {
    busy = true;
    notifyListeners();
    try {
      return await call();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String get _tone => look.base.tone.name;

  Future<void> buy(ShopItem item) => _call(() async {
    final profile = await shop.buy(item.id);
    owned = {...owned, item.id};
    account.saved(profile);
  });

  Map<String, ShopItem> get _byId => {for (final item in catalog) item.id: item};

  /// I pacchetti che si sanno disegnare tutti: prima i completi, poi il lusso.
  List<ShopBundle> get shelfBundles => [
    for (final bundle in bundles)
      if (bundleItems(bundle).length == bundle.itemIds.length && bundle.itemIds.isNotEmpty) bundle,
  ];

  /// Il gesto di un pezzo, o null.
  static TableGesture? gestureOf(ShopItem item) => item.isGesture ? TableGesture.byId(item.lookId) : null;

  /// I gesti di un pacchetto (vuoto se non ne ha).
  List<TableGesture> bundleGestures(ShopBundle bundle) => [for (final item in bundleItems(bundle)) ?gestureOf(item)];

  /// Un pacchetto di cornici e nomi: si prova sul posto del tavolo.
  bool bundleAround(ShopBundle bundle) => bundleItems(bundle).any((item) => item.around);

  /// I pezzi di un pacchetto, nell'ordine del pacchetto.
  List<ShopItem> bundleItems(ShopBundle bundle) => [
    for (final id in bundle.itemIds)
      if (item(id) case final item? when drawable(item)) item,
  ];

  /// La somma dei pezzi interi presi uno a uno, e quella dei soli mancanti.
  int bundleFull(ShopBundle bundle) => bundle.singles(_byId, const {});
  int bundleSingles(ShopBundle bundle) => bundle.singles(_byId, owned);
  int bundlePrice(ShopBundle bundle) => bundle.price(_byId, owned);
  int bundleOwnedCount(ShopBundle bundle) => bundle.itemIds.where(owned.contains).length;
  bool bundleComplete(ShopBundle bundle) => bundle.missing(_byId, owned).isEmpty;

  /// Il pacchetto addosso: un pezzo per posto, il primo che c'è.
  AvatarLook bundleLook(ShopBundle bundle) {
    var dressed = look;
    final used = <String>{};
    for (final item in bundleItems(bundle)) {
      final slot = slotOf(item);
      if (slot == null || !used.add(item.slot)) continue;
      dressed = dressed.wearing(slot, item.lookId) ?? dressed;
    }
    return dressed;
  }

  Future<void> buyBundle(ShopBundle bundle) => _call(() async {
    final profile = await shop.buyBundle(bundle.id);
    owned = {...owned, for (final item in bundleItems(bundle)) if (!item.free) item.id};
    account.saved(profile);
  });

  Future<void> equip(ShopItem item) => _call(() async {
    account.saved(await shop.equip(item.id, tone: _tone, current: look.toJson(), hand: item.slot == 'held' ? hand.name : null));
  });

  /// Si toglie [item]: un segno della faccia da solo (gli altri restano),
  /// una cosa in mano dalla sua mano, il resto con tutto il suo posto.
  Future<void> takeOff(ShopItem item) {
    if (item.slot == 'faceExtras') return equip(item);
    if (item.slot == 'held') {
      final held = HeldItem.values.where((h) => h.name == item.lookId).firstOrNull;
      final key = held == null || held.twoHanded ? 'held' : (look.heldL == held ? Hand.left.key : Hand.right.key);
      return unequip(key);
    }
    return unequip(item.slot);
  }

  Future<void> unequip(String slot) => _call(() async {
    account.saved(await shop.unequip(slot, tone: _tone, current: look.toJson()));
  });

  @override
  void dispose() {
    account.removeListener(notifyListeners);
    super.dispose();
  }
}
