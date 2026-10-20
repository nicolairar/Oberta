import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/desktop_strings.dart';
import '../../../online/join_code.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import 'sign_in_sheet.dart';

/// «Collega account»: da qui si crea il codice, o si scrive quello fatto
/// sull'altro dispositivo. Le regole di fusione stanno sul server.
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
  final _typed = TextEditingController();
  LinkCode? _code;
  bool _entering = false;
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() step) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await step();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _make() => _run(() async {
        final code = await widget.links.createCode();
        if (mounted) setState(() => _code = code);
      });

  Future<void> _redeem() => _run(() async {
        final code = JoinCode.normalize(_typed.text);
        if (code == null) throw const OnlineException(OnlineFailure.linkCodeInvalid);
        final signInAgain = await widget.links.redeemCode(code);
        if (!mounted) return;
        final d = DesktopStrings.of(context);
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text(signInAgain ? d.linkSignInAgain : d.linkDone)));
      });

  @override
  Widget build(BuildContext context) {
    final d = DesktopStrings.of(context);
    final code = _code;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(d.linkAccount),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (code != null) ...[
              SelectableText(
                code.code,
                key: const Key('link.code'),
                textAlign: TextAlign.center,
                style: AppText.display(34).copyWith(letterSpacing: 6, color: AppColors.gold),
              ),
              const SizedBox(height: 10),
              Text(d.linkCodeBody(10), style: AppText.body),
            ] else if (_entering) ...[
              TextField(
                key: const Key('link.input'),
                controller: _typed,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: JoinCode.length,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
                style: AppText.display(24).copyWith(letterSpacing: 4),
                textAlign: TextAlign.center,
                onSubmitted: (_) => _busy ? null : _redeem(),
              ),
              Text(d.linkRule, style: AppText.body.copyWith(fontSize: 12)),
            ] else ...[
              Text(d.linkHint, style: AppText.body),
              const SizedBox(height: 14),
              ElevatedButton(key: const Key('link.make'), onPressed: _busy ? null : _make, child: Text(d.linkMake)),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('link.enter'),
                onPressed: _busy ? null : () => setState(() => _entering = true),
                child: Text(d.linkEnter),
              ),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              FailureNote(error: error),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(d.close)),
        if (_entering && code == null)
          TextButton(
            key: const Key('link.submit'),
            onPressed: _busy ? null : _redeem,
            child: Text(d.linkSubmit),
          ),
      ],
    );
  }
}
