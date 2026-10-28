import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/voice_strings.dart';
import '../../../../online/safety.dart';
import '../../../../online/voice/voice_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/noir_modal.dart';
import '../game/noir_ui.dart';

/// Il microfono della voce al tavolo, piccolo, accanto al titolo della chat:
/// a microfono aperto si tocca per zittirsi; a premi-per-parlare si tiene
/// premuto (sul PC anche il tasto V). L'ingranaggio accanto apre le scelte:
/// il modo, chi si sente, chi zittire. Se il server non dà la voce in questa
/// stanza non c'è niente da mostrare.
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
    final desk = NoirDesk.of(context);
    final size = desk ? 22.0 : 16.0;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        if (c.unavailable) return const SizedBox.shrink();
        final talking = c.mode == VoiceMode.mic && c.mayTalk;
        final (icon, color) = switch (c.mode) {
          VoiceMode.off => (Icons.mic_off, Saloon.brassDeep),
          _ when c.connecting => (Icons.more_horiz, Saloon.brassDeep),
          _ when !c.connected => (Icons.voice_over_off, Saloon.brassDeep),
          VoiceMode.listen => (Icons.headphones, Saloon.brass),
          VoiceMode.mic when !c.mayTalk => (Icons.headphones, Saloon.brass),
          VoiceMode.mic when c.live => (Icons.mic, Saloon.blood),
          VoiceMode.mic => (c.pushToTalk ? Icons.mic_none : Icons.mic_off, Saloon.brass),
        };
        final mic = Icon(icon, size: size, color: color, key: const Key('voice.state'));
        final button = talking && c.pushToTalk
            ? GestureDetector(
                key: const Key('voice.talk'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => c.hold(true),
                onTapUp: (_) => c.hold(false),
                onTapCancel: () => c.hold(false),
                child: Padding(padding: const EdgeInsets.all(6), child: mic),
              )
            : InkResponse(
                key: const Key('voice.talk'),
                radius: size,
                onTap: talking ? c.toggleSelfMute : () => showVoiceSheet(context, c, onPerson: widget.onPerson),
                child: Padding(padding: const EdgeInsets.all(6), child: mic),
              );
        return Semantics(
          label: t.button,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: c.live ? [BoxShadow(color: Saloon.blood.withValues(alpha: 0.45), blurRadius: 10)] : null,
                ),
                child: button,
              ),
              InkResponse(
                key: const Key('voice.settings'),
                radius: size,
                onTap: () => showVoiceSheet(context, c, onPerson: widget.onPerson),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.tune, size: size * 0.85, color: Saloon.brassDeep),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Le scelte della voce: il modo, premi-per-parlare, e chi si sente (con
/// chi zittire, solo qui).
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
          _ when !c.connected => t.closed,
          VoiceMode.listen => t.listening,
          VoiceMode.mic when !c.mayTalk => t.silencedNow,
          VoiceMode.mic when c.live => t.live,
          VoiceMode.mic => c.pushToTalk ? (_VoiceDockState._desktop ? t.pushToTalkDesk : t.pushToTalkPhone) : t.openMic,
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
              onSelectionChanged: (picked) => _pick(context, c, picked.first),
            ),
            if (c.mode == VoiceMode.mic)
              SwitchListTile(
                key: const Key('voice.pushToTalk'),
                contentPadding: EdgeInsets.zero,
                title: Text(t.pushToTalk, style: AppText.body),
                value: c.pushToTalk,
                onChanged: c.setPushToTalk,
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
                    return ListTile(
                      key: Key('voice.person.$identity'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        c.isSpeaking(identity) ? Icons.graphic_eq : Icons.person_outline,
                        color: c.isSpeaking(identity) ? Saloon.brass : Saloon.brassDeep,
                      ),
                      title: Text(c.nameOf(identity), style: AppText.body),
                      subtitle: isBlocked ? Text(t.blocked, style: AppText.body.copyWith(fontSize: 12)) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBlocked)
                            const Icon(Icons.block, color: Saloon.brassDeep)
                          else
                            IconButton(
                              key: Key('voice.mute.$identity'),
                              tooltip: muted ? t.unmute : t.mute,
                              icon: Icon(muted ? Icons.volume_off : Icons.volume_up, color: Saloon.brass),
                              onPressed: () => c.toggleMute(identity),
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

/// Prima del microfono, due righe su che cosa succede: poi il sistema
/// chiede il permesso (iOS, macOS, Android) la prima volta che serve.
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
  );
}

Future<void> _pick(BuildContext context, VoiceController c, VoiceMode mode) async {
  if (mode == VoiceMode.mic && c.mode != VoiceMode.mic && !await confirmVoiceMic(context)) return;
  c.setMode(mode);
}

/// Un anello sottile intorno al posto di chi sta parlando.
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
    return ListenableBuilder(
      listenable: c,
      child: child,
      builder: (context, child) {
        final on = c.isSpeaking(identity) && !c.isMuted(identity);
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
          ],
        );
      },
    );
  }
}
