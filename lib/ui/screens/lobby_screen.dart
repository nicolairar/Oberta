import 'package:flutter/material.dart';

import '../../network/fake_local_session.dart';
import '../../rules/player.dart';
import '../theme/app_theme.dart';

class LobbyScreen extends StatefulWidget {
  final FakeLocalSession session;

  const LobbyScreen({super.key, required this.session});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int _fakeCount = 0;

  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  void _addFakePlayer() {
    _fakeCount++;
    widget.session.addFakePlayer('Giocatore $_fakeCount');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          const Text('CODICE STANZA', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            widget.session.roomCode,
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: StreamBuilder<List<Player>>(
              initialData: widget.session.currentPlayers,
              stream: widget.session.playersStream,
              builder: (context, snapshot) {
                final players = snapshot.data ?? const [];
                return ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return ListTile(
                      leading: const Icon(Icons.person, color: AppColors.gold),
                      title: Text(
                        player.name,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _addFakePlayer,
                    child: const Text('+ giocatore (test)'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scelta narratore: prossima fase')),
                      );
                    },
                    child: const Text('AVVIA'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
