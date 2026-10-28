part of 'shop_screen.dart';

/// One thing on the shelf: a piece (maybe in the window, with its time
/// left) or a bundle.
class _Entry {
  final ShopItem? item;
  final ShopFeature? feature;
  final ShopBundle? bundle;

  const _Entry.item(ShopItem this.item, {this.feature}) : bundle = null;
  const _Entry.bundle(ShopBundle this.bundle) : item = null, feature = null;

  String get key => bundle != null ? 'bundle.${bundle!.id}' : item!.id;

  /// The test key of its thumbnail or card.
  Key get widgetKey => Key(bundle != null ? 'shop.bundle.${bundle!.id}' : 'shop.item.${item!.id}');

  String name(AppLanguage language) => bundle?.name(language) ?? item!.name(language);

  ShopRarity get rarity => bundle == null ? item!.rarity : (bundle!.premium ? ShopRarity.leggendario : ShopRarity.epico);
}

/// The part of the bust a thumbnail zooms on, in bust units.
Rect _focusOf(_Entry entry) {
  if (entry.bundle != null) return const Rect.fromLTWH(0.1, 0.06, 0.8, 0.8);
  return switch (entry.item!.slot) {
    'hat' => const Rect.fromLTWH(0.12, 0.0, 0.76, 0.6),
    'hairdo' || 'hairDye' => const Rect.fromLTWH(0.06, 0.0, 0.88, 0.7),
    'headFx' => const Rect.fromLTWH(0.06, -0.04, 0.88, 0.72),
    'face' || 'glasses' || 'tattoo' || 'faceExtras' => const Rect.fromLTWH(0.2, 0.22, 0.6, 0.55),
    'eyeShine' => const Rect.fromLTWH(0.26, 0.3, 0.48, 0.34),
    'outfit' => const Rect.fromLTWH(0.0, 0.58, 1.0, 0.45),
    'aura' || 'back' || 'held' || 'frontFx' => const Rect.fromLTWH(0, 0, 1, 1),
    _ => const Rect.fromLTWH(0.06, 0.12, 0.88, 0.88),
  };
}

/// A bust of [look], zoomed on [focus], with no background.
class _ZoomBustPainter extends CustomPainter {
  final AvatarLook look;
  final Rect focus;
  const _ZoomBustPainter(this.look, {this.focus = const Rect.fromLTWH(0, 0, 1, 1)});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = max(size.width / focus.width, size.height / focus.height);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2 - focus.center.dx * scale, size.height / 2 - focus.center.dy * scale);
    LookPainter.bust(canvas, look, scale);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ZoomBustPainter old) => old.look != look || old.focus != focus;
}

/// The picture of an entry: the player wearing it, zoomed on where it
/// goes; a gesture's art; a frame or a name on a small seat card.
class _EntryArt extends StatelessWidget {
  final _Entry entry;
  final AvatarLook look;
  final String who;
  const _EntryArt({required this.entry, required this.look, required this.who});

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    if (item != null && item.isGesture) {
      return Padding(padding: const EdgeInsets.all(8), child: CustomPaint(painter: GestureArt(ShopController.gestureOf(item)!), child: const SizedBox.expand()));
    }
    if (item != null && item.around) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
        child: FittedBox(child: SizedBox(width: 90, height: 90 * SeatPreview.aspect, child: SeatPreview(look: look, name: who))),
      );
    }
    return CustomPaint(painter: _ZoomBustPainter(look, focus: _focusOf(entry)), child: const SizedBox.expand());
  }
}

/// The background of a thumbnail: lamp-lit, tinted with the class.
BoxDecoration _thumbGround(ShopRarity rarity) => BoxDecoration(
  gradient: RadialGradient(
    center: const Alignment(0, -0.2),
    radius: 0.9,
    colors: [Color.lerp(const Color(0xFF3A2A1E), rarityColor(rarity), 0.35)!, const Color(0xFF120C08)],
  ),
);

/// The hero: the player as big as the room allows. A new piece makes him
/// settle in it with a small lift, once (nothing loops).
class _Hero extends StatelessWidget {
  final _Entry? entry;
  final AvatarLook look;
  final String who;
  final double size;

  /// How the bust sits in the square: zoomed out, so the shoulders show.
  final Rect frame;

  /// The seat card as the table sees it instead of the bust: true or false,
  /// or null for the card only with a frame or a name ink.
  final bool? card;

