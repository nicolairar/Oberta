import 'dart:math';

import 'package:flutter/material.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/shop_strings.dart';
import '../../../online/online_account.dart';
import '../../../online/online_services.dart';
import '../../avatar/avatar_look.dart';
import '../../avatar/look_painter.dart';
import '../../press.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home_account.dart' show CoinPainter;
import '../../widgets/noir_avatar.dart' show AvatarHead;
import '../../widgets/player_avatar.dart' show AvatarBustPainter;
import '../online/online_widgets.dart' show showFailure;
import 'shop_controller.dart';

/// Apre la bottega di chi è entrato.
Future<void> openShop(BuildContext context, {required OnlineAccount account, required ShopRepository shop}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopScreen(account: account, shop: shop),
      ),
    );

/// I colori delle classi, come le etichette cucite dentro la giacca.
Color rarityColor(ShopRarity rarity) => switch (rarity) {
  ShopRarity.base => const Color(0xFF8A8178),
  ShopRarity.comune => const Color(0xFF7FA37A),
  ShopRarity.raro => const Color(0xFF5B95D6),
  ShopRarity.epico => const Color(0xFFAE6BDB),
  ShopRarity.leggendario => const Color(0xFFE8B84A),
};

/// I posti del reparto accessori, e quelli dell'armadio.
const _accessorySlots = ['glasses', 'accessory', 'face'];
const _allSlots = ['hat', 'outfit', 'glasses', 'accessory', 'face'];
const _cream = Color(0xFFF2E6CF);
const _wood = Color(0xFF4A2C1A);

/// Il nome della rotta del creatore di facce, se l'app ce l'ha.
const avatarRoute = '/avatar';

/// La bottega: il retrobottega di un sarto e cappellaio degli anni '40,
/// diviso in reparti. In alto le linguette (vetrina, sartoria, cappelleria,
/// accessori, firme, stramberie, armadio); sotto, i pezzi grandi, due per
/// fila, con filtri per classe e prezzo. Toccato un pezzo, ci si prova
/// davanti allo specchio, a tutto schermo, e lì si compra o si indossa.
class ShopScreen extends StatefulWidget {
  final OnlineAccount account;
  final ShopRepository shop;

  const ShopScreen({super.key, required this.account, required this.shop});

  /// Il padrone della bottega: baffi a tricheco, pince-nez e catena d'orologio.
  static final AvatarLook shopkeeper = AvatarLook(
    base: AvatarBase.of(SkinTone.olive, FaceMark.walrus),
    hat: AvatarHead.slicked,
    glasses: AvatarGlasses.pinceNez,
    outfit: AvatarOutfit.byId('grey_flannel')!,
    accessory: AvatarAccessory.pocketWatch,
  );

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final ShopController _shop = ShopController(shop: widget.shop, account: widget.account)..load();
  final _scroll = ScrollController();

  ShopTab _tab = ShopTab.window;
  ShopRarity? _rarity;
  bool _affordable = false;
  bool _cheapFirst = false;

  /// Il posto scelto negli accessori e nell'armadio, o null per tutti.
  String? _slot;

  /// La casa aperta tra le firme, o la collezione tra le stramberie.
  ShopBrand? _brand;
  ShopCollection? _collection;

