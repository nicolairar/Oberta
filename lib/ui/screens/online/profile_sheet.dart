import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/settings_strings.dart';
import '../../../l10n/progress_strings.dart';
import '../../../l10n/stats_strings.dart';
import '../../../online/online_account.dart';
import '../../../online/online_services.dart';
import '../../../rules/role.dart';
import '../../avatar/avatar_look.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import '../../theme/role_style.dart';
import '../../widgets/home_account.dart';
import '../../widgets/platform_marks.dart';
import '../../widgets/player_avatar.dart';
import '../avatar/barber_mirror_screen.dart';
import 'online_widgets.dart';
import 'progress_hooks.dart';

part 'profile_dossier_desktop.dart';
part 'profile_public.dart';
part 'profile_stats.dart';

/// La cartellina di cartone kraft e il foglio dattiloscritto dentro.
const _kraft = Color(0xFFC79E5C);
const _kraftDark = Color(0xFF9E7738);
const _paper = Color(0xFFF1E7CE);
const _paperDark = Color(0xFFE2D3AE);
const _ink = Color(0xFF2A1E16);
const _stamp = Color(0xFFA3242C);
const _brass = Color(0xFFD9B04C);

const _typed = TextStyle(fontFamily: 'Courier', fontFamilyFallback: ['monospace'], color: _ink);

/// Il fascicolo del giocatore, dal ritratto in alto a sinistra nel vicolo:
/// una cartellina della questura, anni Quaranta. Foto segnaletica, nome
/// battuto a macchina, timbri del livello e del grado, l'esperienza su un
/// manometro d'ottone, le monete e gli ultimi casi.
Future<void> showProfileSheet(
  BuildContext context, {
  required OnlineAccount account,
  VoidCallback? onMirror,
  VoidCallback? onShop,
  VoidCallback? onSettings,
}) {
  account.refresh();
  if (DesktopCanvas.peek(context)) {
    return _showDeskDossier(context, account: account, onMirror: onMirror, onShop: onShop, onSettings: onSettings);
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.94,
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
          null => const _Folder(
            child: Center(child: CircularProgressIndicator(color: _ink)),
          ),
        },
      ),
    ),
  );
}

/// La cartellina di cartone kraft: la linguetta in alto a sinistra col
/// numero di pratica, e dentro il foglio dattiloscritto.
class _Folder extends StatelessWidget {
  final Widget child;
  final String? tab;

  /// Le linguette delle pagine, in alto a destra.
  final Widget? index;

  const _Folder({required this.child, this.tab, this.index});

  static const tabHeight = 30.0;

  @override
  Widget build(BuildContext context) => Stack(
    key: const Key('profile.dossier'),
    children: [
      Positioned.fill(
        child: CustomPaint(painter: _FolderPainter(tabHeight: tabHeight, tabWidth: index == null ? null : 150)),
      ),
      if (tab case final tab?)
        Positioned(
          left: 30,
          top: 7,
          child: Text(
            tab,
            style: _typed.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.6,
              color: _ink.withValues(alpha: 0.75),
            ),
          ),
        ),
      Positioned.fill(
        top: tabHeight + 8,
        left: 8,
        right: 8,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_paper, _paperDark],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
            boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: ClipRect(child: child),
        ),
      ),
      if (index case final index?) Positioned(right: 14, top: 4, child: index),
    ],
  );
}

class _FolderPainter extends CustomPainter {
  final double tabHeight;

  /// Larghezza della linguetta; di base si adatta alla cartellina.
  final double? tabWidth;

  const _FolderPainter({required this.tabHeight, this.tabWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final tabWidth = this.tabWidth ?? min(220.0, size.width * 0.55);
    final path = Path()
      ..moveTo(0, tabHeight + 6)
      ..quadraticBezierTo(0, tabHeight, 6, tabHeight)
      ..lineTo(14, tabHeight)
      ..lineTo(22, 4)
      ..quadraticBezierTo(23, 0, 28, 0)
      ..lineTo(tabWidth - 6, 0)
      ..quadraticBezierTo(tabWidth - 1, 0, tabWidth, 4)
      ..lineTo(tabWidth + 8, tabHeight)
      ..lineTo(size.width - 6, tabHeight)
      ..quadraticBezierTo(size.width, tabHeight, size.width, tabHeight + 6)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 10, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kraft, _kraftDark],
        ).createShader(Offset.zero & size),
    );
    // Le fibre del cartone.
    final fibre = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 0.8;
    final random = Random(7);
    for (var i = 0; i < 160; i++) {
      final x = random.nextDouble() * size.width;
      final y = tabHeight + random.nextDouble() * (size.height - tabHeight);
      canvas.drawLine(Offset(x, y), Offset(x + 4 + random.nextDouble() * 8, y + random.nextDouble() * 1.2), fibre);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66000000),
    );
  }

  @override
  bool shouldRepaint(_FolderPainter old) => old.tabHeight != tabHeight || old.tabWidth != tabWidth;
}

