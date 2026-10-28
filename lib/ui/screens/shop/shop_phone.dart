part of 'shop_screen.dart';

/// The phone shop: the department medallions under the sign, the player
/// big in the middle, the brass dial rising from the bottom edge with the
/// pieces on its rim, and the price tag right above the notch.
extension _Phone on _ShopScreenState {
  static const _step = 17.0 * pi / 180;

  Widget _phone() {
    final t = _t;
    final purseWidth = widget.onAddCoins == null ? 104.0 : 130.0;
    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      body: StreetBackdrop(
        section: StreetSection.shop,
        title: t.title,
        trailing: purseWidth,
        builder: (context, layout) {
          final now = DateTime.now();
          final entries = _entries(now);
          final index = _pickedIndex(entries);
          final picked = index < 0 ? null : entries[index];
          final w = layout.size.width;
          final h = layout.size.height;
          final disc = min(w, 460.0);
          final rim = disc - 58;
          final center = Offset(w / 2, h - layout.safe.bottom + disc * 0.38);
          final dialTop = center.dy - disc;
          final medalsTop = layout.neon.bottom + 2;
          const medalsHeight = 68.0;
          final hero = min(w * 1.1, dialTop + 46 - (medalsTop + medalsHeight + 4));
          final mid = layout.neon.center.dy;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // The street darkens toward the shop floor.
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x66000000), Color(0xEE07060A)],
                        stops: [0.12, 0.45, 0.78],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (w - hero) / 2,
                top: dialTop + 46 - hero,
                child: _Hero(entry: picked, look: _lookOf(picked), who: _shop.who, size: hero, frame: _heroFrame(picked)),
              ),
              Positioned(left: 0, right: 0, top: medalsTop, height: medalsHeight, child: _medals(now)),
              Positioned(
                left: 0,
                top: dialTop,
                width: w,
                height: h - dialTop,
                child: _dial(entries, index, Offset(center.dx, center.dy - dialTop), disc, rim, now),
              ),
              Positioned(left: 12, right: 12, bottom: h - dialTop + 6, child: _tag(picked, now)),
              Positioned(left: 8, top: mid - 23, child: const TargaBackButton(key: Key('shop.back'), size: 46)),
              Positioned(
                right: 8,
                top: mid - 19,
                child: CoinPurse(key: const Key('shop.coins'), coins: _shop.coins, onAdd: widget.onAddCoins, hint: t.coinsHint),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Hats and faces close up; suits, vices and whole looks from further
  /// back, so the shoulders clear the price tag.
  Rect _heroFrame(_Entry? entry) {
    final slot = entry?.item?.slot;
    final wide = entry?.bundle != null || slot == 'outfit' || slot == 'accessory';
    return wide ? const Rect.fromLTWH(-0.3, -0.12, 1.6, 1.6) : const Rect.fromLTWH(-0.15, -0.08, 1.3, 1.3);
  }

  /// One medallion per department: what is worn there, or its sign.
  Widget _medals(DateTime now) {
    final t = _t;
    final ends = _shop.windowEnds(now);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final dept in ShopDept.values)
          _Medal(
            key: Key('shop.dept.${dept.name}'),
            dept: dept,
            label: t.dept(dept),
            worn: _shop.wornIn(dept),
            look: _shop.look,
            on: dept == _dept,
            badge: dept == ShopDept.window && ends != null ? t.timeLeft(ends.difference(now)).split(' ').first : null,
            onTap: () => _openDept(dept),
          ),
      ],
    );
  }

  Widget _tag(_Entry? entry, DateTime now) {
    final t = _t;
    if (entry == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xE60C0907), borderRadius: BorderRadius.circular(14)),
          child: Text(t.emptyShelf, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ),
      );
    }
    final timer = entry.feature == null ? null : t.timeLeft(entry.feature!.endsAt.difference(now));
    return Container(
      key: const Key('shop.tag'),
      padding: const EdgeInsets.fromLTRB(14, 8, 7, 8),
      decoration: BoxDecoration(
        color: const Color(0xEB0C0907),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Targa.brassDim.withValues(alpha: 0.8)),
        boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FitName(entry.name(_language), size: 18),
                const SizedBox(height: 5),
                _TagLine(entry: entry, strings: t, timer: timer),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _action(entry, height: 48, short: true),
        ],
      ),
    );
  }

  /// The dial: the pieces on its rim, the notch, and on its face the
  /// sections or the filters. A sideways drag turns it.
  Widget _dial(List<_Entry> entries, int index, Offset c, double disc, double rim, DateTime now) {
    final n = entries.length;
    final turn = n == 0 ? 0.0 : (_turn < 0 ? index.toDouble() : _turn.clamp(0, n - 1).toDouble());
    final perItem = rim * _step;
    // The state, not [turn]: several moves can come in one frame.
    double current() => n == 0 ? 0.0 : (_turn < 0 ? index.toDouble() : _turn.clamp(0, n - 1).toDouble());
    void drag(double dx) {
      if (n < 2) return;
      final next = (current() - dx / perItem).clamp(0.0, n - 1.0);
      final near = next.round();
      _update(() {
        _turn = next;
        _pick = entries[near].key;
      });
    }

    void settle(double velocity) {
      if (n == 0) return;
      final near = (current() - velocity / perItem * 0.12).clamp(0.0, n - 1.0).round();
      _choose(entries[near], turn: near.toDouble());
    }

    final thumbs = <Widget>[];
    final first = max(0, turn.round() - 4);
    final last = min(n - 1, turn.round() + 4);
    for (var i = first; i <= last; i++) {
      final a = (i - turn) * _step;
      if (a.abs() > 62 * pi / 180) continue;
      final on = i == index;
      final side = on ? 80.0 : 58.0;
      final at = c + Offset(sin(a) * rim, -cos(a) * rim);
      final entry = entries[i];
      thumbs.add(
        Positioned(
          left: at.dx - side / 2,
          top: at.dy - side / 2,
          child: GestureDetector(
            key: entry.widgetKey,
            onTap: pressed(() => _choose(entry, turn: i.toDouble()), Press.toggle),
            child: Transform.rotate(angle: a * 0.6, child: _RimThumb(entry: entry, shop: _shop, look: _lookOf(entry), side: side, on: on)),
          ),
        ),
      );
    }
    return GestureDetector(
      key: const Key('shop.dial'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => drag(d.delta.dx),
      onHorizontalDragEnd: (d) => settle(d.primaryVelocity ?? 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: c.dx - disc,
            top: c.dy - disc,
            width: disc * 2,
            height: disc * 2,
            child: const RepaintBoundary(child: CustomPaint(painter: _DialPainter())),
          ),
          ...thumbs,
          Positioned(left: c.dx - 12, top: -6, child: const CustomPaint(size: Size(24, 18), painter: _NotchPainter())),
          Positioned(left: 0, right: 0, top: c.dy - rim + 82, child: _dialFace(entries, now)),
        ],
      ),
    );
  }

  /// On the dial's face: the window's sections, or the filters of a shelf,
  /// and a line under them (time left, or how many pieces show).
  Widget _dialFace(List<_Entry> entries, DateTime now) {
    final t = _t;
    final List<Widget> chips;
    final String caption;
    if (_dept == ShopDept.window) {
      final open = _openSection(now);
      chips = [
        for (final s in _sections(now))
          _Chip(
            key: Key('shop.section.${s.name}'),
            label: switch (s) {
              _WindowSection.featured => t.featured,
              _WindowSection.sets => t.bundlesHeading,
              _WindowSection.luxe => t.premiumHeading,
            },
            on: s == open,
            scale: 0.9,
            onTap: () => _openSectionTap(s),
          ),
      ];
      final ends = _shop.windowEnds(now);
      caption = open == _WindowSection.featured && ends != null
          ? '${t.pieces(entries.length)}  ·  ${t.endsIn(max(1, ends.difference(now).inHours ~/ 24 + 1))}'
          : t.pieces(entries.length);
    } else {
      chips = [
        for (final o in ShopOwnership.values)
          _Chip(
            key: Key('shop.filter.${o.name}'),
            label: t.ownership(o),
            on: _filter.own == o,
            onTap: () => _setFilter(_filter.copyWith(own: o)),
          ),
        TargaIconButton(key: const Key('shop.filters'), icon: Icons.tune, size: 36, badge: _filter.extra, tooltip: t.filters, onPressed: _openFilters),
        if (_dept == ShopDept.face && widget.onChangeFace != null)
          TargaIconButton(key: const Key('shop.changeFace'), icon: Icons.face_retouching_natural, size: 36, tooltip: t.changeFace, onPressed: widget.onChangeFace),
      ];
      caption = t.count(entries.length, _deptAll().length);
    }
    return Column(
      children: [
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 7, runSpacing: 6, children: chips),
        const SizedBox(height: 8),
        Text(caption, key: const Key('shop.count'), style: const TextStyle(color: Color(0xFF9A8A78), fontSize: 11.5, letterSpacing: 0.4)),
      ],
    );
  }
}

