import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/collection_strings.dart';
import '../../l10n/progress_strings.dart';
import '../../online/online_services.dart';
import '../../platform/achievements.dart';
import '../../rules/role.dart';
import '../desktop/desktop_canvas.dart';
import '../theme/app_theme.dart';
import '../theme/role_style.dart';
import '../widgets/noir_modal.dart';
import '../widgets/role_rules.dart';
import '../widgets/targa.dart';
import 'online/game/noir_ui.dart';
import 'online/sign_in_sheet.dart';

/// «I ruoli»: the collection. One card per role, grouped by side (village,
/// mafia, loners). A card stays face down — a silhouette and a name, no
/// explanation — until the server says the player won a game with it; then
/// it shows what the role does and the player's numbers with it.
///
/// Only this page hides the rules: the card dealt in a game, the narrator's
/// sheet and the tutorials always explain the role.
class RolesScreen extends StatefulWidget {
  final OnlineServices? services;

  const RolesScreen({super.key, this.services});

  static Future<void> open(BuildContext context, {OnlineServices? services}) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => RolesScreen(services: services ?? OnlineServices.instance)));

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  Future<Map<String, RoleRecord>>? _load;

  ProgressRepository? get _progress => widget.services?.progress;
  bool get _signedIn => widget.services?.auth.signedIn ?? false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final progress = _progress;
    _load = progress == null || !_signedIn
        ? Future.value(const <String, RoleRecord>{})
        : progress.roleStats().then((cards) {
            // Server-confirmed: the card achievements go to Steam / Game Center too.
            unawaited(PlatformAchievements.instance.report([
              for (final c in cards.values)
                if (c.unlocked) Achievement.roleIdOf(c.role),
            ]));
            return cards;
          });
  }

  Future<void> _signIn() async {
    final services = widget.services;
    if (services == null) return;
    if (await showSignInSheet(context, services: services) && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final c = CollectionStrings.of(context);
    final desk = DesktopCanvas.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0706),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.85),
            radius: 1.3,
            colors: [Color(0xFF2E1C10), Color(0xFF140C07), Color(0xFF070504)],
            stops: [0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 16, 4),
                child: Row(
                  children: [
                    TargaBackButton(size: desk ? 60 : 44),
                    Expanded(
                      child: Text(
                        c.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppText.overline.copyWith(color: Saloon.brass, fontSize: desk ? 24 : 13, letterSpacing: desk ? 6 : 4),
                      ),
                    ),
                    SizedBox(width: desk ? 64 : 48),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<Map<String, RoleRecord>>(
                  future: _load,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      final s = ProgressStrings.of(context);
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(s.loadFailed, style: AppText.body.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            TargaButton(label: s.retry, compact: true, onPressed: () => setState(_reload)),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Saloon.brass));
                    }
                    return _Collection(
                      cards: snapshot.data!,
                      signedIn: _signedIn,
                      desk: desk,
                      onSignIn: widget.services == null ? null : _signIn,
                      onRefresh: () async {
                        setState(_reload);
                        await _load;
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Collection extends StatelessWidget {
  final Map<String, RoleRecord> cards;
  final bool signedIn;
  final bool desk;
  final VoidCallback? onSignIn;
  final Future<void> Function() onRefresh;

  const _Collection({
    required this.cards,
    required this.signedIn,
    required this.desk,
    required this.onSignIn,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final c = CollectionStrings.of(context);
    final unlocked = Role.values.where((r) => cards[r.name]?.unlocked ?? false).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, desk ? 1240.0 : 640.0);
        final pad = desk ? 32.0 : 16.0;
        final gap = desk ? 16.0 : 10.0;
        final columns = ((width - 2 * pad + gap) / ((desk ? 150 : 108) + gap)).floor().clamp(3, 8);
        final cardWidth = (width - 2 * pad - gap * (columns - 1)) / columns;
        return RefreshIndicator(
          color: Saloon.brass,
          onRefresh: onRefresh,
          child: Center(
            child: SizedBox(
              width: width,
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
                children: [
                  Text(
                    c.count(unlocked, Role.values.length),
                    key: const Key('roles.count'),
                    textAlign: TextAlign.center,
                    style: AppText.display(desk ? 42 : 22, color: Saloon.paper),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.hint,
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: desk ? 19 : 12.5),
                  ),
                  if (!signedIn) ...[
                    const SizedBox(height: 14),
                    _SignInNote(text: c.signedOut, label: c.signIn, onSignIn: onSignIn, desk: desk),
                  ],
                  for (final team in Team.values) ...[
                    SizedBox(height: desk ? 28 : 20),
                    _SideHeader(
                      label: c.team(team),
                      count: c.sideCount(
                        Role.values.where((r) => r.team == team && (cards[r.name]?.unlocked ?? false)).length,
                        Role.values.where((r) => r.team == team).length,
                      ),
                      desk: desk,
                    ),
                    SizedBox(height: desk ? 14 : 10),
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final role in Role.values.where((r) => r.team == team))
                          SizedBox(
                            width: cardWidth,
                            height: cardWidth * 1.42,
                            child: RoleCollectionCard(
                              role: role,
                              record: cards[role.name],
                              desk: desk,
                              onTap: () => showRoleCard(context, role, cards[role.name]),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignInNote extends StatelessWidget {
  final String text;
  final String label;
  final VoidCallback? onSignIn;
  final bool desk;

  const _SignInNote({required this.text, required this.label, required this.onSignIn, required this.desk});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('roles.signIn'),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF3A0E14), Color(0xFF1E070A)]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Saloon.brassDeep.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Saloon.brass, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: AppText.body.copyWith(color: Saloon.paper, fontSize: desk ? 18 : 13, height: 1.3)),
            ),
            if (onSignIn case final onSignIn?) ...[
              const SizedBox(width: 10),
              TargaButton(label: label, compact: true, desk: desk, onPressed: onSignIn),
            ],
          ],
        ),
      );
}

class _SideHeader extends StatelessWidget {
  final String label;
  final String count;
  final bool desk;

  const _SideHeader({required this.label, required this.count, required this.desk});

  @override
  Widget build(BuildContext context) {
    final style = AppText.overline.copyWith(color: Saloon.brass, fontSize: desk ? 18 : 12, letterSpacing: 3);
    return Row(
      children: [
        Text(label.toUpperCase(), style: style),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Saloon.brassDeep.withValues(alpha: 0.5))),
        const SizedBox(width: 10),
        Text(count, style: style.copyWith(color: AppColors.textSecondary, letterSpacing: 1)),
      ],
    );
  }
}

/// The role's icon, drawn, or — face down — a dark medallion with only the
/// shape of its emblem pressed into it.
class _RoleFace extends StatelessWidget {
  final Role role;
  final bool unlocked;
  final double size;

  const _RoleFace({required this.role, required this.unlocked, required this.size});

  @override
  Widget build(BuildContext context) {
    if (unlocked) return RoleIcon(role, size: size);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFF1C1510), Color(0xFF0C0907)]),
        border: Border.all(color: Saloon.brassDeep.withValues(alpha: 0.45), width: size * 0.03),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Icon(
        role.icon,
        size: size * 0.52,
        color: const Color(0xFF3B2D21),
        shadows: const [Shadow(color: Color(0x33F2D58A), offset: Offset(0, 1))],
      ),
    );
  }
}