class _Dossier extends StatefulWidget {
  final OnlineAccount account;
  final Profile profile;
  final VoidCallback? onMirror;
  final VoidCallback? onShop;
  final VoidCallback? onSettings;

  const _Dossier({required this.account, required this.profile, this.onMirror, this.onShop, this.onSettings});

  @override
  State<_Dossier> createState() => _DossierState();
}

class _DossierState extends State<_Dossier> {
  List<MatchResult>? _history;
  RankTier? _tier;

  /// 0 la scheda, 1 le statistiche (caricate la prima volta che si apre).
  int _page = 0;
  PlayerStats? _stats;
  bool _statsFailed = false;
  bool _withTests = false;

  void _openPage(int page) {
    setState(() => _page = page);
    if (page == 1 && _stats == null && !_statsFailed) _loadStats();
  }

  void _toggleTests() => setState(() => _withTests = !_withTests);

  Future<void> _loadStats() async {
    final ranked = widget.account.services.ranked;
    if (_statsFailed) setState(() => _statsFailed = false);
    if (ranked == null) {
      setState(() => _stats = const PlayerStats());
      return;
    }
    try {
      final stats = await ranked.stats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      if (mounted) setState(() => _statsFailed = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    final ranked = widget.account.services.ranked;
    if (ranked == null) {
      setState(() => _history = const []);
      return;
    }
    try {
      final history = await ranked.history(limit: 6);
      if (mounted) setState(() => _history = history);
    } catch (_) {
      if (mounted) setState(() => _history = const []);
    }
    try {
      final ratings = await ranked.ratings();
      final rating = ratings[widget.profile.language] ?? (ratings.isEmpty ? null : ratings.values.first);
      if (rating != null && mounted) setState(() => _tier = RankTier.of(rating.ordinal));
    } catch (_) {}
  }

  Future<void> _mirror() async {
    if (widget.onMirror case final onMirror?) {
      Navigator.of(context).pop();
      onMirror();
      return;
    }
    final saved = await BarberMirrorScreen.open(context, services: widget.account.services, profile: widget.profile);
    if (saved != null) widget.account.saved(saved);
  }

  void _then(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final t = strings.online;
    final profile = widget.profile;
    final next = Profile.xpToNext(profile.level);
    final number = profile.id.length >= 6 ? profile.id.substring(0, 6).toUpperCase() : profile.id.toUpperCase();
    if (DesktopCanvas.of(context)) return _DeskDossier(host: this, number: number);
    return _Folder(
      tab: 'N. $number',
      index: _IndexTabs(page: _page, onPage: _openPage),
      child: _PageTurn(page: _page, child: _page == 1 ? _StatsPage(host: this) : ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.dossierTitle,
                    style: _typed.copyWith(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.5),
                  ),
                  Container(height: 2, color: _ink, margin: const EdgeInsets.only(top: 6)),
                  Container(height: 0.8, color: _ink, margin: const EdgeInsets.only(top: 2, bottom: 18)),
                ],
              ),
              Positioned(
                right: 0,
                top: -8,
                child: IgnorePointer(child: _Stamp(text: t.dossierConfidential, angle: 0.12, size: 12)),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, box) {
              final photo = box.maxWidth < 330 ? 108.0 : 124.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Mugshot(profile: profile, width: photo),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Field(t.dossierName),
                        _TypedLine(
                          text: profile.name.isEmpty ? t.pickHandle : profile.name,
                          steam: profile.onSteam,
                          apple: profile.onApple,
                        ),
                        _SteamLines(account: widget.account, profile: profile),
                        DossierTitle(progress: widget.account.services.progress, style: _typed),
                        const SizedBox(height: 14),
                        _Field(t.dossierRank),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _LevelSeal(
                              key: const Key('profile.level'),
                              level: profile.level,
                              label: t.levelShort(profile.level),
                            ),
                            const SizedBox(width: 10),
                            if (_tier case final tier?)
                              Flexible(
                                child: _Stamp(text: t.tierName(tier).toUpperCase(), angle: -0.06, color: _ink),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _Field(t.coins),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const SizedBox.square(dimension: 22, child: CustomPaint(painter: CoinPainter())),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${profile.coins}',
                                key: const Key('profile.coins'),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: _typed.copyWith(fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _Field(t.dossierExperience),
              const Spacer(),
              Text(
                '${profile.xp} / $next XP',
                key: const Key('profile.xpNumbers'),
                style: _typed.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _XpBar(key: const Key('profile.xp'), progress: profile.levelProgress),
          const SizedBox(height: 6),
          Text(
            t.xpProgress(profile.xp, next),
            textAlign: TextAlign.center,
            style: _typed.copyWith(fontSize: 12, color: _ink.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 22),
          _Heading(t.dossierHistory),
          const SizedBox(height: 8),
          switch (_history) {
            null => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _ink)),
              ),
            ),
            [] => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(t.dossierNoHistory, style: _typed.copyWith(fontStyle: FontStyle.italic, fontSize: 13)),
            ),
            final history => Column(
              children: [for (final match in history) _CaseRow(match: match, strings: strings)],
            ),
          },
          const SizedBox(height: 18),
          for (final link in progressLinks(context, widget.account.services.progress, profile.language))
            _Plate(key: link.key, label: link.label, icon: Icon(link.icon, color: _brass, size: 22), onTap: link.open),
          _Plate(
            key: const Key('profile.mirror'),
            label: SettingsStrings.of(context).changeLook,
            icon: const SizedBox.square(dimension: 24, child: CustomPaint(painter: BarberPoleIconPainter())),
            onTap: _mirror,
          ),
          if (widget.onShop case final onShop?)
            _Plate(
              key: const Key('profile.shop'),
              label: strings.shop.homeSign,
              icon: const SizedBox.square(dimension: 26, child: CustomPaint(painter: ShopIconPainter())),
              onTap: () => _then(onShop),
            ),
          if (widget.onSettings case final onSettings?)
            _Plate(
              key: const Key('profile.settings'),
              label: t.dossierSettings,
              icon: const Icon(Icons.settings, color: _brass, size: 22),
              onTap: () => _then(onSettings),
            ),
          _Plate(
            key: const Key('profile.signOut'),
            label: t.signOut,
            icon: const Icon(Icons.logout, color: _ink, size: 20),
            dim: true,
            onTap: () async {
              final navigator = Navigator.of(context);
              try {
                await widget.account.services.auth.signOut();
                navigator.pop();
              } catch (error) {
                if (context.mounted) showFailure(context, error);
              }
            },
          ),
        ],
      )),
    );
  }
}

