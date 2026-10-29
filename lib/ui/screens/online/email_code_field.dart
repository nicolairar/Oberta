import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/script_fonts.dart';
import '../../widgets/noir_modal.dart';

/// Le sei caselle del codice della mail. Sotto ci sono sei caselle
/// disegnate; sopra, grande quanto loro, un campo solo e invisibile, che fa
/// tutto il resto: si scrive, si incolla (anche «123 456», o una riga con il
/// codice dentro: restano le cifre), e l'iPhone propone il codice arrivato
/// per mail (`oneTimeCode`). A sei cifre chiama [onCompleted], una volta.
class EmailCodeField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onCompleted;

  /// Per i lettori di schermo: «Codice di 6 cifre».
  final String label;
  final bool enabled;

  /// Le caselle in rosso: il codice di prima non andava.
  final bool error;
  final bool autofocus;

  /// Sul PC: caselle più grandi.
  final bool desk;

  static const length = 6;

  const EmailCodeField({
    super.key,
    required this.controller,
    required this.onCompleted,
    required this.label,
    this.enabled = true,
    this.error = false,
    this.autofocus = true,
    this.desk = false,
  });

  @override
  State<EmailCodeField> createState() => _EmailCodeFieldState();
}

class _EmailCodeFieldState extends State<EmailCodeField> {
  final _focus = FocusNode();
  String? _sent;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(EmailCodeField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final code = widget.controller.text;
    if (code.length < EmailCodeField.length) {
      _sent = null;
      return;
    }
    if (code == _sent) return;
    _sent = code;
    widget.onCompleted(code);
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final box = widget.desk ? 66.0 : 46.0;
    final gap = widget.desk ? 14.0 : 8.0;
    final height = widget.desk ? 84.0 : 58.0;
    final digits = [
      for (var i = 0; i < EmailCodeField.length; i++)
        _Box(
          digit: i < code.length ? code[i] : null,
          current: _focus.hasFocus && widget.enabled && i == code.length.clamp(0, EmailCodeField.length - 1),
          error: widget.error,
          width: box,
          height: height,
          size: widget.desk ? 40 : 28,
        ),
    ];
    return Center(
      child: SizedBox(
        width: box * EmailCodeField.length + gap * (EmailCodeField.length - 1) + gap,
        height: height,
        child: Stack(
          children: [
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final (i, digit) in digits.indexed) ...[
                    digit,
                    // Un respiro in mezzo: 123 456, come nella mail.
                    if (i == 2) SizedBox(width: gap),
                  ],
                ],
              ),
            ),
            Positioned.fill(
              child: Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: const TextSelectionThemeData(
                    selectionColor: Colors.transparent,
                    cursorColor: Colors.transparent,
                  ),
                ),
                // Il nome per i lettori di schermo; le cifre le legge il campo.
                child: Semantics(
                  label: widget.label,
                  child: TextField(
                    key: const Key('online.emailCodeInput'),
                    controller: widget.controller,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    // In attesa del server non si scrive, ma la tastiera resta su.
                    readOnly: !widget.enabled,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    autocorrect: false,
                    enableSuggestions: false,
                    showCursor: false,
                    maxLines: 1,
                    inputFormatters: const [_CodeFormatter()],
                    style: const TextStyle(color: Colors.transparent, fontSize: 1, height: 1),
                    decoration: const InputDecoration.collapsed(hintText: null),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Solo cifre, al massimo sei: un incollato «Il codice è 123 456» diventa 123456.
class _CodeFormatter extends TextInputFormatter {
  const _CodeFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > EmailCodeField.length) digits = digits.substring(0, EmailCodeField.length);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// Una casella: carta scura, bordo d'ottone; la prossima da riempire più
/// accesa, in rosso se il codice non andava.
class _Box extends StatelessWidget {
  final String? digit;
  final bool current;
  final bool error;
  final double width;
  final double height;
  final double size;

  const _Box({
    required this.digit,
    required this.current,
    required this.error,
    required this.width,
    required this.height,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final edge = error
        ? NoirInk.blood
        : current
        ? NoirInk.brassLight
        : digit == null
        ? NoirInk.brassDeep
        : NoirInk.brass;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NoirInk.cardDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: edge, width: current || error ? 2 : 1.4),
        boxShadow: current ? [BoxShadow(color: NoirInk.brass.withValues(alpha: 0.25), blurRadius: 10)] : null,
      ),
      child: Text(
        digit ?? '',
        style: TextStyle(
          fontFamily: 'Courier',
          fontFamilyFallback: monoFallback,
          fontSize: size,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