  /// How much of the square shows above what covers its bottom (the price
  /// tag on the phone): the card fits in there.
  final double? cardRoom;
  const _Hero({
    required this.entry,
    required this.look,
    required this.who,
    required this.size,
    this.frame = const Rect.fromLTWH(-0.15, -0.08, 1.3, 1.3),
    this.card,
    this.cardRoom,
  });

  /// Whether [entry] shows as the seat card when nobody chose.
  static bool cardFirst(_Entry? entry) => entry?.item?.around ?? false;

  @override
  Widget build(BuildContext context) {
    final item = entry?.item;
    final Widget art;
    if (item != null && item.isGesture) {
      art = Padding(
        padding: EdgeInsets.fromLTRB(size * 0.12, size * 0.1, size * 0.12, size * 0.2),
        child: GestureShowcase(key: const Key('shop.hero.gesture'), gestures: [ShopController.gestureOf(item)!]),
      );
    } else if (card ?? cardFirst(entry)) {
      final room = (cardRoom ?? size) - size * 0.06;
      final width = min(size * 0.62, room / SeatPreview.aspect);
      art = Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.04),
          child: SizedBox(
            width: width,
            height: width * SeatPreview.aspect,
            child: SeatPreview(key: const Key('shop.hero.seat'), look: look, name: who),
          ),
        ),
      );
    } else {
      art = CustomPaint(painter: _ZoomBustPainter(look, focus: frame), size: Size.square(size));
    }
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The lamp's warm pool behind the head.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.15),
                radius: 0.62,
                colors: [const Color(0xFFFFC46B).withValues(alpha: 0.3), const Color(0x00FFC46B)],
              ),
            ),
          ),
          RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(entry?.key),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..translateByDouble(0.0, size * 0.012 * (1 - t), 0.0, 1.0)
                  ..scaleByDouble(0.985 + 0.015 * t, 0.985 + 0.015 * t, 1.0, 1.0),
                child: child,
              ),
              child: art,
            ),
          ),
        ],
      ),
    );
  }
}

/// A piece's name, as big as fits: it shrinks, then wraps to two lines,
/// and only then gives up with an ellipsis.
class _FitName extends StatelessWidget {
  final String text;
  final double size;
  const _FitName(this.text, {this.size = 19});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      var s = size;
      final style = TextStyle(fontFamily: 'Georgia', fontFamilyFallback: const ['serif'], fontStyle: FontStyle.italic, color: _cream, height: 1.12);
      // Down to 80% on one line; past that, two lines at 80%.
      for (; s > size * 0.8; s -= 0.5) {
        final tp = TextPainter(text: TextSpan(text: text, style: style.copyWith(fontSize: s)), maxLines: 1, textDirection: TextDirection.ltr)
          ..layout(maxWidth: box.maxWidth);
        final fits = !tp.didExceedMaxLines;
        tp.dispose();
        if (fits) break;
      }
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style.copyWith(fontSize: s));
    },
  );
}

/// The class on its colour, and the house after it.
class _RarityTag extends StatelessWidget {
  final ShopRarity rarity;
  final String label;
  final double scale;
  const _RarityTag(this.rarity, this.label, {this.scale = 1});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
    decoration: BoxDecoration(color: rarityColor(rarity), borderRadius: BorderRadius.circular(3)),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(color: const Color(0xFF1A1208), fontSize: 9.5 * scale, fontWeight: FontWeight.w900, letterSpacing: 1.3 * scale),
    ),
  );
}

/// Time left on a piece in the window, from the server's end date.
class _TimerBadge extends StatelessWidget {
  final String text;
  final double scale;
  const _TimerBadge(this.text, {this.scale = 1});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 2.5 * scale),
    decoration: const ShapeDecoration(shape: StadiumBorder(), color: Color(0xFFE07A1F)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 11 * scale, color: const Color(0xFF1A0E04)),
        SizedBox(width: 3 * scale),
        Text(text, style: TextStyle(color: const Color(0xFF1A0E04), fontSize: 10.5 * scale, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
      ],
    ),
  );
}

