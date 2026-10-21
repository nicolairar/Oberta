import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/join_code.dart';
import '../../../online/online_services.dart';
import '../../../l10n/desktop_online_strings.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/scene_scaffold.dart';
import 'online_desktop.dart';
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
    return SceneScaffold(
      resizeForKeyboard: false,
      appBar: AppBar(title: Text(t.joinTitle)),
      body: OnlineBody(
        children: [
          const SizedBox(height: 12),
          OnlinePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('online.joinCode'),
                  controller: _code,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: JoinCode.length,
                  style: AppText.display(30, color: AppColors.gold).copyWith(letterSpacing: 8),
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (old, value) => value.copyWith(text: value.text.toUpperCase()),
                    ),
                    FilteringTextInputFormatter.allow(RegExp('[${JoinCode.alphabet}]')),
                  ],
                  decoration: InputDecoration(labelText: t.codeLabel, errorText: _error, counterText: ''),
                  onSubmitted: (_) => _join(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _busy ? null : _join, child: Text(t.joinSubmit)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(t.scan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sul PC: le sei caselle grandi al centro, si scrive e INVIO entra. La
  /// fotocamera qui non c'è: niente QR.
  Widget _desk(BuildContext context) {
    final t = AppStrings.of(context).online;
    final d = DesktopOnlineStrings.of(context);
    return DeskOnlineScene(
      title: t.joinTitle,
      child: Center(
        child: Container(
          width: 1000,
          padding: const EdgeInsets.fromLTRB(72, 64, 72, 56),
          decoration: DeskPanel.decoration(lit: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.codeLabel.toUpperCase(), style: DeskText.overline(color: AppColors.gold)),
              const SizedBox(height: 40),
              GestureDetector(
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
                            if (i > 0) SizedBox(width: i == JoinCode.length ~/ 2 ? 40 : 20),
                            _CodeBox(
                              char: i < _code.text.length ? _code.text[i] : null,
                              active: _focus.hasFocus &&
                                  (i == _code.text.length || (i == JoinCode.length - 1 && _code.text.length == JoinCode.length)),
                              error: _error != null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Il campo vero, invisibile sopra le caselle: tastiera,
                    // incolla e INVIO come in ogni campo.
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0,
                        child: TextField(
                          key: const Key('online.joinCode'),
                          controller: _code,
                          focusNode: _focus,
                          autofocus: true,
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
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 30,
                child: Text(
                  _error ?? d.joinHint,
                  style: DeskText.text(color: _error == null ? AppColors.textSecondary : AppColors.accent),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 420,
                height: DeskSize.button + 8,
                child: ListenableBuilder(
                  listenable: _code,
                  builder: (context, _) => ElevatedButton.icon(
                    onPressed: _busy || _code.text.length != JoinCode.length ? null : _join,
                    icon: const Icon(Icons.login),
                    label: Text(t.joinSubmit),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una casella del codice: la lettera grande in oro; quella da scrivere ha
/// il filo acceso.
class _CodeBox extends StatelessWidget {
  final String? char;
  final bool active;
  final bool error;

  const _CodeBox({required this.char, required this.active, required this.error});

  @override
  Widget build(BuildContext context) {
    final edge = error
        ? AppColors.accent
        : active
            ? AppColors.gold
            : AppColors.gold.withValues(alpha: char == null ? 0.25 : 0.55);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 108,
      height: 136,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.gold.withValues(alpha: 0.08) : const Color(0x66000000),
        borderRadius: BorderRadius.circular(DeskSize.radius),
        border: Border.all(color: edge, width: active ? 2.4 : 1.4),
        boxShadow: [if (active) BoxShadow(color: AppColors.gold.withValues(alpha: 0.25), blurRadius: 24)],
      ),
      child: char == null
          ? (active
              ? Container(width: 40, height: 4, color: AppColors.gold, margin: const EdgeInsets.only(top: 60))
              : null)
          : Text(char!, style: DeskText.display(72)),
    );
  }
}
