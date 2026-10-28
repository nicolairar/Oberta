part of 'shop_screen.dart';

/// I colori del gran lusso: oro vecchio su nero; e il rosso dello sconto.
const _luxe = Color(0xFFFFD77A);
const _saveRed = Color(0xFFC0392B);

/// I pacchetti nella bottega: lo scaffale, l'assaggio in vetrina, l'acquisto.
extension _Bundles on _ShopScreenState {
  Future<void> _buyBundle(ShopBundle bundle) async {
    final t = _t;
    final language = AppStrings.of(context).language;
    final price = _shop.bundlePrice(bundle);
    if (_shop.coins < price) {
      _say(t.missing(price - _shop.coins));
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => _deskDialog(context, _BundleReceipt(
        bundle: bundle,
        price: price,
        saved: _shop.bundleSingles(bundle) - price,
        coins: _shop.coins,
        strings: t,
        language: language,
      )),
    );
    if (yes != true || !mounted) return;
    await _run(() async {
      await _shop.buyBundle(bundle);
      if (mounted) _say(t.bundleBought(bundle.name(language)));
    });
  }

  /// Un pacchetto aperto: il look intero e, sotto, ogni pezzo col suo prezzo.
  Future<void> _openBundle(ShopBundle bundle) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _BundlePage(shop: _shop, bundle: bundle, onBuy: _buyBundle, onTryOn: _tryOn),
    ),
  );

  Widget _bundleCard(ShopStrings t, AppLanguage language, ShopBundle bundle) => _BundleCard(
    key: Key('shop.bundle.${bundle.id}'),
    bundle: bundle,
    language: language,
    strings: t,
    look: _shop.bundleLook(bundle),
    around: _shop.bundleAround(bundle),
    gestures: _shop.bundleGestures(bundle),
    who: _shop.who,
    count: _shop.bundleItems(bundle).length,
    singles: _shop.bundleSingles(bundle),
    price: _shop.bundlePrice(bundle),
    complete: _shop.bundleComplete(bundle),
    onTap: () => _openBundle(bundle),
  );

  Widget _heading(String title, {String? hint, Color color = AppColors.gold, Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 8, 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: const ['serif'],
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.2,
                ),
              ),
              if (hint != null)
                Text(
                  hint,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );

  /// Lo scaffale dei pacchetti: i completi, poi il gran lusso.
  List<Widget> _bundleShelf(ShopStrings t, AppLanguage language) {
    final all = _shop.shelfBundles;
    final sets = [
      for (final b in all)
        if (!b.premium) b,
    ];
    final luxe = [
      for (final b in all)
        if (b.premium) b,
    ];
    return [
      if (sets.isNotEmpty) ...[
        SliverToBoxAdapter(child: _heading(t.bundlesHeading, hint: t.bundlesHint)),
        SliverList.list(children: [for (final b in sets) _bundleCard(t, language, b)]),
      ],
      if (luxe.isNotEmpty) ...[
        SliverToBoxAdapter(child: _heading('★ ${t.premiumHeading}', color: _luxe)),
        SliverList.list(children: [for (final b in luxe) _bundleCard(t, language, b)]),
      ],
      if (all.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              t.emptyShelf,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ),
        ),
    ];
  }

  /// In vetrina, sotto il padrone: il completo che conviene di più e uno di lusso.
  List<Widget> _bundleTeaser(ShopStrings t, AppLanguage language) {
    final open = [
      for (final b in _shop.shelfBundles)
        if (!_shop.bundleComplete(b)) b,
    ];
    if (open.isEmpty) return const [];
    ShopBundle? pick(bool premium) {
      final pool = [
        for (final b in open)
          if (b.premium == premium) b,
      ];
      if (pool.isEmpty) return null;
      pool.sort((a, b) => b.discountPct.compareTo(a.discountPct));
      return pool.first;
    }

    final picks = [?pick(false), ?pick(true)];
    return [
      SliverToBoxAdapter(
        child: _heading(
          t.bundlesHeading,
          hint: t.bundlesHint,
          trailing: TextButton(
            key: const Key('shop.bundles.all'),
            onPressed: pressed(() => _open(ShopTab.bundles), Press.toggle),
            child: Text(
              '${t.seeAll} ›',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
      ),
      SliverList.list(children: [for (final b in picks) _bundleCard(t, language, b)]),
      const SliverToBoxAdapter(child: SizedBox(height: 6)),
    ];
  }
}

/// Il prezzo barrato: quanto costerebbe pezzo per pezzo.
class _Struck extends StatelessWidget {
  final int coins;
  final double size;

  const _Struck(this.coins, {this.size = 13});

  @override
  Widget build(BuildContext context) => Text(
    '$coins',
    style: TextStyle(
      color: AppColors.textSecondary,
      fontSize: size,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.lineThrough,
      decorationColor: _saveRed,
      decorationThickness: 2.2,
    ),
  );
}

/// Il prezzo con la moneta.
class _Price extends StatelessWidget {
  final int coins;
  final double size;
  final Color color;

  const _Price(this.coins, {this.size = 18, this.color = _cream});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: CoinPainter()),
      ),
      const SizedBox(width: 5),
      Text(
        '$coins',
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: size),
      ),
    ],
  );
}

