import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/safety_strings.dart';
import '../../../l10n/stats_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import 'game/noir_ui.dart';
import 'online_widgets.dart';
import 'profile_sheet.dart';

/// Il foglio di un altro giocatore, tenendo premuto il suo posto, la sua
/// riga nella stanza o un suo messaggio: segnalarlo, bloccarlo o sbloccarlo.
/// Non fa niente per sé stessi, per i bot o dove la sicurezza non c'è.
Future<void> showPlayerActions(
  BuildContext context, {
  required OnlineServices services,
  required String profileId,
  required String name,
  required String myId,
  String? gameId,
  ChatMessage? message,
}) async {
  final safety = services.safety;
  if (safety == null || profileId == myId) return;
  HapticFeedback.selectionClick();
  final s = SafetyStrings.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _NoirSheet(
      key: const Key('safety.actions'),
      children: [
        Text(name, textAlign: TextAlign.center, style: AppText.display(20, color: Saloon.brass)),
        if (message != null) ...[
          const SizedBox(height: 10),
          _Quote(message.body),
        ],
        const SizedBox(height: 16),
        _SheetButton(
          key: const Key('safety.profile'),
          icon: Icons.badge_outlined,
          label: StatsStrings.of(context).profile,
          onTap: () => Navigator.pop(context, 'profile'),
        ),
        _SheetButton(
          key: const Key('safety.report'),
          icon: Icons.flag_outlined,
          label: s.report,
          color: Saloon.blood,
          onTap: () => Navigator.pop(context, 'report'),
        ),
        ValueListenableBuilder(
          valueListenable: BlockedPlayers.ids,
          builder: (context, ids, _) => ids.contains(profileId)
              ? _SheetButton(
                  key: const Key('safety.unblock'),
                  icon: Icons.lock_open,
                  label: s.unblock,
                  onTap: () => Navigator.pop(context, 'unblock'),
                )
              : _SheetButton(
                  key: const Key('safety.block'),
                  icon: Icons.block,
                  label: s.block,
                  onTap: () => Navigator.pop(context, 'block'),
                ),
        ),
        _SheetButton(
          key: const Key('safety.rules'),
          icon: Icons.menu_book_outlined,
          label: s.rulesTitle,
          dim: true,
          onTap: () => Navigator.pop(context, 'rules'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'profile':
      await showPublicProfile(context, services: services, target: profileId);
    case 'report':
      await showReportDialog(context, safety: safety, profileId: profileId, name: name, gameId: gameId, message: message);
    case 'block':
      await confirmBlock(context, safety: safety, profileId: profileId, name: name);
    case 'unblock':
      await _run(context, () => safety.unblock(profileId), s.unblocked(name));
    case 'rules':
      await showCommunityRules(context);
  }
}

/// Il foglio di un posto al tavolo: si sa solo il nome, che è unico, e da
/// lì si ritrova il profilo. I bot non hanno profilo, e non si segnalano.
Future<void> showSeatActions(
  BuildContext context, {
  required OnlineServices services,
  required String name,
  required String myId,
  String? gameId,
}) async {
  if (services.safety == null) return;
  Profile? profile;
  try {
    final found = await services.profiles.search(name);
    profile = found.where((p) => p.handle?.toLowerCase() == name.toLowerCase()).firstOrNull;
  } catch (_) {
    return;
  }
  if (profile == null || !context.mounted) return;
  await showPlayerActions(context, services: services, profileId: profile.id, name: name, myId: myId, gameId: gameId);
}

Future<void> _run(BuildContext context, Future<void> Function() call, String done) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await call();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(done)));
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

/// «Bloccare?», con quello che cambia. Vero se si è bloccato.
Future<bool> confirmBlock(
  BuildContext context, {
  required SafetyRepository safety,
  required String profileId,
  required String name,
}) async {
  final s = SafetyStrings.of(context);
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(s.blockTitle(name)),
      content: Text(s.blockBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
        TextButton(
          key: const Key('safety.block.confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.block, style: const TextStyle(color: Saloon.blood)),
        ),
      ],
    ),
  );
  if (sure != true || !context.mounted) return false;
  await _run(context, () => safety.block(profileId), s.blocked(name));
  return true;
}

