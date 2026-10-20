import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../online/device_session.dart';
import '../theme/app_theme.dart';

/// Sopra tutta l'app: quando l'account è aperto su due dispositivi copre lo
/// schermo con la domanda («GIOCO QUA»), e quando gioca l'altro con il
/// cartello «Sei connesso su un altro dispositivo». Sotto, l'app resta com'è.
class DeviceSessionGate extends StatelessWidget {
  final DeviceSession? session;
  final Widget child;

  const DeviceSessionGate({super.key, required this.session, required this.child});

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    if (session == null) return child;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (session.blocked) _Curtain(session: session),
        ],
      ),
    );
  }
}

class _Curtain extends StatefulWidget {
  final DeviceSession session;

  const _Curtain({required this.session});

  @override
  State<_Curtain> createState() => _CurtainState();
}

class _CurtainState extends State<_Curtain> {
  bool _claiming = false;

  Future<void> _playHere() async {
    setState(() => _claiming = true);
    await widget.session.playHere();
    if (mounted) setState(() => _claiming = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final session = widget.session;
    final other = session.otherLabel ?? '?';
    final displaced = session.state == DeviceSessionState.displaced;
    return Material(
      key: ValueKey(displaced ? 'device-displaced' : 'device-contested'),
      color: AppColors.background.withValues(alpha: 0.94),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phonelink_lock, color: AppColors.gold, size: 44),
                  const SizedBox(height: 20),
                  Text(
                    displaced ? t.deviceDisplacedTitle : t.deviceOneAtATime,
                    textAlign: TextAlign.center,
                    style: AppText.display(24),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displaced ? t.deviceDisplaced(other) : t.deviceContested(other),
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _claiming ? null : _playHere,
                      child: Text(t.devicePlayHere, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