/// Il cartellino rosso dello sconto.
class _SaveTag extends StatelessWidget {
  final String label;
  final double size;

  const _SaveTag(this.label, {this.size = 11});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size * 0.7, vertical: size * 0.3),
    decoration: BoxDecoration(
      color: _saveRed,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0xFFF5C9A8)),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 3, offset: Offset(1, 2))],
    ),
    child: Text(
      label,
      style: TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 1.2),
    ),
  );
}

/// Un pacchetto sullo scaffale: il busto con tutto addosso, il nome, quanti
/// pezzi, il prezzo pezzo per pezzo barrato e quello del pacchetto.
class _BundleCard extends StatelessWidget {
  final ShopBundle bundle;
  final AppLanguage language;
  final ShopStrings strings;
  final AvatarLook look;

  /// Cornici e nomi: si mostra il posto del tavolo, non il busto.
  final bool around;

  /// I gesti: si mostrano loro, non il busto.
  final List<TableGesture> gestures;
  final String who;
  final int count;
  final int singles;
  final int price;
  final bool complete;
  final VoidCallback onTap;

  const _BundleCard({
    super.key,
    required this.bundle,
    required this.language,
    required this.strings,
    required this.look,
    this.around = false,
    this.gestures = const [],
    this.who = '',
    required this.count,
    required this.singles,
    required this.price,
    required this.complete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final luxe = bundle.premium;
    final edge = luxe ? _luxe : AppColors.gold.withValues(alpha: 0.75);
    final t = strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: GestureDetector(
        onTap: pressed(onTap, Press.toggle),
        child: Container(
          height: luxe ? 160 : 142,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: luxe
                  ? const [Color(0xFF3A2A10), Color(0xFF120D08), Color(0xFF2A1E0C)]
                  : const [Color(0xFF2C1C12), Color(0xFF17110D)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: edge, width: luxe ? 2 : 1.4),
            boxShadow: [
              const BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 3)),
              if (luxe) BoxShadow(color: _luxe.withValues(alpha: 0.18), blurRadius: 14),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: luxe ? 132 : 116,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 0.75,
                            colors: [edge.withValues(alpha: 0.28), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: 8,
                      child: gestures.isNotEmpty
                          ? Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 8), child: GestureShowcase(gestures: gestures))
                          : around
                          ? Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 8), child: SeatPreview(look: look, name: who))
                          : CustomPaint(painter: AvatarBustPainter(look)),
                    ),
                  ],
                ),
              ),
              Container(width: 1, color: edge.withValues(alpha: 0.4)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  if (luxe)
                                    TextSpan(
                                      text: '★ ${t.premium}   ',
                                      style: const TextStyle(color: _luxe),
                                    ),
                                  TextSpan(text: t.pieces(count).toUpperCase()),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (complete)
                            _Badge(label: t.complete, worn: true)
                          else
                            _SaveTag(t.save(bundle.discountPct), size: 10),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bundle.name(language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontFamilyFallback: const ['serif'],
                          color: luxe ? _luxe : _cream,
                          fontSize: luxe ? 20 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          bundle.tagline(language),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: complete
                                  ? Text(
                                      t.owned,
                                      style: const TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _Struck(singles),
                                        const SizedBox(width: 8),
                                        _Price(price, size: luxe ? 20 : 18, color: luxe ? _luxe : _cream),
                                      ],
                                    ),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: edge),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il pacchetto aperto: in alto lo specchio col look intero, poi ogni pezzo
/// col suo prezzo da solo (o «tuo»), e sul bancone il prezzo del pacchetto.
class _BundlePage extends StatelessWidget {
  final ShopController shop;
  final ShopBundle bundle;
  final Future<void> Function(ShopBundle bundle) onBuy;
  final Future<void> Function(ShopItem item) onTryOn;

