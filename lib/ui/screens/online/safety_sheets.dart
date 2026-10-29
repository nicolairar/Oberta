import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/safety_strings.dart';
import '../../../l10n/stats_strings.dart';
import '../../../online/online_services.dart';
import '../../press.dart';
import '../../theme/app_theme.dart';
import '../../widgets/noir_modal.dart';
import '../../widgets/noir_avatar.dart';
import '../../widgets/noir_notice.dart';
import '../../widgets/platform_marks.dart';
import 'game/noir_ui.dart';
import 'online_widgets.dart';
import 'profile_sheet.dart';
import 'voice/voice_dock.dart';

/// Il foglio di un altro giocatore: toccando il suo volto al tavolo o nella
/// stanza, tenendo premuto un suo messaggio. In testa solo quello che si vede
/// adesso (ritratto, nome, livello, posto, stato pubblico: mai il ruolo),
/// sotto le azioni: il fascicolo, chiedere l'amicizia, silenziarne la voce o
/// la chat (solo qui), bloccarlo, segnalarlo. Niente per sé stessi.
Future<void> showPlayerActions(
  BuildContext context, {
  required OnlineServices services,
  required String profileId,
  required String name,
  required String myId,
  String? gameId,
  ChatMessage? message,
  VoiceMuteAction? voice,
  String? seat,
  String? status,
  bool? canBefriend,
}) async {
  final safety = services.safety;
  if (profileId == myId) return;
  HapticFeedback.selectionClick();
  final s = SafetyStrings.of(context);
  final t = AppStrings.of(context).online;
  final blocked = BlockedPlayers.ids.value.contains(profileId);
  final chatMuted = BlockedPlayers.chatMutes(profileId);
  final friendable = !blocked && (canBefriend ?? await _notLinked(services, profileId));
  if (!context.mounted) return;
  final action = await showNoirMenu<String>(
    context,
    key: const Key('safety.actions'),
    title: name,
    header: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlayerHeader(services: services, profileId: profileId, name: name, seat: seat, status: status),
        if (message != null) ...[SizedBox(height: NoirMetrics.of(context).gap), NoirQuote(message.body)],
      ],
    ),
    items: [
      NoirMenuItem(
        key: const Key('safety.profile'),
        value: 'profile',
        icon: Icons.badge_outlined,
        label: StatsStrings.of(context).profile,
      ),
      if (friendable)
        NoirMenuItem(key: const Key('safety.befriend'), value: 'friend', icon: Icons.person_add_alt, label: t.addFriend),
      // Silenziare la voce e la chat: solo su questo telefono.
      if (voice != null)
        NoirMenuItem(
          key: const Key('voice.muteSeat'),
          value: 'voice',
          icon: voice.muted ? Icons.volume_up : Icons.volume_off,
          label: voice.label,
        ),
      NoirMenuItem(
        key: const Key('safety.muteChat'),
        value: 'chat',
        icon: chatMuted ? Icons.chat_bubble_outline : Icons.speaker_notes_off_outlined,
        label: chatMuted ? s.unmuteChat : s.muteChat,
      ),
      if (safety != null) ...[
        if (blocked)
          NoirMenuItem(key: const Key('safety.unblock'), value: 'unblock', icon: Icons.lock_open, label: s.unblock)
        else
          NoirMenuItem(key: const Key('safety.block'), value: 'block', icon: Icons.block, label: s.block),
        NoirMenuItem(
          key: const Key('safety.rules'),
          value: 'rules',
          icon: Icons.menu_book_outlined,
          label: s.rulesTitle,
          tone: NoirMenuTone.dim,
        ),
        NoirMenuItem(
          key: const Key('safety.report'),
          value: 'report',
          icon: Icons.flag_outlined,
          label: s.report,
          tone: NoirMenuTone.danger,
        ),
      ],
    ],
  );
  if (!context.mounted) return;
  switch (action) {
    case 'voice':
      voice?.toggle();
    case 'chat':
      BlockedPlayers.toggleChat(profileId);
      showNotice(context, chatMuted ? s.chatUnmuted(name) : s.chatMuted(name), kind: NoticeKind.done);
    case 'friend':
      await _run(context, () async {
        final status = await services.friends.request(profileId);
        return status == FriendStatus.accepted ? t.nowFriends(name) : t.friendRequestSent(name);
      });
    case 'profile':
      await showPublicProfile(context, services: services, target: profileId);
    case 'report' when safety != null:
      await showReportDialog(context, safety: safety, profileId: profileId, name: name, gameId: gameId, message: message);
    case 'block' when safety != null:
      await confirmBlock(context, safety: safety, profileId: profileId, name: name);
    case 'unblock' when safety != null:
      await unblockPlayer(context, safety: safety, profileId: profileId, name: name);
    case 'rules':
      await showCommunityRules(context);
  }
}

