import 'dart:ui' show AppExitType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/desktop_strings.dart';
import '../../online/online_models.dart';
import '../avatar/avatar_look.dart';
import '../theme/app_theme.dart';
import '../widgets/home_account.dart';
import '../widgets/player_avatar.dart';
import 'desktop_canvas.dart';
import '../widgets/noir_modal.dart';

const _cream = Color(0xFFE9DEC4);

/// La barra in alto del vicolo sul PC, come il menu di un gioco: a sinistra
/// chi sei (o «Accedi»), a destra bottega, barbiere, impostazioni, esci.
class HomeDeskTopBar extends StatelessWidget {
  /// Null se l'app non ha l'online: a sinistra non c'è niente.
  final bool? signedIn;
  final Profile? profile;
  final String signInLabel;
  final VoidCallback onSignIn;
  final VoidCallback? onSignInTest;
  final VoidCallback onProfile;
  final String pickHandle;
  final String Function(int level) levelLabel;
  final String coinsLabel;

  final String shopLabel;
  final String? shopFresh;
  final VoidCallback? onShop;
  final String mirrorLabel;
  final VoidCallback? onMirror;
  final String settingsLabel;
  final VoidCallback? onSettings;
  final String tutorialLabel;
  final VoidCallback? onTutorial;
  final VoidCallback onQuit;

