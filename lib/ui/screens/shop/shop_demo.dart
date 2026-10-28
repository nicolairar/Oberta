part of 'shop_screen.dart';

/// Due prove di disposizione della bottega sul telefono, da guardare nei
/// render (`tool/render/bottega_demo_render_test.dart`) prima di sceglierne
/// una. Nell'app non si vedono: [ShopScreen.debugDemo] resta null.
enum ShopDemoLayout {
  /// Lo specchio grande in alto, il bancone col bottone sotto, e gli
  /// scaffali a tre per fila in fondo.
  mirrorTop,

  /// Il camerino: lo specchio a figura intera a sinistra, i campioni a
  /// destra, i reparti in basso sotto il pollice.
  fittingRoom,
}

extension _ShopDemo on _ShopScreenState {
  /// Il pezzo nello specchio: quello toccato, o il primo dello scaffale.
  ShopItem? _demoPick(List<ShopItem> items) => _shop.trying ?? items.firstOrNull;

  List<ShopItem> _demoItems() => _tab == ShopTab.window ? [for (final (item, _) in _shop.window) item] : _filtered();

  Widget _demo(ShopStrings t, ShopDemoLayout layout) => StreetScaffold(
    section: StreetSection.shop,
    title: t.title,
    backKey: const Key('shop.back'),
    body: ListenableBuilder(
      listenable: _shop,
      builder: (context, _) {
        if (_shop.loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
        final language = AppStrings.of(context).language;
        final items = _demoItems();
        final pick = _demoPick(items);
        return switch (layout) {
          ShopDemoLayout.mirrorTop => _demoMirrorTop(t, language, items, pick),
          ShopDemoLayout.fittingRoom => _demoFittingRoom(t, language, items, pick),
        };
      },
    ),
  );

  /// A: reparti e borsellino in una riga; lo specchio grande; il cartellino
  /// e il bottone sul bancone; sotto, lo scaffale a tre per fila.
  Widget _demoMirrorTop(ShopStrings t, AppLanguage language, List<ShopItem> items, ShopItem? pick) => Column(
    children: [
      _tabs(t),
      Expanded(
        flex: 12,
        child: CustomPaint(
          painter: const _BackRoomPainter(),
          child: LayoutBuilder(
            builder: (context, box) {
              final h = box.maxHeight - 76;
              final mirrorW = min(box.maxWidth * 0.70, h / 1.25);
              return Stack(
                children: [
                  Positioned(
                    right: -6,
                    bottom: 68,
                    width: box.maxWidth * 0.30,
                    height: box.maxWidth * 0.30,
                    child: CustomPaint(painter: _BustPainter(ShopScreen.shopkeeper)),
                  ),
                  Positioned(
                    left: (box.maxWidth - mirrorW) / 2 - box.maxWidth * 0.06,
                    top: 8,
                    width: mirrorW,
                    height: mirrorW * 1.25,
                    child: _Mirror(look: pick == null ? _shop.look : _shop.tryOn(pick), brand: pick?.brand),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 76,
                    child: _demoCounter(t, language, pick),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      if (_tab != ShopTab.window) _filters(t),
      Expanded(
        flex: 9,
        child: CustomPaint(
          painter: const _ShelfWallPainter(),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.80,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _DemoSwatch(
              item: items[i],
              look: _shop.tryOn(items[i]),
              state: _shop.stateOf(items[i]),
              on: items[i] == pick,
              onTap: () => _shop.preview(items[i]),
            ),
          ),
        ),
      ),
    ],
  );

  /// Il bancone sotto lo specchio: il cartellino del pezzo e il bottone.
  Widget _demoCounter(ShopStrings t, AppLanguage language, ShopItem? pick) => CustomPaint(
    painter: const _CounterPainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: pick == null
          ? const SizedBox.expand()
          : Row(
              children: [
                Expanded(child: _DemoTag(item: pick, name: pick.name(language), strings: t)),
                const SizedBox(width: 10),
                _BrassButton(label: t.buy, price: pick.price, onTap: () {}),
              ],
            ),
    ),
  );

  /// B: il camerino. Lo specchio alto a sinistra, i campioni e il bottone a
  /// destra; i reparti in fondo, dove arriva il pollice.
  Widget _demoFittingRoom(ShopStrings t, AppLanguage language, List<ShopItem> items, ShopItem? pick) => Column(
    children: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 12,
              child: CustomPaint(
                painter: const _BackRoomPainter(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 0, 10),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 0.74,
                            child: _Mirror(look: pick == null ? _shop.look : _shop.tryOn(pick), brand: pick?.brand),
                          ),
                        ),
                      ),
                      if (pick != null) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _SpeechCard(
                            text: pick.name(language),
                            caption: [t.rarity(pick.rarity), ?pick.brand?.label].join(' · ').toUpperCase(),
                            color: rarityColor(pick.rarity),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _BrassButton(label: t.buy, price: pick.price, big: true, onTap: () {}),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: CustomPaint(
                painter: const _ShelfWallPainter(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: CoinBalance(coins: _shop.coins, hint: t.coinsHint),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 7,
                          crossAxisSpacing: 7,
                          childAspectRatio: 0.66,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) => _DemoSwatch(
                          item: items[i],
                          look: _shop.tryOn(items[i]),
                          state: _shop.stateOf(items[i]),
                          on: items[i] == pick,
                          onTap: () => _shop.preview(items[i]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // I reparti in fondo: un pollice ci arriva senza allungarsi.
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF120D0A),
          border: Border(top: BorderSide(color: Color(0xFF5A3A22))),
        ),
        child: SizedBox(height: 54, child: _tabStrip(t)),
      ),
    ],
  );
}

/// Un campione sullo scaffale: piccolo, la fascia della classe, il prezzo.
class _DemoSwatch extends StatelessWidget {
  final ShopItem item;
  final AvatarLook look;
  final ItemState state;
  final bool on;
  final VoidCallback onTap;

  const _DemoSwatch({required this.item, required this.look, required this.state, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(item.rarity);
    return GestureDetector(
      onTap: pressed(onTap, Press.toggle),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF241812),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: on ? AppColors.gold : color.withValues(alpha: 0.7), width: on ? 2.4 : 1.2),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 5, color: color),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.1),
                    radius: 0.8,
                    colors: [color.withValues(alpha: 0.22), const Color(0xFF241812)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                  child: CustomPaint(painter: AvatarBustPainter(look), child: const SizedBox.expand()),
                ),
              ),
            ),
            Container(height: 4, color: _wood),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state == ItemState.forSale) ...[
                    const SizedBox.square(dimension: 13, child: CustomPaint(painter: CoinPainter())),
                    const SizedBox(width: 4),
                    Text('${item.price}', style: const TextStyle(color: _cream, fontWeight: FontWeight.w900, fontSize: 13)),
                  ] else
                    Icon(state == ItemState.worn ? Icons.check_circle : Icons.check, size: 15, color: AppColors.gold),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il cartellino sul bancone: la classe e il nome, su una riga sola.
class _DemoTag extends StatelessWidget {
  final ShopItem item;
  final String name;
  final ShopStrings strings;

  const _DemoTag({required this.item, required this.name, required this.strings});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
    decoration: BoxDecoration(
      color: _cream,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: rarityColor(item.rarity), width: 2),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(2, 3))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          [strings.rarity(item.rarity), ?item.brand?.label].join(' · ').toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Color.lerp(rarityColor(item.rarity), Colors.black, 0.25), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.4),
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, color: Color(0xFF2A1A08), fontSize: 15),
        ),
      ],
    ),
  );
}
