import 'dart:math';

import 'package:flutter/material.dart';

import '../desktop/desktop_canvas.dart';
import '../theme/app_theme.dart';
import '../theme/script_fonts.dart';

/// La didascalia in fondo al vicolo, battuta a macchina una lettera alla
/// volta come nelle scene del delitto. Resta lì qualche secondo, si
/// cancella, e ne arriva un'altra.
///
/// Chi ha chiesto di ridurre le animazioni la trova già scritta, e ferma.
class HomeCaption extends StatefulWidget {
  /// Le battute, in ordine: si comincia da [first] e poi si gira.
  final List<String> lines;
  final int first;

  /// Secondi di silenzio prima della prima battuta.
  final double delay;

  const HomeCaption({super.key, required this.lines, this.first = 0, this.delay = 0});

  @override
  State<HomeCaption> createState() => HomeCaptionState();
}

class HomeCaptionState extends State<HomeCaption> with SingleTickerProviderStateMixin {
  static const _turn = 10.0;
  static const _typing = 32.0;
  static const _erasing = 80.0;

  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 10))
    ..addListener(_type);

  /// Quante lettere della battuta si vedono adesso.
  final _typed = ValueNotifier<int>(0);

  late int _index = widget.first;
  late double _wait = widget.delay;
  String? _aside;
  double _last = 0;
  bool _still = false;

  String get _line => _aside ?? widget.lines[_index % widget.lines.length];

  /// Interrompe il giro per battere [text]; poi le battute riprendono.
  void say(String text) {
    setState(() => _aside = text);
    _wait = 0;
    _last = 0;
    if (_still) {
      _typed.value = text.length;
    } else {
      _clock
        ..value = 0
        ..repeat();
    }
  }

  void _type() {
    final value = _clock.value;
    if (value < _last) {
      // Giro nuovo, battuta nuova.
      setState(() {
        if (_aside != null) {
          _aside = null;
        } else {
          _index++;
        }
      });
      _wait = 0;
    }
    _last = value;
    final seconds = value * _turn;
    final length = _line.length;
    final typed = ((seconds - _wait) * _typing).floor().clamp(0, length);
    final erased = ((seconds - (_turn - 0.2 - length / _erasing)) * _erasing).floor().clamp(0, length);
    _typed.value = max(0, typed - erased);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _clock.stop();
      _typed.value = _line.length;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sul PC la riga si legge da più lontano: più grande.
    final style = TextStyle(
      fontFamily: 'Courier',
      fontFamilyFallback: monoFallback,
      color: AppColors.textPrimary,
      fontSize: DesktopCanvas.of(context) ? 21 : 13.5,
      height: 1.3,
      shadows: const [
        Shadow(color: Colors.black, blurRadius: 6),
        Shadow(color: Colors.black, blurRadius: 2),
      ],
    );
    final line = _line;
    return Align(
      alignment: Alignment.center,
      child: ValueListenableBuilder<int>(
        valueListenable: _typed,
        builder: (context, typed, _) {
          final shown = min(typed, line.length);
          // Le lettere non ancora battute ci sono già, trasparenti: così la
          // riga non si sposta mentre si scrive.
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: line.substring(0, shown)),
                TextSpan(
                  text: line.substring(shown),
                  style: const TextStyle(color: Color(0x00000000), shadows: []),
                ),
              ],
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            style: style,
          );
        },
      ),
    );
  }
}