  @override
  void dispose() {
    _shop.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ShopStrings get _t => AppStrings.of(context).shop;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  Future<void> _buy(ShopItem item) async {
    final t = _t;
    final language = AppStrings.of(context).language;
    if (_shop.coins < item.price) {
      _say(t.missing(item.price - _shop.coins));
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => _ReceiptDialog(item: item, coins: _shop.coins, strings: t, language: language),
    );
    if (yes != true || !mounted) return;
    await _run(() async {
      await _shop.buy(item);
      if (mounted) _say(t.bought(item.name(language)));
    });
  }

  /// Lo specchio a tutto schermo, con il pezzo addosso.
  Future<void> _tryOn(ShopItem item) async {
    _shop.preview(item);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TryOnPage(shop: _shop, onBuy: _buy, onRun: _run),
      ),
    );
    if (mounted) _shop.preview(null);
  }

  void _open(ShopTab tab) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _tab = tab;
      _slot = null;
      _brand = null;
      _collection = null;
      _rarity = null;
      _affordable = false;
    });
  }

  bool get _hasAvatarRoute {
    final navigator = Navigator.maybeOf(context);
    return navigator?.widget.onGenerateRoute?.call(const RouteSettings(name: avatarRoute)) != null;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: const Color(0xFF120E0B),
      body: ListenableBuilder(
        listenable: _shop,
        builder: (context, _) => SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(t),
              _tabs(t),
              Expanded(child: _body(t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ShopStrings t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
    child: Row(
      children: [
        IconButton(
          key: const Key('shop.back'),
          onPressed: pressed(() => Navigator.of(context).maybePop()),
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.gold, size: 20),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.title, style: AppText.display(22)),
              Text(
                t.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        CoinBalance(coins: _shop.coins, hint: t.coinsHint),
      ],
    ),
  );

  /// Le insegne dei reparti, appese in fila: si scorrono di lato.
  Widget _tabs(ShopStrings t) => SizedBox(
    height: 50,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          for (final tab in ShopTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                key: Key('shop.tab.${tab.name}'),
                onTap: pressed(() => _open(tab), Press.toggle),
                child: _ShelfSign(
                  label: t.tab(tab),
                  on: _tab == tab,
                  gilded: tab == ShopTab.brands || tab == ShopTab.oddities || tab == ShopTab.window,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _body(ShopStrings t) {
    if (_shop.loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    if (_shop.error case final error?) {
      return Center(
        child: TextButton(
          onPressed: _shop.load,
          child: Text(
            '${AppStrings.of(context).online.failure(error is OnlineException ? error.failure : OnlineFailure.unknown)} ↻',
          ),
        ),
      );
    }
    final language = AppStrings.of(context).language;
    final slivers = <Widget>[];
    switch (_tab) {
      case ShopTab.window:
        slivers.add(SliverToBoxAdapter(child: _greeting(t)));
        final now = DateTime.now();
        slivers.add(
          _grid(t, language, [
            for (final (item, feature) in _shop.window)
              (item, t.endsIn(max(1, feature.endsAt.difference(now).inHours ~/ 24 + 1))),
          ]),
        );
      case ShopTab.brands when _brand == null:
        slivers.add(
          SliverList.list(
            children: [
              for (final brand in ShopBrand.values)
                if (_shop.branded(brand, wardrobe: false) case final items when items.isNotEmpty)
                  _CollectionCard(
                    key: Key('shop.brand.${brand.name}'),
                    title: brand.label,
                    tagline: t.brandTagline(brand),
                    count: t.pieces(items.length),
                    color: brand.color,
                    brand: brand,
                    look: _shop.tryOn(items.first),
                    onTap: () => setState(() => _brand = brand),
                  ),
            ],
          ),
        );
      case ShopTab.oddities when _collection == null:
        slivers.add(
          SliverList.list(
            children: [
              for (final collection in ShopCollection.values)
                if (_collected(collection) case final items when items.isNotEmpty)
                  _CollectionCard(
                    key: Key('shop.collection.${collection.name}'),
                    title: language == AppLanguage.en ? collection.en : collection.it,
                    tagline: [for (final item in items.take(3)) item.name(language)].join(' · '),
                    count: t.pieces(items.length),
                    color: _collectionColor(collection),
                    look: _shop.tryOn(items.first),
                    onTap: () => setState(() => _collection = collection),
                  ),
            ],
          ),
        );
      default:
        if (_tab == ShopTab.brands || _tab == ShopTab.oddities) {
          slivers.add(SliverToBoxAdapter(child: _openedHeader(t, language)));
        }
        if (_tab == ShopTab.wardrobe && _hasAvatarRoute) {
          slivers.add(SliverToBoxAdapter(child: _changeFace(t)));
        }
        // TODO(avatar): quando c'è la rotta [avatarRoute], la scheda «Cambia
        // faccia» compare da sola in cima all'armadio.
        slivers.add(SliverToBoxAdapter(child: _filters(t)));
        slivers.add(_grid(t, language, [for (final item in _filtered()) (item, null)]));
    }
    return CustomPaint(
      painter: const _ShelfWallPainter(),
      child: CustomScrollView(
        key: const Key('shop.grid'),
        controller: _scroll,
        slivers: [
          ...slivers,
          SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }

  List<ShopItem> _collected(ShopCollection collection) => [
    for (final item in _shop.oddities(wardrobe: false))
      if (item.collection == collection) item,
  ];

  static Color _collectionColor(ShopCollection collection) => switch (collection) {
    ShopCollection.circo => const Color(0xFFD9483B),
    ShopCollection.carnevale => const Color(0xFF3FB59E),
    ShopCollection.assurdo => const Color(0xFFE7C33A),
  };

  /// I pezzi del reparto aperto, filtrati e messi in ordine.
  List<ShopItem> _filtered() {
    final wardrobe = _tab == ShopTab.wardrobe;
    final items = switch (_tab) {
      ShopTab.tailoring => _shop.forSale('outfit'),
      ShopTab.hats => _shop.forSale('hat'),
      ShopTab.accessories => [for (final slot in _accessorySlots) ..._shop.forSale(slot)],
      ShopTab.brands => _shop.branded(_brand, wardrobe: false),
      ShopTab.oddities => _collected(_collection!),
      ShopTab.wardrobe => [for (final slot in _allSlots) ..._shop.wardrobe(slot)],
      ShopTab.window => const <ShopItem>[],
    };
    final picked = [
      for (final item in items)
        if ((_slot == null || item.slot == _slot) &&
            (_rarity == null || item.rarity == _rarity) &&
            (wardrobe || !_affordable || item.price <= _shop.coins))
          item,
    ];
    if (wardrobe) return picked;
    picked.sort(
      (a, b) => a.price != b.price
          ? (_cheapFirst ? a.price.compareTo(b.price) : b.price.compareTo(a.price))
          : a.sort.compareTo(b.sort),
    );
    return picked;
  }

  /// Il padrone, sopra la vetrina, con il suo benvenuto.
  Widget _greeting(ShopStrings t) => SizedBox(
    height: 112,
    child: ClipRect(
      child: CustomPaint(
        painter: const _BackRoomPainter(),
        child: Row(
          children: [
            const SizedBox(width: 8),
            SizedBox.square(dimension: 96, child: CustomPaint(painter: _BustPainter(ShopScreen.shopkeeper))),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _SpeechCard(text: t.greeting, caption: t.featured, color: AppColors.gold),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// In cima a una casa o a una collezione aperta: si torna alle insegne.
  Widget _openedHeader(ShopStrings t, AppLanguage language) {
    final brand = _brand;
    final collection = _collection;
    final title = brand?.label ?? (language == AppLanguage.en ? collection!.en : collection!.it);
    final color = brand?.color ?? _collectionColor(collection!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 0),
      child: Row(
        children: [
          TextButton.icon(
            key: const Key('shop.opened.back'),
            onPressed: pressed(() => setState(() => _brand = _collection = null), Press.toggle),
            icon: const Icon(Icons.chevron_left, color: AppColors.gold),
            label: Text(
              t.back,
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          if (brand != null) ...[
            SizedBox.square(dimension: 26, child: CustomPaint(painter: BrandMarkPainter(brand, seal: true))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _changeFace(ShopStrings t) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: GestureDetector(
      key: const Key('shop.changeFace'),
      onTap: pressed(() => Navigator.of(context).pushNamed(avatarRoute)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF241812),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gold, width: 1.4),
        ),
        child: Row(
          children: [
            SizedBox.square(dimension: 52, child: CustomPaint(painter: AvatarBustPainter(_shop.look))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.changeFace.toUpperCase(), style: AppText.display(15)),
                  Text(t.changeFaceHint, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold),
          ],
        ),
      ),
    ),
  );

  /// I filtri: la classe, il portafoglio, l'ordine; e il posto, dove serve.
  Widget _filters(ShopStrings t) {
    final wardrobe = _tab == ShopTab.wardrobe;
    final slots = switch (_tab) {
      ShopTab.accessories => _accessorySlots,
      ShopTab.wardrobe => _allSlots,
      _ => const <String>[],
    };
    Widget row(List<Widget> chips) => SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Row(
          children: [for (final chip in chips) Padding(padding: const EdgeInsets.only(right: 6), child: chip)],
        ),
      ),
    );
    return Column(
      children: [
        if (slots.isNotEmpty)
          row([
            _Chip(
              key: const Key('shop.slot.all'),
              label: t.allSlots,
              on: _slot == null,
              onTap: () => setState(() => _slot = null),
            ),
            for (final slot in slots)
              _Chip(
                key: Key('shop.slot.$slot'),
                label: t.slot(slot),
                on: _slot == slot,
                onTap: () => setState(() => _slot = slot),
              ),
          ]),
        row([
          _Chip(
            key: const Key('shop.rarity.all'),
            label: t.allRarities,
            on: _rarity == null,
            onTap: () => setState(() => _rarity = null),
          ),
          for (final rarity in ShopRarity.values)
            if (wardrobe || rarity != ShopRarity.base)
              _Chip(
                key: Key('shop.rarity.${rarity.name}'),
                label: t.rarity(rarity),
                color: rarityColor(rarity),
                on: _rarity == rarity,
                onTap: () => setState(() => _rarity = _rarity == rarity ? null : rarity),
              ),
          if (!wardrobe) ...[
            _Chip(
              key: const Key('shop.affordable'),
              label: t.affordable,
              coin: true,
              on: _affordable,
              onTap: () => setState(() => _affordable = !_affordable),
            ),
            _Chip(
              key: const Key('shop.sort'),
              label: _cheapFirst ? t.cheapFirst : t.dearFirst,
              on: true,
              onTap: () => setState(() => _cheapFirst = !_cheapFirst),
            ),
          ],
        ]),
      ],
    );
  }

  /// I pezzi grandi, due per fila; [ends] è il cartellino della vetrina.
  Widget _grid(ShopStrings t, AppLanguage language, List<(ShopItem, String?)> items) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            _tab == ShopTab.wardrobe ? t.emptyWardrobe : t.emptyShelf,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final (item, ends) = items[i];
          return _ItemCard(
            key: Key('shop.item.${item.id}'),
            item: item,
            look: _shop.tryOn(item),
            name: item.name(language),
            state: _shop.stateOf(item),
            strings: t,
            ends: ends,
            onTap: () => _tryOn(item),
          );
        },
      ),
    );
  }
}

/// La prova a tutto schermo: il retrobottega, lo specchio grande con il
/// pezzo addosso, il padrone che dice la sua e, sul bancone, il bottone.
class _TryOnPage extends StatelessWidget {
  final ShopController shop;
  final Future<void> Function(ShopItem item) onBuy;
  final Future<void> Function(Future<void> Function() action) onRun;

  const _TryOnPage({required this.shop, required this.onBuy, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).shop;
    final language = AppStrings.of(context).language;
    return Scaffold(
      backgroundColor: const Color(0xFF120E0B),
      body: ListenableBuilder(
        listenable: shop,
        builder: (context, _) {
          final item = shop.trying;
          if (item == null) return const SizedBox.shrink();
          final color = rarityColor(item.rarity);
          return Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: const _BackRoomPainter(),
                  child: SafeArea(
                    bottom: false,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final mirrorW = min(box.maxWidth * 0.66, (box.maxHeight - 80) / 1.3);
                        final mirrorH = mirrorW * 1.3;
                        return Stack(
                          children: [
                            Positioned(
                              left: 4,
                              top: 4,
                              child: IconButton(
                                key: const Key('shop.tryOn.back'),
                                onPressed: pressed(() => Navigator.of(context).maybePop()),
                                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.gold, size: 22),
                              ),
                            ),
                            Positioned(
                              right: 14,
                              top: 12,
                              child: CoinBalance(coins: shop.coins, hint: t.coinsHint),
                            ),
                            Positioned(
                              left: (box.maxWidth - mirrorW) / 2 - box.maxWidth * 0.08,
                              top: max(56.0, (box.maxHeight - mirrorH) / 2 + 16),
                              height: mirrorH,
                              width: mirrorW,
                              child: _Mirror(look: shop.mirror, brand: item.brand),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              width: box.maxWidth * 0.36,
                              height: box.maxWidth * 0.36,
                              child: CustomPaint(painter: _BustPainter(ShopScreen.shopkeeper)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              CustomPaint(
                painter: const _CounterPainter(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SpeechCard(
                        text: '${item.name(language)} · ${t.rarity(item.rarity)}',
                        caption: [t.tryingOn, ?item.brand?.label].join(' · '),
                        color: color,
                        big: true,
                      ),
                      const SizedBox(height: 14),
                      _action(t, item),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _action(ShopStrings t, ShopItem item) {
    final (label, action, price) = switch (shop.stateOf(item)) {
      ItemState.forSale => (t.buy, () => onBuy(item), item.price),
      ItemState.owned => (t.wear, () => onRun(() => shop.equip(item)), null),
      ItemState.worn =>
        item.free ? (t.worn, null, null) : (t.takeOff, () => onRun(() => shop.unequip(item.slot)), null),
    };
    return _BrassButton(
      key: const Key('shop.action'),
      label: label,
      price: price,
      big: true,
      onTap: shop.busy || action == null ? null : action,
    );
  }
}

/// Un filtro: un cartellino tondo, acceso quando scelto.
class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final Color? color;
  final bool coin;
  final VoidCallback onTap;

  const _Chip({super.key, required this.label, required this.on, required this.onTap, this.color, this.coin = false});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.gold;
    return GestureDetector(
      onTap: pressed(onTap, Press.toggle),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.22) : const Color(0xFF1B1410),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? tint : tint.withValues(alpha: 0.35), width: on ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            if (coin) ...[
              const SizedBox.square(dimension: 13, child: CustomPaint(painter: CoinPainter())),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: on ? _cream : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'insegna grande di una casa o di una collezione: il marchio, il nome,
/// quanti pezzi, e il più bello addosso a un busto.
class _CollectionCard extends StatelessWidget {
  final String title;
  final String tagline;
  final String count;
  final Color color;
  final ShopBrand? brand;
  final AvatarLook look;
  final VoidCallback onTap;

  const _CollectionCard({
    super.key,
    required this.title,
    required this.tagline,
    required this.count,
    required this.color,
    required this.look,
    required this.onTap,
    this.brand,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
    child: GestureDetector(
      onTap: pressed(onTap, Press.toggle),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.30), const Color(0xFF17110D)]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.85), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            if (brand case final brand?) ...[
              SizedBox.square(dimension: 54, child: CustomPaint(painter: BrandMarkPainter(brand, seal: true))),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const ['serif'],
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _cream, fontSize: 12.5, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    count.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 100, height: 110, child: CustomPaint(painter: AvatarBustPainter(look))),
            Icon(Icons.chevron_right, color: color),
            const SizedBox(width: 6),
          ],
        ),
      ),
    ),
  );
}

/// Un pezzo sullo scaffale: grande, con la fascia della classe in alto, il
/// busto che lo porta, il nome e il prezzo (o se è già tuo, o addosso).
class _ItemCard extends StatelessWidget {
  final ShopItem item;
  final AvatarLook look;
  final String name;
  final ItemState state;
  final ShopStrings strings;
  final String? ends;
  final VoidCallback onTap;

  const _ItemCard({
    super.key,
    required this.item,
    required this.look,
    required this.name,
    required this.state,
    required this.strings,
    required this.onTap,
    this.ends,
  });

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(item.rarity);
    final worn = state == ItemState.worn;
    return GestureDetector(
      onTap: pressed(onTap, Press.toggle),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF241812),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: worn ? AppColors.gold : color.withValues(alpha: 0.7), width: worn ? 2.2 : 1.4),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 5, offset: Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // La fascia della classe.
            Container(
              height: 24,
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.rarity(item.rarity).toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF1A120C),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  if (state != ItemState.forSale)
                    _Badge(label: worn ? strings.worn : (item.free ? strings.free : strings.owned), worn: worn),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.1),
                          radius: 0.8,
                          colors: [color.withValues(alpha: 0.22), const Color(0xFF241812)],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: CustomPaint(painter: AvatarBustPainter(look), child: const SizedBox.expand()),
                    ),
                  ),
                  if (item.brand case final brand?)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: SizedBox.square(
                        dimension: 24,
                        child: CustomPaint(painter: BrandMarkPainter(brand, seal: true)),
                      ),
                    ),
                ],
              ),
            ),
            // La mensola su cui posa il pezzo.
            Container(height: 5, color: _wood),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.brand case final brand?) _BrandLabel(brand: brand, size: 9.5),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _cream, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (state == ItemState.forSale) ...[
                        const SizedBox.square(dimension: 16, child: CustomPaint(painter: CoinPainter())),
                        const SizedBox(width: 5),
                        Text(
                          '${item.price}',
                          style: const TextStyle(color: _cream, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ] else
                        Text(
                          strings.slot(item.slot),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      if (ends case final ends?) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ends,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Tuo» o «Indossato», cucito sulla fascia.
class _Badge extends StatelessWidget {
  final String label;
  final bool worn;

  const _Badge({required this.label, required this.worn});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: worn ? const Color(0xFF1A120C) : const Color(0x33000000),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0xFF1A120C)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: worn ? AppColors.gold : const Color(0xFF1A120C),
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class CoinBalance extends StatelessWidget {
  final int coins;
  final String hint;

  const CoinBalance({super.key, required this.coins, required this.hint});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: hint,
    triggerMode: TooltipTriggerMode.tap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1916),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.85), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(1, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 16, child: CustomPaint(painter: CoinPainter())),
          const SizedBox(width: 6),
          Text(
            '$coins',
            key: const Key('shop.coins'),
            style: const TextStyle(color: _cream, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
        ],
      ),
    ),
  );
}

class _BustPainter extends CustomPainter {
  final AvatarLook look;

  _BustPainter(this.look);

  @override
  void paint(Canvas canvas, Size size) => LookPainter.bust(canvas, look, size.shortestSide);

  @override
  bool shouldRepaint(_BustPainter old) => old.look != look;
}

/// Lo specchio ovale con la cornice dorata: dentro, chi si prova il pezzo.
class _Mirror extends StatelessWidget {
  final AvatarLook look;

  /// La casa del pezzo in prova: la sua targa d'ottone sotto lo specchio.
  final ShopBrand? brand;

  const _Mirror({required this.look, this.brand});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(child: _glass()),
      if (brand case final brand?)
        Positioned(
          left: 0,
          right: 0,
          bottom: -6,
          child: Center(
            child: Container(
              key: const Key('shop.mirror.brand'),
              padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2A1A0E), Color(0xFF1A100A)]),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: brand.color, width: 1.2),
                boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(dimension: 14, child: CustomPaint(painter: BrandMarkPainter(brand))),
                  const SizedBox(width: 4),
                  Text(
                    brand.label.toUpperCase(),
                    style: TextStyle(
                      color: brand.color,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _glass() => CustomPaint(
    painter: _MirrorFramePainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: ClipOval(
        child: CustomPaint(
          painter: _GlassPainter(),
          foregroundPainter: _GlintPainter(),
          child: Align(
            alignment: const Alignment(0, 0.6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: SizedBox.square(
                key: ValueKey(look),
                dimension: 128,
                child: CustomPaint(painter: _BustPainter(look)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MirrorFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final oval = rect.deflate(4);
    canvas.drawOval(
      oval.shift(const Offset(3, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawOval(
      oval,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF8C6A14),
            Color(0xFFFFE29A),
            Color(0xFFC9A227),
            Color(0xFF6B4E0E),
            Color(0xFFE9C766),
            Color(0xFF8C6A14),
          ],
        ).createShader(oval),
    );
    canvas.drawOval(oval.deflate(6), Paint()..color = const Color(0xFF3A2A0C));
    canvas.drawOval(
      oval.deflate(8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFE9A0).withValues(alpha: 0.6),
    );
    // Il ricciolo in cima alla cornice.
    final top = Offset(size.width / 2, 4);
    final curl = Paint()..color = const Color(0xFFD9B54E);
    canvas.drawCircle(top, 7, curl);
    canvas.drawCircle(top.translate(-11, 4), 4, curl);
    canvas.drawCircle(top.translate(11, 4), 4, curl);
  }

  @override
  bool shouldRepaint(_MirrorFramePainter old) => false;
}

class _GlassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.3),
          radius: 0.9,
          colors: [Color(0xFF5B6A6E), Color(0xFF2B3335), Color(0xFF131718)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) => false;
}

class _GlintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.18, size.height * 0.34), Offset(size.width * 0.42, size.height * 0.1), glint);
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.16),
      glint..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_GlintPainter old) => false;
}

/// La carta da parati verde a righe damascate, la boiserie, la lampada e
/// gli attaccapanni con i cappelli.
class _BackRoomPainter extends CustomPainter {
  const _BackRoomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF17241D));
    final stripe = Paint()..color = const Color(0xFF1D2E25);
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 12, size.height), stripe);
    }
    final fleur = Paint()..color = const Color(0xFFC9A227).withValues(alpha: 0.08);
    for (var x = 20.0; x < size.width; x += 56) {
      for (var y = 18.0; y < size.height - 70; y += 44) {
        canvas.drawCircle(Offset(x, y), 3, fleur);
        canvas.drawCircle(Offset(x - 4, y + 5), 2, fleur);
        canvas.drawCircle(Offset(x + 4, y + 5), 2, fleur);
      }
    }
    // La boiserie sotto.
    final wainscot = Rect.fromLTWH(0, size.height - 96, size.width, 96);
    canvas.drawRect(wainscot, Paint()..color = const Color(0xFF2A1A10));
    canvas.drawLine(
      wainscot.topLeft,
      wainscot.topRight,
      Paint()
        ..color = const Color(0xFF6B4A2A)
        ..strokeWidth = 3,
    );
    // L'attaccapanni nel mezzo, con un cappello e un abito.
    final cx = size.width * 0.52;
    final pole = Paint()
      ..color = const Color(0xFF3A2414)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, 40), Offset(cx, size.height - 50), pole);
    canvas.drawLine(Offset(cx - 18, 52), Offset(cx + 18, 52), pole..strokeWidth = 3);
    final felt = Paint()..color = const Color(0xFF0E0C0E);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 18, 54), width: 30, height: 6), felt);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 18, 46), width: 18, height: 14),
        const Radius.circular(5),
      ),
      felt,
    );
    // La lampada: un alone caldo dall'alto.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.1, -1.1),
          radius: 1.1,
          colors: [const Color(0xFFFFD27A).withValues(alpha: 0.22), Colors.transparent],
        ).createShader(rect),
    );
    // I bordi nel buio.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xAA000000), Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
          stops: [0, 0.15, 0.85, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BackRoomPainter old) => false;
}

