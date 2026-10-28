import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/noir_avatar.dart';
import '../../widgets/noir_notice.dart';
import '../../widgets/platform_marks.dart';

export '../../widgets/noir_notice.dart' show NoticeKind;

/// Che cosa dire quando una chiamata al server non va.
String failureText(BuildContext context, Object error) {
  final t = AppStrings.of(context).online;
  return t.failure(error is OnlineException ? error.failure : OnlineFailure.unknown);
}

void showFailure(BuildContext context, Object error) =>
    showNotice(context, failureText(context, error), kind: NoticeKind.error);

/// A short notice on the noir paper slip ([showNotice]).
void showNote(BuildContext context, String text, {NoticeKind kind = NoticeKind.info}) =>
    showNotice(context, text, kind: kind);

/// Il contenuto delle schermate online: una colonna stretta sopra la città,
/// che scorre se il telefono è piccolo.
class OnlineBody extends StatelessWidget {
  final List<Widget> children;

  const OnlineBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Un foglio scuro con il bordo dorato, come le targhe del vicolo.
class OnlinePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const OnlinePanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Un titoletto spaziato sopra una sezione.
class OnlineSection extends StatelessWidget {
  final String label;

  const OnlineSection(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(label, style: AppText.overline.copyWith(color: AppColors.gold)),
      );
}

/// Una riga con la faccia e il nome unico di un profilo.
class ProfileRow extends StatelessWidget {
  final Profile profile;
  final List<Widget> badges;
  final Widget? trailing;

  /// Tocco sulla riga (non sui bottoni): il fascicolo pubblico.
  final VoidCallback? onTap;

  const ProfileRow({super.key, required this.profile, this.badges = const [], this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = _row();
    return onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: row);
  }

  Widget _row() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MarkedPortrait(
            name: profile.name,
            picture: profile.pictureUrl,
            size: 46,
            fallback: NoirAvatar.drawn(seed: profile.avatarSeed, size: 46),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    PlatformBadges.of(steam: profile.onSteam, apple: profile.onApple, size: 14),
                  ],
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: badges),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class OnlineBadge extends StatelessWidget {
  final String label;
  final Color color;

  const OnlineBadge(this.label, {super.key, this.color = AppColors.gold});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ),
      );
}
