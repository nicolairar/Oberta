import 'package:flutter/material.dart';

import '../../../online/online_services.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/city_backdrop.dart';
import '../../widgets/noir_avatar.dart';
import '../../widgets/platform_marks.dart';

/// I pezzi delle schermate online sul PC: la scena a tutto schermo con la
/// barra in alto, le righe dei giocatori col passaggio del mouse, le porte
/// grandi della sala. Si usano solo quando `DesktopCanvas.of` è vero.

/// La scena desktop: la città dietro, la barra (indietro, titolo, azioni),
/// Esc per tornare, e sotto il contenuto con i margini del PC.
class DeskOnlineScene extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;

  /// Indietro (anche Esc). Senza, si chiude la pagina.
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;

  const DeskOnlineScene({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(DeskSize.gutter, 8, DeskSize.gutter, DeskSize.gutter),
  });

  @override
  Widget build(BuildContext context) {
    final back = onBack ?? () => Navigator.of(context).maybePop();
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: CityBackdrop(
        child: DeskTheme(
          child: DeskEscape(
            onEscape: back,
            child: DecoratedBox(
              // Un velo in alto e in basso: i pannelli si staccano dal cielo.
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x33000000), Color(0x99000000)],
                  stops: [0, 0.45, 1],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DeskTopBar(title: title, onBack: back, actions: actions),
                  Expanded(child: Padding(padding: padding, child: child)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un pulsante a icona del PC: tondo, si accende sotto il mouse, il
/// suggerimento dice cosa fa.
class DeskIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  const DeskIconAction({super.key, required this.icon, required this.tooltip, this.onTap, this.color = AppColors.gold});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        child: DeskHover(
          onTap: onTap,
          tooltip: tooltip,
          builder: (context, hovered) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hovered ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: color.withValues(alpha: onTap == null ? 0.15 : (hovered ? 0.9 : 0.35))),
            ),
            child: Icon(icon, size: 24, color: onTap == null ? color.withValues(alpha: 0.3) : color),
          ),
        ),
      );
}

/// Una targhetta piccola accanto al nome (padrone di casa, tu, bot).
class DeskBadge extends StatelessWidget {
  final String label;
  final Color color;

  const DeskBadge(this.label, {super.key, this.color = AppColors.gold});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.6),
          ),
        ),
      );
}

/// Una riga di un giocatore sul PC: faccia grande, nome, targhette, e le
/// azioni a destra. Sotto il mouse la riga si schiarisce.
class DeskProfileRow extends StatelessWidget {
  final Profile profile;
  final List<Widget> badges;
  final List<Widget> actions;
  final String? subtitle;
  final double avatar;

  const DeskProfileRow({
    super.key,
    required this.profile,
    this.badges = const [],
    this.actions = const [],
    this.subtitle,
    this.avatar = 56,
    this.onTap,
  });

  /// Clic sulla riga (non sulle azioni): il fascicolo pubblico.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _HoverRow(
          onTap: onTap,
          child: Row(
            children: [
              MarkedPortrait(
                name: profile.name,
                picture: profile.pictureUrl,
                size: avatar,
                fallback: NoirAvatar.drawn(seed: profile.avatarSeed, size: avatar),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DeskText.text(size: DeskText.lead, weight: FontWeight.w600),
                          ),
                        ),
                        PlatformBadges.of(steam: profile.onSteam, apple: profile.onApple, size: 18, gap: 10),
                        for (final badge in badges) ...[const SizedBox(width: 12), badge],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: DeskText.text(size: DeskText.label, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              for (final action in actions) ...[const SizedBox(width: 12), action],
            ],
          ),
      );
}

/// Il fondo che si accende sotto il mouse, per le righe senza tocco.
class _HoverRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverRow({required this.child, this.onTap});

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _over = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _over = true),
        onExit: (_) => setState(() => _over = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _over ? AppColors.gold.withValues(alpha: 0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _over ? AppColors.gold.withValues(alpha: 0.25) : Colors.transparent),
          ),
          child: widget.child,
          ),
        ),
      );
}

/// Una porta grande della sala: icona, titolo, due righe di spiegazione.
/// Sotto il mouse si alza e il filo dorato si accende; [primary] è rossa.
class DeskDoor extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final bool primary;
  final String? trailing;

  const DeskDoor({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.primary = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: title,
        child: DeskHover(
          onTap: onTap,
          builder: (context, hovered) {
            final accent = primary ? AppColors.accent : AppColors.gold;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, hovered ? -6 : 0, 0),
              padding: const EdgeInsets.fromLTRB(36, 36, 36, 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DeskSize.radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: primary
                      ? [const Color(0xF23A0E12), const Color(0xF2190708)]
                      : [const Color(0xF01C1713), const Color(0xF00E0B09)],
                ),
                border: Border.all(color: accent.withValues(alpha: hovered ? 0.95 : 0.4), width: hovered ? 2 : 1.2),
                boxShadow: [
                  const BoxShadow(color: Color(0xAA000000), blurRadius: 30, offset: Offset(0, 14)),
                  if (hovered) BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 36),
                ],
              ),
              child: Opacity(
                opacity: onTap == null ? 0.45 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.12),
                        border: Border.all(color: accent.withValues(alpha: 0.6)),
                      ),
                      child: Icon(icon, size: 36, color: primary ? const Color(0xFFF0C9B0) : AppColors.gold),
                    ),
                    const Spacer(),
                    Text(title, style: DeskText.display(DeskText.title, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Text(body, style: DeskText.text(color: AppColors.textSecondary).copyWith(height: 1.4)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (trailing != null)
                          Expanded(
                            child: Text(trailing!, style: DeskText.overline(color: accent), overflow: TextOverflow.ellipsis),
                          )
                        else
                          const Spacer(),
                        AnimatedSlide(
                          duration: const Duration(milliseconds: 160),
                          offset: Offset(hovered ? 0.25 : 0, 0),
                          child: Icon(Icons.arrow_forward, color: accent.withValues(alpha: hovered ? 1 : 0.6), size: 28),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

/// Un testo al centro di un pannello vuoto.
class DeskEmpty extends StatelessWidget {
  final String text;
  final IconData? icon;

  const DeskEmpty(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 44, color: AppColors.gold.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
              ],
              Text(
                text,
                textAlign: TextAlign.center,
                style: DeskText.text(color: AppColors.textSecondary).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      );
}

/// Un avviso da solo al centro della scena (niente server, un errore).
class DeskNotice extends StatelessWidget {
  final List<Widget> children;

  const DeskNotice({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 760,
          padding: const EdgeInsets.all(56),
          decoration: DeskPanel.decoration(lit: true),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
}
