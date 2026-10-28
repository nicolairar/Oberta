import 'package:flutter/material.dart';

import '../../../../l10n/app_strings.dart';
import '../../../../l10n/desktop_game_strings.dart';
import '../../../../l10n/roles_sheet_strings.dart';
import '../../../../rules/role.dart';
import '../../../desktop/desktop_canvas.dart';
import '../../../press.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/role_style.dart';
import '../../../widgets/roles_sheet.dart';
import 'noir_ui.dart';
import '../../../widgets/noir_modal.dart';

/// I pezzi della partita online su PC: la barra in alto, i tasti disegnati,
/// il mazzo accanto alla chat, il menu di Esc e la conferma per uscire.
/// Tutto misurato sulla tela da 1080p.

/// Un tasto della tastiera disegnato: «Esc», «Invio».
class DeskKeycap extends StatelessWidget {
  final String label;

  const DeskKeycap(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1712),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Saloon.brassDeep),
      boxShadow: const [BoxShadow(color: Color(0xFF050302), offset: Offset(0, 2))],
    ),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(color: Saloon.brass, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.4),
    ),
  );
}

/// La barra in alto della partita: il menu (Esc) a sinistra, il giorno o
/// la notte al centro con il nastro della fase, l'orologio grande a destra.
/// Sempre alta uguale: la pagina sotto non si muove.
class DeskGameHud extends StatelessWidget {
  static const double height = 112;

  final String title;
  final String? ribbon;
  final String? countdown;
  final bool urgent;
  final VoidCallback onMenu;
  final DesktopGameStrings strings;