/// Il bancone di mogano, col bordo d'ottone.
class _CounterPainter extends CustomPainter {
  const _CounterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final top = Rect.fromLTWH(0, 0, size.width, 12);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A3420), Color(0xFF2C170C)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A5634), Color(0xFF4A2A18)],
        ).createShader(top),
    );
    canvas.drawLine(
      Offset(0, 12),
      Offset(size.width, 12),
      Paint()
        ..color = const Color(0xFFC9A227)
        ..strokeWidth = 1.5,
    );
    final grain = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var y = 20.0; y < size.height; y += 9) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 2), grain);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 3), Paint()..color = Colors.black.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(_CounterPainter old) => false;
}

/// La parete dietro gli scaffali: legno scuro, e una mensola ogni riga.
class _ShelfWallPainter extends CustomPainter {
  const _ShelfWallPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1A120D));
    final seam = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), seam);
    }
  }

  @override
  bool shouldRepaint(_ShelfWallPainter old) => false;
}

class _SpeechCard extends StatelessWidget {
  final String text;
  final String? caption;
  final Color? color;
  final bool big;

  const _SpeechCard({required this.text, this.caption, this.color, this.big = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF2E6CF),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color ?? const Color(0xFF8C6A14), width: color == null ? 1 : 2),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(2, 3))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (caption != null)
          Text(
            caption!.toUpperCase(),
            style: TextStyle(color: color, fontSize: big ? 11 : 9, fontWeight: FontWeight.w800, letterSpacing: 1.6),
          ),
        Text(
          text,
          key: const Key('shop.speech'),
          style: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['serif'],
            color: const Color(0xFF2A1A10),
            fontSize: big ? 17 : 12.5,
            height: 1.25,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}