/// Vero se con [profileId] non c'è ancora un legame (amici o richiesta).
Future<bool> _notLinked(OnlineServices services, String profileId) async {
  try {
    final links = await services.friends.list().timeout(const Duration(seconds: 3));
    return !links.any((link) => link.other.id == profileId);
  } catch (_) {
    return false;
  }
}

/// In testa al foglio: il ritratto, il livello (dal fascicolo pubblico, se
/// c'è), il posto e lo stato che vedono tutti. Il nome è il titolo.
class _PlayerHeader extends StatefulWidget {
  final OnlineServices services;
  final String profileId;
  final String name;
  final String? seat;
  final String? status;

  const _PlayerHeader({required this.services, required this.profileId, required this.name, this.seat, this.status});

  @override
  State<_PlayerHeader> createState() => _PlayerHeaderState();
}

class _PlayerHeaderState extends State<_PlayerHeader> {
  late final Future<PublicProfile> _load = widget.services.profiles.publicProfile(widget.profileId);

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    final t = AppStrings.of(context).online;
    final size = m.desk ? 88.0 : 64.0;
    return FutureBuilder<PublicProfile>(
      future: _load,
      builder: (context, snap) {
        final profile = snap.data?.profile;
        final line = [?widget.seat, ?widget.status].join(' · ');
        return Row(
          key: const Key('player.header'),
          children: [
            MarkedPortrait(
              name: widget.name,
              picture: profile?.pictureUrl,
              size: size,
              fallback: NoirAvatar.drawn(seed: profile?.avatarSeed ?? widget.name, size: size),
            ),
            SizedBox(width: m.gap * 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile != null)
                    Text(
                      t.levelShort(profile.level),
                      key: const Key('player.level'),
                      style: NoirType.label(m, color: NoirInk.brass),
                    ),
                  if (line.isNotEmpty)
                    Text(line, key: const Key('player.status'), style: NoirType.small(m, color: NoirInk.body)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Il foglio di un posto al tavolo. [profileId] è chi siede lì (dal tavolo
/// della partita); senza, lo si ritrova dal nome, che è unico. I bot non
/// hanno profilo, e non si segnalano.
Future<void> showSeatActions(
  BuildContext context, {
  required OnlineServices services,
  required String name,
  required String myId,
  String? profileId,
  String? gameId,
  VoiceMuteAction? voice,
  String? seat,
  String? status,
}) async {
  var id = profileId;
  if (id == null) {
    try {
      final found = await services.profiles.search(name);
      id = found.where((p) => p.handle?.toLowerCase() == name.toLowerCase()).firstOrNull?.id;
    } catch (_) {}
  }
  if (!context.mounted) return;
  if (id == null) {
    // Un bot, o nessun profilo da trovare: resta solo la voce da silenziare.
    if (voice != null) await _voiceOnly(context, name, voice);
    return;
  }
  await showPlayerActions(
    context,
    services: services,
    profileId: id,
    name: name,
    myId: myId,
    gameId: gameId,
    voice: voice,
    seat: seat,
    status: status,
  );
}

Future<void> _voiceOnly(BuildContext context, String name, VoiceMuteAction voice) async {
  HapticFeedback.selectionClick();
  final action = await showNoirMenu<String>(
    context,
    key: const Key('safety.actions'),
    title: name,
    items: [
      NoirMenuItem(
        key: const Key('voice.muteSeat'),
        value: 'voice',
        icon: voice.muted ? Icons.volume_up : Icons.volume_off,
        label: voice.label,
      ),
    ],
  );
  if (action == 'voice') voice.toggle();
}

Future<void> _run(BuildContext context, Future<String> Function() call) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  try {
    final done = await call();
    showNoticeIn(overlay, done, kind: NoticeKind.done);
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
  final sure = await confirmNoir(
    context,
    title: s.blockTitle(name),
    body: s.blockBody,
    icon: Icons.block,
    danger: true,
    cancel: s.cancel,
    confirm: s.block,
    confirmKey: const Key('safety.block.confirm'),
  );
  if (!sure || !context.mounted) return false;
  await _run(context, () async {
    await safety.block(profileId);
    return s.blocked(name);
  });
  return true;
}

/// Sblocca, senza domande: si torna a bloccare con un tocco.
Future<void> unblockPlayer(
  BuildContext context, {
  required SafetyRepository safety,
  required String profileId,
  required String name,
}) {
  final s = SafetyStrings.of(context);
  return _run(context, () async {
    await safety.unblock(profileId);
    return s.unblocked(name);
  });
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
  final sent = await showNoirDialog<bool>(
    context,
    builder: (_) => _ReportDialog(safety: safety, profileId: profileId, name: name, gameId: gameId, message: message),
  );
  if (sent == true && context.mounted) {
    showNotice(context, SafetyStrings.of(context).reportSent, kind: NoticeKind.done);
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
    final m = NoirMetrics.of(context);
    return NoirDialog(
      key: const Key('safety.reportDialog'),
      icon: Icons.flag_outlined,
      danger: true,
      title: s.reportTitle(widget.name),
      body: s.reportWhy,
      actions: [
        NoirAction(label: s.cancel, feel: Press.back, onPressed: _busy ? null : () => Navigator.pop(context, false)),
        NoirAction(
          key: const Key('safety.report.send'),
          label: s.send,
          style: NoirButtonStyle.danger,
          feel: Press.confirm,
          onPressed: _reason == null || _busy ? null : _send,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message case final message?) ...[
            Text(s.reportedMessage.toUpperCase(), style: NoirType.overline(m)),
            SizedBox(height: m.gap),
            NoirQuote(message.body),
            SizedBox(height: m.gap * 2),
          ],
          NoirMenuGroup(
            indent: false,
            children: [
              for (final reason in ReportReason.values)
                _ReasonRow(
                  key: Key('safety.reason.${reason.name}'),
                  label: s.reason(reason),
                  on: _reason == reason,
                  onTap: () => setState(() => _reason = reason),
                ),
            ],
          ),
          SizedBox(height: m.gap * 2),
          NoirField(key: const Key('safety.note'), controller: _note, maxLength: 500, maxLines: 4, hint: s.noteHint),
          SizedBox(height: m.gap),
          Row(
            children: [
              Icon(Icons.visibility_off_outlined, size: m.desk ? 20 : 15, color: NoirInk.muted),
              SizedBox(width: m.gap),
              Expanded(child: Text(s.reportPrivate, style: NoirType.small(m))),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('safety.report.rules'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size(0, m.desk ? 48 : 44),
                foregroundColor: NoirInk.brass,
              ),
              onPressed: () => showCommunityRules(context),
              icon: Icon(Icons.menu_book_outlined, size: m.desk ? 20 : 16),
              label: Text(s.rulesTitle, style: NoirType.small(m, color: NoirInk.brass).copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
          if (_failure case final failure?) NoirErrorLine(failure, key: const Key('safety.report.failure')),
        ],
      ),
    );
  }
}

/// A reason in the report card: the label and a brass check when picked.
class _ReasonRow extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _ReasonRow({super.key, required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = NoirMetrics.of(context);
    return Semantics(
      selected: on,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: pressed(onTap, Press.toggle),
        child: Container(
          constraints: BoxConstraints(minHeight: m.desk ? 56 : 44),
          color: on ? NoirInk.brass.withValues(alpha: 0.1) : null,
          padding: EdgeInsets.symmetric(horizontal: m.desk ? 20 : 14),
          child: Row(
            children: [
              Expanded(child: Text(label, style: NoirType.label(m, color: on ? NoirInk.text : NoirInk.body).copyWith(fontSize: m.desk ? 18 : 15))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: m.desk ? 26 : 20,
                height: m.desk ? 26 : 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? NoirInk.brass : Colors.transparent,
                  border: Border.all(color: on ? NoirInk.brass : NoirInk.muted, width: 1.5),
                ),
                child: on ? Icon(Icons.check, size: m.desk ? 18 : 14, color: const Color(0xFF1C140E)) : null,
              ),
            ],
          ),
        ),
      ),
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
    await _run(context, () async {
      await widget.safety.unblock(profile.id);
      return s.unblocked(profile.name);
    });
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

/// «Profilo pubblico: sì/no» nelle impostazioni: legge il proprio profilo e
/// salva la scelta. [builder] disegna l'interruttore (telefono o desktop);
/// il valore è null finché non si sa.
class PublicProfileToggle extends StatefulWidget {
  final ProfileRepository profiles;
  final Widget Function(BuildContext context, bool? value, ValueChanged<bool> onChanged) builder;

  /// Quale interruttore del profilo: per difetto «Profilo pubblico».
  final bool Function(Profile me) read;
  final Future<Profile> Function(ProfileRepository profiles, bool on) write;

  const PublicProfileToggle({
    super.key,
    required this.profiles,
    required this.builder,
    this.read = _public,
    this.write = _setPublic,
  });

  /// «Gesti al tavolo».
  const PublicProfileToggle.gestures({super.key, required this.profiles, required this.builder})
    : read = _gestures,
      write = _setGestures;

  static bool _public(Profile me) => me.publicProfile;
  static Future<Profile> _setPublic(ProfileRepository profiles, bool on) => profiles.setPublicProfile(on);
  static bool _gestures(Profile me) => me.tableReactions;
  static Future<Profile> _setGestures(ProfileRepository profiles, bool on) => profiles.setTableReactions(on);

  @override
  State<PublicProfileToggle> createState() => _PublicProfileToggleState();
}

class _PublicProfileToggleState extends State<PublicProfileToggle> {
  bool? _value;

  @override
  void initState() {
    super.initState();
    widget.profiles.me().then((me) {
      if (mounted) setState(() => _value = widget.read(me));
    }, onError: (_) {});
  }

  Future<void> _set(bool on) async {
    final before = _value;
    setState(() => _value = on);
    try {
      await widget.write(widget.profiles, on);
    } catch (error) {
      if (!mounted) return;
      setState(() => _value = before);
      showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value, _set);
}
