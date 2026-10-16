import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/app_strings.dart';
import '../../narration/narrator_script.dart';
import '../../sound/narrator_voice.dart';
import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import 'script_card.dart';

/// Il copione della pagina. Se legge un narratore in carne e ossa, o se il
/// telefono è muto, è il solito [ScriptCard]. Se il narratore è automatico
/// legge il telefono: la voce dice le battute una dopo l'altra e il testo si
/// scrive a tempo, come un sottotitolo; dove c'è il nome di un giocatore la
/// voce tace e il nome si accende.
///
/// Le battute possono crescere (la carta del condannato si gira): la voce
/// riprende da dove si era fermata.
class SpokenScriptCard extends StatefulWidget {
  final String? reader;
  final List<ScriptLine> lines;

  /// Il silenzio prima della prima battuta: al cambio d'ora lascia partire
  /// il tramonto, o l'alba, prima della voce.
  final Duration leadIn;

  const SpokenScriptCard({super.key, required this.reader, required this.lines, this.leadIn = const Duration(milliseconds: 350)});

  /// Vero se in questa pagina, adesso, parla il telefono.
  static bool speaksIn(BuildContext context, String? reader) =>
      reader == null && SoundStage.instance.enabled && NarratorVoice.instance.speaks(AppStrings.of(context).language);

  @override
  State<SpokenScriptCard> createState() => _SpokenScriptCardState();
}

class _SpokenScriptCardState extends State<SpokenScriptCard> with SingleTickerProviderStateMixin {
  /// Il testo si scrive un po' più in fretta della voce, così non resta mai indietro.
  static const _typingShare = 0.85;

  late final Ticker _ticker = createTicker(_tick);
  bool _started = false;
  bool _speaking = false;
  bool _animate = true;
  bool _done = false;
  bool _disposed = false;
  VoicePlan? _plan;
  int _from = 0;
  int _next = 0;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  int _currentLine = -1;
  final List<GlobalKey> _lineKeys = [];

  NarratorVoice get _voice => NarratorVoice.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _speaking = SpokenScriptCard.speaksIn(context, widget.reader);
    _animate = !MediaQuery.disableAnimationsOf(context);
    if (_speaking) _start(0, widget.leadIn);
  }

  @override
  void didUpdateWidget(SpokenScriptCard old) {
    super.didUpdateWidget(old);
    if (_speaking && widget.lines.length > old.lines.length) {
      _start(old.lines.length, const Duration(milliseconds: 500));
    }
  }

  void _start(int from, Duration leadIn) {
    _ticker.stop();
    _timer?.cancel();
    _from = from;
    _next = 0;
    _elapsed = Duration.zero;
    _done = false;
    _currentLine = -1;
    _plan = _voice.plan(widget.lines, AppStrings.of(context).language, from: from, leadIn: leadIn);
    _voice.claim(this, _hushed);
    if (_animate) {
      _ticker.start();
    } else {
      _schedule();
    }
  }

  /// Il telefono senza animazioni: il testo è già tutto lì, la voce va a tempo.
  void _schedule() {
    final plan = _plan!;
    if (_next < plan.steps.length) {
      _timer = Timer(plan.steps[_next].start - _elapsed, () {
        _elapsed = plan.steps[_next].start;
        _fireDue();
        _schedule();
      });
    } else {
      _timer = Timer(plan.length - _elapsed, _finish);
    }
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed;
    _fireDue();
    if (elapsed >= _plan!.length) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _fireDue() {
    final steps = _plan!.steps;
    while (_next < steps.length && steps[_next].start <= _elapsed) {
      final step = steps[_next++];
      _voice.say(this, step);
      if (step.line != _currentLine) {
        _currentLine = step.line;
        _follow(step.line);
      }
    }
  }

  /// Il gobbo segue la voce: la battuta che comincia resta in vista.
  void _follow(int line) {
    if (!_animate || line >= _lineKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _lineKeys[line].currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.9,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  void _finish() {
    _ticker.stop();
    _timer?.cancel();
    _voice.release(this);
    if (!_disposed) setState(() => _done = true);
  }

  /// Qualcuno è andato avanti: la voce tace, e il testo resta tutto.
  void _hushed() {
    _ticker.stop();
    _timer?.cancel();
    if (!_disposed && mounted) setState(() => _done = true);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _ticker.dispose();
    if (_speaking) _voice.drop(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_speaking) return ScriptCard(reader: widget.reader, lines: widget.lines);
    while (_lineKeys.length < widget.lines.length) {
      _lineKeys.add(GlobalKey());
    }
    final plan = _plan;
    final typing = _animate && !_done && plan != null;
    final spans = <InlineSpan>[];
    final shown = <bool>[];
    for (var i = 0; i < widget.lines.length; i++) {
      final steps = typing && i >= _from ? [for (final step in plan.steps) if (step.line == i) step] : const <VoiceStep>[];
      final started = steps.isEmpty || steps.first.start <= _elapsed;
      shown.add(started);
      spans.add(_spanFor(widget.lines[i], steps));
    }
    return ScriptCard(
      reader: widget.reader,
      lines: widget.lines,
      spans: spans,
      shown: shown,
      lineKeys: _lineKeys.sublist(0, widget.lines.length),
      spoken: true,
    );
  }

  /// La battuta come sottotitolo: quello già detto si vede, il resto c'è ma
  /// trasparente, così il testo non si sposta mentre si scrive.
  InlineSpan _spanFor(ScriptLine line, List<VoiceStep> steps) {
    final parts = line.voice.isEmpty ? [VoicePart.spoken(line.text)] : line.voice;
    return TextSpan(children: [
      for (var j = 0; j < parts.length; j++) ..._partSpans(parts[j], steps.isEmpty ? null : steps[j]),
    ]);
  }

  static const _hidden = TextStyle(color: Colors.transparent);
  static const _nameStyle = TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700);

  List<InlineSpan> _partSpans(VoicePart part, VoiceStep? step) {
    final text = part.display;
    var visible = text.length;
    var active = false;
    if (step != null) {
      if (_elapsed < step.start) {
        visible = 0;
      } else if (_elapsed < step.end) {
        active = true;
        final typed = step.length * _typingShare;
        final t = typed <= Duration.zero ? 1.0 : (_elapsed - step.start).inMicroseconds / typed.inMicroseconds;
        visible = part.isName ? text.length : (text.length * t.clamp(0.0, 1.0)).ceil();
      }
    }
    final style = part.isName
        ? _nameStyle.copyWith(backgroundColor: active ? AppColors.gold.withValues(alpha: 0.22) : null)
        : null;
    return [
      if (visible > 0) TextSpan(text: text.substring(0, visible), style: style),
      if (visible < text.length) TextSpan(text: text.substring(visible), style: style == null ? _hidden : style.merge(_hidden)),
    ];
  }
}
