part of 'shop_screen.dart';

/// The desktop shop, «il manichino»: the departments as a rail on the left
/// (the window first, with its time left), the player huge in the middle
/// behind the counter, and on the right the case with the open shelf, its
/// sections and filters, a search and the picked piece's Buy.
extension _Desktop on _ShopScreenState {
  Widget _desktop() {
    final t = _t;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreetBackdrop(
        section: StreetSection.shop,
        desk: true,
        title: t.title,
        builder: (context, layout) {
          final now = DateTime.now();
          final w = layout.size.width;
          final h = layout.size.height;
          final entries = _entries(now);
          final index = _pickedIndex(entries);
          final picked = index < 0 ? null : entries[index];
          final pad = max(24.0, w * 0.03);
          final railW = (w * 0.2).clamp(280.0, 400.0);
          final caseW = (w * 0.31).clamp(400.0, 600.0);
          final stageL = pad + railW + 20;
          final stageR = w - pad - caseW - 20;
          final stageW = stageR - stageL;
          final counterTop = h * 0.83;
          final top = layout.neon.bottom + 24;
          final bust = min(stageW * 0.98, counterTop + 34 - top - 30);
          final cx = (stageL + stageR) / 2;
          final cardW = min(stageW * 0.2, 190.0);
          return Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x55000000), Color(0xDD07060A)],
                        stops: [0.1, 0.5, 0.9],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: cx - stageW * 0.42,
                top: layout.neon.bottom,
                width: stageW * 0.84,
                height: counterTop - layout.neon.bottom + 20,
                child: const IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _LampConePainter()))),
              ),
              Positioned(
                left: cx - bust / 2,
                top: counterTop + 34 - bust,
                child: _Hero(
                  entry: picked,
                  look: _lookOf(picked),
                  who: _shop.who,
                  size: bust,
                  // The scene, the shoulders and the hands want the whole portrait, the
                  // wings reaching past it too.
                  frame: (ShopController.slotOf(picked?.item)?.wide ?? false) ? const Rect.fromLTWH(-0.13, -0.08, 1.26, 1.26) : const Rect.fromLTWH(-0.15, -0.27, 1.3, 1.3),
                  card: false,
                ),
              ),
              Positioned(
                left: stageL - 10,
                width: stageW + 20,
                top: counterTop,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5A3A22), Color(0xFF2A1A0E), Color(0xFF120A06)]),
                    border: Border(top: BorderSide(color: Targa.brass, width: 3)),
                    boxShadow: [BoxShadow(color: Color(0xCC000000), blurRadius: 20, offset: Offset(0, -6))],
                  ),
                ),
              ),
              // The seat card beside the bust, standing on the counter: the
              // frame and the name ink as the table sees them.
              if (picked?.isGesture != true)
                Positioned(
                  left: stageR - cardW,
                  top: counterTop + 18 - cardW * SeatPreview.aspect,
                  width: cardW,
                  height: cardW * SeatPreview.aspect,
                  child: SeatPreview(key: const Key('shop.desk.seat'), look: _lookOf(picked), name: _shop.who),
                ),
              Positioned(left: pad, top: top, width: railW, bottom: pad, child: _rail(now)),
              Positioned(right: pad, top: top, width: caseW, bottom: pad, child: _case(entries, index, picked, now)),
              Positioned(left: 28, top: layout.neon.center.dy - 28, child: const TargaBackButton(key: Key('shop.back'), size: 56)),
              Positioned(
                right: 28,
                top: layout.neon.center.dy - 24,
                child: CoinPurse(key: const Key('shop.coins'), coins: _shop.coins, onAdd: _earnCoins, hint: t.coinsHint, scale: 1.25),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rail(DateTime now) {
    final t = _t;
    final ends = _shop.windowEnds(now);
    final live = _shop.liveWindow(now);
    final shown = <_Entry>[
      for (final (item, feature) in live.take(4)) _Entry.item(item, feature: feature),
      for (final b in _shop.shelfBundles.take(max(0, 4 - live.length))) _bundleEntry(b),
    ];
    final onWindow = _dept == ShopDept.window;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            key: const Key('shop.dept.window'),
            onTap: pressed(() => _openDept(ShopDept.window), Press.toggle),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [Color(0xF2401C08), Color(0xF2160D08)]),
                border: Border.all(color: onWindow ? const Color(0xFFFFD27A) : const Color(0xFF9C6A30), width: onWindow ? 2 : 1.2),
                boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFD27A), size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(t.featured, style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.4)),
                      ),
                      if (ends != null) _TimerBadge(t.timeLeft(ends.difference(now)), scale: 1.15),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final e in shown)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: rarityColor(e.rarity), width: 2)),
                                clipBehavior: Clip.antiAlias,
                                child: DecoratedBox(decoration: _thumbGround(e.rarity), child: _EntryArt(entry: e, look: _lookOf(e), who: _shop.who)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          for (final dept in ShopDept.values)
            if (dept != ShopDept.window) _railRow(dept),
          if (widget.onChangeFace != null) ...[
            const SizedBox(height: 6),
            TargaButton(
              key: const Key('shop.changeFace'),
              label: t.changeFace,
              kind: TargaKind.secondary,
              icon: Icons.face_retouching_natural,
              compact: true,
              desk: true,
              onPressed: widget.onChangeFace,
            ),
          ],
        ],
      ),
    );
  }

  Widget _railRow(ShopDept dept) {
    final t = _t;
    final on = dept == _dept;
    final worn = _shop.wornIn(dept);
    final count = _shop.deptItems(dept).where((i) => !i.free).length;
    return GestureDetector(
      key: Key('shop.dept.${dept.name}'),
      onTap: pressed(() => _openDept(dept), Press.toggle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
        decoration: BoxDecoration(
          color: on ? const Color(0xE6241911) : const Color(0xB30C0907),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? Targa.brass : const Color(0xFF3A2A1E), width: on ? 2 : 1),
        ),
        child: Row(
          children: [
            _Medal(dept: dept, label: '', worn: worn, look: _shop.look, on: on, onTap: () => _openDept(dept), side: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.dept(dept).toUpperCase(), style: TextStyle(color: on ? Targa.brass : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  const SizedBox(height: 3),
                  Text(
                    worn?.name(_language) ?? t.pieces(count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Georgia', fontFamilyFallback: serifFallback, fontStyle: FontStyle.italic, color: _cream, fontSize: 18),
                  ),
                  if (worn != null) Text(t.pieces(count), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: on ? Targa.brass : const Color(0xFF5A4A3A)),
          ],
        ),
      ),
    );
  }

  Widget _case(List<_Entry> entries, int index, _Entry? picked, DateTime now) {
    final t = _t;
    final window = _dept == ShopDept.window;
    final open = _openSection(now);
    final collections = window ? const <Object>[] : ShopController.collectionsIn(_deptAll());
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xF2241911), Color(0xF21B130E), Color(0xF20E0A08)]),
        border: Border.all(color: Targa.brassDim, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0xEE000000), blurRadius: 30, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_Medal.iconOf(_dept), color: Targa.brass, size: 22),
              const SizedBox(width: 10),
              Text(t.dept(_dept).toUpperCase(), style: const TextStyle(color: Targa.brass, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
              const Spacer(),
              if (!window)
                SizedBox(
                  width: 220,
                  height: 38,
                  child: TextField(
                    key: const Key('shop.search'),
                    controller: _search,
                    onChanged: (v) => _setFilter(_filter.copyWith(query: v)),
                    style: const TextStyle(color: _cream, fontSize: 15),
                    cursorColor: Targa.brass,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: t.search,
                      hintStyle: const TextStyle(color: Color(0xFF8E8070), fontSize: 15),
                      prefixIcon: const Icon(Icons.search, size: 19, color: Color(0xFF8E8070)),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36),
                      filled: true,
                      fillColor: Targa.ink,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: const BorderSide(color: Color(0xFF4A3A2A))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: const BorderSide(color: Targa.brass)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: window
                ? [
                    for (final s in _sections(now))
                      _Chip(
                        key: Key('shop.section.${s.name}'),
                        label: switch (s) {
                          _WindowSection.featured => t.featured,
                          _WindowSection.sets => t.bundlesHeading,
                          _WindowSection.luxe => t.premiumHeading,
                        },
                        on: s == open,
                        scale: 1.1,
                        onTap: () => _openSectionTap(s),
                      ),
                  ]
                : [
                    if (_dept == ShopDept.hands) ..._handChips(scale: 1.1),
                    for (final o in ShopOwnership.values)
                      _Chip(key: Key('shop.filter.${o.name}'), label: t.ownership(o), on: _filter.own == o, scale: 1.1, onTap: () => _setFilter(_filter.copyWith(own: o))),
                    for (final r in ShopRarity.values)
                      if (r != ShopRarity.base && _deptAll().any((i) => i.rarity == r))
                        _Chip(
                          key: Key('shop.rarity.${r.name}'),
                          label: t.rarity(r),
                          dot: rarityColor(r),
                          on: _filter.rarity == r,
                          scale: 1.1,
                          onTap: () => _setFilter(_filter.copyWith(rarity: () => _filter.rarity == r ? null : r)),
                        ),
                    if (collections.isNotEmpty)
                      _Chip(
                        key: const Key('shop.filters'),
                        label: _filter.collection == null ? t.collectionFilter : _collectionLabel(_filter.collection!, _language),
                        more: true,
                        dot: _filter.collection == null ? null : _collectionColor(_filter.collection!),
                        on: _filter.collection != null,
                        scale: 1.1,
                        onTap: _openFilters,
                      ),
                  ],
          ),
          const SizedBox(height: 8),
          Text(
            window ? t.pieces(entries.length) : t.count(entries.length, _deptAll().length),
            key: const Key('shop.count'),
            style: const TextStyle(color: Color(0xFF8E8070), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text(t.emptyShelf, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)))
                : GridView.builder(
                    key: const Key('shop.grid'),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.74),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => GestureDetector(
                      key: entries[i].widgetKey,
                      onTap: pressed(() => _choose(entries[i]), Press.toggle),
                      child: _DeskCard(entry: entries[i], shop: _shop, look: _lookOf(entries[i]), on: i == index, strings: t, now: now),
                    ),
                  ),
          ),
          if (picked != null) ...[
            const Divider(color: Color(0xFF3A2A1E), height: 26),
            _FitName(picked.name(_language), size: 28),
            const SizedBox(height: 8),
            _TagLine(entry: picked, strings: t, timer: picked.feature == null ? null : t.timeLeft(picked.feature!.endsAt.difference(now)), scale: 1.3),
            if (picked.bundle case final bundle?) ...[
              const SizedBox(height: 10),
              _bundleParts(bundle),
            ],
            const SizedBox(height: 16),
            _action(picked, desk: true, expand: true),
          ],
        ],
      ),
    );
  }

  /// A bundle's pieces in a row, and what they would cost one by one.
  Widget _bundleParts(ShopBundle bundle) {
    final items = _shop.bundleItems(bundle);
    return Row(
      children: [
        for (final item in items.take(6))
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: rarityColor(item.rarity), width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: _thumbGround(item.rarity),
              child: _EntryArt(entry: _Entry.item(item), look: _shop.tryOn(item), who: _shop.who),
            ),
          ),
        const Spacer(),
        Text(
          '${_shop.bundleSingles(bundle)}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, decoration: TextDecoration.lineThrough, decorationColor: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// A piece in the case: the thumbnail, a class bar, the name, the price.
class _DeskCard extends StatelessWidget {
  final _Entry entry;
  final ShopController shop;
  final AvatarLook look;
  final bool on;
  final ShopStrings strings;
  final DateTime now;
  const _DeskCard({required this.entry, required this.shop, required this.look, required this.on, required this.strings, required this.now});

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final bundle = entry.bundle;
    final state = item == null ? null : shop.stateOf(item);
    final Widget foot;
    if (bundle != null) {
      final complete = shop.bundleComplete(bundle);
      foot = complete
          ? Text(strings.complete, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800))
          : _price(shop.bundlePrice(bundle));
    } else if (state == ItemState.forSale) {
      foot = _price(item!.price);
    } else if (state == ItemState.locked) {
      foot = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 14, color: AppColors.gold),
          const SizedBox(width: 4),
          Flexible(
            child: Text(ProgressStrings.of(context).missionOnly,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      );
    } else {
      final worn = state == ItemState.worn;
      foot = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(worn ? Icons.check_circle : Icons.check, size: 15, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(worn ? strings.worn : (item!.free ? strings.free : strings.owned), style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      transform: Matrix4.translationValues(0, on ? -4 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1510),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? AppColors.gold : const Color(0xFF3A2A1E), width: on ? 2.4 : 1.2),
        boxShadow: [
          const BoxShadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 3)),
          if (on) const BoxShadow(color: Color(0x66FFB443), blurRadius: 14),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(decoration: _thumbGround(entry.rarity), child: _EntryArt(entry: entry, look: look, who: shop.who)),
                if (entry.feature != null)
                  Positioned(left: 6, top: 6, child: _TimerBadge(strings.timeLeft(entry.feature!.endsAt.difference(now)))),
                if (bundle != null) Positioned(left: 6, top: 6, child: _SaveTag(strings.save(bundle.discountPct))),
                if (item?.brand case final brand?)
                  Positioned(right: 6, top: 6, child: SizedBox.square(dimension: 22, child: CustomPaint(painter: BrandMarkPainter(brand, seal: true)))),
              ],
            ),
          ),
          Container(height: 3, color: rarityColor(entry.rarity)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
            child: Column(
              children: [
                Text(
                  entry.name(AppStrings.of(context).language),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _cream, fontSize: 13, height: 1.15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                foot,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _price(int price) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox.square(dimension: 15, child: CustomPaint(painter: _Coin())),
      const SizedBox(width: 4),
      Text('$price', style: const TextStyle(color: _cream, fontWeight: FontWeight.w900, fontSize: 14)),
    ],
  );
}

/// A soft cone of lamp light falling on the dummy.
class _LampConePainter extends CustomPainter {
  const _LampConePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cone = Path()
      ..moveTo(w * 0.36, 0)
      ..lineTo(w * 0.64, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33FFD27A), Color(0x14FFD27A), Color(0x00FFD27A)],
        ).createShader(Offset.zero & size)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  @override
  bool shouldRepaint(_LampConePainter old) => false;
}
