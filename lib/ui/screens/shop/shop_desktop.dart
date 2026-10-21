part of 'shop_screen.dart';

/// La larghezza del bancone con lo specchio, a destra, sulla tela a 1080p.
const double _deskCounterWidth = 620;

/// Sul PC le ricevute del sarto si leggono come i pannelli: un po' più grandi.
Widget _deskDialog(BuildContext context, Widget dialog) =>
    DesktopCanvas.of(context) ? Transform.scale(scale: 1.45, child: dialog) : dialog;

/// La bottega sul PC: in alto le insegne dei reparti, a sinistra gli
/// scaffali coi pezzi (si passa col mouse, si clicca per provare), a destra
/// il bancone fisso con lo specchio grande, il padrone e il bottone.
extension _Desk on _ShopScreenState {
  /// Prova un pezzo nello specchio del bancone, senza cambiare pagina.
  void _deskTry(ShopItem item) {
    _update(() => _bundle = null);
    _shop.preview(item);
  }

  /// Mette un pacchetto intero nello specchio del bancone.
  void _deskBundle(ShopBundle bundle) {
    _update(() => _bundle = bundle);
    _shop.preview(null);
  }

  Widget _desktop(ShopStrings t) => DeskTheme(
    child: DeskEscape(
      onEscape: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0B09),
        body: ListenableBuilder(
          listenable: _shop,
          builder: (context, _) => CustomPaint(
            painter: const _DeskWallPainter(),
            child: Column(
              children: [
                DeskTopBar(
                  title: t.title,
                  actions: [
                    Text(t.subtitle, style: DeskText.text(color: AppColors.textSecondary).copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(width: 32),
                    _DeskCoins(coins: _shop.coins, hint: t.coinsHint),
                  ],
                ),
                _deskTabs(t),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(DeskSize.gutter, 24, DeskSize.gutter, 40),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _deskShelf(t)),
                        const SizedBox(width: 32),
                        SizedBox(width: _deskCounterWidth, child: _deskCounter(t)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Le insegne dei reparti, tutte in fila sotto la barra.
  Widget _deskTabs(ShopStrings t) => Container(
    height: 68,
    width: double.infinity,
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: AppColors.gold.withValues(alpha: 0.18)),
        bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.18)),
      ),
      color: const Color(0x66000000),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: DeskSize.gutter),
      child: Row(
        children: [
          for (final tab in ShopTab.values)
            _DeskTab(
              key: Key('shop.tab.${tab.name}'),
              label: t.tab(tab),
              on: _tab == tab,
              onTap: pressed(() => _open(tab), Press.toggle)!,
            ),
        ],
      ),
    ),
  );

  // ---------------------------------------------------------------------
  // Gli scaffali, a sinistra.

