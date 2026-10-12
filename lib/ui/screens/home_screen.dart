import 'package:flutter/material.dart';

import '../../network/fake_local_session.dart';
import '../theme/app_theme.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _createRoom(BuildContext context) {
    final session = FakeLocalSession(hostName: 'Narratore');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LobbyScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'OMERTÀ',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'nessuno parla. qualcuno muore.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 64),
              ElevatedButton(
                onPressed: () => _createRoom(context),
                child: const Text('CREA STANZA'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('In arrivo nella prossima fase')),
                  );
                },
                child: const Text(
                  'Entra in una stanza',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