/// La segnalazione: un motivo, due righe se si vuole, e via. Vero se è
/// partita.
Future<bool> showReportDialog(
  BuildContext context, {
  required SafetyRepository safety,
  required String profileId,
  required String name,
  String? gameId,
  ChatMessage? message,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportDialog(safety: safety, profileId: profileId, name: name, gameId: gameId, message: message),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(SafetyStrings.of(context).reportSent)));
  }
  return sent == true;
}

class _ReportDialog extends StatefulWidget {
  final SafetyRepository safety;
  final String profileId;
  final String name;
  final String? gameId;
  final ChatMessage? message;

  const _ReportDialog({required this.safety, required this.profileId, required this.name, this.gameId, this.message});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _note = TextEditingController();
  ReportReason? _reason;
  bool _busy = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    if (widget.message != null) _reason = ReportReason.language;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.safety.report(
        widget.profileId,
        reason,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        gameId: widget.gameId,
        messageId: widget.message?.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = failureText(context, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SafetyStrings.of(context);
    return AlertDialog(
      key: const Key('safety.reportDialog'),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Saloon.brassDeep),
      ),
      title: Text(s.reportTitle(widget.name), style: AppText.display(18, color: Saloon.brass)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.message case final message?) ...[
              Text(s.reportedMessage.toUpperCase(), style: AppText.overline.copyWith(fontSize: 11)),
              const SizedBox(height: 4),
              _Quote(message.body),
              const SizedBox(height: 12),
            ],
            Text(s.reportWhy, style: AppText.body),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (reason) => setState(() => _reason = reason),
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      key: Key('safety.reason.${reason.name}'),
                      value: reason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Saloon.brass,
                      title: Text(s.reason(reason), style: const TextStyle(color: AppColors.textPrimary)),
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('safety.note'),
              controller: _note,
              maxLength: 500,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(color: AppColors.textPrimary),
              cursorColor: Saloon.brass,
              decoration: InputDecoration(
                hintText: s.noteHint,
                hintStyle: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Text(s.reportPrivate, style: AppText.body.copyWith(fontSize: 12, color: AppColors.textSecondary)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('safety.report.rules'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Saloon.brass),
                onPressed: () => showCommunityRules(context),
                icon: const Icon(Icons.menu_book_outlined, size: 16),
                label: Text(s.rulesTitle),
              ),
            ),
            if (_failure case final failure?)
              Text(failure, key: const Key('safety.report.failure'), style: const TextStyle(color: Color(0xFFFF8A80))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(s.cancel)),
        TextButton(
          key: const Key('safety.report.send'),
          onPressed: _reason == null || _busy ? null : _send,
          child: Text(s.send, style: TextStyle(color: _reason == null ? AppColors.textSecondary : Saloon.blood)),
        ),
      ],
    );
  }
}

/// Le regole della community, con l'indirizzo per le cose urgenti.
Future<void> showCommunityRules(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CommunityRulesScreen()),
    );

