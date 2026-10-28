import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/voice_strings.dart';
import '../../../../online/safety.dart';
import '../../../../online/voice/mic_permission.dart';
import '../../../../online/voice/voice_controller.dart';
import '../../../../settings/app_settings.dart';
import '../../../desktop/desktop_platform.dart';
import '../../../press.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/noir_modal.dart';
import '../../../widgets/noir_notice.dart';
import '../game/noir_ui.dart';

/// La voce al tavolo, in testa alla chat: un'icona piccola che dice come
/// va (spenta, si ascolta, si parla) e apre le scelte. Per parlare c'è il
/// pulsante grande ([VoiceTalkButton]); sul PC anche il tasto V, tenuto
/// premuto. Se il server non dà la voce in questa stanza non c'è niente da
/// mostrare.
class VoiceDock extends StatefulWidget {
  final VoiceController controller;

  /// Segnalare o bloccare chi si sente (le azioni di sempre, safety_sheets).
  final void Function(String identity)? onPerson;

  const VoiceDock({super.key, required this.controller, this.onPerson});

  @override
  State<VoiceDock> createState() => _VoiceDockState();
}

class _VoiceDockState extends State<VoiceDock> {
  static bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    if (_desktop) HardwareKeyboard.instance.addHandler(_key);
    // Il microfono scelto in un'altra versione, o su un altro schermo: il
    // permesso si chiede adesso, entrando, mai quando si comincia a parlare.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkVoiceMic(context, widget.controller.settings);
    });
  }

  bool _key(KeyEvent event) => widget.controller.handleKey(event);

  @override
  void dispose() {
    if (_desktop) HardwareKeyboard.instance.removeHandler(_key);
    widget.controller.hold(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = VoiceStrings.of(context);
    final size = NoirMetrics.of(context).desk ? 22.0 : 16.0;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        if (c.unavailable) return const SizedBox.shrink();
        final (icon, color) = switch (c.mode) {
          VoiceMode.off => (Icons.mic_off, Saloon.brassDeep),
          _ when c.connecting => (Icons.more_horiz, Saloon.brassDeep),
          _ when !c.connected => (Icons.headset_off, Saloon.brassDeep),
          VoiceMode.listen => (Icons.headphones, Saloon.brass),
          VoiceMode.mic when !c.mayTalk => (Icons.headphones, Saloon.brass),
          VoiceMode.mic when c.live => (Icons.mic, Saloon.blood),
          VoiceMode.mic => (Icons.mic_none, Saloon.brass),
        };
        return Semantics(
          button: true,
          label: t.settings,
          child: InkResponse(
            key: const Key('voice.settings'),
            radius: size * 1.4,
            onTap: () => showVoiceSheet(context, c, onPerson: widget.onPerson),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: size, color: color, key: const Key('voice.state')),
                  const SizedBox(width: 2),
                  Icon(Icons.tune, size: size * 0.8, color: Saloon.brassDeep),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lo stato del pulsante grande per parlare.
enum TalkState { hold, talking, muted, connecting, offline }

/// Il pulsante grande per parlare: si tiene premuto (sul PC anche V) e la
/// voce passa finché lo si tiene. Rotondo, almeno 64 punti, con sotto una
/// riga che dice che cosa succede: «Tieni premuto», «Ti sentono» (con
/// l'anello che segue la voce), perché adesso non si parla, o che la voce è
/// scollegata. Si vede solo col microfono scelto. [reason] dice perché
/// adesso non si parla (la fase, la regola), se lo schermo lo sa.
class VoiceTalkButton extends StatefulWidget {
  final VoiceController controller;
  final String? Function(VoiceStrings t)? reason;

  /// Riga sotto (accanto alla striscia della partita) o a destra (la stanza).
  final Axis direction;

  const VoiceTalkButton({super.key, required this.controller, this.reason, this.direction = Axis.vertical});

  /// Il posto che prende accanto alla striscia, quando si vede.
  static double widthFor({required bool desk}) => desk ? 128 : 84;

  /// Se il pulsante si vede adesso.
  static bool shows(VoiceController? c) => c != null && !c.unavailable && c.mode == VoiceMode.mic;

  @override
  State<VoiceTalkButton> createState() => _VoiceTalkButtonState();
}

class _VoiceTalkButtonState extends State<VoiceTalkButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  VoiceController get c => widget.controller;

  @override
  void dispose() {
    _pulse.dispose();
    if (c.holding) c.hold(false);
    super.dispose();
  }

  TalkState get _state {
    if (c.offline) return TalkState.offline;
    if (c.connecting) return TalkState.connecting;
    if (c.holding && c.canHold) return TalkState.talking;
    if (c.canHold) return TalkState.hold;
    return TalkState.muted;
  }

  String _why(VoiceStrings t) {
    if (widget.reason?.call(t) case final reason?) return reason;
    if (c.opensSoon) return t.opensSoon;
    return c.connected ? t.silencedNow : t.nobodyNow;
  }

  void _down() {
    if (!c.canHold) {
      HapticFeedback.selectionClick();
      final t = VoiceStrings.of(context);
      showNotice(context, _state == TalkState.offline ? t.offline : _why(t));
      return;
    }
    HapticFeedback.mediumImpact();
    c.hold(true);
  }

  void _up() {
    if (!c.holding) return;
    HapticFeedback.lightImpact();
    c.hold(false);
  }

  @override
  Widget build(BuildContext context) {
    final t = VoiceStrings.of(context);
    final desk = NoirMetrics.of(context).desk;
    final size = desk ? 84.0 : 64.0;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!VoiceTalkButton.shows(c)) return const SizedBox.shrink();
        final state = _state;
        if (state == TalkState.talking) {
          if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
        } else if (_pulse.isAnimating) {
          _pulse.stop();
        }
        final (icon, fill, ink, caption) = switch (state) {
          TalkState.hold => (
            Icons.mic,
            Saloon.enamel,
            Saloon.paper,
            DesktopPlatform.isDesktop ? t.holdV : t.holdToTalk,
          ),
          TalkState.talking => (Icons.mic, Saloon.blood, Colors.white, t.live),
          TalkState.muted => (Icons.mic_off, Saloon.ink, Saloon.brassDeep, _why(t)),
          TalkState.connecting => (Icons.more_horiz, Saloon.ink, Saloon.brassDeep, t.connecting),
          TalkState.offline => (Icons.cloud_off, Saloon.ink, Saloon.brassDeep, t.offline),
        };
        final circle = AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final live = state == TalkState.talking;
            // L'anello segue la voce: più forte, più largo; un respiro
            // anche nel silenzio, per dire che si è in onda.
            final level = live ? max(c.level, 0.15 + 0.15 * _pulse.value) : 0.0;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: Border.all(
                  color: state == TalkState.muted || state == TalkState.offline || state == TalkState.connecting
                      ? Saloon.brassDeep
                      : Saloon.brass,
                  width: desk ? 3 : 2.4,
                ),
                boxShadow: [
                  const BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 4)),
                  if (live)
                    BoxShadow(
                      color: Saloon.blood.withValues(alpha: 0.35 + 0.4 * level),
                      blurRadius: 8 + 22 * level,
                      spreadRadius: 2 + (desk ? 14 : 10) * level,
                    ),
                ],
              ),
              child: child,
            );
          },
          child: Icon(icon, color: ink, size: size * 0.46, key: const Key('voice.talk.icon')),
        );
        final label = Text(
          caption,
          key: const Key('voice.talk.caption'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: widget.direction == Axis.vertical ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: state == TalkState.talking ? Saloon.blood : AppColors.textSecondary,
            fontSize: desk ? 15 : 11,
            height: 1.15,
            fontWeight: state == TalkState.hold || state == TalkState.talking ? FontWeight.w600 : FontWeight.w500,
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        );
        final button = Semantics(
          button: true,
          label: '${t.pushToTalk}. $caption',
          child: Listener(
            key: const Key('voice.talk'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _down(),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => _up(),
            child: circle,
          ),
        );
        final gap = desk ? 8.0 : 4.0;
        if (widget.direction == Axis.horizontal) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              button,
              SizedBox(width: gap * 2),
              Flexible(child: label),
            ],
          );
        }
        return SizedBox(
          width: VoiceTalkButton.widthFor(desk: desk),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [button, SizedBox(height: gap), label],
          ),
        );
      },
    );
  }
}

