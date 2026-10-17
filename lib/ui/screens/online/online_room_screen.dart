import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/join_code.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/scene_scaffold.dart';
import 'online_widgets.dart';

/// La stanza online prima della partita: il codice grande e il QR per chi
/// deve ancora entrare, e la fila di chi è già seduto, aggiornata dal vivo.
/// Da qui si chiede l'amicizia a chi siede al tavolo. La partita online
/// non c'è ancora: il pulsante per cominciare dice «presto».
///
/// Uscendo dalla schermata si esce anche dalla stanza.
class OnlineRoomScreen extends StatefulWidget {
  final OnlineServices services;
  final Room room;
  final Profile me;

  const OnlineRoomScreen({super.key, required this.services, required this.room, required this.me});

  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen> {
  late Room _room = widget.room;
  List<RoomMember> _members = const [];
  StreamSubscription<List<RoomMember>>? _watch;

  /// Con chi c'è già un legame (amici o richiesta in corso): niente pulsante.
  final Set<String> _linked = {};
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _watch = widget.services.rooms
        .watchMembers(_room.id)
        .listen(
          _seated,
          onError: (Object error) {
            if (mounted) showFailure(context, error);
          },
        );
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final links = await widget.services.friends.list();
      if (mounted) setState(() => _linked.addAll(links.map((link) => link.other.id)));
    } catch (_) {
      // Senza l'elenco degli amici si vede solo qualche pulsante in più.
    }
  }

  Future<void> _seated(List<RoomMember> members) async {
    setState(() => _members = members);
    // Chi è padrone di casa può cambiare quando qualcuno esce.
    try {
      final room = await widget.services.rooms.fetch(_room.id);
      if (room != null && mounted) setState(() => _room = room);
    } catch (_) {}
  }

  @override
  void dispose() {
    _watch?.cancel();
    // Uscita senza un gesto (l'app che si chiude): la stanza passa da sola
    // al primo arrivato, nessuno resta senza padrone di casa.
    if (!_left) widget.services.rooms.leave(_room.id, autoHeir: true).ignore();
    super.dispose();
  }

  /// Uscire è una scelta: prima si conferma, e il padrone di casa con altra
  /// gente al tavolo sceglie a chi lasciare la stanza.
  Future<void> _askToLeave() async {
    if (_left) return;
    final t = AppStrings.of(context).online;
    final others = [
      for (final member in _members)
        if (member.profile.id != widget.me.id) member,
    ];
    String? heir;
    if (_room.hostId == widget.me.id && others.isNotEmpty) {
      heir = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text(t.chooseHostTitle, style: AppText.display(22, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(t.chooseHostBody, style: AppText.body),
              const SizedBox(height: 12),
              for (final member in others)
                ListTile(
                  key: Key('online.heir.${member.profile.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.vpn_key, color: AppColors.gold),
                  title: Text(member.profile.name, style: AppText.body),
                  onTap: () => Navigator.of(context).pop(member.profile.id),
                ),
            ],
          ),
        ),
      );
      if (heir == null || !mounted) return;
    } else {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(t.leaveConfirmTitle, style: AppText.display(22, color: AppColors.textPrimary)),
          content: Text(t.leaveConfirmBody, style: AppText.body),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.stay)),
            TextButton(
              key: const Key('online.leaveConfirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                t.leaveConfirm,
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    try {
      await widget.services.rooms.leave(_room.id, newHostId: heir);
      _left = true;
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _addFriend(Profile other) async {
    HapticFeedback.selectionClick();
    final t = AppStrings.of(context).online;
    try {
      final status = await widget.services.friends.request(other.id);
      if (!mounted) return;
      setState(() => _linked.add(other.id));
      showNote(context, status == FriendStatus.accepted ? t.nowFriends(other.name) : t.friendRequestSent(other.name));
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final t = strings.online;
    return PopScope(
      canPop: _left,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askToLeave();
      },
      child: SceneScaffold(
        appBar: AppBar(title: Text(t.roomTitle)),
        body: OnlineBody(
          children: [
            OnlinePanel(
              child: Column(
                children: [
                  Text(t.codeLabel.toUpperCase(), style: AppText.overline),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SelectableText(
                      _room.code,
                      key: const Key('online.roomCode'),
                      style: AppText.display(46, color: AppColors.gold).copyWith(letterSpacing: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(color: const Color(0xFFEDE2C8), borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: QrImageView(
                        data: JoinCode.qrPayload(_room.code),
                        size: 180,
                        backgroundColor: const Color(0xFFEDE2C8),
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF14110F)),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF14110F),
                        ),
                        semanticsLabel: _room.code,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(t.roomShareHint, textAlign: TextAlign.center, style: AppText.body),
                ],
              ),
            ),
            OnlineSection(t.roomSeated(_members.length, _room.maxPlayers)),
            OnlinePanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  for (final member in _members)
                    ProfileRow(
                      key: ValueKey(member.profile.id),
                      profile: member.profile,
                      badges: [
                        if (member.profile.id == _room.hostId) OnlineBadge(t.hostBadge),
                        if (member.profile.id == widget.me.id)
                          OnlineBadge(strings.youBadge, color: AppColors.textSecondary),
                      ],
                      trailing: member.profile.id == widget.me.id || _linked.contains(member.profile.id)
                          ? null
                          : IconButton(
                              tooltip: t.addFriend,
                              icon: const Icon(Icons.person_add_alt_1, color: AppColors.gold),
                              onPressed: () => _addFriend(member.profile),
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: null, child: Text(t.startSoon)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _askToLeave, child: Text(t.leaveRoom)),
          ],
        ),
      ),
    );
  }
}