/// La voce di un modulo prestampato, sopra il dattiloscritto.
class _Field extends StatelessWidget {
  final String text;
  final double size;

  const _Field(this.text, {this.size = 10.5});

  @override
  Widget build(BuildContext context) => Text(
    '$text:',
    style: TextStyle(
      color: _ink.withValues(alpha: 0.6),
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: size == 10.5 ? 1.8 : size * 0.17,
    ),
  );
}

/// La foto segnaletica fermata da una graffetta, davanti alle righe
/// dell'altezza.
class _Mugshot extends StatelessWidget {
  final Profile profile;
  final double width;

  const _Mugshot({required this.profile, required this.width});

  @override
  Widget build(BuildContext context) {
    // Sul telefono la foto resta com'è; più grande (desktop) cresce tutto.
    final k = max(1.0, width / 124);
    return SizedBox(
    width: width + 6 * k,
    height: width * 1.26 + 10 * k,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: 8 * k,
          child: Transform.rotate(
            angle: -0.035,
            child: Container(
              width: width,
              height: width * 1.26,
              padding: EdgeInsets.fromLTRB(6 * k, 6 * k, 6 * k, 18 * k),
              decoration: const BoxDecoration(
                color: Color(0xFFFBF7EC),
                boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 5, offset: Offset(2, 3))],
              ),
              child: ClipRect(
                child: CustomPaint(
                  painter: const _HeightLinesPainter(),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: PlayerAvatar(seed: profile.avatarSeed, look: profile.look, picture: profile.pictureUrl, size: width * 0.8),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 14 * k,
          top: -2 * k,
          width: 16 * k,
          height: 42 * k,
          child: const CustomPaint(painter: _PaperclipPainter()),
        ),
      ],
    ),
  );
  }
}