/// Le scelte della voce: il modo, e chi si sente (con chi zittire, solo
/// qui).
Future<void> showVoiceSheet(BuildContext context, VoiceController controller, {void Function(String identity)? onPerson}) {
  final t = VoiceStrings.of(context);
  return showNoirSheet<void>(
    context,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final blocked = BlockedPlayers.ids.value;
        final people = [...c.participants]..sort();
        final status = switch (c.mode) {
          VoiceMode.off => null,
          _ when c.connecting => t.connecting,
          _ when c.offline => t.offline,
          _ when !c.connected => t.closed,
          VoiceMode.listen => t.listening,
          VoiceMode.mic when !c.mayTalk => t.silencedNow,
          VoiceMode.mic when c.live => t.live,
          VoiceMode.mic => DesktopPlatform.isDesktop ? t.pushToTalkDesk : t.pushToTalkPhone,
        };
        return NoirSheet(
          title: t.settings,
          subtitle: t.settingsHint,
          children: [
            SegmentedButton<VoiceMode>(
              key: const Key('voice.mode'),
              showSelectedIcon: false,
              segments: [for (final m in VoiceMode.values) ButtonSegment(value: m, label: Text(t.mode(m)))],
              selected: {c.mode},
              onSelectionChanged: (picked) => chooseVoiceMode(context, c.settings, picked.first),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(status, style: AppText.body.copyWith(fontStyle: FontStyle.italic)),
              ),
            if (c.connected) ...[
              Text(t.people.toUpperCase(), style: AppText.overline.copyWith(color: Saloon.brass)),
              if (people.isEmpty) Text(t.nobody, style: AppText.body),
              for (final identity in people)
                Builder(
                  builder: (context) {
                    final isBlocked = blocked.contains(c.profileOf(identity));
                    final muted = c.isMuted(identity);
                    final speaking = c.isSpeaking(identity) && !muted;
                    return ListTile(
                      key: Key('voice.person.$identity'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        muted ? Icons.volume_off : (speaking ? Icons.graphic_eq : Icons.person_outline),
                        color: speaking ? Saloon.brass : Saloon.brassDeep,
                      ),
                      title: Text(c.nameOf(identity), style: AppText.body),
                      subtitle: isBlocked
                          ? Text(t.blocked, style: AppText.body.copyWith(fontSize: 12))
                          : muted
                          ? Text(t.mutedHere, style: AppText.body.copyWith(fontSize: 12))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBlocked)
                            const Icon(Icons.block, color: Saloon.brassDeep)
                          else
                            TextButton.icon(
                              key: Key('voice.mute.$identity'),
                              style: TextButton.styleFrom(
                                foregroundColor: muted ? Saloon.blood : Saloon.brass,
                                side: BorderSide(color: (muted ? Saloon.blood : Saloon.brass).withValues(alpha: 0.6)),
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              icon: Icon(muted ? Icons.volume_up : Icons.volume_off, size: 18),
                              label: Text(muted ? t.unmute : t.mute),
                              onPressed: pressed(() => c.toggleMute(identity), Press.toggle),
                            ),
                          if (onPerson != null)
                            IconButton(
                              key: Key('voice.report.$identity'),
                              tooltip: t.reportOrBlock,
                              icon: const Icon(Icons.flag_outlined, color: Saloon.brassDeep),
                              onPressed: () => onPerson(identity),
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ],
        );
      },
    ),
  );
}

/// Silenziare la voce di qualcuno, dal menu del suo posto: solo qui.
typedef VoiceMuteAction = ({String label, bool muted, VoidCallback toggle});

/// La voce di [identity] da silenziare (o riattivare), se c'è la voce.
VoiceMuteAction? voiceMuteFor(BuildContext context, VoiceController? c, String identity) {
  if (c == null || c.unavailable || c.mode == VoiceMode.off) return null;
  final t = VoiceStrings.of(context);
  final muted = c.isMuted(identity);
  return (label: muted ? t.unmuteVoice : t.muteVoice, muted: muted, toggle: () => c.toggleMute(identity));
}

/// Prima del microfono, due righe su che cosa succede.
Future<bool> confirmVoiceMic(BuildContext context) {
  final t = VoiceStrings.of(context);
  return confirmNoir(
    context,
    title: t.micAskTitle,
    body: t.micAsk,
    confirm: t.micAllow,
    cancel: t.cancel,
    icon: Icons.mic,
    key: const Key('voice.micAsk'),
    confirmKey: const Key('voice.micAllow'),
  );
}

/// Il microfono negato: si resta ad ascoltare, con la strada per le
/// impostazioni del sistema.
Future<void> showVoiceMicDenied(BuildContext context) {
  final t = VoiceStrings.of(context);
  return showNoirDialog<void>(
    context,
    builder: (context) => NoirDialog(
      key: const Key('voice.micDenied'),
      title: t.micDeniedTitle,
      body: t.micDenied,
      icon: Icons.mic_off,
      actions: [
        NoirAction(label: t.notNow, feel: Press.back, onPressed: () => Navigator.of(context).pop()),
        if (MicPermission.canOpenSettings)
          NoirAction(
            key: const Key('voice.openSettings'),
            label: t.openSettings,
            style: NoirButtonStyle.primary,
            onPressed: () {
              Navigator.of(context).pop();
              MicPermission.openSettings();
            },
          ),
      ],
    ),
  );
}

/// Si sceglie un modo della voce. «Microfono» prima spiega, poi chiede
/// subito il permesso al sistema: se è negato si resta ad ascoltare.
Future<void> chooseVoiceMode(BuildContext context, AppSettings settings, VoiceMode mode) async {
  if (mode != VoiceMode.mic || settings.voiceMode == VoiceMode.mic) {
    settings.voiceMode = mode;
    return;
  }
  if (!await confirmVoiceMic(context)) return;
  final granted = await MicPermission.request();
  _micChecked = granted;
  if (granted) {
    settings.voiceMode = VoiceMode.mic;
    return;
  }
  settings.voiceMode = VoiceMode.listen;
  if (context.mounted) await showVoiceMicDenied(context);
}

bool _micChecked = false;

/// Per i test: si torna a verificare il permesso alla prossima voce.
@visibleForTesting
void debugResetVoiceMicCheck() => _micChecked = false;

/// Col microfono già scelto (da prima): una volta per apertura dell'app si
/// verifica il permesso entrando nella voce. Negato: si ascolta soltanto.
Future<void> checkVoiceMic(BuildContext context, AppSettings settings) async {
  if (_micChecked || settings.voiceMode != VoiceMode.mic) return;
  _micChecked = true;
  if (await MicPermission.request()) return;
  if (settings.voiceMode == VoiceMode.mic) settings.voiceMode = VoiceMode.listen;
  if (context.mounted) await showVoiceMicDenied(context);
}

/// Un anello sottile intorno al posto di chi sta parlando, e un segno
/// piccolo su chi si è silenziato. Chi parla lo dice l'identità firmata dal
/// server (il posto), mai un nome mandato dal telefono.
class VoiceRing extends StatelessWidget {
  final VoiceController? controller;
  final String identity;
  final double width;
  final Widget child;

  const VoiceRing({
    super.key,
    required this.controller,
    required this.identity,
    required this.width,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) return child;
    final arch = BorderRadius.vertical(top: Radius.circular(width / 2), bottom: Radius.circular(width * 0.12));
    final badge = (width * 0.2).clamp(16.0, 26.0);
    return ListenableBuilder(
      listenable: c,
      child: child,
      builder: (context, child) {
        final muted = c.isMuted(identity);
        final on = c.isSpeaking(identity) && !muted;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  key: Key('voice.ring.$identity'),
                  opacity: on ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: arch,
                      border: Border.all(color: Saloon.brass.withValues(alpha: 0.75), width: 1.4),
                      boxShadow: [BoxShadow(color: Saloon.brass.withValues(alpha: 0.28), blurRadius: 9)],
                    ),
                  ),
                ),
              ),
            ),
            if (muted)
              Positioned(
                top: 2,
                right: 2,
                child: IgnorePointer(
                  child: Container(
                    key: Key('voice.muted.$identity'),
                    width: badge,
                    height: badge,
                    decoration: BoxDecoration(
                      color: Saloon.ink.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Saloon.brassDeep),
                    ),
                    child: Icon(Icons.volume_off, size: badge * 0.62, color: Saloon.brass),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
