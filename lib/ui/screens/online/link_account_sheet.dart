import 'package:flutter/material.dart';

import '../../../l10n/desktop_strings.dart';
import '../../../online/online_services.dart';
import '../../press.dart';
import '../../widgets/noir_modal.dart';
import '../../widgets/noir_notice.dart';
import '../../widgets/platform_marks.dart';
import 'sign_in_sheet.dart';

/// «Collega account»: si entra con l'altra identità nel browser (Apple o
/// Google dal PC, Steam dal telefono) e il server unisce i due profili.
/// Niente codici da copiare. Le regole di fusione stanno sul server.
Future<void> showLinkAccount(BuildContext context, {required AccountLinkRepository links}) => showNoirDialog<void>(
      context,
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
    final overlay = Overlay.of(context, rootOverlay: true);
    final navigator = Navigator.of(context);
    try {
      final switched = await widget.links.link(provider);
      if (!mounted) return;
      navigator.pop();
      showNoticeIn(overlay, switched ? d.linkSwitched : d.linkDone, kind: NoticeKind.done);
    } on OnlineException catch (error) {
      if (!mounted) return;
      if (error.failure == OnlineFailure.linkSameAccount) {
        navigator.pop();
        showNoticeIn(overlay, d.linkAlready);
        return;
      }
      if (error.failure != OnlineFailure.cancelled) setState(() => _error = error);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _logo(LinkProvider provider, NoirMetrics m) => switch (provider) {
        LinkProvider.steam => SteamLogo(size: m.desk ? 26 : 20, color: NoirInk.brass),
        LinkProvider.apple => Icon(Icons.apple, color: NoirInk.brass, size: m.icon),
        LinkProvider.google => Icon(Icons.g_mobiledata, color: NoirInk.brass, size: m.icon + 6),
      };

  @override
  Widget build(BuildContext context) {
    final d = DesktopStrings.of(context);
    final m = NoirMetrics.of(context);
    return NoirDialog(
      icon: Icons.link,
      title: d.linkAccount,
      body: d.linkBody,
      actions: [NoirAction(label: d.close, feel: Press.back, onPressed: () => Navigator.of(context).pop())],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoirMenuGroup(
            children: [
              for (final provider in widget.links.providers)
                NoirMenuRow(
                  key: Key('link.${provider.name}'),
                  icon: Icons.link,
                  leading: _busy == provider
                      ? Center(
                          child: SizedBox.square(
                            dimension: m.desk ? 22 : 18,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: NoirInk.brass),
                          ),
                        )
                      : _logo(provider, m),
                  label: d.linkWith(provider.label),
                  onTap: _busy == null ? () => _link(provider) : null,
                ),
            ],
          ),
          SizedBox(height: m.gap * 2),
          if (_busy != null) ...[
            Text(d.linkWaiting, textAlign: TextAlign.center, style: NoirType.small(m, color: NoirInk.body)),
            SizedBox(height: m.gap),
          ],
          Text(d.linkRule, textAlign: TextAlign.center, style: NoirType.small(m)),
          if (_error case final error?) ...[
            SizedBox(height: m.gap * 2),
            FailureNote(error: error),
          ],
        ],
      ),
    );
  }
}
