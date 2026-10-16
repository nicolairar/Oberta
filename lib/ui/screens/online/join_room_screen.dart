import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/join_code.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/scene_scaffold.dart';
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

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
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
}