/// A department medallion.
class _Medal extends StatelessWidget {
  final ShopDept dept;
  final String label;
  final ShopItem? worn;
  final AvatarLook look;
  final bool on;
  final String? badge;
  final VoidCallback onTap;
  final double side;

  const _Medal({
    super.key,
    required this.dept,
    required this.label,
    required this.worn,
    required this.look,
    required this.on,
    required this.onTap,
    this.badge,
    this.side = 46,
  });

  static IconData iconOf(ShopDept dept) => switch (dept) {
    ShopDept.window => Icons.star_rounded,
    ShopDept.hats => Icons.school_outlined,
    ShopDept.face => Icons.visibility_outlined,
    ShopDept.outfit => Icons.checkroom,
    ShopDept.vice => Icons.local_fire_department_outlined,
    ShopDept.frames => Icons.crop_portrait,
    ShopDept.gestures => Icons.waving_hand_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final item = worn;
    final face = item != null && !item.around
        ? DecoratedBox(
            decoration: _thumbGround(item.rarity),
            child: CustomPaint(painter: _ZoomBustPainter(look, focus: _focusOf(_Entry.item(item))), child: const SizedBox.expand()),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: on ? const [Color(0xFF5A2A10), Color(0xFF1A0E08)] : const [Color(0xFF2A1F17), Color(0xFF0E0A08)]),
            ),
            child: Icon(iconOf(dept), color: on ? const Color(0xFFFFD27A) : Targa.brassDim, size: side * 0.46),
          );
    return GestureDetector(
      onTap: pressed(onTap, Press.toggle),
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        child: SizedBox(
          width: side + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: side,
                    height: side,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: on ? const [Color(0xFFFFE7A8), Color(0xFFD9B45A), Color(0xFF9C7424)] : const [Color(0xFF7A5E2A), Color(0xFF3A2C14)],
                      ),
                      boxShadow: [
                        const BoxShadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 4)),
                        if (on) const BoxShadow(color: Color(0x88FFB443), blurRadius: 14),
                      ],
                    ),
                    child: ClipOval(child: face),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE07A1F),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Targa.ink, width: 1.2),
                        ),
                        child: Text(badge!, style: const TextStyle(color: Color(0xFF1A0E04), fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  style: TextStyle(
                    color: on ? _cream : AppColors.textSecondary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
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

/// A piece or a bundle on the dial's rim.
class _RimThumb extends StatelessWidget {
  final _Entry entry;
  final ShopController shop;
  final AvatarLook look;
  final double side;
  final bool on;
  const _RimThumb({required this.entry, required this.shop, required this.look, required this.side, required this.on});

  @override
  Widget build(BuildContext context) {
    final owned = entry.item != null ? shop.stateOf(entry.item!) != ItemState.forSale : shop.bundleComplete(entry.bundle!);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: side,
          height: side,
          padding: EdgeInsets.all(on ? 3.5 : 2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? AppColors.gold : rarityColor(entry.rarity).withValues(alpha: 0.85),
            boxShadow: [
              const BoxShadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 4)),
              if (on) const BoxShadow(color: Color(0x99FFB443), blurRadius: 18),
            ],
          ),
          child: ClipOval(
            child: DecoratedBox(
              decoration: _thumbGround(entry.rarity),
              child: _EntryArt(entry: entry, look: look, who: shop.who),
            ),
          ),
        ),
        if (entry.feature != null)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(color: const Color(0xFFE07A1F), shape: BoxShape.circle, border: Border.all(color: Targa.ink, width: 1.5)),
              child: const Icon(Icons.schedule, size: 12, color: Color(0xFF1A0E04)),
            ),
          ),
        if (owned)
          Positioned(
            left: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(color: Targa.ink, shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 1.5)),
              child: const Icon(Icons.check, size: 12, color: AppColors.gold),
            ),
          ),
      ],
    );
  }
}

