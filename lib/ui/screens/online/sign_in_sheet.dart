import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/desktop_strings.dart';
import '../../../l10n/online_strings.dart';
import '../../../online/online_services.dart';
import '../../desktop/desktop_canvas.dart';
import '../../desktop/home_modal.dart';
import '../../theme/app_theme.dart';
import 'email_code_field.dart';
import 'online_widgets.dart';
import '../../widgets/noir_modal.dart';
import '../../theme/script_fonts.dart';

/// Il foglio dell'accesso, che sale dal fondo del vicolo: Steam sul PC,
/// Apple, Google se l'app lo conosce, e l'email senza password (un codice di
/// sei cifre, o il link della stessa mail). Torna vero se qualcuno è entrato.
Future<bool> showSignInSheet(BuildContext context, {required OnlineServices services, String? note}) async {
  // Sul PC non c'è fondo da cui salire: una finestra al centro del vicolo.
  if (DesktopCanvas.peek(context)) {
    final t = AppStrings.of(context).online;
    final signedIn = await showDeskModal<bool>(
      context,
      builder: (context) => _DeskSignIn(
        title: t.loginTitle,
        builder: (onEnter) => SignInPanel(
          auth: services.auth,
          note: note,
          sheet: false,
          enterKey: onEnter,
          onSignedIn: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    return signedIn ?? false;
  }
  final signedIn = await showNoirSheet<bool>(
    context,
    builder: (context) => NoirSheet(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      children: [SignInPanel(auth: services.auth, note: note, onSignedIn: () => Navigator.of(context).pop(true))],
    ),
  );
  return signedIn ?? false;
}

/// La finestra dell'accesso sul PC: il titolo nella carta, INVIO entra
/// col primo modo d'accesso.
class _DeskSignIn extends StatefulWidget {
  final String title;
  final Widget Function(ValueNotifier<int> onEnter) builder;

  const _DeskSignIn({required this.title, required this.builder});

  @override
  State<_DeskSignIn> createState() => _DeskSignInState();
}

class _DeskSignInState extends State<_DeskSignIn> {
  final _enter = ValueNotifier(0);

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DeskModal(
    overline: AppStrings.of(context).homeTitle,
    title: widget.title,
    width: 680,
    hint: DesktopStrings.of(context).enterHint,
    onEnter: () => _enter.value++,
    child: widget.builder(_enter),
  );
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
                  fontFamilyFallback: monoFallback,
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
  final VoidCallback? onSignedIn;

  /// Nel foglio dal vicolo ha la maniglia e il suo titolo; nella schermata
  /// online il titolo sta già nella barra in alto.
  final bool sheet;

  /// Sul PC: ogni scatto è un INVIO, che entra col primo modo d'accesso (o
  /// manda l'email, o il codice).
  final ValueListenable<int>? enterKey;

  const SignInPanel({super.key, required this.auth, this.note, this.onSignedIn, this.sheet = true, this.enterKey});

  @override
  State<SignInPanel> createState() => _SignInPanelState();
}

/// Dove si è: i modi per entrare, l'indirizzo email, il codice della mail.
enum _Step { providers, email, code }

class _SignInPanelState extends State<SignInPanel> {
  _Step _step = _Step.providers;
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _done = false;
  Object? _error;

  /// A chi è partita l'ultima mail, e quando.
  String? _sentTo;
  DateTime? _sentAt;

  /// «Codice nuovo in arrivo»: dopo un secondo invio.
  bool _resent = false;
  Timer? _tick;

  /// Una mail al minuto per indirizzo: lo stesso limite del server
  /// (`smtp_max_frequency`), che altrimenti risponde «troppe mail».
  static const resendAfter = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    widget.enterKey?.addListener(_entered);
    widget.auth.addListener(_authChanged);
    _code.addListener(_codeChanged);
  }

  @override
  void dispose() {
    widget.enterKey?.removeListener(_entered);
    widget.auth.removeListener(_authChanged);
    _tick?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _codeChanged() {
    if (mounted) setState(() {});
  }

  /// Entrato da fuori (il link della mail, toccato nell'app di posta), o un
  /// link che non è andato. Chi entra col pulsante lo chiude [_signIn].
  void _authChanged() {
    if (!mounted) return;
    if (widget.auth.takeEmailLinkFailure() case final failure?) {
      setState(() {
        _error = failure;
        if (_sentTo != null) _step = _Step.code;
      });
    }
    if (widget.auth.signedIn && !_busy) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onSignedIn?.call();
  }

  /// INVIO: il primo modo d'accesso, l'indirizzo o il codice, secondo il passo.
  void _entered() {
    if (_busy) return;
    switch (_step) {
      case _Step.email:
        _sendCode();
      case _Step.code:
        _verify();
      case _Step.providers:
        final auth = widget.auth;
        if (auth.steamAvailable) {
          _signIn(auth.signInWithSteam);
        } else if (auth.appleAvailable) {
          _signIn(auth.signInWithApple);
        } else if (auth.googleAvailable) {
          _signIn(auth.signInWithGoogle);
        } else if (auth.emailAvailable) {
          _go(_Step.email);
        }
    }
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
      if (mounted) _finish();
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

  void _go(_Step step) {
    HapticFeedback.selectionClick();
    setState(() {
      _step = step;
      _error = null;
      _resent = false;
      if (step != _Step.code) _code.clear();
    });
  }

  /// Quanti secondi mancano prima di poter rimandare la mail.
  int get _wait {
    final sent = _sentAt;
    if (sent == null) return 0;
    final left = resendAfter - clock.now().difference(sent);
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _wait == 0) timer.cancel();
      if (mounted) setState(() {});
    });
  }

  /// Manda la mail (o la rimanda, [again]): poi si aspetta il codice.
  Future<void> _sendCode({bool again = false}) async {
    final address = again ? (_sentTo ?? '') : _email.text.trim();
    if (address.isEmpty || _busy) return;
    final language = AppStrings.of(context).language.code;
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
      _error = null;
      _resent = false;
    });
    try {
      await widget.auth.sendEmailCode(address, language: language);
      if (!mounted) return;
      setState(() {
        _sentTo = address;
        _sentAt = clock.now();
        _step = _Step.code;
        _resent = again;
        _code.clear();
      });
      _startTick();
    } catch (error) {
      debugPrint('Mail non partita: $error');
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final address = _sentTo;
    final code = _code.text;
    if (address == null || code.length < EmailCodeField.length || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.verifyEmailCode(email: address, code: code);
      if (mounted) _finish();
    } catch (error) {
      debugPrint('Codice non accettato: $error');
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = error;
          _code.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final auth = widget.auth;
    final desk = DesktopCanvas.of(context);
    final body = desk ? DeskText.text(size: DeskText.lead, color: AppColors.textSecondary) : AppText.body;
    final link = auth.emailLinkOpensApp;
    final lead = switch (_step) {
      _Step.providers => t.loginBody,
      _Step.email => link ? t.emailBody : t.emailBodyCodeOnly,
      _Step.code => link ? t.emailSentTo(_sentTo ?? '') : t.emailSentToCodeOnly(_sentTo ?? ''),
    };
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
        if (widget.sheet) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              _step == _Step.providers ? t.loginTitle : t.loginEmail.toUpperCase(),
              key: const Key('online.signInTitle'),
              textAlign: TextAlign.center,
              style: AppText.display(20),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.note case final note? when _step == _Step.providers) ...[
          Text(
            note,
            textAlign: TextAlign.center,
            style: body.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
        ],
        Text(lead, key: const Key('online.signInLead'), textAlign: TextAlign.center, style: body),
        SizedBox(height: desk ? 36 : 18),
        ...switch (_step) {
          _Step.providers => _providers(t, auth, desk),
          _Step.email => _emailForm(t, desk),
          _Step.code => _codeForm(t, desk),
        },
        // Gli errori dell'email stanno sotto il campo che li riguarda.
        if (_error case final error? when _step == _Step.providers) ...[
          const SizedBox(height: 14),
          FailureNote(error: error),
        ],
        SizedBox(height: desk ? 28 : 14),
        Text(
          t.loginPrivacy,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(fontSize: desk ? 15 : 12),
        ),
      ],
    );
  }

  List<Widget> _failure() => [
    if (_error case final error?) ...[const SizedBox(height: 14), FailureNote(error: error)],
  ];

  Widget _spinner() => const Padding(
    padding: EdgeInsets.only(top: 12),
    child: Center(
      child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
    ),
  );

  /// L'indirizzo: la tastiera delle email, e il portachiavi che lo propone.
  List<Widget> _emailForm(OnlineStrings t, bool desk) => [
    AutofillGroup(
      child: TextField(
        key: const Key('online.email'),
        controller: _email,
        autofocus: true,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.send,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.email],
        style: desk ? DeskText.text(size: DeskText.lead, color: AppColors.textPrimary) : null,
        decoration: InputDecoration(labelText: t.emailLabel),
        onSubmitted: (_) => _sendCode(),
      ),
    ),
    ..._failure(),
    SizedBox(height: desk ? 20 : 14),
    ElevatedButton(
      key: const Key('online.emailSend'),
      style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(desk ? 64 : 50)),
      onPressed: _busy ? null : _sendCode,
      child: Text(t.emailSend),
    ),
    if (_busy) _spinner(),
    SizedBox(height: desk ? 10 : 6),
    TextButton(
      key: const Key('online.emailBack'),
      onPressed: _busy ? null : () => _go(_Step.providers),
      child: Text(t.emailOtherWays),
    ),
  ];

  /// Il codice: sei caselle, «Entra», «Rimanda» col suo conto alla rovescia.
  List<Widget> _codeForm(OnlineStrings t, bool desk) {
    final wait = _wait;
    final codeFailure = switch (_error) {
      OnlineException(:final failure) =>
        failure == OnlineFailure.emailCodeWrong || failure == OnlineFailure.emailCodeExpired,
      _ => false,
    };
    final small = AppText.body.copyWith(fontSize: desk ? 15 : 12.5);
    return [
      EmailCodeField(
        key: const Key('online.emailCode'),
        controller: _code,
        label: t.emailCodeLabel,
        enabled: !_busy,
        error: codeFailure,
        desk: desk,
        onCompleted: (_) => _verify(),
      ),
      ..._failure(),
      SizedBox(height: desk ? 22 : 16),
      ElevatedButton(
        key: const Key('online.emailVerify'),
        style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(desk ? 64 : 50)),
        onPressed: _busy || _code.text.length < EmailCodeField.length ? null : _verify,
        child: Text(t.emailVerify),
      ),
      if (_busy) _spinner(),
      if (_resent) ...[
        const SizedBox(height: 10),
        Text(t.emailResent, key: const Key('online.emailResent'), textAlign: TextAlign.center, style: small),
      ],
      SizedBox(height: desk ? 10 : 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          TextButton(
            key: const Key('online.emailResend'),
            onPressed: _busy || wait > 0 ? null : () => _sendCode(again: true),
            child: Text(wait > 0 ? t.emailResendIn(wait) : t.emailResend),
          ),
          TextButton(
            key: const Key('online.emailChange'),
            onPressed: _busy ? null : () => _go(_Step.email),
            child: Text(t.emailChange),
          ),
        ],
      ),
      Text(t.emailSpam, textAlign: TextAlign.center, style: small),
    ];
  }

  List<Widget> _providers(OnlineStrings t, OnlineAuth auth, bool desk) => [
    if (auth.steamAvailable) ...[
      ElevatedButton.icon(
        key: const Key('online.signInSteam'),
        style:
            ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF171A21),
              foregroundColor: const Color(0xFFC7D5E0),
              minimumSize: Size.fromHeight(desk ? 72 : 50),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
              textStyle: desk ? const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.2) : null,
              iconSize: desk ? 32 : null,
            ).copyWith(
              overlayColor: desk ? WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.08)) : null,
              side: desk
                  ? WidgetStateProperty.resolveWith(
                      (states) => BorderSide(
                        color: const Color(0xFF66C0F4)
                            .withValues(alpha: states.contains(WidgetState.hovered) ? 0.9 : 0.3),
                        width: 1.4,
                      ),
                    )
                  : null,
            ),
        onPressed: _busy ? null : () => _signIn(auth.signInWithSteam),
        icon: const Icon(Icons.sports_esports),
        label: Text(DesktopStrings.of(context).loginSteam),
      ),
      if (_busy) ...[
        const SizedBox(height: 8),
        Text(DesktopStrings.of(context).steamWaiting, textAlign: TextAlign.center, style: AppText.body),
      ],
      if (auth.appleAvailable || auth.googleAvailable) SizedBox(height: desk ? 16 : 12),
    ],
    if (auth.appleAvailable)
      SignInWithAppleButton(
        text: t.loginApple,
        height: desk ? 64 : 50,
        style: SignInWithAppleButtonStyle.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        onPressed: _busy ? () {} : () => _signIn(auth.signInWithApple),
      ),
    // TODO(google): il pulsante segue le regole di Google; oggi è
    // un pulsante del gioco con la «G», da rivedere col logo ufficiale.
    if (auth.googleAvailable) ...[
      if (auth.appleAvailable) SizedBox(height: desk ? 16 : 12),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _signIn(auth.signInWithGoogle),
        icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        label: Text(t.loginGoogle),
      ),
    ],
    // L'email, per tutti e su ogni piattaforma: niente password, un codice.
    if (auth.emailAvailable) ...[
      if (auth.appleAvailable || auth.googleAvailable || auth.steamAvailable) SizedBox(height: desk ? 16 : 12),
      OutlinedButton.icon(
        key: const Key('online.signInEmail'),
        style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(desk ? 64 : 50)),
        onPressed: _busy ? null : () => _go(_Step.email),
        icon: Icon(Icons.mail_outline, size: desk ? 28 : 22),
        label: Text(t.loginEmail),
      ),
    ],
    if (!auth.appleAvailable && !auth.googleAvailable && !auth.steamAvailable && !auth.emailAvailable)
      Text(t.loginNoProvider, textAlign: TextAlign.center, style: AppText.body),
    if (_busy) ...[
      const SizedBox(height: 12),
      const Center(
        child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
      ),
    ],
  ];
}
