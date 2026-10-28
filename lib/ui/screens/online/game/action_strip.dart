import 'package:flutter/material.dart';

import '../../../desktop/desktop_canvas.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/noir_modal.dart';
import 'noir_ui.dart';

/// How the strip's status line reads: something to do, waiting for the
/// others, done, out of the game, or silenced.
enum StripTone { act, wait, done, out, muted }

/// The one strip under the table, the same height in every phase: a status
/// line (what to do now, what is chosen, who we are waiting for) and the
/// phase's buttons, the main one on the right. With no buttons the line
/// sits in the middle of the strip.
class ActionStrip extends StatelessWidget {
  /// What to do now, or what happened, in a plain sentence.
  final String status;
  final Key? statusKey;
  final StripTone tone;

  /// A short figure at the end of the status line (votes cast), with a
  /// ballot mark; [countTooltip] says it in words.
  final String? count;
  final String? countTooltip;

  /// A choice next to the buttons (the Tailor: vote or sew).
  final Widget? control;
  final List<NoirAction> actions;

  const ActionStrip({
    super.key,
    required this.status,
    this.statusKey,
    this.tone = StripTone.act,
    this.count,
    this.countTooltip,
    this.control,
    this.actions = const [],
  });

  /// The strip is always this tall: nothing above or below it moves.
  static double heightFor({required bool desk}) => desk ? 152 : 104;

  static (IconData, Color) _mark(StripTone tone) => switch (tone) {
    StripTone.act => (Icons.touch_app_outlined, Saloon.brass),
    StripTone.wait => (Icons.hourglass_empty, AppColors.textSecondary),
    StripTone.done => (Icons.check_circle_outline, Saloon.clean),
    StripTone.out => (Icons.visibility_outlined, AppColors.textSecondary),
    StripTone.muted => (Icons.voice_over_off, Saloon.mafia),
  };

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics(DesktopCanvas.of(context));
    final (icon, color) = _mark(tone);
    final buttons = control != null || actions.isNotEmpty;
    const shadow = [Shadow(color: Colors.black, blurRadius: 8)];
    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: m.desk ? 2 : 1),
          child: Icon(icon, size: m.desk ? 26 : 20, color: color),
        ),
        SizedBox(width: m.gap),
        Expanded(
          child: Text(
            status,
            key: statusKey,
            maxLines: buttons ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: m.body,
              height: 1.3,
              fontWeight: FontWeight.w500,
              shadows: shadow,
            ),
          ),
        ),
        if (count case final count?) ...[
          SizedBox(width: m.gap * 1.5),
          Tooltip(
            message: countTooltip ?? count,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.how_to_vote_outlined, size: m.desk ? 24 : 18, color: AppColors.textSecondary),
                SizedBox(width: m.gap / 2),
                Text(
                  count,
                  key: const Key('strip.count'),
                  maxLines: 1,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: m.body,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures(), FontFeature.liningFigures()],
                    shadows: shadow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
    // The strip changes with every tick of the phase: on its own layer.
    return RepaintBoundary(
      child: SizedBox(
      height: heightFor(desk: m.desk),
      child: Padding(
        padding: EdgeInsets.only(top: m.gap, bottom: m.desk ? m.gap : 0),
        child: Column(
          mainAxisAlignment: buttons ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line,
            if (buttons) _buttons(m),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buttons(NoirMetrics m) {
    final control = this.control;
    if (control == null) return NoirActions(actions: actions);
    return Row(
      children: [
        Expanded(flex: 3, child: control),
        for (final action in actions) ...[
          SizedBox(width: m.gap * 1.5),
          Expanded(flex: 2, child: NoirModalButton(key: action.key, action: action)),
        ],
      ],
    );
  }
}