  Widget _deskShelf(ShopStrings t) {
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
        final teaser = _deskTeaser(t, language);
        if (teaser.isNotEmpty) {
          slivers.add(_deskHeading(t.bundlesHeading, hint: t.bundlesHint, trailing: _DeskLink(
            key: const Key('shop.bundles.all'),
            label: '${t.seeAll} ›',
            onTap: () => _open(ShopTab.bundles),
          )));
          slivers.add(_deskBundles(t, language, teaser));
        }
        slivers.add(_deskHeading(t.featured));
        final now = DateTime.now();
        slivers.add(_deskGrid(t, language, [
          for (final (item, feature) in _shop.window)
            (item, t.endsIn(max(1, feature.endsAt.difference(now).inHours ~/ 24 + 1))),
        ]));
      case ShopTab.bundles:
        final all = _shop.shelfBundles;
        final sets = [for (final b in all) if (!b.premium) b];
        final luxe = [for (final b in all) if (b.premium) b];
        if (sets.isNotEmpty) {
          slivers.add(_deskHeading(t.bundlesHeading, hint: t.bundlesHint));
          slivers.add(_deskBundles(t, language, sets));
        }
        if (luxe.isNotEmpty) {
          slivers.add(_deskHeading('★ ${t.premiumHeading}', color: _luxe));
          slivers.add(_deskBundles(t, language, luxe));
        }
        if (all.isEmpty) slivers.add(_deskEmpty(t.emptyShelf));
      case ShopTab.brands when _brand == null:
        slivers.add(_deskHeading(t.tab(ShopTab.brands).toUpperCase()));
        slivers.add(_deskCards([
          for (final brand in ShopBrand.values)
            if (_shop.branded(brand, wardrobe: false) case final items when items.isNotEmpty)
              _DeskCollectionCard(
                key: Key('shop.brand.${brand.name}'),
                title: brand.label,
                tagline: t.brandTagline(brand),
                count: t.pieces(items.length),
                color: brand.color,
                brand: brand,
                look: _shop.tryOn(items.first),
                onTap: () => _update(() => _brand = brand),
              ),
        ]));
      case ShopTab.oddities when _collection == null:
        slivers.add(_deskHeading(t.tab(ShopTab.oddities).toUpperCase()));
        slivers.add(_deskCards([
          for (final collection in ShopCollection.values)
            if (_collected(collection) case final items when items.isNotEmpty && collection != ShopCollection.calcio)
              _DeskCollectionCard(
                key: Key('shop.collection.${collection.name}'),
                title: language == AppLanguage.en ? collection.en : collection.it,
                tagline: [for (final item in items.take(3)) item.name(language)].join(' · '),
                count: t.pieces(items.length),
                color: _ShopScreenState._collectionColor(collection),
                look: _shop.tryOn(items.first),
                onTap: () => _update(() => _collection = collection),
              ),
        ]));
      case ShopTab.calcio when _team == null:
        slivers.add(_deskHeading('⚽ ${t.tab(ShopTab.calcio).toUpperCase()}', hint: t.calcioHint));
        final curva = [for (final b in _shop.shelfBundles) if (b.id == 'curva') b];
        if (curva.isNotEmpty) slivers.add(_deskBundles(t, language, curva));
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 20)));
        slivers.add(_deskCards([
          for (final team in CalcioTeam.values)
            if (_teamItems(team) case final items when items.isNotEmpty)
              _DeskCollectionCard(
                key: Key('shop.team.${team.name}'),
                title: team.label,
                tagline: team.tagline(language),
                count: t.pieces(items.length),
                color: team.primary.computeLuminance() > 0.6 ? team.secondary : _ShopScreenState._bright(team.primary),
                look: _teamLook(team),
                onTap: () => _update(() => _team = team),
              ),
        ]));
      case ShopTab.calcio:
        final team = _team!;
        slivers.add(_deskOpened(t, language));
        final own = [for (final b in _shop.shelfBundles) if (b.id == 'curva_${team.name}') b];
        if (own.isNotEmpty) slivers.add(_deskBundles(t, language, own));
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 20)));
        slivers.add(_deskGrid(t, language, [for (final item in _teamItems(team)) (item, null)]));
      default:
        if (_tab == ShopTab.brands || _tab == ShopTab.oddities) slivers.add(_deskOpened(t, language));
        if (_tab == ShopTab.wardrobe && _hasAvatarRoute) slivers.add(_deskChangeFace(t));
        slivers.add(_deskFilters(t));
        slivers.add(_deskGrid(t, language, [for (final item in _filtered()) (item, null)]));
    }
    return RawScrollbar(
      controller: _scroll,
      thumbColor: AppColors.gold.withValues(alpha: 0.4),
      radius: const Radius.circular(4),
      thickness: 6,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: CustomScrollView(
          key: const Key('shop.grid'),
          controller: _scroll,
          slivers: [
            ...slivers,
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  /// In vetrina: il completo che conviene di più e uno di lusso.
  List<ShopBundle> _deskTeaser(ShopStrings t, AppLanguage language) {
    final open = [for (final b in _shop.shelfBundles) if (!_shop.bundleComplete(b)) b];
    ShopBundle? pick(bool premium) {
      final pool = [for (final b in open) if (b.premium == premium) b]
        ..sort((a, b) => b.discountPct.compareTo(a.discountPct));
      return pool.firstOrNull;
    }

    return [?pick(false), ?pick(true)];
  }

  Widget _deskHeading(String title, {String? hint, Color color = AppColors.gold, Widget? trailing}) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DeskText.display(DeskText.title, color: color).copyWith(letterSpacing: 3)),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: DeskText.text(size: DeskText.label, color: AppColors.textSecondary)
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      );

  Widget _deskEmpty(String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.all(80),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: DeskText.text(size: DeskText.lead, color: AppColors.textSecondary).copyWith(fontStyle: FontStyle.italic),
      ),
    ),
  );

  /// Due cartelloni per fila: le case, le collezioni, le squadre.
  Widget _deskCards(List<Widget> cards) => SliverGrid(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      mainAxisExtent: 168,
    ),
    delegate: SliverChildListDelegate(cards),
  );

  Widget _deskBundles(ShopStrings t, AppLanguage language, List<ShopBundle> bundles) => _deskCards([
    for (final bundle in bundles)
      _DeskBundleCard(
        key: Key('shop.bundle.${bundle.id}'),
        bundle: bundle,
        language: language,
        strings: t,
        look: _shop.bundleLook(bundle),
        around: _shop.bundleAround(bundle),
        who: _shop.who,
        count: _shop.bundleItems(bundle).length,
        singles: _shop.bundleSingles(bundle),
        price: _shop.bundlePrice(bundle),
        complete: _shop.bundleComplete(bundle),
        selected: _bundle?.id == bundle.id,
        onTap: () => _deskBundle(bundle),
      ),
  ]);

  /// In cima a una casa, una collezione o una squadra aperta.
  Widget _deskOpened(ShopStrings t, AppLanguage language) {
    final brand = _brand;
    final collection = _collection;
    final team = _team;
    final title = brand?.label ?? team?.label ?? (language == AppLanguage.en ? collection!.en : collection!.it);
    final color = brand?.color ??
        (team != null ? _ShopScreenState._bright(team.primary) : _ShopScreenState._collectionColor(collection!));
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            _DeskLink(
              key: const Key('shop.opened.back'),
              label: '‹ ${t.back}',
              onTap: () => _update(() {
                _brand = _collection = null;
                _team = null;
              }),
            ),
            const SizedBox(width: 28),
            if (brand != null) ...[
              SizedBox.square(dimension: 44, child: CustomPaint(painter: BrandMarkPainter(brand, seal: true))),
              const SizedBox(width: 14),
            ],
            Flexible(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DeskText.display(DeskText.title, color: color).copyWith(letterSpacing: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deskChangeFace(ShopStrings t) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DeskHover(
        key: const Key('shop.changeFace'),
        onTap: pressed(widget.onChangeFace),
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 104,
          padding: const EdgeInsets.fromLTRB(16, 10, 24, 10),
          decoration: BoxDecoration(
            color: hovered ? const Color(0xFF2E2017) : const Color(0xFF241812),
            borderRadius: BorderRadius.circular(DeskSize.radius),
            border: Border.all(color: AppColors.gold.withValues(alpha: hovered ? 1 : 0.6), width: 1.6),
          ),
          child: Row(
            children: [
              SizedBox.square(dimension: 84, child: CustomPaint(painter: AvatarBustPainter(_shop.look))),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.changeFace.toUpperCase(), style: DeskText.display(DeskText.lead)),
                    Text(t.changeFaceHint, style: DeskText.text(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text('›', style: DeskText.display(DeskText.heading)),
            ],
          ),
        ),
      ),
    ),
  );

  /// I filtri, tutti su una riga (o due, se serve).
  Widget _deskFilters(ShopStrings t) {
    final wardrobe = _tab == ShopTab.wardrobe;
    final slots = switch (_tab) {
      ShopTab.accessories => _accessorySlots,
      ShopTab.hats => _hatSlots,
      ShopTab.wardrobe => _allSlots,
      ShopTab.frames => _frameSlots,
      _ => const <String>[],
    };
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (slots.isNotEmpty) ...[
              _DeskChip(
                key: const Key('shop.slot.all'),
                label: t.allSlots,
                on: _slot == null,
                onTap: () => _update(() => _slot = null),
              ),
              for (final slot in slots)
                _DeskChip(
                  key: Key('shop.slot.$slot'),
                  label: t.slot(slot),
                  on: _slot == slot,
                  onTap: () => _update(() => _slot = slot),
                ),
              const _DeskDivider(),
            ],
            _DeskChip(
              key: const Key('shop.rarity.all'),
              label: t.allRarities,
              on: _rarity == null,
              onTap: () => _update(() => _rarity = null),
            ),
            for (final rarity in ShopRarity.values)
              if (wardrobe || rarity != ShopRarity.base)
                _DeskChip(
                  key: Key('shop.rarity.${rarity.name}'),
                  label: t.rarity(rarity),
                  color: rarityColor(rarity),
                  on: _rarity == rarity,
                  onTap: () => _update(() => _rarity = _rarity == rarity ? null : rarity),
                ),
            if (!wardrobe) ...[
              const _DeskDivider(),
              _DeskChip(
                key: const Key('shop.affordable'),
                label: t.affordable,
                coin: true,
                on: _affordable,
                onTap: () => _update(() => _affordable = !_affordable),
              ),
              _DeskChip(
                key: const Key('shop.sort'),
                label: '${_cheapFirst ? t.cheapFirst : t.dearFirst}  ⇅',
                on: true,
                onTap: () => _update(() => _cheapFirst = !_cheapFirst),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _deskGrid(ShopStrings t, AppLanguage language, List<(ShopItem, String?)> items) {
    if (items.isEmpty) return _deskEmpty(_tab == ShopTab.wardrobe ? t.emptyWardrobe : t.emptyShelf);
    final trying = _shop.trying?.id;
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.66,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (item, ends) = items[i];
        return _DeskItemCard(
          key: Key('shop.item.${item.id}'),
          item: item,
          look: _shop.tryOn(item),
          who: _shop.who,
          name: item.name(language),
          state: _shop.stateOf(item),
          strings: t,
          ends: ends,
          selected: trying == item.id,
          onTap: () => _deskTry(item),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Il bancone con lo specchio, a destra.

  Widget _deskCounter(ShopStrings t) {
    final language = AppStrings.of(context).language;
    final item = _shop.trying;
    final bundle = item == null ? _bundle : null;
    final AvatarLook look;
    final bool around;
    final ShopBrand? brand;
    if (item != null) {
      look = _shop.mirror;
      around = item.around;
      brand = item.brand;
    } else if (bundle != null) {
      look = _shop.bundleLook(bundle);
      around = _shop.bundleAround(bundle);
      brand = null;
    } else {
      look = _shop.look;
      around = false;
      brand = null;
    }
    final edge = item != null
        ? rarityColor(item.rarity)
        : bundle?.premium == true
        ? _luxe
        : AppColors.gold;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DeskSize.radius),
        border: Border.all(color: edge.withValues(alpha: 0.75), width: 1.6),
        boxShadow: [
          const BoxShadow(color: Color(0xCC000000), blurRadius: 40, offset: Offset(0, 16)),
          BoxShadow(color: edge.withValues(alpha: 0.12), blurRadius: 30),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CustomPaint(
              painter: const _BackRoomPainter(),
              child: LayoutBuilder(
                builder: (context, box) {
                  final mirrorH = min(box.maxHeight - 56, 560.0);
                  final mirrorW = min(mirrorH / 1.3, box.maxWidth * 0.62);
                  final keeper = min(250.0, box.maxHeight * 0.5);
                  return Stack(
                    children: [
                      Positioned(
                        left: box.maxWidth * 0.36 - mirrorW / 2,
                        top: (box.maxHeight - mirrorH) / 2,
                        width: mirrorW,
                        height: mirrorH,
                        child: around
                            ? Padding(
                                padding: EdgeInsets.symmetric(horizontal: mirrorW * 0.08, vertical: mirrorH * 0.06),
                                child: SeatPreview(key: const Key('shop.tryOn.seat'), look: look, name: _shop.who),
                              )
                            : _DeskMirror(look: look, brand: brand),
                      ),
                      Positioned(
                        right: -keeper * 0.12,
                        bottom: 0,
                        width: keeper,
                        height: keeper,
                        child: CustomPaint(painter: _BustPainter(ShopScreen.shopkeeper)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          CustomPaint(
            painter: const _CounterPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 30, 32, 30),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: item != null
                    ? _deskItemCounter(t, language, item)
                    : bundle != null
                    ? _deskBundleCounter(t, language, bundle)
                    : _deskIdleCounter(t),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Niente in prova: il padrone saluta.
  Widget _deskIdleCounter(ShopStrings t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _DeskSpeech(caption: _shop.who, text: t.greeting, color: AppColors.gold),
      const SizedBox(height: 18),
      Text(
        t.coinsHint,
        textAlign: TextAlign.center,
        style: DeskText.text(size: DeskText.label, color: _cream.withValues(alpha: 0.7)).copyWith(fontStyle: FontStyle.italic),
      ),
    ],
  );

  Widget _deskItemCounter(ShopStrings t, AppLanguage language, ShopItem item) {
    final color = rarityColor(item.rarity);
    final state = _shop.stateOf(item);
    final (label, action, price) = switch (state) {
      ItemState.forSale => (t.buy, () => _buy(item), item.price),
      ItemState.owned => (t.wear, () => _run(() => _shop.equip(item)), null),
      ItemState.worn =>
        item.free ? (t.worn, null, null) : (t.takeOff, () => _run(() => _shop.unequip(item.slot)), null),
    };
    final short = state == ItemState.forSale && _shop.coins < item.price;
    return Column(
      key: ValueKey('desk.counter.${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              child: Text(
                t.rarity(item.rarity).toUpperCase(),
                style: const TextStyle(color: Color(0xFF1A120C), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                [t.tryingOn, t.slot(item.slot)].join(' · ').toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DeskText.overline(color: _cream.withValues(alpha: 0.75)),
              ),
            ),
            if (state != ItemState.forSale)
              _DeskBadge(label: state == ItemState.worn ? t.worn : (item.free ? t.free : t.owned)),
          ],
        ),
        const SizedBox(height: 14),
        if (item.brand case final brand?) ...[
          _BrandLabel(brand: brand, size: 15),
          const SizedBox(height: 4),
        ],
        Text(
          item.name(language),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: DeskText.display(34, color: _cream).copyWith(height: 1.15),
        ),
        const SizedBox(height: 22),
        _DeskBrass(
          key: const Key('shop.action'),
          label: label,
          price: price,
          onTap: _shop.busy || action == null ? null : action,
        ),
        if (short) ...[
          const SizedBox(height: 10),
          Text(
            t.missing(item.price - _shop.coins),
            textAlign: TextAlign.center,
            style: DeskText.text(size: DeskText.label, color: const Color(0xFFE8A08A)).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  Widget _deskBundleCounter(ShopStrings t, AppLanguage language, ShopBundle bundle) {
    final luxe = bundle.premium;
    final accent = luxe ? _luxe : AppColors.gold;
    final items = _shop.bundleItems(bundle);
    final complete = _shop.bundleComplete(bundle);
    final price = _shop.bundlePrice(bundle);
    final singles = _shop.bundleSingles(bundle);
    final ownedCount = items.where((item) => !item.free && _shop.owned.contains(item.id)).length;
    return Column(
      key: ValueKey('desk.counter.${bundle.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                [if (luxe) '★ ${t.premium}', t.pieces(items.length)].join('   ').toUpperCase(),
                style: DeskText.overline(color: accent),
              ),
            ),
            if (complete) _DeskBadge(label: t.complete) else _SaveTag(t.save(bundle.discountPct), size: 14),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          bundle.name(language),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DeskText.display(34, color: luxe ? _luxe : _cream),
        ),
        Text(
          bundle.tagline(language),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: DeskText.text(color: _cream.withValues(alpha: 0.8)).copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        // I pezzi del pacchetto, piccoli: col mouse se ne legge il nome, col
        // clic se ne prova uno solo.
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              _DeskPiece(
                key: Key('shop.bundle.item.${item.id}'),
                look: _shop.tryOn(item),
                around: item.around,
                who: _shop.who,
                color: rarityColor(item.rarity),
                mine: _shop.stateOf(item) != ItemState.forSale,
                tooltip: _shop.stateOf(item) == ItemState.forSale
                    ? '${item.name(language)} · ${item.price}'
                    : '${item.name(language)} · ${t.owned}',
                onTap: () => _deskTry(item),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (!complete)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Text('${t.singlesLabel}: ', style: DeskText.text(color: _cream)),
                _Struck(singles, size: 19),
                const Spacer(),
                if (ownedCount > 0)
                  Text(
                    t.ownedPart(ownedCount, items.length),
                    key: const Key('shop.bundle.ownedPart'),
                    style: DeskText.text(size: DeskText.label, color: _cream).copyWith(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        _DeskBrass(
          key: const Key('shop.bundle.buy'),
          label: complete ? t.complete : t.buyBundle,
          price: complete ? null : price,
          onTap: _shop.busy || complete ? null : () => _buyBundle(bundle),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// I pezzi del layout PC.

/// La parete dietro gli scaffali, sul PC: legno scuro, la lampada in alto a
/// sinistra e gli angoli nel buio.
class _DeskWallPainter extends CustomPainter {
  const _DeskWallPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF17100C));
    final seam = Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), seam);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -1.1),
          radius: 1.2,
          colors: [const Color(0xFFFFD27A).withValues(alpha: 0.10), Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: 1.0,
          colors: [Color(0x00000000), Color(0x00000000), Color(0xB0000000)],
          stops: [0, 0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_DeskWallPainter old) => false;
}

/// Il borsellino in alto a destra, grande.
class _DeskCoins extends StatelessWidget {
  final int coins;
  final String hint;

  const _DeskCoins({required this.coins, required this.hint});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: hint,
    child: Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(14, 0, 22, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1916),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.85), width: 1.6),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 28, child: CustomPaint(painter: CoinPainter())),
          const SizedBox(width: 10),
          Text(
            '$coins',
            key: const Key('shop.coins'),
            style: const TextStyle(color: _cream, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
        ],
      ),
    ),
  );
}

/// Un'insegna di reparto: accesa sotto la lampada se scelta, il filo
/// d'oro che si scalda al passaggio del mouse.
class _DeskTab extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _DeskTab({super.key, required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) => DeskHover(
    onTap: onTap,
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: on || hovered
            ? LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.gold.withValues(alpha: on ? 0.22 : 0.10), Colors.transparent],
              )
            : null,
        border: Border(
          bottom: BorderSide(
            color: on ? AppColors.gold : (hovered ? AppColors.gold.withValues(alpha: 0.5) : Colors.transparent),
            width: 3,
          ),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        style: TextStyle(
          color: on ? AppColors.gold : (hovered ? _cream : AppColors.textSecondary),
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
        ),
      ),
    ),
  );
}

/// Un collegamento dorato, che si sottolinea al passaggio.
class _DeskLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DeskLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => DeskHover(
    onTap: pressed(onTap, Press.toggle),
    builder: (context, hovered) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          color: hovered ? const Color(0xFFFFE29A) : AppColors.gold,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          decoration: hovered ? TextDecoration.underline : null,
          decorationColor: AppColors.gold,
        ),
      ),
    ),
  );
}

class _DeskDivider extends StatelessWidget {
  const _DeskDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: AppColors.gold.withValues(alpha: 0.25),
  );
}

/// Un filtro, grande per il mouse.
class _DeskChip extends StatelessWidget {
  final String label;
  final bool on;
  final Color? color;
  final bool coin;
  final VoidCallback onTap;

  const _DeskChip({super.key, required this.label, required this.on, required this.onTap, this.color, this.coin = false});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.gold;
    return DeskHover(
      onTap: pressed(onTap, Press.toggle),
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.22) : (hovered ? const Color(0xFF2A1F18) : const Color(0xFF1B1410)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: on || hovered ? tint : tint.withValues(alpha: 0.35), width: on ? 1.6 : 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(width: 11, height: 11, decoration: BoxDecoration(color: tint, shape: BoxShape.circle)),
              const SizedBox(width: 9),
            ],
            if (coin) ...[
              const SizedBox.square(dimension: 18, child: CustomPaint(painter: CoinPainter())),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: on || hovered ? _cream : AppColors.textSecondary,
                fontSize: 16,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Tuo», «Indossato», «Completo».
class _DeskBadge extends StatelessWidget {
  final String label;

  const _DeskBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF1A120C),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppColors.gold),
    ),
    child: Text(
      label,
      style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.4),
    ),
  );
}