class _HeightLinesPainter extends CustomPainter {
  const _HeightLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.3),
          radius: 0.9,
          colors: [Color(0xFF5A534B), Color(0xFF2E2A26)],
        ).createShader(Offset.zero & size),
    );
    final line = Paint()..color = const Color(0x88E9DEC4);
    for (var i = 0; i * 9.0 < size.height; i++) {
      final y = size.height - i * 9.0;
      final long = i % 5 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(long ? size.width : size.width * 0.16, y),
        line..strokeWidth = long ? 1.1 : 0.7,
      );
    }
  }

  @override
  bool shouldRepaint(_HeightLinesPainter old) => false;
}

/// Una graffetta d'acciaio.
class _PaperclipPainter extends CustomPainter {
  const _PaperclipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wire = Path()
      ..moveTo(w * 0.72, h * 0.30)
      ..lineTo(w * 0.72, h * 0.80)
      ..arcToPoint(Offset(w * 0.28, h * 0.80), radius: Radius.circular(w * 0.22))
      ..lineTo(w * 0.28, h * 0.12)
      ..arcToPoint(Offset(w * 0.88, h * 0.12), radius: Radius.circular(w * 0.30))
      ..lineTo(w * 0.88, h * 0.86)
      ..arcToPoint(Offset(w * 0.12, h * 0.86), radius: Radius.circular(w * 0.38))
      ..lineTo(w * 0.12, h * 0.26);
    canvas.drawPath(
      wire.shift(const Offset(1, 1.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0x55000000),
    );
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(colors: [Color(0xFF8E9399), Color(0xFFE4E7EA), Color(0xFF7C8187)])
            .createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_PaperclipPainter old) => false;
}

/// Il nome battuto a macchina sulla riga del modulo.
class _TypedLine extends StatelessWidget {
  final String text;
  final double size;

  /// I loghi delle piattaforme collegate, dopo il nome.
  final bool steam;
  final bool apple;

  const _TypedLine({required this.text, this.size = 20, this.steam = false, this.apple = false});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: 2, bottom: 3),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: _ink.withValues(alpha: 0.55))),
    ),
    child: Row(
      children: [
        Flexible(
          child: Text(
            text,
            key: const Key('profile.handle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _typed.copyWith(fontSize: size, fontWeight: FontWeight.bold),
          ),
        ),
        PlatformBadges.of(steam: steam, apple: apple, size: size * 0.8, gap: size * 0.4, color: _ink.withValues(alpha: 0.75)),
      ],
    ),
  );
}

/// Sotto il nome, per chi gioca con Steam: il nome Steam com'è su Steam e
/// la scelta dell'immagine del profilo (il ritratto del gioco o quella di
/// Steam). Niente per gli altri.
class _SteamLines extends StatefulWidget {
  final OnlineAccount account;
  final Profile profile;
  final double size;

  const _SteamLines({required this.account, required this.profile, this.size = 12});

  @override
  State<_SteamLines> createState() => _SteamLinesState();
}

class _SteamLinesState extends State<_SteamLines> {
  bool _busy = false;

  Future<void> _choose(ProfilePicture picture) async {
    if (_busy || picture == widget.profile.picture) return;
    setState(() => _busy = true);
    try {
      widget.account.saved(await widget.account.services.profiles.setPicture(picture));
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    if (!profile.onSteam) return const SizedBox.shrink();
    final t = AppStrings.of(context).online;
    final size = widget.size;
    Widget option(ProfilePicture picture, String label) {
      final on = profile.picture == picture;
      return InkWell(
        key: Key('profile.picture.${picture.name}'),
        onTap: _busy ? null : () => _choose(picture),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: size * 0.6, vertical: size * 0.25),
          decoration: BoxDecoration(
            color: on ? _ink : Colors.transparent,
            border: Border.all(color: _ink.withValues(alpha: 0.7)),
          ),
          child: Text(
            label.toUpperCase(),
            style: _typed.copyWith(
              fontSize: size * 0.85,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: on ? _paper : _ink,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: size * 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.steamPersona case final persona?)
            Text(
              t.steamPersona(persona),
              key: const Key('profile.steamPersona'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _typed.copyWith(fontSize: size, color: _ink.withValues(alpha: 0.75)),
            ),
          SizedBox(height: size * 0.5),
          Text(
            '${t.pictureLabel}:',
            style: _typed.copyWith(fontSize: size * 0.85, fontWeight: FontWeight.w800, color: _ink.withValues(alpha: 0.6)),
          ),
          SizedBox(height: size * 0.3),
          Wrap(
            spacing: size * 0.4,
            runSpacing: size * 0.3,
            children: [option(ProfilePicture.game, t.pictureGame), option(ProfilePicture.steam, t.pictureSteam)],
          ),
        ],
      ),
    );
  }
}

/// Il livello come un sigillo di ceralacca.
class _LevelSeal extends StatelessWidget {
  final int level;
  final String label;
  final double size;

