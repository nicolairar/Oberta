part of 'profile_sheet.dart';

/// Sul desktop il fascicolo non sale dal fondo come sul telefono: si apre
/// sul tavolo, al centro dello schermo, come una cartellina spalancata.
/// A sinistra la foto segnaletica e le generalità, a destra i conti e i
/// casi chiusi. Esc o un clic fuori la richiudono.
Future<void> _showDeskDossier(
  BuildContext context, {
  required OnlineAccount account,
  VoidCallback? onMirror,
  VoidCallback? onShop,
  VoidCallback? onSettings,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0xCC050404),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, _) => DeskTheme(
      child: DeskEscape(
        onEscape: () => Navigator.of(context).maybePop(),
        child: Center(
          child: SizedBox(
            width: _DeskDossier.width,
            height: _DeskDossier.height,
            child: Material(
              type: MaterialType.transparency,
              child: ListenableBuilder(
                listenable: account,
                builder: (context, _) => switch (account.profile) {
                  final profile? => _Dossier(
                    account: account,
                    profile: profile,
                    onMirror: onMirror,
                    onShop: onShop,
                    onSettings: onSettings,
                  ),
                  null => const _DeskFolder(
                    left: Center(child: CircularProgressIndicator(color: _ink)),
                    right: SizedBox.shrink(),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// La cartellina aperta: cartone kraft con la linguetta, due fogli
/// affiancati e la piega in mezzo. In alto a destra la crocetta per
/// chiuderla.
class _DeskFolder extends StatelessWidget {
  final Widget left;
  final Widget right;
  final String? tab;

  /// Le linguette delle pagine, accanto alla crocetta.
  final Widget? index;

  const _DeskFolder({required this.left, required this.right, this.tab, this.index});

  static const tabHeight = 52.0;
  static const leftWidth = 640.0;

  static const _sheet = BoxDecoration(
    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_paper, _paperDark]),
    borderRadius: BorderRadius.all(Radius.circular(4)),
    boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 4))],
  );

  @override
  Widget build(BuildContext context) => Stack(
    key: const Key('profile.dossier'),
    children: [
      const Positioned.fill(
        child: CustomPaint(painter: _FolderPainter(tabHeight: tabHeight, tabWidth: 380)),
      ),
      if (tab case final tab?)
        Positioned(
          left: 52,
          top: 14,
          child: Text(
            tab,
            style: _typed.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: _ink.withValues(alpha: 0.78),
            ),
          ),
        ),
      if (index case final index?) Positioned(right: 96, top: tabHeight + 18 - 46, child: index),
      Positioned(right: 16, top: 0, child: _DeskClose(onTap: () => Navigator.of(context).maybePop())),
      Positioned.fill(
        top: tabHeight + 18,
        left: 22,
        right: 22,
        bottom: 22,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftWidth,
              child: Transform.rotate(
                angle: -0.004,
                child: DecoratedBox(
                  decoration: _sheet,
                  child: ClipRect(child: left),
                ),
              ),
            ),
            // La piega del cartone, tra i due fogli.
            Container(
              width: 26,
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x00000000), Color(0x44000000), Color(0x00000000)]),
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: _sheet,
                child: ClipRect(child: right),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// La crocetta d'ottone che richiude il fascicolo.
class _DeskClose extends StatelessWidget {
  final VoidCallback onTap;

  const _DeskClose({required this.onTap});

  @override
  Widget build(BuildContext context) => DeskHover(
    key: const Key('profile.close'),
    onTap: onTap,
    tooltip: 'Esc',
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: hovered ? const [Color(0xFF5C4130), Color(0xFF34241A)] : const [Color(0xFF4A3426), Color(0xFF2A1C14)],
        ),
        border: Border.all(color: _brass.withValues(alpha: hovered ? 1 : 0.7), width: 1.4),
        boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Icon(Icons.close, color: hovered ? const Color(0xFFFBE7A6) : _brass, size: 24),
    ),
  );
}

class _DeskDossier extends StatelessWidget {
  static const width = 1640.0;
  static const height = 940.0;

  final _DossierState host;
  final String number;

  const _DeskDossier({required this.host, required this.number});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final t = strings.online;
    final profile = host.widget.profile;
    final next = Profile.xpToNext(profile.level);
    final history = host._history;
    final tier = host._tier;

    final left = Padding(
      padding: const EdgeInsets.fromLTRB(44, 38, 44, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.dossierTitle,
                    style: _typed.copyWith(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4),
                  ),
                  Container(height: 3, color: _ink, margin: const EdgeInsets.only(top: 10)),
                  Container(height: 1.2, color: _ink, margin: const EdgeInsets.only(top: 3)),
                ],
              ),
              Positioned(
                right: -6,
                top: -12,
                child: IgnorePointer(child: _Stamp(text: t.dossierConfidential, angle: 0.12, size: 20)),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Mugshot(profile: profile, width: 300),
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _Field(t.dossierName, size: 15),
                    const SizedBox(height: 4),
                    _TypedLine(text: profile.name.isEmpty ? t.pickHandle : profile.name, size: 32),
                    const SizedBox(height: 30),
                    _Field(t.dossierRank, size: 15),
                    const SizedBox(height: 10),
                    _LevelSeal(
                      key: const Key('profile.level'),
                      level: profile.level,
                      label: t.levelShort(profile.level),
                      size: 104,
                    ),
                    if (tier != null) ...[
                      const SizedBox(height: 18),
                      _Stamp(text: t.tierName(tier).toUpperCase(), angle: -0.06, color: _ink, size: 20),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // Il cartellino delle impronte, come in ogni fascicolo di questura.
          SizedBox(
            height: 96,
            child: CustomPaint(
              painter: _FingerprintsPainter(profile.avatarSeed.codeUnits.fold(7, (a, b) => a * 31 + b & 0xFFFFFF)),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Field(t.dossierExperience, size: 15),
              const Spacer(),
              Text(
                '${profile.xp} / $next XP',
                key: const Key('profile.xpNumbers'),
                style: _typed.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _XpBar(key: const Key('profile.xp'), progress: profile.levelProgress, height: 32),
          const SizedBox(height: 10),
          Text(
            t.xpProgress(profile.xp, next),
            style: _typed.copyWith(fontSize: 18, color: _ink.withValues(alpha: 0.72)),
          ),
        ],
      ),
    );

    final won = history?.where((m) => m.won && !m.abandoned).length ?? 0;
    final lost = history?.where((m) => !m.won && !m.abandoned).length ?? 0;
    final plates = <Widget>[
      _DeskPlate(
        key: const Key('profile.mirror'),
        label: SettingsStrings.of(context).changeLook,
        icon: const SizedBox.square(dimension: 30, child: CustomPaint(painter: BarberPoleIconPainter())),
        onTap: host._mirror,
      ),
      if (host.widget.onShop case final onShop?)
        _DeskPlate(
          key: const Key('profile.shop'),
          label: strings.shop.homeSign,
          icon: const SizedBox.square(dimension: 32, child: CustomPaint(painter: ShopIconPainter())),
          onTap: () => host._then(onShop),
        ),
      if (host.widget.onSettings case final onSettings?)
        _DeskPlate(
          key: const Key('profile.settings'),
          label: t.dossierSettings,
          icon: const Icon(Icons.settings, color: _brass, size: 28),
          onTap: () => host._then(onSettings),
        ),
      _DeskPlate(
        key: const Key('profile.signOut'),
        label: t.signOut,
        icon: const Icon(Icons.logout, color: _ink, size: 26),
        dim: true,
        onTap: () async {
          final navigator = Navigator.of(context);
          try {
            await host.widget.account.services.auth.signOut();
            navigator.pop();
          } catch (error) {
            if (context.mounted) showFailure(context, error);
          }
        },
      ),
    ];

    final right = Padding(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(t.coins, size: 15),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox.square(dimension: 48, child: CustomPaint(painter: CoinPainter())),
              const SizedBox(width: 18),
              Flexible(
                child: Text(
                  '${profile.coins}',
                  key: const Key('profile.coins'),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: _typed.copyWith(fontSize: 50, fontWeight: FontWeight.w900, height: 1),
                ),
              ),
            ],
          ),
          Container(
            height: 1.2,
            color: _ink.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(top: 22, bottom: 34),
          ),
          Row(
            children: [
              Expanded(child: _Heading(t.dossierHistory, size: 20)),
              if (history != null && history.isNotEmpty) ...[
                const SizedBox(width: 18),
                _Tally(label: t.resultsWon, count: won, color: const Color(0xFF2E5E2A)),
                const SizedBox(width: 12),
                _Tally(label: t.resultsLost, count: lost, color: _stamp),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: switch (history) {
              null => const Center(
                child: SizedBox.square(dimension: 32, child: CircularProgressIndicator(strokeWidth: 3, color: _ink)),
              ),
              [] => Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(t.dossierNoHistory, style: _typed.copyWith(fontStyle: FontStyle.italic, fontSize: 20)),
              ),
              final history => SingleChildScrollView(
                child: Column(
                  children: [for (final match in history) _CaseRow(match: match, strings: strings, scale: 1.45)],
                ),
              ),
            },
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, box) {
              const gap = 16.0;
              final columns = plates.length <= 2 ? plates.length : 2;
              final width = (box.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final plate in plates) SizedBox(width: width, child: plate)],
              );
            },
          ),
        ],
      ),
    );

    final (statsLeft, statsRight) = host._page == 1 ? _deskStatsSheets(host, context) : (null, null);
    return _DeskFolder(
      tab: 'N. $number',
      index: _IndexTabs(page: host._page, onPage: host._openPage, scale: 1.4),
      left: _PageTurn(page: host._page, child: statsLeft ?? left),
      right: _PageTurn(page: host._page, child: statsRight ?? right),
    );
  }
}

