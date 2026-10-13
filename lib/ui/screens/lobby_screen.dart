import 'package:flutter/material.dart';

import '../../network/fake_local_session.dart';
import '../../rules/player.dart';
import '../../rules/role_assignment.dart';
import '../theme/app_theme.dart';
import '../widgets/noir_avatar.dart';
import '../widgets/scene_scaffold.dart';
import 'narrator_selection_screen.dart';

class LobbyScreen extends StatefulWidget {
  final FakeLocalSession session;

  const LobbyScreen({super.key, required this.session});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  static const _testNames = [
    'Marco', 'Giulia', 'Luca', 'Sara', 'Paolo', 'Elena',
    'Davide', 'Chiara', 'Matteo', 'Anna', 'Simone', 'Marta',
  ];

  int _fakeCount = 0;

  @override
  void dispose() {
    widget.session.dispose();
    super.dispose();
  }

  void _addFakePlayer() {
    final name = _fakeCount < _testNames.length ? _testNames[_fakeCount] : 'Ospite ${_fakeCount + 1}';
    _fakeCount++;
    widget.session.addFakePlayer(name);
  }

  void _start(List<Player> players) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NarratorSelectionScreen(players: players)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return SceneScaffold(
      appBar: AppBar(
        title: const Text('LOBBY'),
        actions: [
          TextButton(
            onPressed: _addFakePlayer,
            child: const Text('+ TEST', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Player>>(
          initialData: session.currentPlayers,
          stream: session.playersStream,
          builder: (context, snapshot) {
            final players = snapshot.data ?? const <Player>[];
            final missing = minRolePlayers - players.length;
            return Column(
              children: [
                const SizedBox(height: 16),
                const Text('CODICE STANZA', style: AppText.overline),
                const SizedBox(height: 6),
                Text(session.roomCode, style: AppText.display(56)),
                const SizedBox(height: 20),
                Text(
                  missing > 0
                      ? 'Ne mancano ancora $missing per cominciare'
                      : '${players.length} al tavolo',
                  style: AppText.body,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return ListTile(
                        leading: NoirAvatar(seed: player.name, size: 46),
                        title: Text(
                          player.name,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 17),
                        ),
                        trailing: player == session.me
                            ? const Text('TU', style: AppText.overline)
                            : null,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: missing > 0 ? null : () => _start(players),
                      child: const Text('AVVIA'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