class _BrassButton extends StatelessWidget {
  final String label;
  final int? price;
  final VoidCallback? onTap;
  final bool big;

  const _BrassButton({super.key, required this.label, this.price, this.onTap, this.big = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: pressed(onTap),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: big ? 15 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE29A), Color(0xFFC9A227), Color(0xFF8C6A14)],
            ),
            border: Border.all(color: const Color(0xFF5A420C)),
            boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(1, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(big ? 18 : 14, color: const Color(0xFF2A1A08)),
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: 10),
                const SizedBox.square(dimension: 14, child: CustomPaint(painter: CoinPainter())),
                const SizedBox(width: 4),
                Text(
                  '$price',
                  style: const TextStyle(color: Color(0xFF2A1A08), fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfSign extends StatelessWidget {
  final String label;
  final bool on;

  /// La targhetta delle firme: nera e oro, come un'insegna di via Montenapoleone.
  final bool gilded;

  const _ShelfSign({required this.label, required this.on, this.gilded = false});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: gilded
          ? (on ? const Color(0xFF2A2116) : const Color(0xFF14110D))
          : (on ? const Color(0xFF6B4226) : const Color(0xFF2E1D12)),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: on || gilded ? AppColors.gold : const Color(0xFF5A3A22), width: on ? 1.5 : 1),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 3, offset: Offset(0, 2))],
    ),
    child: Text(
      label.toUpperCase(),
      maxLines: 1,
      style: TextStyle(
        color: gilded ? AppColors.gold : (on ? _cream : AppColors.textSecondary),
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
      ),
    ),
  );
}