  const HomeDeskTopBar({
    super.key,
    required this.signedIn,
    required this.profile,
    required this.signInLabel,
    required this.onSignIn,
    this.onSignInTest,
    required this.onProfile,
    required this.pickHandle,
    required this.levelLabel,
    required this.coinsLabel,
    required this.shopLabel,
    this.shopFresh,
    this.onShop,
    required this.mirrorLabel,
    this.onMirror,
    required this.settingsLabel,
    this.onSettings,
    this.tutorialLabel = 'Tutorial',
    this.onTutorial,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final d = DesktopStrings.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6050406), Color(0x99050406), Color(0x00050406)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DeskSize.gutter, 22, DeskSize.gutter, 40),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (signedIn == true)
              _ProfileChip(
                profile: profile,
                pickHandle: pickHandle,
                levelLabel: levelLabel,
                coinsLabel: coinsLabel,
                onTap: onProfile,
                onCoins: onShop,
              )
            else if (signedIn == false)
              _SignInButton(label: signInLabel, onTap: onSignIn, onLongPress: onSignInTest),
            const Spacer(),
            if (signedIn == true && onShop != null) ...[
              _BarButton(
                key: const Key('desk.shop'),
                icon: Icons.storefront_outlined,
                label: shopLabel,
                badge: shopFresh,
                onTap: onShop!,
              ),
              const SizedBox(width: 14),
            ],
            if (signedIn == true && onMirror != null) ...[
              _BarButton(key: const Key('desk.mirror'), icon: Icons.content_cut, label: mirrorLabel, onTap: onMirror!),
              const SizedBox(width: 14),
            ],
            if (onTutorial != null) ...[
              _BarButton(
                key: const Key('desk.tutorial'),
                icon: Icons.school_outlined,
                label: tutorialLabel,
                onTap: onTutorial!,
              ),
              const SizedBox(width: 14),
            ],
            if (onSettings != null) ...[
              _BarButton(
                key: const Key('desk.settings'),
                icon: Icons.settings_outlined,
                label: settingsLabel,
                onTap: onSettings!,
              ),
              const SizedBox(width: 14),
            ],
            _BarButton(
              key: const Key('desk.quit'),
              icon: Icons.power_settings_new,
              label: d.quit,
              onTap: onQuit,
              quiet: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un pulsante della barra: icona e nome, il filo d'oro che si accende sotto il mouse.
class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final bool quiet;

  const _BarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DeskHover(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        builder: (context, hovered) {
          final tint = hovered ? AppColors.gold : (quiet ? AppColors.textSecondary : _cream);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  color: hovered ? AppColors.gold.withValues(alpha: 0.14) : const Color(0x8C0C0A0A),
                  borderRadius: BorderRadius.circular(DeskSize.radius),
                  border: Border.all(color: AppColors.gold.withValues(alpha: hovered ? 0.85 : 0.22), width: 1.2),
                  boxShadow: hovered
                      ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.22), blurRadius: 24)]
                      : const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 26, color: tint),
                    const SizedBox(width: 12),
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(color: tint, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2.2),
                    ),
                  ],
                ),
              ),
              if (badge case final badge?)
                Positioned(
                  top: -10,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.6), blurRadius: 12)],
                    ),
                    child: Text(
                      badge.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// «Accedi»: il pulsante d'oro, il primo che si vede.
class _SignInButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SignInButton({required this.label, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: DeskHover(
          key: const Key('home.signIn'),
          onTap: onTap,
          builder: (context, hovered) => AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hovered
                    ? const [Color(0xFFF0D27E), Color(0xFFC9A227)]
                    : const [Color(0xFFD9B54A), Color(0xFFA9861C)],
              ),
              borderRadius: BorderRadius.circular(DeskSize.radius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: hovered ? 0.5 : 0.25),
                  blurRadius: hovered ? 32 : 18,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.vpn_key_outlined, size: 26, color: Color(0xFF1C140C)),
                const SizedBox(width: 14),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF1C140C),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chi è entrato: il ritratto nel cerchio d'ottone, il nome, il livello e le monete.
class _ProfileChip extends StatelessWidget {
  final Profile? profile;
  final String pickHandle;
  final String Function(int level) levelLabel;
  final String coinsLabel;
  final VoidCallback onTap;
  final VoidCallback? onCoins;

  const _ProfileChip({
    required this.profile,
    required this.pickHandle,
    required this.levelLabel,
    required this.coinsLabel,
    required this.onTap,
    this.onCoins,
  });

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    final complete = profile?.isComplete ?? false;
    final name = profile == null ? '…' : (complete ? profile.name : pickHandle);
    return Semantics(
      button: true,
      label: profile == null ? name : '$name, ${levelLabel(profile.level)}, ${profile.coins} $coinsLabel',
      excludeSemantics: true,
      child: DeskHover(
        key: const Key('home.badge'),
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 84,
          padding: const EdgeInsets.fromLTRB(8, 8, 28, 8),
          decoration: BoxDecoration(
            color: hovered ? const Color(0xE6221A14) : const Color(0xB30C0A0A),
            borderRadius: BorderRadius.circular(42),
            border: Border.all(color: AppColors.gold.withValues(alpha: hovered ? 0.85 : 0.3), width: 1.2),
            boxShadow: hovered
                ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.22), blurRadius: 26)]
                : const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF08080B),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.9), width: 2),
                ),
                child: PlayerAvatar(seed: profile?.name ?? '?', look: profile?.look, picture: profile?.pictureUrl, size: 58),
              ),
              const SizedBox(width: 18),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontFamilyFallback: const ['serif'],
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.bold,
                        fontStyle: complete || profile == null ? FontStyle.normal : FontStyle.italic,
                        color: complete || profile == null ? _cream : AppColors.gold,
                      ),
                    ),
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            levelLabel(profile.level).toUpperCase(),
                            style: const TextStyle(
                              color: _cream,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const SizedBox.square(dimension: 18, child: CustomPaint(painter: CoinPainter())),
                        const SizedBox(width: 7),
                        Text(
                          '${profile.coins}',
                          key: const Key('home.coins'),
                          style: const TextStyle(
                            color: _cream,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un manifesto del muro sotto il mouse: si stacca un poco, si raddrizza,
/// e dietro gli si accende un alone. La manina dice che si può cliccare.
class HomeDeskPoster extends StatefulWidget {
  final Color glow;
  final Widget child;

  const HomeDeskPoster({super.key, required this.glow, required this.child});

  @override
  State<HomeDeskPoster> createState() => _HomeDeskPosterState();
}

class _HomeDeskPosterState extends State<HomeDeskPoster> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 180);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        duration: duration,
        curve: Curves.easeOut,
        offset: _hovered ? const Offset(0, -0.018) : Offset.zero,
        child: AnimatedScale(
          duration: duration,
          curve: Curves.easeOut,
          scale: _hovered ? 1.035 : 1,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                left: 40,
                top: 40,
                right: 40,
                bottom: 40,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: _hovered ? 1 : 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: widget.glow.withValues(alpha: 0.5), blurRadius: 120, spreadRadius: 10),
                          const BoxShadow(color: Color(0xAA000000), blurRadius: 40, offset: Offset(0, 30)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

/// «Lasci il vicolo?»: Esc o il pulsante Esci. Vero se si esce.
Future<void> confirmDeskQuit(BuildContext context) async {
  final d = DesktopStrings.of(context);
  final quit = await confirmNoir(
    context,
    title: d.quitTitle,
    body: d.quitBody,
    icon: Icons.logout,
    danger: true,
    cancel: d.stay,
    confirm: d.quitConfirm,
    cancelKey: const Key('desk.quitStay'),
    confirmKey: const Key('desk.quitConfirm'),
  );
  if (quit) await ServicesBinding.instance.exitApplication(AppExitType.required);
}
