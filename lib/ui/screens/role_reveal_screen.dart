import 'package:flutter/material.dart';

import '../../rules/game_setup.dart';
import '../theme/app_theme.dart';
import '../widgets/flip_role_card.dart';
import '../widgets/handoff_view.dart';
import 'game_screen.dart';

/// Finché c'è un solo telefono, la carta si guarda a turno passandoselo.
/// Con la rete vera ognuno vedrà solo il pezzo "carta" sul proprio schermo.
class RoleRevealScreen extends StatefulWidget {
  final GameSetup setup;

  const RoleRevealScreen({super.key, required this.setup});

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen> {
  int _index = 0;
  bool _holdingPhone = false;
  bool _seen = false;

  void _next() {
    final players = widget.setup.players;
    if (_index + 1 < players.length) {
      setState(() {
        _index++;
        _holdingPhone = false;
        _seen = false;
      });
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GameScreen(setup: widget.setup)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.setup;
    final players = setup.players;
    final player = players[_index];

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('CARTA ${_index + 1} DI ${players.length}'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _holdingPhone
                  ? Column(
                      key: ValueKey('card-$_index'),
                      children: [
                        Text(
                          player.name.toUpperCase(),
                          style: AppText.display(24, color: AppColors.textPrimary),
                        ),
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                              child: FlipRoleCard(
                                role: setup.roleOf(player),
                                teammates: setup.teammatesOf(player),
                                onRevealed: () => setState(() => _seen = true),
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          'Tieni premuta la carta per guardarla.\nRilascia e torna coperta.',
                          textAlign: TextAlign.center,
                          style: AppText.body,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _seen ? _next : null,
                            child: const Text('HO VISTO'),
                          ),
                        ),
                      ],
                    )
                  : HandoffView(
                      key: ValueKey('handoff-$_index'),
                      name: player.name,
                      onReady: () => setState(() => _holdingPhone = true),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
