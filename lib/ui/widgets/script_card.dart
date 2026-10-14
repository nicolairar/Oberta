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

  const ScriptCard({super.key, required this.reader, required this.lines});

  @override
  Widget build(BuildContext context) {
    final reader = this.reader;
    final t = AppStrings.of(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over, color: AppColors.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reader == null ? t.readAloud : t.readerReadsAloud(reader),
                  style: AppText.overline.copyWith(color: AppColors.gold),
                ),
              ),
            ],
          ),
          for (final line in lines) ...[
            const SizedBox(height: 14),
            if (line.isFact) _FactLine(line.text) else _StoryLine(line.text),
          ],
        ],
      ),
    );
  }
}

class _StoryLine extends StatelessWidget {
  final String text;

  const _StoryLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: ['serif'],
        fontSize: 18,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _FactLine extends StatelessWidget {
  final String text;

  const _FactLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