  const _LevelSeal({super.key, required this.level, required this.label, this.size = 56});

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    excludeSemantics: true,
    child: _WaxSeal(
      size: size,
      seed: level,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.split(' ').first,
            style: size == 56 ? _sealSmall : _sealSmall.copyWith(fontSize: 8 * size / 56, letterSpacing: size / 56),
          ),
          Text(
            '$level',
            style: AppText.display((level >= 100 ? 15 : 19) * size / 56, color: const Color(0xFFFFE9DA)).copyWith(
              letterSpacing: 0,
              height: 1.05,
              shadows: const [Shadow(color: Color(0x88000000), offset: Offset(0, -1))],
            ),
          ),
        ],
      ),
    ),
  );
}

const _sealSmall = TextStyle(
  color: Color(0xFFF6D9C8),
  fontSize: 8,
  fontWeight: FontWeight.w900,
  letterSpacing: 1,
  height: 1,
  shadows: [Shadow(color: Color(0x88000000), offset: Offset(0, -0.6))],
);

/// Una goccia di ceralacca rossa: bordo irregolare e colato, anello
/// impresso dal sigillo, luce in alto a sinistra.
class _WaxSeal extends StatelessWidget {
  final double size;
  final int seed;
  final Widget child;

  const _WaxSeal({required this.size, required this.seed, required this.child});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _WaxPainter(seed),
      child: Padding(
        padding: EdgeInsets.all(size * 0.17),
        child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: child)),
      ),
    ),
  );
}

class _WaxPainter extends CustomPainter {
  final int seed;

  const _WaxPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rng = math.Random(seed);
    final blob = Path();
    const n = 28;
    final bumps = [for (var i = 0; i < n; i++) 0.86 + rng.nextDouble() * 0.1 + (rng.nextDouble() < 0.12 ? 0.08 : 0)];
    for (var i = 0; i <= n; i++) {
      final a = i / n * math.pi * 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * bumps[i % n];
      if (i == 0) {
        blob.moveTo(p.dx, p.dy);
      } else {
        final pa = (i - 0.5) / n * math.pi * 2;
        final ctrl = c + Offset(math.cos(pa), math.sin(pa)) * r * (bumps[i % n] + bumps[i - 1]) / 2 * 1.02;
        blob.quadraticBezierTo(ctrl.dx, ctrl.dy, p.dx, p.dy);
      }
    }
    blob.close();
    canvas.drawShadow(blob, const Color(0xFF000000), 2.5, false);
    canvas.drawPath(
      blob,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [Color(0xFFD63A42), Color(0xFF9A1C25), Color(0xFF5E0F15)],
          stops: [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );
    // L'anello impresso: ombra sotto, luce sopra.
    final ring = r * 0.68;
    canvas.drawCircle(
      c + const Offset(0, 0.8),
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0x66FFB9A6),
    );
    canvas.drawCircle(
      c,
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0x995A0C12),
    );
    // Un lampo di luce sulla cera.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.8),
      math.pi * 1.05,
      math.pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x55FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_WaxPainter old) => old.seed != seed;
}

/// Un timbro a inchiostro, un po' storto.
class _Stamp extends StatelessWidget {
  final String text;
  final double angle;
  final Color color;
  final double size;

  const _Stamp({required this.text, required this.angle, this.color = _stamp, this.size = 13});

  @override
  Widget build(BuildContext context) {
    final k = max(1.0, size / 13);
    return Transform.rotate(
    angle: angle,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * k, vertical: 3 * k),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.8), width: 2 * k),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: TextStyle(
          color: color.withValues(alpha: 0.85),
          fontWeight: FontWeight.w900,
          fontSize: size,
          letterSpacing: 1.8,
        ),
      ),
    ),
  );
  }
}