class CommunityRulesScreen extends StatelessWidget {
  const CommunityRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SafetyStrings.of(context);
    return Scaffold(
      key: const Key('safety.rulesScreen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1E16),
        foregroundColor: AppColors.gold,
        centerTitle: true,
        title: Text(s.rulesTitle, style: AppText.display(18)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                for (final (i, rule) in s.rules.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('${i + 1}.', style: AppText.display(16, color: Saloon.brass)),
                        ),
                        Expanded(child: Text(rule, style: AppText.body.copyWith(fontSize: 15, color: AppColors.textPrimary))),
                      ],
                    ),
                  ),
                const Divider(color: Saloon.brassDeep, height: 28),
                Text(s.rulesEnforcement, style: AppText.body),
                const SizedBox(height: 16),
                Text(s.rulesContact, style: AppText.body),
                TextButton.icon(
                  key: const Key('safety.contact'),
                  style: TextButton.styleFrom(foregroundColor: Saloon.brass, alignment: Alignment.centerLeft),
                  onPressed: () => launchUrl(Uri(scheme: 'mailto', path: safetyContactEmail)),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text(safetyContactEmail),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// I giocatori bloccati, dalle impostazioni: ognuno con «Sblocca».
class BlockedPlayersScreen extends StatefulWidget {
  final SafetyRepository safety;

  const BlockedPlayersScreen({super.key, required this.safety});

  @override
  State<BlockedPlayersScreen> createState() => _BlockedPlayersScreenState();
}

class _BlockedPlayersScreenState extends State<BlockedPlayersScreen> {
  late Future<List<Profile>> _list = widget.safety.blocked();

  Future<void> _unblock(Profile profile) async {
    final s = SafetyStrings.of(context);
    await _run(context, () => widget.safety.unblock(profile.id), s.unblocked(profile.name));
    if (!mounted) return;
    final next = widget.safety.blocked();
    setState(() {
      _list = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = SafetyStrings.of(context);
    return Scaffold(
      key: const Key('safety.blockedScreen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1E16),
        foregroundColor: AppColors.gold,
        centerTitle: true,
        title: Text(s.blockedPlayers, style: AppText.display(18)),
      ),
      body: FutureBuilder<List<Profile>>(
        future: _list,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(failureText(context, snapshot.error!), style: AppText.body));
          }
          final list = snapshot.data;
          if (list == null) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          if (list.isEmpty) {
            return Center(child: Text(s.noneBlocked, key: const Key('safety.noneBlocked'), style: AppText.body));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OnlinePanel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    for (final profile in list)
                      ProfileRow(
                        key: ValueKey('blocked-${profile.id}'),
                        profile: profile,
                        trailing: TextButton(
                          key: Key('safety.unblock.${profile.id}'),
                          onPressed: () => _unblock(profile),
                          child: Text(s.unblock, style: const TextStyle(color: Saloon.brass)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoirSheet extends StatelessWidget {
  final List<Widget> children;

  const _NoirSheet({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF110C09),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: Saloon.brass, width: 1.6)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Saloon.brassDeep, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  final String text;

  const _Quote(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1712),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Saloon.brassDeep),
        ),
        child: Text(
          '«$text»',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: AppText.body.copyWith(fontStyle: FontStyle.italic, color: AppColors.textPrimary),
        ),
      );
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool dim;
  final VoidCallback onTap;

  const _SheetButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Saloon.brass,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: dim ? AppColors.textSecondary : color,
            side: BorderSide(color: (dim ? Saloon.brassDeep : color).withValues(alpha: 0.8)),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(icon),
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );
}

/// «Profilo pubblico: sì/no» nelle impostazioni: legge il proprio profilo e
/// salva la scelta. [builder] disegna l'interruttore (telefono o desktop);
/// il valore è null finché non si sa.
class PublicProfileToggle extends StatefulWidget {
  final ProfileRepository profiles;
  final Widget Function(BuildContext context, bool? value, ValueChanged<bool> onChanged) builder;

  const PublicProfileToggle({super.key, required this.profiles, required this.builder});

  @override
  State<PublicProfileToggle> createState() => _PublicProfileToggleState();
}

class _PublicProfileToggleState extends State<PublicProfileToggle> {
  bool? _value;

  @override
  void initState() {
    super.initState();
    widget.profiles.me().then((me) {
      if (mounted) setState(() => _value = me.publicProfile);
    }, onError: (_) {});
  }

  Future<void> _set(bool on) async {
    final before = _value;
    setState(() => _value = on);
    try {
      await widget.profiles.setPublicProfile(on);
    } catch (error) {
      if (!mounted) return;
      setState(() => _value = before);
      showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value, _set);
}