/// The dial: dark enamel with a brass rim and safe ticks. It never changes,
/// so it sits behind its own repaint boundary.
class _DialPainter extends CustomPainter {
  const _DialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c.translate(0, -6), r + 4, Paint()
      ..color = const Color(0xAA000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawCircle(c, r, Paint()
      ..shader = const SweepGradient(colors: [Color(0xFFFFE29A), Color(0xFF8C6A14), Color(0xFFC9A227), Color(0xFF5A420C), Color(0xFFFFE29A)])
          .createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r - 6, Paint()
      ..shader = const RadialGradient(colors: [Color(0xFF0C0907), Color(0xFF1E1510), Color(0xFF2A1D14)], stops: [0.5, 0.86, 1])
          .createShader(Rect.fromCircle(center: c, radius: r)));
    final tick = Paint()
      ..color = const Color(0x55D9B45A)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 120; i++) {
      final a = i * 2 * pi / 120;
      final d = Offset(sin(a), -cos(a));
      canvas.drawLine(c + d * (r - 11), c + d * (r - (i % 5 == 0 ? 20 : 15)), tick);
    }
    canvas.drawCircle(c, r - 150, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x44D9B45A));
  }

  @override
  bool shouldRepaint(_DialPainter old) => false;
}

class _NotchPainter extends CustomPainter {
  const _NotchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p.shift(const Offset(0, 2)), Paint()..color = const Color(0xAA000000));
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFE29A));
    canvas.drawPath(p, Paint()
      ..style = PaintingStyle.stroke
      ..color = Targa.brassDim);
  }

  @override
  bool shouldRepaint(_NotchPainter old) => false;
}
