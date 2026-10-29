import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../../l10n/desktop_online_strings.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import 'cafe_room.dart';
import 'game/noir_ui.dart';
import 'online_desktop.dart';
import 'online_widgets.dart';
import 'profile_sheet.dart';

/// Gli amici, nella saletta riservata: cercare qualcuno per nome unico,
/// rispondere alle richieste, vedere chi aspetta una risposta e chi è già
/// amico.
class FriendsScreen extends StatefulWidget {
  final OnlineServices services;

  const FriendsScreen({super.key, required this.services});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _search = TextEditingController();
  Timer? _typing;
  List<Friendship> _links = const [];
  List<Profile>? _results;
  bool _loading = true;

  FriendsRepository get _friends => widget.services.friends;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _typing?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final links = await _friends.list();
      if (mounted) setState(() => _links = links);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _typed(String text) {
    _typing?.cancel();
    if (text.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _typing = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await widget.services.profiles.search(text);
        if (mounted && _search.text == text) setState(() => _results = results);
      } catch (error) {
        if (mounted) showFailure(context, error);
      }
    });
  }

  Future<void> _act(Future<void> Function() action, {String? note}) async {
    HapticFeedback.selectionClick();
    try {
      await action();
      if (note != null && mounted) showNote(context, note);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
    await _reload();
  }

  /// Il fascicolo pubblico, con «Blocca» e «Segnala» in fondo. Al ritorno
  /// la lista si rilegge: un blocco toglie l'amicizia e le richieste.
  Future<void> _openProfile(Profile other) async {
    await showPublicProfile(context, services: widget.services, target: other.id);
    if (mounted) await _reload();
  }

  Future<void> _request(Profile other) async {
    final t = AppStrings.of(context).online;
    HapticFeedback.selectionClick();
    try {
      final status = await _friends.request(other.id);
      if (mounted) {
        showNote(context, status == FriendStatus.accepted ? t.nowFriends(other.name) : t.friendRequestSent(other.name));
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final incoming = [for (final l in _links) if (l.status == FriendStatus.pending && l.incoming) l];
    final outgoing = [for (final l in _links) if (l.status == FriendStatus.pending && !l.incoming) l];
    final friends = [for (final l in _links) if (l.status == FriendStatus.accepted) l];
    final linked = {for (final l in _links) l.other.id};
    if (DesktopCanvas.of(context)) {
      return _desk(context, incoming: incoming, outgoing: outgoing, friends: friends, linked: linked);
    }

    return CafeScaffold(
      resizeForKeyboard: false,
      title: t.friends,
      child: OnlineBody(
        children: [
          TextField(
            key: const Key('online.search'),
            controller: _search,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: _typed,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: AppColors.gold),
              hintText: t.searchHint,
              filled: true,
              fillColor: Saloon.ink.withValues(alpha: 0.86),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Saloon.brassDeep.withValues(alpha: 0.7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Saloon.brass, width: 1.6),
              ),
            ),
          ),
          if (_results case final results?) ...[
            const SizedBox(height: 8),
            CafePanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(t.noResults, textAlign: TextAlign.center, style: AppText.body),
                    )
                  : Column(
                      children: [
                        for (final profile in results)
                          ProfileRow(
                            profile: profile,
                            onTap: () => _openProfile(profile),
                            trailing: linked.contains(profile.id)
                                ? null
                                : TextButton(onPressed: () => _request(profile), child: Text(t.add)),
                          ),
                      ],
                    ),
            ),
          ],
          if (incoming.isNotEmpty) ...[
            _Section(t.requests),
            CafePanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  for (final link in incoming)
                    ProfileRow(
                      key: Key('friends.request.${link.other.id}'),
                      profile: link.other,
                      onTap: () => _openProfile(link.other),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: t.decline,
                            icon: const Icon(Icons.close, color: AppColors.textSecondary),
                            onPressed: () => _act(() => _friends.respond(link.other.id, accept: false)),
                          ),
                          IconButton(
                            tooltip: t.accept,
                            icon: const Icon(Icons.check, color: AppColors.gold),
                            onPressed: () => _act(
                              () => _friends.respond(link.other.id, accept: true),
                              note: t.nowFriends(link.other.name),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          _Section(t.yourFriends),
          CafePanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  )
                : friends.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(t.friendsEmpty, textAlign: TextAlign.center, style: AppText.body),
                      )
                    : Column(
                        children: [
                          for (final link in friends)
                            ProfileRow(
                              key: Key('friends.row.${link.other.id}'),
                              profile: link.other,
                              onTap: () => _openProfile(link.other),
                              trailing: TextButton(
                                onPressed: () => _act(() => _friends.remove(link.other.id)),
                                child: Text(t.remove),
                              ),
                            ),
                        ],
                      ),
          ),
          if (outgoing.isNotEmpty) ...[
            _Section(t.waiting),
            CafePanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  for (final link in outgoing)
                    ProfileRow(
                      profile: link.other,
                      trailing: TextButton(
                        onPressed: () => _act(() => _friends.remove(link.other.id)),
                        child: Text(t.withdraw),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Sul PC: a sinistra la ricerca, al centro gli amici, a destra chi
  /// aspetta una risposta (le richieste in arrivo e quelle mandate).
  Widget _desk(
    BuildContext context, {
    required List<Friendship> incoming,
    required List<Friendship> outgoing,
    required List<Friendship> friends,
    required Set<String> linked,
  }) {
    final t = AppStrings.of(context).online;
    final d = DesktopOnlineStrings.of(context);
    Widget list(List<Widget> rows, {required String empty, IconData? icon}) => rows.isEmpty
        ? DeskEmpty(empty, icon: icon)
        : ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) => rows[i],
          );
    Widget count(int n) => n == 0 ? const SizedBox.shrink() : DeskBadge('$n');

    final results = _results;
    return CafeDesk(
      title: t.friends,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: CafePanel(
              expand: true,
              title: d.search,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('online.search'),
                    controller: _search,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: _typed,
                    style: DeskText.text(size: DeskText.lead),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(Icons.search, color: AppColors.gold, size: 28),
                      ),
                      hintText: t.searchHint,
                      hintStyle: DeskText.text(size: DeskText.lead, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: const Color(0x66000000),
                      contentPadding: const EdgeInsets.symmetric(vertical: 22),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(DeskSize.radius)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (results != null && results.isNotEmpty) ...[
                    Text(d.results.toUpperCase(), style: DeskText.overline()),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: results == null
                        ? DeskEmpty(d.searchEmpty, icon: Icons.person_search)
                        : list(
                            [
                              for (final profile in results)
                                DeskProfileRow(
                                  profile: profile,
                                  onTap: () => _openProfile(profile),
                                  actions: [
                                    if (!linked.contains(profile.id))
                                      OutlinedButton.icon(
                                        onPressed: () => _request(profile),
                                        icon: const Icon(Icons.person_add_alt_1, size: 22),
                                        label: Text(t.add),
                                      ),
                                  ],
                                ),
                            ],
                            empty: t.noResults,
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: DeskSize.gap),
          Expanded(
            flex: 6,
            child: CafePanel(
              expand: true,
              title: t.yourFriends,
              trailing: count(friends.length),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : list(
                      [
                        for (final link in friends)
                          DeskProfileRow(
                            profile: link.other,
                            onTap: () => _openProfile(link.other),
                            subtitle: t.levelShort(link.other.level),
                            actions: [
                              DeskIconAction(
                                icon: Icons.person_remove_outlined,
                                tooltip: t.remove,
                                color: AppColors.textSecondary,
                                onTap: () => _act(() => _friends.remove(link.other.id)),
                              ),
                            ],
                          ),
                      ],
                      empty: t.friendsEmpty,
                      icon: Icons.people_outline,
                    ),
            ),
          ),
          const SizedBox(width: DeskSize.gap),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CafePanel(
              expand: true,
                    title: t.requests,
                    trailing: count(incoming.length),
                    child: list(
                      [
                        for (final link in incoming)
                          DeskProfileRow(
                            profile: link.other,
                            onTap: () => _openProfile(link.other),
                            actions: [
                              DeskIconAction(
                                icon: Icons.close,
                                tooltip: t.decline,
                                color: AppColors.textSecondary,
                                onTap: () => _act(() => _friends.respond(link.other.id, accept: false)),
                              ),
                              DeskIconAction(
                                icon: Icons.check,
                                tooltip: t.accept,
                                onTap: () => _act(
                                  () => _friends.respond(link.other.id, accept: true),
                                  note: t.nowFriends(link.other.name),
                                ),
                              ),
                            ],
                          ),
                      ],
                      empty: '—',
                    ),
                  ),
                ),
                const SizedBox(height: DeskSize.gap),
                Expanded(
                  child: CafePanel(
              expand: true,
                    title: t.waiting,
                    trailing: count(outgoing.length),
                    child: list(
                      [
                        for (final link in outgoing)
                          DeskProfileRow(
                            profile: link.other,
                            actions: [
                              TextButton(
                                onPressed: () => _act(() => _friends.remove(link.other.id)),
                                child: Text(t.withdraw),
                              ),
                            ],
                          ),
                      ],
                      empty: '—',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Il titoletto d'ottone sopra un riquadro.
class _Section extends StatelessWidget {
  final String label;

  const _Section(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(label, style: AppText.overline.copyWith(color: Saloon.brass, fontSize: 11, letterSpacing: 3.2)),
      );
}