/// The bundle's saving, in red.
class _SaveTag extends StatelessWidget {
  final String text;
  final double scale;
  const _SaveTag(this.text, {this.scale = 1});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
    decoration: BoxDecoration(color: const Color(0xFFC0392B), borderRadius: BorderRadius.circular(3)),
    child: Text(text, style: TextStyle(color: Colors.white, fontSize: 9.5 * scale, fontWeight: FontWeight.w900, letterSpacing: 1 * scale)),
  );
}

/// A filter chip: a thin outline, filled when on.
class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final Color? dot;
  final VoidCallback onTap;
  final double scale;

  /// A small chevron: the chip opens a choice.
  final bool more;
  const _Chip({super.key, required this.label, required this.on, required this.onTap, this.dot, this.scale = 1, this.more = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: pressed(onTap, Press.toggle),
    child: Container(
      height: 30 * scale,
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: on ? Targa.brass : const Color(0xFF4A3A2A))),
        color: on ? const Color(0x40D9B45A) : const Color(0xCC0C0907),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(width: 7 * scale, height: 7 * scale, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            SizedBox(width: 6 * scale),
          ],
          Text(label, style: TextStyle(color: on ? _cream : const Color(0xFFB0A090), fontSize: 12.5 * scale, fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
          if (more) Icon(Icons.expand_more, size: 16 * scale, color: on ? _cream : const Color(0xFFB0A090)),
        ],
      ),
    ),
  );
}

String _collectionLabel(Object collection, AppLanguage language) => switch (collection) {
  final ShopBrand brand => brand.label,
  final ShopCollection c => language == AppLanguage.it ? c.it : c.en,
  _ => '$collection',
};

Color _collectionColor(Object collection) => switch (collection) {
  final ShopBrand brand => brand.color,
  ShopCollection.circo => const Color(0xFFD9483B),
  ShopCollection.carnevale => const Color(0xFF3FB59E),
  ShopCollection.assurdo => const Color(0xFFE7C33A),
  ShopCollection.calcio => const Color(0xFF4FA3E0),
  _ => AppColors.gold,
};

String _collectionKey(Object collection) => switch (collection) {
  final ShopBrand brand => brand.name,
  final ShopCollection c => c.name,
  _ => '$collection',
};

/// The filter sheet: the class and the collection.
class _FilterSheet extends StatelessWidget {
  final ShopStrings strings;
  final AppLanguage language;
  final ShopFilter filter;
  final List<Object> collections;
  final ValueChanged<ShopFilter> onChanged;
  const _FilterSheet({required this.strings, required this.language, required this.filter, required this.collections, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Color(0xFF9A8A78), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
    );
    return NoirSheet(
      title: strings.filters,
      children: [
        heading(strings.rarityFilter),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Chip(label: strings.allRarities, on: filter.rarity == null, onTap: () => onChanged(filter.copyWith(rarity: () => null))),
          for (final r in ShopRarity.values)
            if (r != ShopRarity.base)
              _Chip(
                key: Key('shop.rarity.${r.name}'),
                label: strings.rarity(r),
                dot: rarityColor(r),
                on: filter.rarity == r,
                onTap: () => onChanged(filter.copyWith(rarity: () => filter.rarity == r ? null : r)),
              ),
        ]),
        if (collections.isNotEmpty) ...[
          heading(strings.collectionFilter),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip(label: strings.allBrands, on: filter.collection == null, onTap: () => onChanged(filter.copyWith(collection: () => null))),
            for (final c in collections)
              _Chip(
                key: Key('shop.collection.${_collectionKey(c)}'),
                label: _collectionLabel(c, language),
                dot: _collectionColor(c),
                on: filter.collection == c,
                onTap: () => onChanged(filter.copyWith(collection: () => filter.collection == c ? null : c)),
              ),
          ]),
        ],
        const SizedBox(height: 18),
        Center(
          child: TargaButton(
            key: const Key('shop.filters.clear'),
            label: strings.clearFilters,
            kind: TargaKind.secondary,
            compact: true,
            onPressed: filter.extra == 0 ? null : () => onChanged(filter.copyWith(rarity: () => null, collection: () => null)),
          ),
        ),
      ],
    );
  }
}

class _ReceiptDialog extends StatelessWidget {
  final ShopItem item;
  final int coins;
  final ShopStrings strings;
  final AppLanguage language;

  const _ReceiptDialog({required this.item, required this.coins, required this.strings, required this.language});

