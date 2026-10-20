import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/desktop_strings.dart';
import '../../../l10n/online_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import 'online_widgets.dart';

/// Il foglio dell'accesso, che sale dal fondo del vicolo: Apple, Google se
/// l'app lo conosce, e nient'altro. Torna vero se qualcuno è entrato.
///
/// Chi tiene premuto il titolo (o la targhetta «Accedi» nel vicolo, che
/// apre il foglio con [test]) trova l'account di prova con email e password.
Future<bool> showSignInSheet(
  BuildContext context, {
  required OnlineServices services,
  String? note,
  bool test = false,
}) async {
  final signedIn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
          child: SignInPanel(
            auth: services.auth,
            note: note,
            test: test,
            onSignedIn: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    ),
  );
  return signedIn ?? false;
}

/// Che cosa è andato storto, in due righe: quella gentile per chi gioca, e
/// sotto, in piccolo, il motivo tecnico da riportare a chi fa l'app.
class FailureNote extends StatelessWidget {
  final Object error;

  const FailureNote({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final reason = error is OnlineException ? (error as OnlineException).reason : error.toString();
    return DecoratedBox(
      key: const Key('online.failure'),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failureText(context, error),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(
                '${t.technicalReason}: $reason',
                key: const Key('online.failure.reason'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Courier',
                  fontFamilyFallback: ['monospace'],
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// L'ingresso vero e proprio, nel foglio dal vicolo e nella schermata online.
class SignInPanel extends StatefulWidget {
  final OnlineAuth auth;

  /// Una riga sopra i pulsanti: perché si sta entrando (una stanza, per esempio).
  final String? note;

  /// Comincia dall'account di prova.
  final bool test;
  final VoidCallback? onSignedIn;

  /// Nel foglio dal vicolo ha la maniglia e il suo titolo; nella schermata
  /// online il titolo sta già nella barra in alto.
  final bool sheet;

  const SignInPanel({
    super.key,
    required this.auth,
    this.note,
    this.test = false,
    this.onSignedIn,
    this.sheet = true,
  });

  @override
  State<SignInPanel> createState() => _SignInPanelState();
}

class _SignInPanelState extends State<SignInPanel> {
  late bool _test = widget.test;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(Future<void> Function() method) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await method();
      if (mounted) widget.onSignedIn?.call();
    } on OnlineException catch (error) {
      if (error.failure != OnlineFailure.cancelled) {
        debugPrint('Accesso non riuscito: $error');
        if (mounted) setState(() => _error = error);
      }
    } catch (error) {
      debugPrint('Accesso non riuscito: $error');
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleTest() {
    HapticFeedback.mediumImpact();
    setState(() {
      _test = !_test;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final auth = widget.auth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.sheet)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        // Il titolo tenuto premuto apre l'account di prova: i giocatori
        // non lo cercano, chi prova l'app sa dov'è.
        GestureDetector(
          key: const Key('online.signInTitle'),
          behavior: HitTestBehavior.opaque,
          onLongPress: _toggleTest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.sheet || _test) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    _test ? t.testAccount.toUpperCase() : t.loginTitle,
                    textAlign: TextAlign.center,
                    style: AppText.display(20),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (widget.note case final note?) ...[
                Text(note, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 8),
              ],
              Text(_test ? t.testAccountBody : t.loginBody, textAlign: TextAlign.center, style: AppText.body),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_test) ..._testForm(t) else ..._providers(t, auth),
        if (_error case final error?) ...[
          const SizedBox(height: 14),
          FailureNote(error: error),
        ],
        const SizedBox(height: 14),
        Text(t.loginPrivacy, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 12)),
      ],
    );
  }

  List<Widget> _providers(OnlineStrings t, OnlineAuth auth) => [
        if (auth.steamAvailable) ...[
          ElevatedButton.icon(
            key: const Key('online.signInSteam'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF171A21),
              foregroundColor: const Color(0xFFC7D5E0),
              minimumSize: const Size.fromHeight(50),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
            onPressed: _busy ? null : () => _signIn(auth.signInWithSteam),
            icon: const Icon(Icons.sports_esports),
            label: Text(DesktopStrings.of(context).loginSteam),
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            Text(DesktopStrings.of(context).steamWaiting, textAlign: TextAlign.center, style: AppText.body),
          ],
          if (auth.appleAvailable || auth.googleAvailable) const SizedBox(height: 12),
        ],
        if (auth.appleAvailable)
          SignInWithAppleButton(
            text: t.loginApple,
            height: 50,
            style: SignInWithAppleButtonStyle.white,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            onPressed: _busy ? () {} : () => _signIn(auth.signInWithApple),
          ),
        // TODO(google): il pulsante segue le regole di Google; oggi è
        // un pulsante del gioco con la «G», da rivedere col logo ufficiale.
        if (auth.googleAvailable) ...[
          if (auth.appleAvailable) const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _signIn(auth.signInWithGoogle),
            icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            label: Text(t.loginGoogle),
          ),
        ],
        if (!auth.appleAvailable && !auth.googleAvailable && !auth.steamAvailable)
          Text(t.loginNoProvider, textAlign: TextAlign.center, style: AppText.body),
        if (_busy) ...[
          const SizedBox(height: 12),
          const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
        ],
      ];

  List<Widget> _testForm(OnlineStrings t) => [
        TextField(
          key: const Key('online.testEmail'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: t.emailLabel),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('online.testPassword'),
          controller: _password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: t.passwordLabel),
          onSubmitted: (_) => _submitTest(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          key: const Key('online.testSubmit'),
          onPressed: _busy ? null : _submitTest,
          child: Text(t.testAccountSubmit),
        ),
      ];

  void _submitTest() => _signIn(
        () => widget.auth.signInWithTestAccount(email: _email.text, password: _password.text),
      );
}
