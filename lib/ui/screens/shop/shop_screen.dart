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

const _slots = ['hat', 'face', 'glasses', 'outfit', 'accessory'];

/// La targhetta in più, dopo i posti: le case di moda.
const _brands = 'brands';
const _cream = Color(0xFFF2E6CF);
const _wood = Color(0xFF4A2C1A);

/// La bottega: il retrobottega di un sarto e cappellaio degli anni '40. Il
/// padrone dietro il bancone, lo specchio dove ci si prova il pezzo prima di
/// comprarlo, gli scaffali per posto e, in alto, la vetrina della settimana.
/// Dall'altra linguetta, il guardaroba: si cambia quello che si possiede.
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
  String _slot = 'hat';
  bool _wardrobe = false;

  /// La casa scelta sotto la targhetta delle firme, o null per tutte.
  ShopBrand? _brand;

  @override
  void dispose() {
    _shop.dispose();
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

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: const Color(0xFF120E0B),
      body: ListenableBuilder(
        listenable: _shop,
        builder: (context, _) => SafeArea(
          child: Column(
            children: [
              _header(t),
              _stage(t),
              if (!_wardrobe && _shop.window.isNotEmpty) _window(t),
              _tabs(t),
              _shelfSigns(t),
              if (_slot == _brands) _brandRow(t),
              Expanded(child: _shelves(t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ShopStrings t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 14, 2),
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
              Text(t.title, style: AppText.display(20)),
              const SizedBox(height: 2),
              Text(
                t.subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
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

  /// Il retrobottega: la carta da parati, il padrone, lo specchio e il bancone.
  Widget _stage(ShopStrings t) {
    final language = AppStrings.of(context).language;
    final trying = _shop.trying;
    final line = trying == null ? t.greeting : '${trying.name(language)} · ${t.rarity(trying.rarity)}';
    return SizedBox(
      height: 262,
      child: ClipRect(
        child: CustomPaint(
          painter: const _BackRoomPainter(),
          child: Stack(
            children: [
              // Il padrone, dietro il bancone a destra.
              Positioned(
                right: 6,
                bottom: 54,
                width: 132,
                height: 132,
                child: CustomPaint(painter: _BustPainter(ShopScreen.shopkeeper)),
              ),
              Positioned(
                right: 12,
                top: 14,
                width: 168,
                child: _SpeechCard(
                  text: line,
                  caption: trying == null ? null : [t.tryingOn, ?trying.brand?.label].join(' · '),
                  color: trying == null ? null : rarityColor(trying.rarity),
                ),
              ),
              // Lo specchio, a sinistra, con chi guarda dentro.
              Positioned(
                left: 18,
                top: 8,
                width: 146,
                bottom: 50,
                child: _Mirror(look: _shop.mirror, brand: trying?.brand),
              ),
              // Il bancone, e sopra il bottone.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 58,
                child: CustomPaint(painter: const _CounterPainter()),
              ),
              Positioned(right: 16, bottom: 12, left: 186, child: _actionButton(t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(ShopStrings t) {
    final item = _shop.trying;
    final busy = _shop.busy;
    if (item == null) {
      return Text(
        _wardrobe ? t.emptyWardrobe : t.coinsHint,
        maxLines: 2,
        textAlign: TextAlign.right,
        style: TextStyle(color: _cream.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic, height: 1.25),
      );
    }
    final state = _shop.stateOf(item);
    final (label, action, price) = switch (state) {
      ItemState.forSale => (t.buy, () => _buy(item), item.price),
      ItemState.owned => (t.wear, () => _run(() => _shop.equip(item)), null),
      ItemState.worn =>
        item.free ? (t.worn, null, null) : (t.takeOff, () => _run(() => _shop.unequip(item.slot)), null),
    };
    return Align(
      alignment: Alignment.centerRight,
      child: _BrassButton(
        key: const Key('shop.action'),
        label: label,
        price: price,
        onTap: busy || action == null ? null : action,
      ),
    );
  }

  Widget _window(ShopStrings t) {
    final language = AppStrings.of(context).language;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.featured, style: AppText.overline.copyWith(color: AppColors.gold, fontSize: 11)),
          const SizedBox(height: 6),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (item, feature) in _shop.window)
                  _WindowCard(
                    key: Key('shop.featured.${item.id}'),
                    item: item,
                    look: _shop.tryOn(item),
                    name: item.name(language),
                    ends: t.endsIn(max(1, feature.endsAt.difference(now).inHours ~/ 24 + 1)),
                    state: _shop.stateOf(item),
                    strings: t,
                    selected: _shop.trying?.id == item.id,
                    onTap: () {
                      setState(() => _slot = item.slot);
                      _shop.preview(item);
                    },
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(ShopStrings t) {
    Widget tab(String label, bool wardrobe) {
      final on = _wardrobe == wardrobe;
      return Expanded(
        child: GestureDetector(
          key: Key(wardrobe ? 'shop.tab.wardrobe' : 'shop.tab.counter'),
          behavior: HitTestBehavior.opaque,
          onTap: pressed(() {
            setState(() => _wardrobe = wardrobe);
            _shop.preview(null);
          }, Press.toggle),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: on ? AppColors.gold : Colors.white12, width: on ? 2 : 1),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.display(13, color: on ? AppColors.gold : AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(children: [tab(t.counterTab, false), tab(t.wardrobeTab, true)]),
    );
  }

  /// Le targhette di legno appese sopra gli scaffali, una per posto.
  Widget _shelfSigns(ShopStrings t) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
    child: Row(
      children: [
        for (final slot in [..._slots, _brands])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: GestureDetector(
                key: Key('shop.slot.$slot'),
                onTap: pressed(() => setState(() => _slot = slot), Press.toggle),
                child: _ShelfSign(
                  label: slot == _brands ? t.brands : t.slot(slot),
                  on: _slot == slot,
                  gilded: slot == _brands,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /// Le insegne delle case, sotto la targhetta delle firme: si sceglie una
  /// casa, o tutte.
  Widget _brandRow(ShopStrings t) => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      children: [
        for (final brand in [null, ...ShopBrand.values])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              key: Key('shop.brand.${brand?.name ?? 'all'}'),
              onTap: pressed(() => setState(() => _brand = brand), Press.toggle),
              child: _BrandChip(
                brand: brand,
                label: brand?.label ?? t.allBrands,
                tagline: brand == null ? null : t.brandTagline(brand),
                on: _brand == brand,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _shelves(ShopStrings t) {
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
    final items = _slot == _brands
        ? _shop.branded(_brand, wardrobe: _wardrobe)
        : _wardrobe
        ? _shop.wardrobe(_slot)
        : _shop.forSale(_slot);
    return CustomPaint(
      painter: const _ShelfWallPainter(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return _ItemTile(
            key: Key('shop.item.${item.id}'),
            item: item,
            look: _shop.tryOn(item),
            name: item.name(language),
            state: _shop.stateOf(item),
            strings: t,
            selected: _shop.trying?.id == item.id,
            onTap: () => _shop.preview(_shop.trying?.id == item.id ? null : item),
          );
        },
      ),
    );
  }
}

/// Il saldo delle monete, con la stessa moneta del cartellino nel vicolo.
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
                    style: TextStyle(color: brand.color, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.2),
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

  const _SpeechCard({required this.text, this.caption, this.color});

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
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.6),
          ),
        Text(
          text,
          key: const Key('shop.speech'),
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: ['serif'],
            color: Color(0xFF2A1A10),
            fontSize: 12.5,
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

  const _BrassButton({super.key, required this.label, this.price, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: pressed(onTap),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(14, color: const Color(0xFF2A1A08)),
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
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
    decoration: BoxDecoration(
      color: gilded
          ? (on ? const Color(0xFF2A2116) : const Color(0xFF14110D))
          : (on ? const Color(0xFF6B4226) : const Color(0xFF2E1D12)),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(
        color: on || gilded ? AppColors.gold : const Color(0xFF5A3A22),
        width: on ? 1.5 : 1,
      ),
      boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 3, offset: Offset(0, 2))],
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        style: TextStyle(
          color: gilded ? AppColors.gold : (on ? _cream : AppColors.textSecondary),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    ),
  );
}

/// Lo stato o il prezzo, sotto il pezzo.
class _PriceTag extends StatelessWidget {
  final ShopItem item;
  final ItemState state;
  final ShopStrings strings;

  const _PriceTag({required this.item, required this.state, required this.strings});

  @override
  Widget build(BuildContext context) {
    if (state == ItemState.forSale) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 11, child: CustomPaint(painter: CoinPainter())),
          const SizedBox(width: 3),
          Text(
            '${item.price}',
            style: const TextStyle(color: _cream, fontWeight: FontWeight.w800, fontSize: 11.5),
          ),
        ],
      );
    }
    final worn = state == ItemState.worn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: worn ? AppColors.gold : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.gold),
      ),
      child: Text(
        worn ? strings.worn : (item.free ? strings.free : strings.owned),
        style: TextStyle(
          color: worn ? const Color(0xFF2A1A08) : AppColors.gold,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final ShopItem item;
  final AvatarLook look;
  final String name;
  final ItemState state;
  final ShopStrings strings;
  final bool selected;
  final VoidCallback onTap;

  const _ItemTile({
    super.key,
    required this.item,
    required this.look,
    required this.name,
    required this.state,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(item.rarity);
    return GestureDetector(
      onTap: pressed(onTap, Press.toggle),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: const Color(0xFF241812),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.45), width: selected ? 2.2 : 1.2),
          boxShadow: [
            if (selected) BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12),
            const BoxShadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: CustomPaint(painter: AvatarBustPainter(look), child: const SizedBox.expand()),
                    ),
                  ),
                  if (item.brand case final brand?)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: SizedBox.square(dimension: 16, child: CustomPaint(painter: BrandMarkPainter(brand, seal: true))),
                    ),
                ],
              ),
            ),
            // La mensola su cui posa il pezzo.
            Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 4), color: _wood),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
              child: Column(
                children: [
                  if (item.brand case final brand?) _BrandLabel(brand: brand, size: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _cream, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  _PriceTag(item: item, state: state, strings: strings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowCard extends StatelessWidget {
  final ShopItem item;
  final AvatarLook look;
  final String name;
  final String ends;
  final ItemState state;
  final ShopStrings strings;
  final bool selected;
  final VoidCallback onTap;

  const _WindowCard({
    super.key,
    required this.item,
    required this.look,
    required this.name,
    required this.ends,
    required this.state,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(item.rarity);
    return GestureDetector(
      onTap: pressed(onTap, Press.toggle),
      child: Container(
        width: 196,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.28), const Color(0xFF1E1612)]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.6), width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            SizedBox.square(dimension: 60, child: CustomPaint(painter: AvatarBustPainter(look))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.brand case final brand?)
                    _BrandLabel(brand: brand, size: 9)
                  else
                    Text(
                      strings.rarity(item.rarity).toUpperCase(),
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.4),
                    ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _cream, fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _PriceTag(item: item, state: state, strings: strings),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          ends,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 9.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
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
      SizedBox.square(dimension: size + 3, child: CustomPaint(painter: BrandMarkPainter(brand))),
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

/// L'insegna di una casa nella fila delle firme.
class _BrandChip extends StatelessWidget {
  final ShopBrand? brand;
  final String label;
  final String? tagline;
  final bool on;

  const _BrandChip({required this.brand, required this.label, required this.tagline, required this.on});

  @override
  Widget build(BuildContext context) {
    final color = brand?.color ?? AppColors.gold;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(
        color: on ? const Color(0xFF2A2116) : const Color(0xFF17120E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: on ? color : color.withValues(alpha: 0.35), width: on ? 1.5 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (brand case final brand?) ...[
            SizedBox.square(dimension: 24, child: CustomPaint(painter: BrandMarkPainter(brand, seal: true))),
            const SizedBox(width: 6),
          ],
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
              ),
              if (tagline case final tagline?)
                Text(
                  tagline,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 8.5, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
