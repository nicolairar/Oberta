import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../narration/narrator_script.dart';
import '../theme/app_theme.dart';

/// Il copione da leggere ad alta voce, impaginato come un gobbo: il racconto
/// in corsivo da romanzo, i fatti in evidenza perché nessuno se li perda.
class ScriptCard extends StatelessWidget {
  /// Chi legge; `null` quando il narratore è automatico e legge chi ha il telefono.
  final String? reader;
  final List<ScriptLine> lines;

  /// I sottotitoli della voce (vedi `SpokenScriptCard`): per ogni battuta il
  /// testo a pezzi, già colorato, e quanto si vede. Senza, il testo è tutto lì.
  final List<InlineSpan>? spans;
  final List<bool>? shown;
  final List<Key>? lineKeys;

  /// Vero quando a leggere è la voce del telefono.
  final bool spoken;

  const ScriptCard({
    super.key,
    required this.reader,
    required this.lines,
    this.spans,
    this.shown,
    this.lineKeys,
    this.spoken = false,
  });

  @override
  Widget build(BuildContext context) {
    final reader = this.reader;
    final t = AppStrings.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        border: const Border(left: BorderSide(color: AppColors.gold, width: 3)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(spoken ? Icons.graphic_eq : Icons.record_voice_over, color: AppColors.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spoken ? t.narratorSpeaks : (reader == null ? t.readAloud : t.readerReadsAloud(reader)),
                  style: AppText.overline.copyWith(color: AppColors.gold),
                ),
              ),
            ],
          ),
          for (var i = 0; i < lines.length; i++) ...[
            const SizedBox(height: 14),
            _line(i),
          ],
        ],
      ),
    );
  }

  Widget _line(int i) {
    final line = lines[i];
    final span = spans?[i];
    final Widget child = line.isFact ? _FactLine(line.text, span: span) : _StoryLine(line.text, span: span);
    final shown = this.shown?[i] ?? true;
    return KeyedSubtree(
      key: lineKeys?[i],
      child: shown ? child : Opacity(opacity: 0, child: child),
    );
  }
}

/// Lo stile del racconto e quello dei fatti: servono anche ai sottotitoli.
const storyStyle = TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: ['serif'],
  fontSize: 18,
  height: 1.45,
  color: AppColors.textPrimary,
);

const factStyle = TextStyle(
  fontSize: 17,
  height: 1.4,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);

class _StoryLine extends StatelessWidget {
  final String text;
  final InlineSpan? span;

  const _StoryLine(this.text, {this.span});

  @override
  Widget build(BuildContext context) {
    final span = this.span;
    return span == null ? Text(text, style: storyStyle) : Text.rich(span, style: storyStyle);
  }
}

class _FactLine extends StatelessWidget {
  final String text;
  final InlineSpan? span;

  const _FactLine(this.text, {this.span});

  @override
  Widget build(BuildContext context) {
    final span = this.span;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: span == null ? Text(text, style: factStyle) : Text.rich(span, style: factStyle),
    );
  }
}