/// Un piccolo conteggio a timbro: quante vinte, quante perse.
class _Tally extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _Tally({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.75), width: 2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$count ',
            style: _typed.copyWith(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          TextSpan(
            text: label.toUpperCase(),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.4),
          ),
        ],
      ),
    ),
  );
}

/// La targa di cuoio del desktop: più alta, e col puntatore sopra si
/// scalda (cuoio più chiaro, ottone acceso, la freccia che avanza).
class _DeskPlate extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool dim;

  const _DeskPlate({super.key, required this.label, required this.icon, required this.onTap, this.dim = false});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: DeskHover(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: dim ? (hovered ? _ink.withValues(alpha: 0.08) : null) : null,
          gradient: dim
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: hovered
                      ? const [Color(0xFF62452F), Color(0xFF38261A)]
                      : const [Color(0xFF4A3426), Color(0xFF2A1C14)],
                ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: dim ? _ink.withValues(alpha: hovered ? 0.9 : 0.55) : _brass.withValues(alpha: hovered ? 1 : 0.75),
            width: hovered ? 2 : 1.4,
          ),
          boxShadow: dim
              ? null
              : [
                  BoxShadow(
                    color: hovered ? const Color(0x55D9B04C) : const Color(0x88000000),
                    blurRadius: hovered ? 14 : 5,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            SizedBox(width: 36, child: Center(child: icon)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dim ? _ink : (hovered ? const Color(0xFFFFE6A0) : const Color(0xFFF3D27A)),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.8,
                ),
              ),
            ),
            AnimatedSlide(
              duration: const Duration(milliseconds: 140),
              offset: Offset(hovered ? 0.25 : 0, 0),
              child: Icon(Icons.chevron_right, color: dim ? _ink : _brass, size: 28),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Il cartellino delle dieci dita (qui cinque): caselle a righe sottili e
/// dentro le impronte a inchiostro, ognuna un po' diversa.
class _FingerprintsPainter extends CustomPainter {
  final int seed;

  const _FingerprintsPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    const count = 5;
    final cell = size.width / count;
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _ink.withValues(alpha: 0.45);
    canvas.drawRect(Offset.zero & size, frame);
    for (var i = 1; i < count; i++) {
      canvas.drawLine(Offset(cell * i, 0), Offset(cell * i, size.height), frame);
    }
    final rng = math.Random(seed);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final c = Offset(
        cell * (i + 0.5) + (rng.nextDouble() - 0.5) * 8,
        size.height * 0.5 + (rng.nextDouble() - 0.5) * 6,
      );
      final tilt = (rng.nextDouble() - 0.5) * 0.5;
      final alpha = 0.42 + rng.nextDouble() * 0.2;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(tilt);
      for (var r = 0; r < 13; r++) {
        final w = 6.0 + r * 4.4;
        final h = 8.0 + r * 5.4;
        final start = math.pi * (0.9 + rng.nextDouble() * 0.25);
        final sweep = math.pi * (1.1 + rng.nextDouble() * 0.6);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(0, r * 0.6), width: w, height: h),
          start,
          sweep,
          false,
          ink
            ..strokeWidth = 1.8
            ..color = _ink.withValues(alpha: alpha * (1 - r * 0.045)),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FingerprintsPainter old) => old.seed != seed;
}