/// La ricevuta del sarto: il pezzo, il prezzo, e quante monete restano.
class _ReceiptDialog extends StatelessWidget {
  final ShopItem item;
  final int coins;
  final ShopStrings strings;
  final AppLanguage language;

  const _ReceiptDialog({required this.item, required this.coins, required this.strings, required this.language});

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(item.rarity);
    final name = item.name(language);
    return Dialog(
      backgroundColor: const Color(0xFFF2E6CF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: color, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.brand case final brand?) ...[
              SizedBox.square(dimension: 34, child: CustomPaint(painter: BrandMarkPainter(brand, seal: true))),
              const SizedBox(height: 4),
              Text(
                brand.label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['serif'],
                  color: Color(0xFF2A1A10),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.4,
                ),
              ),
              Text(
                strings.brandTagline(brand),
                style: const TextStyle(color: Color(0xFF6B4A2A), fontSize: 11, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              strings.rarity(item.rarity).toUpperCase(),
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 6),
            Text(
              strings.confirmTitle(name),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontFamilyFallback: ['serif'],
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2A1A10),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              strings.confirmBody(item.price, coins - item.price),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF4A3420), fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.notNow, style: const TextStyle(color: Color(0xFF6B4A2A))),
                ),
                _BrassButton(
                  key: const Key('shop.confirm'),
                  label: strings.confirmYes,
                  price: item.price,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Il marchio di una casa, da solo o in un sigillo tondo scuro con il
/// bordo del suo colore.
class BrandMarkPainter extends CustomPainter {
  final ShopBrand brand;
  final bool seal;

  const BrandMarkPainter(this.brand, {this.seal = false});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    if (seal) {
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF14100C));
      canvas.drawCircle(
        c,
        r - r * 0.08,
        Paint()
          ..color = brand.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1,
      );
    }
    LookPainter.brandMark(canvas, brand, c, seal ? r * 0.58 : r * 0.9);
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) => old.brand != brand || old.seal != seal;
}

/// Il nome della casa con il suo marchio, in maiuscoletto.
class _BrandLabel extends StatelessWidget {
  final ShopBrand brand;
  final double size;

  const _BrandLabel({required this.brand, required this.size});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: size + 3,
        child: CustomPaint(painter: BrandMarkPainter(brand)),
      ),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          brand.label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: brand.color, fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 1.1),
        ),
      ),
    ],
  );
}
