import 'package:flutter/material.dart';
import '../press.dart';
import 'targa.dart';

/// Il pulsante delle impostazioni: una targhetta di smalto scuro avvitata al
/// muro, con un ingranaggio. Sta zitta in un angolo e non ruba la scena
/// all'insegna.
class HomeSettingsPlate extends StatefulWidget {
  /// Il nome del pulsante, per chi lo tiene premuto e per VoiceOver.
  final String label;
  final VoidCallback onTap;

  const HomeSettingsPlate({super.key, required this.label, required this.onTap});

  @override
  State<HomeSettingsPlate> createState() => _HomeSettingsPlateState();
}

class _HomeSettingsPlateState extends State<HomeSettingsPlate> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          onTap: pressed(widget.onTap, Press.toggle),
          // A Targa medallion with the cog, a third of the slot across.
          child: LayoutBuilder(
            builder: (context, box) {
              final side = box.biggest.shortestSide * 0.66;
              return Center(
                child: CustomPaint(
                  painter: TargaPainter(kind: TargaKind.secondary, circle: true, down: _pressed),
                  child: SizedBox.square(dimension: side, child: Icon(Icons.settings, size: side * 0.5, color: const Color(0xFFF0D590))),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
