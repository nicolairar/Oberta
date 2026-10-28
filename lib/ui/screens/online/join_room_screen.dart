import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/join_code.dart';
import '../../../online/online_services.dart';
import '../../../l10n/desktop_online_strings.dart';
import '../../desktop/desktop_canvas.dart';
import '../../../l10n/desktop_strings.dart';
import '../../press.dart';
import '../../theme/app_theme.dart';
import 'cafe_room.dart';
import 'game/noir_ui.dart';
import 'online_room_screen.dart';
import 'online_widgets.dart';
import 'qr_scan_screen.dart';

/// Entrare in una stanza: il codice scritto a mano, o il QR inquadrato sul
/// telefono di chi l'ha aperta.
class JoinRoomScreen extends StatefulWidget {
  final OnlineServices services;
  final Profile me;

  /// Chi legge il QR. Senza, la fotocamera vera.
  final Future<String?> Function(BuildContext context)? scanner;

  const JoinRoomScreen({super.key, required this.services, required this.me, this.scanner});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _focus.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_busy) return;
    final t = AppStrings.of(context).online;
    final code = JoinCode.normalize(_code.text);
    if (code == null) {
      setState(() => _error = t.codeInvalid);
      return;
    }
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final room = await widget.services.rooms.join(code);
      await navigator.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => OnlineRoomScreen(services: widget.services, room: room, me: widget.me),
      ));
    } catch (error) {
      if (mounted) setState(() => _error = failureText(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final scanner = widget.scanner ?? QrScanScreen.scan;
    final code = await scanner(context);
    if (code == null || !mounted) return;
    _code.text = code;
    await _join();
  }

  final _focus = FocusNode();

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    if (DesktopCanvas.of(context)) return _desk(context);
    return CafeScaffold(
      resizeForKeyboard: false,
      title: t.joinTitle,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: (box.maxHeight * 0.3).clamp(120.0, 260.0), child: const CafeScene()),
                  const SizedBox(height: 18),
                  Text(
                    t.codeLabel.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppText.overline.copyWith(color: Saloon.brass, fontSize: 11, letterSpacing: 3.2),
                  ),
                  const SizedBox(height: 12),
                  _boxes(box: 46, gap: 8, autofocus: true),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 34),
                    child: Text(
                      _error ?? '',
                      key: const Key('online.joinError'),
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(fontSize: 13, color: AppColors.accent),
                    ),
                  ),
                  NoirButton(
                    key: const Key('online.joinSubmit'),
                    icon: Icons.login,
                    label: t.joinSubmit,
                    feel: Press.confirm,
                    onPressed: _busy ? null : _join,
                  ),
                  const SizedBox(height: 12),
                  NoirButton(
                    key: const Key('online.scan'),
                    kind: NoirButtonKind.brass,
                    compact: true,
                    icon: Icons.qr_code_scanner,
                    label: t.scan,
                    onPressed: _busy ? null : _scan,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Le sei caselle del codice, con il campo vero invisibile sopra:
  /// tastiera, incolla e INVIO come in ogni campo.
  Widget _boxes({required double box, required double gap, bool autofocus = false}) => GestureDetector(
        onTap: _focus.requestFocus,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([_code, _focus]),
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < JoinCode.length; i++) ...[
                    if (i > 0) SizedBox(width: i == JoinCode.length ~/ 2 ? gap * 2 : gap),
                    _CodeBox(
                      width: box,
                      char: i < _code.text.length ? _code.text[i] : null,
                      active: _focus.hasFocus &&
                          (i == _code.text.length || (i == JoinCode.length - 1 && _code.text.length == JoinCode.length)),
                      error: _error != null,
                    ),
                  ],
                ],
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  key: const Key('online.joinCode'),
                  controller: _code,
                  focusNode: _focus,
                  autofocus: autofocus,
                  autocorrect: false,
                  enableSuggestions: false,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  maxLength: JoinCode.length,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (old, value) => value.copyWith(text: value.text.toUpperCase()),
                    ),
                    FilteringTextInputFormatter.allow(RegExp('[${JoinCode.alphabet}]')),
                  ],
                  decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _join(),
                ),
              ),
            ),
          ],
        ),
      );

  /// Sul PC, come l'ingresso della classificata: la saletta a sinistra; a
  /// destra le sei caselle grandi, si scrive e INVIO entra. La fotocamera
  /// qui non c'è: niente QR.
  Widget _desk(BuildContext context) {
    final t = AppStrings.of(context).online;
    final d = DesktopOnlineStrings.of(context);
    return CafeDesk(
      title: t.joinTitle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: CafeScene()),
          const SizedBox(width: 56),
          Container(
            width: 700,
            padding: const EdgeInsets.fromLTRB(48, 44, 48, 44),
            decoration: Saloon.scrim(radius: DeskSize.radius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.codeLabel.toUpperCase(), style: DeskText.overline(color: Saloon.brass)),
                const SizedBox(height: 12),
                Text(d.hubJoinBody, style: DeskText.text(color: Saloon.paper.withValues(alpha: 0.82)).copyWith(height: 1.45)),
                const Spacer(),
                Center(child: _boxes(box: 82, gap: 12, autofocus: true)),
                const SizedBox(height: 28),
                SizedBox(
                  height: 30,
                  child: Text(
                    _error ?? d.joinHint,
                    textAlign: TextAlign.center,
                    style: DeskText.text(color: _error == null ? AppColors.textSecondary : AppColors.accent),
                  ),
                ),
                const Spacer(),
                ListenableBuilder(
                  listenable: _code,
                  builder: (context, _) => NoirButton(
                    key: const Key('online.joinSubmit'),
                    icon: Icons.login,
                    label: t.joinSubmit,
                    feel: Press.confirm,
                    onPressed: _busy || _code.text.length != JoinCode.length ? null : _join,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  DesktopStrings.of(context).enterHint,
                  textAlign: TextAlign.center,
                  style: DeskText.overline(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una casella del codice: la lettera grande d'ottone; quella da scrivere
/// ha il filo acceso.
class _CodeBox extends StatelessWidget {
  final double width;
  final String? char;
  final bool active;
  final bool error;

  const _CodeBox({required this.width, required this.char, required this.active, required this.error});

  @override
  Widget build(BuildContext context) {
    final edge = error
        ? AppColors.accent
        : active
            ? Saloon.brass
            : Saloon.brass.withValues(alpha: char == null ? 0.25 : 0.55);
    final height = width * 1.28;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? Saloon.brass.withValues(alpha: 0.08) : Saloon.ink.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(width * 0.16),
        border: Border.all(color: edge, width: active ? 2.2 : 1.3),
        boxShadow: [
          const BoxShadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 4)),
          if (active) BoxShadow(color: Saloon.brass.withValues(alpha: 0.25), blurRadius: 20),
        ],
      ),
      child: char == null
          ? (active
              ? Container(width: width * 0.36, height: 3, color: Saloon.brass, margin: EdgeInsets.only(top: height * 0.44))
              : null)
          : Text(char!, style: AppText.display(width * 0.62, color: Saloon.brass)),
    );
  }
}
