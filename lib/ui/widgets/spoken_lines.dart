import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../l10n/app_strings.dart';
import '../../narration/narrator_script.dart';
import '../../sound/narrator_voice.dart';
import 'spoken_script_card.dart';

/// The automatic narrator says [lines] once, while [child] shows them its
/// own way (the curtain, the action strip). Nothing is drawn here: it is
/// the voice of [SpokenScriptCard] without the card. With a human
/// [reader], or with the voice off, it stays silent.
class SpokenLines extends StatefulWidget {
  final List<ScriptLine> lines;
  final String? reader;
  final Duration leadIn;
  final Widget child;

  const SpokenLines({
    super.key,
    required this.lines,
    required this.reader,
    required this.child,
    this.leadIn = const Duration(milliseconds: 350),
  });

  @override
  State<SpokenLines> createState() => _SpokenLinesState();
}

class _SpokenLinesState extends State<SpokenLines> {
  bool _started = false;
  bool _speaking = false;
  final List<Timer> _timers = [];

  NarratorVoice get _voice => NarratorVoice.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _speaking = SpokenScriptCard.speaksIn(context, widget.reader);
    if (!_speaking) return;
    final plan = _voice.plan(widget.lines, AppStrings.of(context).language, leadIn: widget.leadIn);
    _voice.claim(this, _stop);
    for (final step in plan.steps) {
      _timers.add(Timer(step.start, () => _voice.say(this, step)));
    }
    _timers.add(Timer(plan.length, () => _voice.release(this)));
  }

  void _stop() {
    for (final timer in _timers) {
      timer.cancel();
    }
  }

  @override
  void dispose() {
    _stop();
    if (_speaking) _voice.drop(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
