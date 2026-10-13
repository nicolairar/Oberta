import 'package:flutter/material.dart';

import '../../network/fake_local_session.dart';
import '../theme/app_theme.dart';
import '../widgets/scene_scaffold.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _createRoom(BuildContext context) {
    final session = FakeLocalSession(hostName: 'Tu');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LobbyScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SceneScaffold(
      rain: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _NeonSign(),
              const SizedBox(height: 14),
              const Text('NESSUNO PARLA. QUALCUNO MUORE.', style: AppText.overline),
              const Spacer(flex: 5),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _createRoom(context),
                  child: const Text('CREA STANZA'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Arriva insieme alla rete tra telefoni')),
                  ),
                  child: const Text('ENTRA IN UNA STANZA'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il titolo come un'insegna al neon: un alone rosso, e ogni tanto un
/// tubo che sfarfalla.
class _NeonSign extends StatefulWidget {
  const _NeonSign();

  @override
  State<_NeonSign> createState() => _NeonSignState();
}

class _NeonSignState extends State<_NeonSign> with SingleTickerProviderStateMixin {
  late final AnimationController _hum =
      AnimationController(vsync: this, duration: const Duration(seconds: 9));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _hum.stop();
    } else if (!_hum.isAnimating) {
      _hum.repeat();
    }
  }

  @override
  void dispose() {
    _hum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hum,
      builder: (context, _) {
        final tick = (_hum.value * 150).floor();
        final power = tick % 41 == 0 || tick % 59 == 1 || tick % 59 == 3 ? 0.45 : 1.0;
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'OMERTÀ',
            style: AppText.display(62, color: Color.lerp(const Color(0xFF6B4A1E), const Color(0xFFFFE7B0), power)!)
                .copyWith(
              shadows: [
                Shadow(color: AppColors.accent.withValues(alpha: 0.95 * power), blurRadius: 34),
                Shadow(color: const Color(0xFFFF8A3B).withValues(alpha: 0.8 * power), blurRadius: 14),
                Shadow(color: const Color(0xFFFFE7B0).withValues(alpha: 0.6 * power), blurRadius: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}
