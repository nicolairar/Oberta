import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/settings_strings.dart';
import '../../../online/online_account.dart';
import '../../../online/online_services.dart';
import '../../../rules/role.dart';
import '../../avatar/avatar_look.dart';
import '../../theme/app_theme.dart';
import '../../widgets/home_account.dart';
import '../../widgets/player_avatar.dart';
import '../avatar/barber_mirror_screen.dart';
import 'online_widgets.dart';

const _paper = Color(0xFFE6D8B8);
const _paperDark = Color(0xFFCDBA92);
const _ink = Color(0xFF2A1E16);
const _stamp = Color(0xFFA3242C);

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
          null => const _Folder(child: Center(child: CircularProgressIndicator(color: _ink))),
        },
      ),
    ),
  );
}

/// La cartellina di cartone, con la linguetta in alto.
class _Folder extends StatelessWidget {
  final Widget child;

  const _Folder({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('profile.dossier'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_paper, _paperDark],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
          boxShadow: [BoxShadow(color: Color(0xCC000000), blurRadius: 18)],
        ),
        child: child,
      );
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
    return _Folder(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: _ink.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.dossierTitle,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontFamilyFallback: ['monospace'],
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              Text(
                'N. ${profile.id.length >= 6 ? profile.id.substring(0, 6).toUpperCase() : profile.id}',
                style: TextStyle(fontFamily: 'Courier', fontFamilyFallback: const ['monospace'], color: _ink.withValues(alpha: 0.6), fontSize: 12),
              ),
            ],
          ),
          Container(height: 1.5, color: _ink, margin: const EdgeInsets.only(top: 6, bottom: 16)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Mugshot(profile: profile),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TypedCard(text: profile.name.isEmpty ? t.pickHandle : profile.name),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Stamp(key: const Key('profile.level'), text: t.levelShort(profile.level), angle: -0.08),
                        if (_tier case final tier?) _Stamp(text: t.tierName(tier).toUpperCase(), angle: 0.06, color: _ink),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const SizedBox.square(dimension: 22, child: CustomPaint(painter: CoinPainter())),
                        const SizedBox(width: 8),
                        Text(
                          '${profile.coins}',
                          key: const Key('profile.coins'),
                          style: AppText.display(22, color: _ink),
                        ),
                        const SizedBox(width: 6),
                        Text(t.coins.toLowerCase(), style: TextStyle(color: _ink.withValues(alpha: 0.7), fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _BrassGauge(key: const Key('profile.xp'), progress: profile.levelProgress, label: t.xpProgress(profile.xp, next)),
          const SizedBox(height: 22),
          _Heading(t.dossierHistory),
          const SizedBox(height: 8),
          switch (_history) {
            null => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _ink))),
              ),
            [] => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(t.dossierNoHistory, style: const TextStyle(color: _ink, fontStyle: FontStyle.italic, fontSize: 13)),
              ),
            final history => Column(children: [for (final match in history) _CaseRow(match: match, strings: strings)]),
          },
          const SizedBox(height: 22),
          _Plate(
            key: const Key('profile.mirror'),
            label: SettingsStrings.of(context).changeLook,
            icon: const SizedBox.square(dimension: 22, child: CustomPaint(painter: BarberPoleIconPainter())),
            onTap: _mirror,
          ),
          if (widget.onShop case final onShop?)
            _Plate(
              key: const Key('profile.shop'),
              label: strings.shop.homeSign,
              icon: const SizedBox.square(dimension: 22, child: CustomPaint(painter: ShopIconPainter())),
              onTap: () => _then(onShop),
            ),
          if (widget.onSettings case final onSettings?)
            _Plate(
              key: const Key('profile.settings'),
              label: t.dossierSettings,
              icon: const Icon(Icons.settings, color: _ink, size: 20),
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
      ),
    );
  }
}

/// La foto segnaletica: il busto davanti alle righe dell'altezza.
class _Mugshot extends StatelessWidget {
  final Profile profile;

  const _Mugshot({required this.profile});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -0.03,
        child: Container(
          width: 118,
          height: 148,
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Color(0xFFF4EEDF),
            boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(2, 3))],
          ),
          child: ClipRect(
            child: CustomPaint(
              painter: const _HeightLinesPainter(),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: PlayerAvatar(seed: profile.avatarSeed, look: profile.look, size: 96),
              ),
            ),
          ),
        ),
      );
}

class _HeightLinesPainter extends CustomPainter {
  const _HeightLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF3B3631));
    final line = Paint()
      ..color = const Color(0x88E9DEC4)
      ..strokeWidth = 1;
    for (var i = 0; i * 9.0 < size.height; i++) {
      final y = size.height - i * 9.0;
      final long = i % 5 == 0;
      canvas.drawLine(Offset(0, y), Offset(long ? size.width : size.width * 0.18, y), line..strokeWidth = long ? 1.2 : 0.8);
      if (long) canvas.drawLine(Offset(size.width * 0.82, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_HeightLinesPainter old) => false;
}

/// Il nome battuto a macchina su un cartellino incollato.
class _TypedCard extends StatelessWidget {
  final String text;

  const _TypedCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1E2),
          border: Border(bottom: BorderSide(color: _stamp.withValues(alpha: 0.5), width: 1)),
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 2, offset: Offset(1, 1))],
        ),
        child: Text(
          text,
          key: const Key('profile.handle'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Courier',
            fontFamilyFallback: ['monospace'],
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}

/// Un timbro a inchiostro, un po' storto.
class _Stamp extends StatelessWidget {
  final String text;
  final double angle;
  final Color color;

  const _Stamp({super.key, required this.text, required this.angle, this.color = _stamp});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.85), width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            text,
            style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
          ),
        ),
      );
}

/// L'esperienza come un manometro d'ottone: una canna con la lancetta.
class _BrassGauge extends StatelessWidget {
  final double progress;
  final String label;

  const _BrassGauge({super.key, required this.progress, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 22,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF0D27E), Color(0xFF8A6A22)],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFF5A3F12)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Color(0xFF1A1410))),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF8A6A22), AppColors.gold, Color(0xFFF0D27E)]),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < 10; i++)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(width: 1, height: 6, color: const Color(0x66000000)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Courier', fontFamilyFallback: ['monospace'], color: _ink, fontSize: 12),
          ),
        ],
      );
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(text, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: _ink.withValues(alpha: 0.4))),
        ],
      );
}

/// Un caso chiuso: il ruolo, com'è finita, l'esperienza guadagnata.
class _CaseRow extends StatelessWidget {
  final MatchResult match;
  final AppStrings strings;

  const _CaseRow({required this.match, required this.strings});

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
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _ink.withValues(alpha: 0.15)))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              roleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Courier', fontFamilyFallback: ['monospace'], color: _ink, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          Text(outcome.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              '+${match.xpGained} XP',
              textAlign: TextAlign.right,
              style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una targa d'ottone come quelle del vicolo.
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: dim ? const [Color(0xFFBFAE88), Color(0xFF9C8A64)] : const [Color(0xFFF0D27E), Color(0xFFB08A2E)],
                ),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF5A3F12), width: 1.2),
                boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.4),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _ink),
                ],
              ),
            ),
          ),
        ),
      );
}