/// L'esperienza: una canna incassata nella carta che si riempie d'ottone.
/// Il riempimento scorre quando il saldo cambia.
class _XpBar extends StatelessWidget {
  final double progress;
  final double height;

  const _XpBar({super.key, required this.progress, this.height = 20});

  @override
  Widget build(BuildContext context) {
    final target = progress.clamp(0.0, 1.0);
    final still = MediaQuery.disableAnimationsOf(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFCBB98F),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: _ink.withValues(alpha: 0.75), width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0x33FFFFFF), offset: Offset(0, 1))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2 - 2),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: still ? Duration.zero : const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) =>
              CustomPaint(key: const Key('profile.xpFill'), painter: _XpFillPainter(value), size: Size.infinite),
        ),
      ),
    );
  }
}

class _XpFillPainter extends CustomPainter {
  final double progress;

  const _XpFillPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // La canna vuota: carta incavata, più scura in alto.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA8956A), Color(0xFFD6C59C)],
        ).createShader(Offset.zero & size),
    );
    final fill = Rect.fromLTWH(0, 0, size.width * progress, size.height);
    if (fill.width > 0) {
      canvas.drawRect(
        fill,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFBE7A6), _brass, Color(0xFF9A7224)],
            stops: [0, 0.45, 1],
          ).createShader(Offset.zero & size),
      );
      // Il riflesso in cima all'ottone.
      canvas.drawRect(
        Rect.fromLTWH(2, 1.5, max(0, fill.width - 4), size.height * 0.22),
        Paint()..color = const Color(0x66FFFFFF),
      );
      canvas.drawLine(
        Offset(fill.right, 0),
        Offset(fill.right, size.height),
        Paint()
          ..color = const Color(0xFF6E5018)
          ..strokeWidth = 1,
      );
    }
    // Le tacche, una ogni decimo.
    final tick = Paint()
      ..color = _ink.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, size.height * 0.62), Offset(x, size.height), tick);
    }
  }

  @override
  bool shouldRepaint(_XpFillPainter old) => old.progress != progress;
}

class _Heading extends StatelessWidget {
  final String text;
  final double size;

  const _Heading(this.text, {this.size = 13});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(text, style: _typed.copyWith(fontWeight: FontWeight.w900, letterSpacing: size * 2 / 13, fontSize: size)),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: _ink.withValues(alpha: 0.45))),
    ],
  );
}

/// Un caso chiuso: il ruolo, com'è finita, l'esperienza guadagnata.
class _CaseRow extends StatelessWidget {
  final MatchResult match;
  final AppStrings strings;

  /// Più grande, per il fascicolo sul desktop.
  final double scale;

  const _CaseRow({required this.match, required this.strings, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final t = strings.online;
    final role = Role.values.where((r) => r.name == match.role).firstOrNull;
    final roleName = role == null ? match.role : strings.role(role).label;
    final (outcome, color) = match.abandoned
        ? (t.resultsLeft, _ink.withValues(alpha: 0.6))
        : match.won
        ? (t.resultsWon, const Color(0xFF2E5E2A))
        : (t.resultsLost, _stamp);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 7 * scale * scale),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _ink.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              roleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _typed.copyWith(fontSize: 14 * scale, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            outcome.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11 * scale, letterSpacing: scale),
          ),
          SizedBox(width: 12 * scale),
          SizedBox(
            width: 64 * scale,
            child: Text(
              '+${match.xpGained} XP',
              textAlign: TextAlign.right,
              style: _typed.copyWith(fontSize: 12 * scale, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una targa di cuoio scuro con le lettere d'oro, come le insegne del
/// vicolo: le icone dorate si leggono. [dim] è solo inchiostro sulla carta.
class _Plate extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool dim;

  const _Plate({super.key, required this.label, required this.icon, required this.onTap, this.dim = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: dim
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF4A3426), Color(0xFF2A1C14)],
                  ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: dim ? _ink.withValues(alpha: 0.55) : _brass.withValues(alpha: 0.8), width: 1.2),
            boxShadow: dim ? null : const [BoxShadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              SizedBox(width: 28, child: Center(child: icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dim ? _ink : const Color(0xFFF3D27A),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: dim ? _ink : _brass),
            ],
          ),
        ),
      ),
    ),
  );
}