/// Il bottone d'ottone del bancone, alto per il mouse: si accende al passaggio.
class _DeskBrass extends StatelessWidget {
  final String label;
  final int? price;
  final VoidCallback? onTap;

  const _DeskBrass({super.key, required this.label, this.price, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return DeskHover(
      onTap: pressed(onTap, Press.confirm),
      builder: (context, hovered) => Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: hovered
                  ? const [Color(0xFFFFEDB8), Color(0xFFE0B83A), Color(0xFFA27C18)]
                  : const [Color(0xFFFFE29A), Color(0xFFC9A227), Color(0xFF8C6A14)],
            ),
            border: Border.all(color: const Color(0xFF5A420C), width: 1.4),
            boxShadow: [
              const BoxShadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 4)),
              if (hovered) BoxShadow(color: AppColors.gold.withValues(alpha: 0.45), blurRadius: 22),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(24, color: const Color(0xFF2A1A08)).copyWith(letterSpacing: 2),
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: 18),
                Container(width: 1.4, height: 28, color: const Color(0x662A1A08)),
                const SizedBox(width: 18),
                const SizedBox.square(dimension: 24, child: CustomPaint(painter: CoinPainter())),
                const SizedBox(width: 8),
                Text(
                  '$price',
                  style: const TextStyle(color: Color(0xFF2A1A08), fontWeight: FontWeight.w900, fontSize: 24),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Il fumetto del padrone, sul bancone.
class _DeskSpeech extends StatelessWidget {
  final String caption;
  final String text;
  final Color color;

  const _DeskSpeech({required this.caption, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
    decoration: BoxDecoration(
      color: _cream,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color, width: 2),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(2, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          caption.toUpperCase(),
          style: const TextStyle(color: Color(0xFF8C6A14), fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          key: const Key('shop.speech'),
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: ['serif'],
            color: Color(0xFF2A1A10),
            fontSize: 24,
            height: 1.3,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}

/// Lo specchio grande del bancone: la cornice dorata, il vetro, e il busto
/// che riempie l'ovale qualunque sia la sua misura.
class _DeskMirror extends StatelessWidget {
  final AvatarLook look;
  final ShopBrand? brand;

  const _DeskMirror({required this.look, this.brand});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final rim = box.maxWidth * 0.06;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MirrorFramePainter(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(rim, rim * 1.15, rim, rim),
                child: ClipOval(
                  child: CustomPaint(
                    painter: _GlassPainter(),
                    foregroundPainter: _GlintPainter(),
                    child: Align(
                      alignment: const Alignment(0, 1.05),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: SizedBox.square(
                          key: ValueKey(look),
                          dimension: box.maxWidth * 0.86,
                          child: CustomPaint(painter: _BustPainter(look)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (brand case final brand?)
            Positioned(
              left: 0,
              right: 0,
              bottom: -14,
              child: Center(
                child: Container(
                  key: const Key('shop.mirror.brand'),
                  padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2A1A0E), Color(0xFF1A100A)]),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: brand.color, width: 1.6),
                    boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(dimension: 22, child: CustomPaint(painter: BrandMarkPainter(brand))),
                      const SizedBox(width: 8),
                      Text(
                        brand.label.toUpperCase(),
                        style: TextStyle(color: brand.color, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Un pezzo sullo scaffale del PC: al passaggio del mouse si alza e si
/// accende del colore della sua classe; scelto, ha il filo d'oro.
class _DeskItemCard extends StatelessWidget {
  final ShopItem item;
  final AvatarLook look;
  final String who;
  final String name;
  final ItemState state;
  final ShopStrings strings;
  final String? ends;
  final bool selected;
  final VoidCallback onTap;

  const _DeskItemCard({
    super.key,
    required this.item,
    required this.look,
    required this.who,
    required this.name,
    required this.state,
    required this.strings,
    required this.selected,
    required this.onTap,
    this.ends,
  });

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(item.rarity);
    final worn = state == ItemState.worn;
    return DeskHover(
      onTap: pressed(onTap, Press.toggle),
      builder: (context, hovered) {
        final lit = hovered || selected;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          transform: Matrix4.translationValues(0, hovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: lit ? const Color(0xFF2C1E16) : const Color(0xFF221710),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.gold : (hovered ? color : color.withValues(alpha: worn ? 0.9 : 0.5)),
              width: selected ? 3 : (hovered ? 2 : 1.4),
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xAA000000), blurRadius: hovered ? 22 : 8, offset: Offset(0, hovered ? 12 : 4)),
              if (lit) BoxShadow(color: (selected ? AppColors.gold : color).withValues(alpha: 0.35), blurRadius: 24),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 32,
                color: color,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.rarity(item.rarity).toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF1A120C),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.1),
                            radius: 0.85,
                            colors: [color.withValues(alpha: lit ? 0.38 : 0.2), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: item.around ? const EdgeInsets.fromLTRB(36, 14, 36, 6) : const EdgeInsets.fromLTRB(10, 12, 10, 0),
                        child: item.around
                            ? SeatPreview(look: look, name: who)
                            : CustomPaint(painter: AvatarBustPainter(look), child: const SizedBox.expand()),
                      ),
                    ),
                    if (item.brand case final brand?)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: SizedBox.square(
                          dimension: 30,
                          child: CustomPaint(painter: BrandMarkPainter(brand, seal: true)),
                        ),
                      ),
                  ],
                ),
              ),
              Container(height: 6, color: _wood),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.brand case final brand?) _BrandLabel(brand: brand, size: 12),
                    SizedBox(
                      height: 44,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _cream, fontSize: 17, height: 1.25, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (state == ItemState.forSale)
                          _Price(item.price, size: 19)
                        else
                          Text(strings.slot(item.slot), style: DeskText.text(size: DeskText.caption, color: AppColors.textSecondary)),
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
                                fontSize: 14,
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
        );
      },
    );
  }
}

/// Il cartellone di una casa, una collezione o una squadra, sul PC.
class _DeskCollectionCard extends StatelessWidget {
  final String title;
  final String tagline;
  final String count;
  final Color color;
  final ShopBrand? brand;
  final AvatarLook look;
  final VoidCallback onTap;

  const _DeskCollectionCard({
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
  Widget build(BuildContext context) => DeskHover(
    onTap: pressed(onTap, Press.toggle),
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      transform: Matrix4.translationValues(0, hovered ? -4 : 0, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: hovered ? 0.42 : 0.28), const Color(0xFF17110D)]),
        borderRadius: BorderRadius.circular(DeskSize.radius),
        border: Border.all(color: color.withValues(alpha: hovered ? 1 : 0.7), width: hovered ? 2 : 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xAA000000), blurRadius: hovered ? 22 : 10, offset: const Offset(0, 6)),
          if (hovered) BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 24),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          const SizedBox(width: 24),
          if (brand case final brand?) ...[
            SizedBox.square(dimension: 76, child: CustomPaint(painter: BrandMarkPainter(brand, seal: true))),
            const SizedBox(width: 20),
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
                  style: DeskText.display(22, color: color).copyWith(letterSpacing: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DeskText.text(size: 17, color: _cream).copyWith(fontStyle: FontStyle.italic, height: 1.3),
                ),
                const SizedBox(height: 10),
                Text(count.toUpperCase(), style: DeskText.overline()),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 132, height: 150, child: CustomPaint(painter: AvatarBustPainter(look))),
          AnimatedPadding(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.only(left: hovered ? 8 : 0, right: hovered ? 12 : 20),
            child: Text('›', style: DeskText.display(DeskText.heading, color: color)),
          ),
        ],
      ),
    ),
  );
}