/// One card of the collection: face up (the role's colour, its icon, the
/// wins and games) or face down (a silhouette on a dark back, the name, a
/// padlock).
class RoleCollectionCard extends StatelessWidget {
  final Role role;
  final RoleRecord? record;
  final bool desk;
  final VoidCallback? onTap;

  const RoleCollectionCard({super.key, required this.role, this.record, this.desk = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = CollectionStrings.of(context);
    final text = AppStrings.of(context).role(role);
    final open = record?.unlocked ?? false;
    final color = role.color;
    return Semantics(
      button: true,
      label: '${text.label}, ${open ? c.short(record!.wins, record!.played) : c.locked}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('roles.card.${role.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(w * 0.08),
                gradient: open
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.lerp(color, Colors.white, 0.08)!, Color.lerp(color, Colors.black, 0.72)!],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2A1F18), Color(0xFF15100C)],
                      ),
                border: Border.all(
                  color: open ? Saloon.brass : Saloon.brassDeep.withValues(alpha: 0.45),
                  width: open ? 1.4 : 1,
                ),
                boxShadow: [
                  if (open) BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: -2),
                ],
              ),
              child: Stack(
                children: [
                  // The inner frame of a playing card.
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(w * 0.05),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(w * 0.05),
                          border: Border.all(
                            color: (open ? NoirInk.brassLight : Saloon.brassDeep).withValues(alpha: open ? 0.35 : 0.22),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(w * 0.09, w * 0.12, w * 0.09, w * 0.09),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: _RoleFace(role: role, unlocked: open, size: w * 0.56),
                          ),
                        ),
                        Text(
                          text.label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(
                            color: open ? Saloon.paper : Saloon.paper.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w900,
                            fontSize: w * 0.105,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: w * 0.04),
                        Text(
                          open ? c.short(record!.wins, record!.played) : c.locked.toUpperCase(),
                          maxLines: 1,
                          style: AppText.overline.copyWith(
                            color: open ? Saloon.brass : Saloon.brassDeep,
                            fontSize: w * 0.075,
                            letterSpacing: open ? 0.5 : 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!open)
                    Positioned(
                      top: w * 0.09,
                      right: w * 0.09,
                      child: Icon(Icons.lock, size: w * 0.12, color: Saloon.brassDeep.withValues(alpha: 0.9)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A card turned over: what the role does and the player's numbers with it,
/// or, face down, only its name and how far the player got.
Future<void> showRoleCard(BuildContext context, Role role, RoleRecord? record) => showNoirSheet<void>(
      context,
      builder: (context) => RoleCardDetail(role: role, record: record),
    );

class RoleCardDetail extends StatelessWidget {
  final Role role;
  final RoleRecord? record;

  const RoleCardDetail({super.key, required this.role, this.record});

  @override
  Widget build(BuildContext context) {
    final c = CollectionStrings.of(context);
    final text = AppStrings.of(context).role(role);
    final r = record;
    final open = r?.unlocked ?? false;
    final desk = DesktopCanvas.peek(context);
    final k = desk ? 1.5 : 1.0;
    return NoirSheet(
      key: Key('roles.detail.${role.name}'),
      header: Column(
        children: [
          Container(
            width: 112 * k,
            height: 112 * k,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: open
                    ? [role.color.withValues(alpha: 0.55), Colors.transparent]
                    : const [Color(0xFF4A3A2C), Colors.transparent],
              ),
            ),
            child: _RoleFace(role: role, unlocked: open, size: 92 * k),
          ),
          SizedBox(height: 8 * k),
          Text(
            c.team(role.team).toUpperCase(),
            style: AppText.overline.copyWith(
              color: open ? Saloon.brass : Saloon.brassDeep,
              letterSpacing: 3,
              fontSize: 12 * k,
            ),
          ),
          const SizedBox(height: 2),
          Text(text.label, textAlign: TextAlign.center, style: AppText.display(26 * k, color: Saloon.paper)),
          if (open) ...[
            SizedBox(height: 4 * k),
            Text(
              text.motto,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: Saloon.brass, fontStyle: FontStyle.italic, fontSize: 14 * k),
            ),
          ],
        ],
      ),
      children: [
        if (open) ...[
          RoleRules(role, color: AppColors.textPrimary, labelColor: Saloon.brass, fontSize: 14.5 * k, center: true),
          SizedBox(height: 18 * k),
          _StatsGrid(record: r!, k: k),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, color: Saloon.brassDeep, size: 18 * k),
              const SizedBox(width: 6),
              Text(
                c.locked.toUpperCase(),
                style: AppText.overline.copyWith(color: Saloon.brassDeep, letterSpacing: 3, fontSize: 12 * k),
              ),
            ],
          ),
          SizedBox(height: 10 * k),
          Text(
            c.lockedBody,
            key: const Key('roles.detail.locked'),
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.textSecondary, fontSize: 14 * k, height: 1.35),
          ),
          SizedBox(height: 8 * k),
          Text(
            (r?.played ?? 0) > 0 ? c.playedNoWin(r!.played) : c.neverPlayed,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: Saloon.paper.withValues(alpha: 0.7), fontSize: 13 * k),
          ),
        ],
        // On the PC the dialog has its own close button (and Esc).
        if (!desk) ...[
          const SizedBox(height: 18),
          Center(
            child: TargaButton(
              label: c.close,
              compact: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ] else
          SizedBox(height: 8 * k),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final RoleRecord record;
  final double k;

  const _StatsGrid({required this.record, this.k = 1});

  @override
  Widget build(BuildContext context) {
    final c = CollectionStrings.of(context);
    final r = record;
    final tiles = [
      (c.played, '${r.played}'),
      (c.wins, '${r.wins}'),
      (c.losses, '${r.losses}'),
      (c.winRate, '${(r.winRate * 100).round()}%'),
      (c.bestStreak, '${r.bestStreak}'),
      (c.lastPlayed, r.lastPlayed == null ? '—' : c.date(r.lastPlayed!)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final w = (constraints.maxWidth - 2 * gap) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value) in tiles)
              Container(
                width: w,
                height: 62 * k,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1511),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Saloon.brassDeep.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, maxLines: 1, style: AppText.display((value.length > 6 ? 15 : 22) * k, color: Saloon.paper)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.overline.copyWith(color: AppColors.textSecondary, fontSize: 9.5 * k, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
