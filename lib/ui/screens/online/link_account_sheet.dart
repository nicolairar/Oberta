import 'package:flutter/material.dart';

import '../../../l10n/desktop_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/platform_marks.dart';
import 'sign_in_sheet.dart';

/// «Collega account»: si entra con l'altra identità nel browser (Apple o
/// Google dal PC, Steam dal telefono) e il server unisce i due profili.
/// Niente codici da copiare. Le regole di fusione stanno sul server.
Future<void> showLinkAccount(BuildContext context, {required AccountLinkRepository links}) => showDialog<void>(
      context: context,
      builder: (_) => LinkAccountDialog(links: links),
    );

class LinkAccountDialog extends StatefulWidget {
  final AccountLinkRepository links;

  const LinkAccountDialog({super.key, required this.links});

  @override
  State<LinkAccountDialog> createState() => _LinkAccountDialogState();
}

class _LinkAccountDialogState extends State<LinkAccountDialog> {
  LinkProvider? _busy;
  Object? _error;

  Future<void> _link(LinkProvider provider) async {
    setState(() {
      _busy = provider;
      _error = null;
    });
    final d = DesktopStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final switched = await widget.links.link(provider);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(switched ? d.linkSwitched : d.linkDone)));
    } on OnlineException catch (error) {
      if (!mounted) return;
      if (error.failure == OnlineFailure.linkSameAccount) {
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(d.linkAlready)));
        return;
      }
      if (error.failure != OnlineFailure.cancelled) setState(() => _error = error);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _logo(LinkProvider provider) => switch (provider) {
        LinkProvider.steam => const SteamLogo(size: 20, color: AppColors.gold),
        LinkProvider.apple => const Icon(Icons.apple, color: AppColors.gold),
        LinkProvider.google => const Icon(Icons.g_mobiledata, color: AppColors.gold, size: 28),
      };

  @override
  Widget build(BuildContext context) {
    final d = DesktopStrings.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(d.linkAccount),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(d.linkBody, style: AppText.body),
            const SizedBox(height: 14),
            for (final provider in widget.links.providers) ...[
              OutlinedButton.icon(
                key: Key('link.${provider.name}'),
                icon: _busy == provider
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                      )
                    : _logo(provider),
                label: Text(d.linkWith(provider.label)),
                onPressed: _busy == null ? () => _link(provider) : null,
              ),
              const SizedBox(height: 8),
            ],
            if (_busy != null) Text(d.linkWaiting, style: AppText.body.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            Text(d.linkRule, style: AppText.body.copyWith(fontSize: 12, color: AppColors.textSecondary)),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              FailureNote(error: error),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(d.close)),
      ],
    );
  }
}