  @override
  Widget build(BuildContext context) {
    final name = item.name(language);
    final m = NoirMetrics.of(context);
    return NoirDialog(
      tone: NoirTone.paper,
      rim: rarityColor(item.rarity),
      overline: strings.rarity(item.rarity),
      title: strings.confirmTitle(name),
      body: strings.confirmBody(item.price, coins - item.price),
      onEnter: () => Navigator.of(context).pop(true),
      lead: item.brand == null
          ? null
          : Column(
              children: [
                SizedBox.square(dimension: m.desk ? 56 : 40, child: CustomPaint(painter: BrandMarkPainter(item.brand!, seal: true))),
                SizedBox(height: m.gap),
                Text(item.brand!.label.toUpperCase(), style: NoirType.overline(m, color: NoirInk.paperInk)),
                const SizedBox(height: 2),
                Text(strings.brandTagline(item.brand!), style: NoirType.small(m, color: NoirInk.paperBody).copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
      actions: [
        NoirAction(label: strings.notNow, feel: Press.back, onPressed: () => Navigator.of(context).pop(false)),
        NoirAction(
          key: const Key('shop.confirm'),
          label: strings.confirmYes,
          style: NoirButtonStyle.primary,
          feel: Press.chips,
          trailing: _PriceTag(item.price),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _BundleReceipt extends StatelessWidget {
  final ShopBundle bundle;
  final int price;
  final int saved;
  final int coins;
  final ShopStrings strings;
  final AppLanguage language;

  const _BundleReceipt({required this.bundle, required this.price, required this.saved, required this.coins, required this.strings, required this.language});

  @override
  Widget build(BuildContext context) => NoirDialog(
    tone: NoirTone.paper,
    rim: bundle.premium ? const Color(0xFFB8860B) : const Color(0xFF8C6A14),
    lead: _SaveTag(strings.save(bundle.discountPct)),
    title: strings.bundleConfirmTitle(bundle.name(language)),
    body: strings.bundleConfirmBody(price, saved, coins - price),
    onEnter: () => Navigator.of(context).pop(true),
    actions: [
      NoirAction(label: strings.notNow, feel: Press.back, onPressed: () => Navigator.of(context).pop(false)),
      NoirAction(
        key: const Key('shop.confirm'),
        label: strings.confirmYes,
        style: NoirButtonStyle.primary,
        feel: Press.chips,
        trailing: _PriceTag(price),
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
}

/// The price on the receipt's button: a coin and the number.
class _PriceTag extends StatelessWidget {
  final int price;
  const _PriceTag(this.price);

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: m.desk ? 20 : 15, child: const CustomPaint(painter: _Coin())),
        SizedBox(width: m.gap / 2),
        Text('$price', style: TextStyle(fontWeight: FontWeight.w900, fontSize: m.buttonText)),
      ],
    );
  }
}

/// A small coin, drawn like the purse's.
class _Coin extends CustomPainter {
  const _Coin();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF7A5A12));
    canvas.drawCircle(
      c,
      r * 0.88,
      Paint()
        ..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFFFFE9A0), AppColors.gold, Color(0xFF8C6A14)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_Coin old) => false;
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

/// The house's name with its mark, in small capitals.
class _BrandLabel extends StatelessWidget {
  final ShopBrand brand;
  final double size;
  const _BrandLabel({required this.brand, required this.size});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(dimension: size + 3, child: CustomPaint(painter: BrandMarkPainter(brand))),
      const SizedBox(width: 4),
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

/// The second line of a tag: class, house, time left or the saving.
class _TagLine extends StatelessWidget {
  final _Entry entry;
  final ShopStrings strings;
  final String? timer;
  final double scale;
  const _TagLine({required this.entry, required this.strings, this.timer, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final bundle = entry.bundle;
    final item = entry.item;
    return Wrap(
      spacing: 6 * scale,
      runSpacing: 4 * scale,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (bundle != null) ...[
          _SaveTag(strings.save(bundle.discountPct), scale: scale),
          if (bundle.premium) _RarityTag(ShopRarity.leggendario, strings.premium, scale: scale),
        ] else ...[
          _RarityTag(item!.rarity, strings.rarity(item.rarity), scale: scale),
          if (timer != null) _TimerBadge(timer!, scale: scale),
          if (item.brand case final brand? when timer == null) _BrandLabel(brand: brand, size: 9.5 * scale),
        ],
      ],
    );
  }
}
