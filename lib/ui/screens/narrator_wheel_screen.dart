import 'package:flutter/material.dart';

import '../../rules/game_setup.dart';
import '../../rules/player.dart';
import '../../rules/wheel_spin.dart';
import '../theme/app_theme.dart';
import '../widgets/spin_wheel.dart';
import 'role_deal_screen.dart';

class NarratorWheelScreen extends StatefulWidget {
  final List<Player> players;

  const NarratorWheelScreen({super.key, required this.players});

  @override
  State<NarratorWheelScreen> createState() => _NarratorWheelScreenState();
}

class _NarratorWheelScreenState extends State<NarratorWheelScreen> {
  static const _palette = [Color(0xFF8E1620), Color(0xFF2B2320), Color(0xFF5A1B20)];

  late final WheelSpin _spin = WheelSpin.random(segmentCount: widget.players.length);
  late final List<WheelSegment> _segments = _buildSegments();
  bool _stopped = false;

  Player get _narrator => widget.players[_spin.winnerIndex];

  List<WheelSegment> _buildSegments() {
    final count = widget.players.length;
    return [
      for (var i = 0; i < count; i++)
        WheelSegment(
          widget.players[i].name,
          // L'ultimo spicchio non deve avere lo stesso colore del primo, che gli sta accanto.
          _palette[i == count - 1 && i % 3 == 0 ? 1 : i % 3],
        ),
    ];
  }

  void _continue() {
    final setup = GameSetup.deal(lobby: widget.players, narrator: _narrator);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RoleDealScreen(setup: setup)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SORTEGGIO')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('Chi racconta\nstanotte?', textAlign: TextAlign.center, style: AppText.display(30)),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: SpinWheel(
                      segments: _segments,
                      finalAngle: _spin.finalAngle,
                      onStopped: () => setState(() => _stopped = true),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _stopped ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    const Text('IL NARRATORE È', style: AppText.overline),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _narrator.name.toUpperCase(),
                        style: AppText.display(34, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _stopped ? _continue : null,
                  child: const Text('CONTINUA'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