  const DeskGameHud({
    super.key,
    required this.title,
    required this.onMenu,
    required this.strings,
    this.ribbon,
    this.countdown,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final clock = urgent ? Saloon.blood : Saloon.brass;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: DeskSize.gutter),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF5080605), Color(0xCC0C0907), Color(0x000C0907)],
          stops: [0, 0.7, 1],
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DeskHover(
                onTap: pressed(onMenu, Press.tap),
                builder: (context, hovered) => AnimatedContainer(
                  key: const Key('online.menu'),
                  duration: const Duration(milliseconds: 120),
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: hovered ? Saloon.brass.withValues(alpha: 0.14) : Saloon.ink.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(DeskSize.radius),
                    border: Border.all(color: Saloon.brass.withValues(alpha: hovered ? 0.95 : 0.45), width: 1.4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu, color: Saloon.brass, size: 26),
                      const SizedBox(width: 12),
                      Text(strings.menu.toUpperCase(), style: DeskText.overline(color: Saloon.brass)),
                      const SizedBox(width: 14),
                      DeskKeycap(strings.keyEsc),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 48, height: 1.6, color: Saloon.brass),
                    const SizedBox(width: 20),
                    Flexible(
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Saloon.plate(DeskText.heading),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(width: 48, height: 1.6, color: Saloon.brass),
                  ],
                ),
                if (ribbon != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Saloon.enamelDeep, Saloon.enamel, Saloon.enamelDeep]),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Saloon.brass, width: 1.2),
                    ),
                    child: Text(
                      ribbon!.toUpperCase(),
                      style: AppText.display(16, color: const Color(0xFFFFE9C2)).copyWith(letterSpacing: 3.2),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 300,
            child: Align(
              alignment: Alignment.centerRight,
              child: countdown == null
                  ? null
                  : Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: Saloon.scrim(radius: DeskSize.radius, border: clock),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_bottom, size: 28, color: clock),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.timeLeft.toUpperCase(),
                                style: DeskText.overline(color: clock.withValues(alpha: 0.8)).copyWith(fontSize: 12),
                              ),
                              Text(
                                countdown!,
                                key: const Key('online.countdown'),
                                style: AppText.display(36, color: clock).copyWith(
                                  height: 1.05,
                                  letterSpacing: 1.5,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Il mazzo della partita accanto alla chat: ogni ruolo con la sua icona e
/// il nome per esteso; col mouse sopra, cosa fa. Quelli già usciti tutti
/// (morti scoperti) sono spenti e barrati.
class DeskRolesPanel extends StatelessWidget {
  final Map<Role, int> deck;
  final List<RevealedRole> revealed;
  final VoidCallback? onOpen;

  const DeskRolesPanel({super.key, required this.deck, required this.revealed, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final s = RolesSheetStrings.of(context);
    final total = deck.values.fold(0, (a, b) => a + b);
    return Container(
      key: const Key('rolesPanel'),
      decoration: DeskPanel.decoration(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.title.toUpperCase(), style: DeskText.overline(color: AppColors.gold)),
              ),
              Text('$total', style: AppText.display(20, color: Saloon.brass)),
              if (onOpen != null) ...[
                const SizedBox(width: 10),
                DeskHover(
                  onTap: pressed(onOpen, Press.card),
                  tooltip: s.title,
                  builder: (context, hovered) => AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hovered ? Saloon.brass.withValues(alpha: 0.18) : Colors.transparent,
                      border: Border.all(color: Saloon.brass.withValues(alpha: hovered ? 0.9 : 0.4)),
                    ),
                    child: const Icon(Icons.menu_book, size: 18, color: Saloon.brass),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final MapEntry(key: role, value: count) in deck.entries)
                _tile(t, role, count, revealed.where((r) => r.role == role).length.clamp(0, count)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(AppStrings t, Role role, int count, int gone) {
    final text = t.role(role);
    final allGone = gone >= count;
    final badge = gone > 0 ? '†$gone/$count' : (count > 1 ? '×$count' : null);
    final mafia = role.team == Team.mafia;
    return Tooltip(
      key: Key('rolesPanel.${role.name}'),
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(seconds: 8),
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: role.color, width: 1.4),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 18)],
      ),
      textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 16, height: 1.4),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '${text.label}\n',
            style: TextStyle(color: role.color, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          TextSpan(text: text.description),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        child: Opacity(
          opacity: allGone ? 0.4 : 1,
          child: Container(
            width: 205,
            height: 52,
            padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
            decoration: BoxDecoration(
              color: const Color(0xFF17110D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (mafia ? Saloon.mafia : Saloon.brassDeep).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                RoleIcon(role, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: mafia ? Saloon.mafia : AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      decoration: allGone ? TextDecoration.lineThrough : null,
                      decorationColor: Saloon.blood,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: gone > 0 ? const Color(0xFF7A1E26) : AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
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

/// Il menu di Esc, sopra il tavolo. La partita online non si ferma: lo si
/// dice, e si torna al tavolo con Esc o con un clic fuori.
class DeskPauseMenu extends StatelessWidget {
  final DesktopGameStrings strings;
  final VoidCallback onResume;
  final VoidCallback onRoles;
  final VoidCallback onSettings;
  final VoidCallback onLeave;

  const DeskPauseMenu({
    super.key,
    required this.strings,
    required this.onResume,
    required this.onRoles,
    required this.onSettings,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
    ),
    // Sopra lo Scaffold: serve un Material suo per i testi e i tooltip.
    child: Material(
      type: MaterialType.transparency,
      child: Stack(
        key: const Key('online.pause'),
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onResume,
              child: const ColoredBox(color: Color(0xC7000000)),
            ),
          ),
          Center(
            child: Container(
              width: 640,
              padding: const EdgeInsets.fromLTRB(56, 48, 56, 40),
              decoration: DeskPanel.decoration(lit: true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.menu.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: DeskText.overline(color: AppColors.gold),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    strings.menuTitle.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Saloon.plate(DeskText.title + 6, color: Saloon.brass),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    strings.menuBody,
                    textAlign: TextAlign.center,
                    style: DeskText.text(size: DeskText.body, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 36),
                  NoirButton(
                    key: const Key('online.pause.resume'),
                    label: strings.resume,
                    feel: Press.back,
                    onPressed: onResume,
                  ),
                  const SizedBox(height: 14),
                  NoirButton(
                    key: const Key('online.pause.roles'),
                    kind: NoirButtonKind.brass,
                    icon: Icons.style,
                    label: strings.roles,
                    feel: Press.card,
                    onPressed: onRoles,
                  ),
                  const SizedBox(height: 14),
                  NoirButton(
                    key: const Key('online.pause.settings'),
                    kind: NoirButtonKind.brass,
                    icon: Icons.tune,
                    label: strings.settings,
                    onPressed: onSettings,
                  ),
                  const SizedBox(height: 30),
                  Container(height: 1, color: Saloon.brassDeep.withValues(alpha: 0.5)),
                  const SizedBox(height: 30),
                  NoirButton(
                    key: const Key('online.pause.leave'),
                    kind: NoirButtonKind.brass,
                    icon: Icons.logout,
                    label: strings.leave,
                    onPressed: onLeave,
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DeskKeycap(strings.keyEsc),
                      const SizedBox(width: 10),
                      Text(
                        strings.resume,
                        style: DeskText.text(size: DeskText.label, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// La conferma per lasciare il tavolo, su PC: un pannello noir al centro,
/// «resta» a sinistra e «abbandona» (smalto rosso) a destra. Esc resta.
Future<bool> confirmDeskLeave(BuildContext context, {required String title, required String body}) {
  final strings = DesktopGameStrings(AppStrings.of(context).language);
  return confirmNoir(
    context,
    key: const Key('online.leaveDialog'),
    title: title,
    body: body,
    icon: Icons.door_back_door_outlined,
    danger: true,
    cancel: strings.stay,
    confirm: strings.leaveConfirm,
    cancelKey: const Key('online.leave.stay'),
    confirmKey: const Key('online.leave.confirm'),
  );
}