/// Un pacchetto sullo scaffale del PC.
class _DeskBundleCard extends StatelessWidget {
  final ShopBundle bundle;
  final AppLanguage language;
  final ShopStrings strings;
  final AvatarLook look;
  final bool around;
  final String who;
  final int count;
  final int singles;
  final int price;
  final bool complete;
  final bool selected;
  final VoidCallback onTap;

  const _DeskBundleCard({
    super.key,
    required this.bundle,
    required this.language,
    required this.strings,
    required this.look,
    required this.around,
    required this.who,
    required this.count,
    required this.singles,
    required this.price,
    required this.complete,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final luxe = bundle.premium;
    final edge = luxe ? _luxe : AppColors.gold;
    final t = strings;
    return DeskHover(
      onTap: pressed(onTap, Press.toggle),
      builder: (context, hovered) {
        final lit = hovered || selected;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          transform: Matrix4.translationValues(0, hovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: luxe
                  ? const [Color(0xFF3A2A10), Color(0xFF120D08), Color(0xFF2A1E0C)]
                  : const [Color(0xFF2C1C12), Color(0xFF17110D)],
            ),
            borderRadius: BorderRadius.circular(DeskSize.radius),
            border: Border.all(
              color: lit ? edge : edge.withValues(alpha: luxe ? 0.8 : 0.5),
              width: selected ? 3 : (hovered || luxe ? 2 : 1.4),
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xAA000000), blurRadius: hovered ? 22 : 10, offset: const Offset(0, 6)),
              if (lit || luxe) BoxShadow(color: edge.withValues(alpha: lit ? 0.32 : 0.14), blurRadius: 24),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 170,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(radius: 0.75, colors: [edge.withValues(alpha: 0.28), Colors.transparent]),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: 10,
                      child: around
                          ? Padding(padding: const EdgeInsets.fromLTRB(30, 4, 30, 10), child: SeatPreview(look: look, name: who))
                          : CustomPaint(painter: AvatarBustPainter(look)),
                    ),
                  ],
                ),
              ),
              Container(width: 1, color: edge.withValues(alpha: 0.4)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              [if (luxe) '★ ${t.premium}', t.pieces(count)].join('   ').toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DeskText.overline(color: luxe ? _luxe : AppColors.textSecondary).copyWith(fontSize: 13),
                            ),
                          ),
                          if (complete) _DeskBadge(label: t.complete),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bundle.name(language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DeskText.display(26, color: luxe ? _luxe : _cream),
                      ),
                      Text(
                        bundle.tagline(language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DeskText.text(size: 16, color: AppColors.textSecondary)
                            .copyWith(fontStyle: FontStyle.italic, height: 1.2),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (complete)
                            Text(t.owned, style: DeskText.text(color: AppColors.gold, weight: FontWeight.w800))
                          else ...[
                            _Struck(singles, size: 17),
                            const SizedBox(width: 12),
                            _Price(price, size: 24, color: luxe ? _luxe : _cream),
                            const SizedBox(width: 14),
                            _SaveTag(t.save(bundle.discountPct), size: 13),
                          ],
                          const Spacer(),
                          Text('›', style: DeskText.display(DeskText.title, color: edge)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Un pezzo del pacchetto aperto sul bancone: un tondo col busto.
class _DeskPiece extends StatelessWidget {
  final AvatarLook look;
  final bool around;
  final String who;
  final Color color;
  final bool mine;
  final String tooltip;
  final VoidCallback onTap;

  const _DeskPiece({
    super.key,
    required this.look,
    required this.around,
    required this.who,
    required this.color,
    required this.mine,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => DeskHover(
    onTap: pressed(onTap, Press.toggle),
    tooltip: tooltip,
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hovered ? const Color(0xFF3A2A1C) : const Color(0xFF241812),
        border: Border.all(color: mine ? AppColors.gold : color.withValues(alpha: hovered ? 1 : 0.7), width: hovered ? 2.6 : 1.8),
        boxShadow: [if (hovered) BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 14)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            top: 5,
            child: around
                ? Padding(padding: const EdgeInsets.fromLTRB(14, 2, 14, 6), child: SeatPreview(look: look, name: who))
                : CustomPaint(painter: AvatarBustPainter(look)),
          ),
          if (mine)
            const Positioned(
              right: 6,
              bottom: 6,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: AppColors.gold,
                child: Text('✓', style: TextStyle(color: Color(0xFF1A120C), fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    ),
  );
}