  const _BundlePage({required this.shop, required this.bundle, required this.onBuy, required this.onTryOn});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).shop;
    final language = AppStrings.of(context).language;
    final luxe = bundle.premium;
    final accent = luxe ? _luxe : AppColors.gold;
    return Scaffold(
      backgroundColor: const Color(0xFF120E0B),
      body: ListenableBuilder(
        listenable: shop,
        builder: (context, _) {
          final items = shop.bundleItems(bundle);
          final complete = shop.bundleComplete(bundle);
          final price = shop.bundlePrice(bundle);
          final singles = shop.bundleSingles(bundle);
          final ownedCount = items.where((item) => !item.free && shop.owned.contains(item.id)).length;
          return Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: const _ShelfWallPainter(),
                  child: CustomScrollView(
                    key: const Key('shop.bundle.list'),
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 256 + MediaQuery.paddingOf(context).top,
                          child: CustomPaint(
                            painter: const _BackRoomPainter(),
                            child: SafeArea(
                              bottom: false,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 4,
                                    top: 4,
                                    child: IconButton(
                                      key: const Key('shop.bundle.back'),
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
                                    left: 18,
                                    top: 54,
                                    width: 150,
                                    height: 190,
                                    child: shop.bundleGestures(bundle).isNotEmpty
                                        ? GestureShowcase(gestures: shop.bundleGestures(bundle))
                                        : shop.bundleAround(bundle)
                                        ? Padding(
                                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                                            child: SeatPreview(look: shop.bundleLook(bundle), name: shop.who),
                                          )
                                        : _Mirror(look: shop.bundleLook(bundle)),
                                  ),
                                  Positioned(
                                    left: 184,
                                    right: 14,
                                    top: 64,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (luxe)
                                          Text(
                                            '★ ${t.premium}',
                                            style: const TextStyle(
                                              color: _luxe,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.8,
                                            ),
                                          ),
                                        Text(
                                          bundle.name(language),
                                          style: TextStyle(
                                            fontFamily: 'Georgia',
                                            fontFamilyFallback: const ['serif'],
                                            color: accent,
                                            fontSize: 24,
                                            height: 1.1,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          bundle.tagline(language),
                                          style: const TextStyle(
                                            color: _cream,
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (!complete) _SaveTag(t.save(bundle.discountPct), size: 12),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Text(
                            '${t.bundleContents} · ${t.pieces(items.length).toUpperCase()}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      ),
                      SliverList.list(
                        children: [
                          for (final item in items)
                            _BundleRow(
                              key: Key('shop.bundle.item.${item.id}'),
                              item: item,
                              look: shop.tryOn(item),
                              who: shop.who,
                              name: item.name(language),
                              state: shop.stateOf(item),
                              strings: t,
                              onTap: () => onTryOn(item),
                            ),
                        ],
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
              ),
              CustomPaint(
                painter: const _CounterPainter(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 22, 18, 14 + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ownedCount > 0 && !complete)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            t.ownedPart(ownedCount, items.length),
                            key: const Key('shop.bundle.ownedPart'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _cream, fontSize: 12.5, fontStyle: FontStyle.italic),
                          ),
                        ),
                      if (!complete)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${t.singlesLabel}: ', style: const TextStyle(color: _cream, fontSize: 13)),
                                _Struck(singles, size: 15),
                                const SizedBox(width: 12),
                                _SaveTag(t.save(bundle.discountPct), size: 11),
                              ],
                            ),
                          ),
                        ),
                      _BrassButton(
                        key: const Key('shop.bundle.buy'),
                        label: complete ? t.complete : t.buyBundle,
                        price: complete ? null : price,
                        big: true,
                        onTap: shop.busy || complete ? null : () => onBuy(bundle),
                      ),
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
}

/// Una riga del pacchetto: il pezzo addosso, il nome, la classe e il prezzo da solo.
class _BundleRow extends StatelessWidget {
  final ShopItem item;
  final AvatarLook look;
  final String who;
  final String name;
  final ItemState state;
  final ShopStrings strings;
  final VoidCallback onTap;

  const _BundleRow({
    super.key,
    required this.item,
    required this.look,
    this.who = '',
    required this.name,
    required this.state,
    required this.strings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(item.rarity);
    final mine = state != ItemState.forSale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GestureDetector(
        onTap: pressed(onTap, Press.toggle),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF241812),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: mine ? AppColors.gold : color.withValues(alpha: 0.55), width: mine ? 1.6 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(width: 5, color: color),
              Container(
                width: 64,
                decoration: BoxDecoration(
                  gradient: RadialGradient(radius: 0.7, colors: [color.withValues(alpha: 0.25), Colors.transparent]),
                ),
                padding: const EdgeInsets.only(top: 6),
                child: item.isGesture
                    ? Padding(padding: const EdgeInsets.all(6), child: GestureShowcase(gestures: [ShopController.gestureOf(item)!]))
                    : item.around
                    ? Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 4), child: SeatPreview(look: look, name: who))
                    : CustomPaint(painter: AvatarBustPainter(look), child: const SizedBox.expand()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _cream, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${strings.rarity(item.rarity)} · ${strings.slot(item.slot)}',
                      style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: mine
                    ? _Badge(label: state == ItemState.worn ? strings.worn : strings.owned, worn: true)
                    : _Price(item.price, size: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La ricevuta del pacchetto.
class _BundleReceipt extends StatelessWidget {
  final ShopBundle bundle;
  final int price;
  final int saved;
  final int coins;
  final ShopStrings strings;
  final AppLanguage language;

  const _BundleReceipt({
    required this.bundle,
    required this.price,
    required this.saved,
    required this.coins,
    required this.strings,
    required this.language,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: _cream,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: BorderSide(color: bundle.premium ? const Color(0xFFB8860B) : const Color(0xFF8C6A14), width: 2),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SaveTag(strings.save(bundle.discountPct)),
          const SizedBox(height: 8),
          Text(
            strings.bundleConfirmTitle(bundle.name(language)),
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
            strings.bundleConfirmBody(price, saved, coins - price),
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
                price: price,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
