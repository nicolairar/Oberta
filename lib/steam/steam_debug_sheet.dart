import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/theme/app_theme.dart';
import 'steam.dart';
import '../ui/widgets/noir_modal.dart';

/// Il menu nascosto per provare l'idraulica Steam con l'App ID 480: solo
/// nelle build `--dart-define=STEAM=true` di prova (`BuildFlags.testTools`,
/// mai in quella che va su Steam), si apre dalle Impostazioni del
/// desktop con Ctrl+Shift+S (⌘⇧S sul Mac). Non è roba per i giocatori:
/// testi in inglese, nessuna traduzione.
class SteamDebugSheet extends StatefulWidget {
  final SteamClient steam;

  const SteamDebugSheet({super.key, required this.steam});

  static final shortcuts = <ShortcutActivator>[
    const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true),
    const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true),
  ];

  static Future<void> open(BuildContext context) => showNoirDialog<void>(
        context,
        builder: (_) => DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: NoirInk.brass.withValues(alpha: 0.5)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
            child: SteamDebugSheet(steam: SteamClient.instance),
          ),
        ),
      );

  @override
  State<SteamDebugSheet> createState() => _SteamDebugSheetState();
}

class _SteamDebugSheetState extends State<SteamDebugSheet> {
  String? _ticket;
  bool _busy = false;

  SteamClient get _steam => widget.steam;

  Future<void> _requestTicket() async {
    setState(() => _busy = true);
    final bytes = await _steam.webApiTicket(SteamClient.webApiIdentity);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ticket = bytes == null ? 'no ticket (timeout or error)' : '${bytes.length} bytes · ${ticketHex(bytes).substring(0, 32)}…';
    });
  }

  @override
  Widget build(BuildContext context) {
    final running = _steam.running;
    Widget line(String label, String? value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SelectableText('$label: ${value ?? '—'}', style: AppText.body),
        );
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('STEAM DEBUG', style: AppText.display(20)),
          const SizedBox(height: 12),
          line('flag STEAM', '${SteamClient.enabled}'),
          line('dev App ID', '${SteamClient.devAppId}'),
          line('running', '$running'),
          if (!running) line('problem', _steam.problem),
          if (running) ...[
            line('SteamID64', '${_steam.steamId}'),
            line('persona', _steam.personaName),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('steam.ticket'),
              onPressed: _busy ? null : _requestTicket,
              child: Text('GetAuthTicketForWebApi("${SteamClient.webApiIdentity}")'),
            ),
            if (_ticket != null) line('ticket', _ticket),
            const SizedBox(height: 12),
            Text('Spacewar achievements (480)', style: AppText.overline),
            for (final name in spacewarAchievements)
              Row(
                children: [
                  Expanded(child: Text('$name · ${_steam.achieved(name) ?? '?'}', style: AppText.body)),
                  TextButton(onPressed: () => setState(() => _steam.unlock(name)), child: const Text('UNLOCK')),
                  TextButton(onPressed: () => setState(() => _steam.clear(name)), child: const Text('CLEAR')),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
