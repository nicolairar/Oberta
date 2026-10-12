import 'package:flutter/material.dart';

import '../../network/fake_local_session.dart';
import '../theme/app_theme.dart';
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
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.1,
            colors: [Color(0xFF3A1418), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('OMERTÀ', style: AppText.display(60)),
                ),
                const SizedBox(height: 12),
                const Text('NESSUNO PARLA. QUALCUNO MUORE.', style: AppText.overline),
                const Spacer(flex: 4),
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
      ),
    );
  }
}
