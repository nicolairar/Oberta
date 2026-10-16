import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/scene_scaffold.dart';
import 'online_widgets.dart';

/// Gli amici: cercare qualcuno per nome unico, rispondere alle richieste,
/// vedere chi aspetta una risposta e chi è già amico.
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

    return SceneScaffold(
      resizeForKeyboard: false,
      appBar: AppBar(title: Text(t.friends)),
      body: OnlineBody(
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
              fillColor: AppColors.surface.withValues(alpha: 0.92),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (_results case final results?) ...[
            const SizedBox(height: 8),
            OnlinePanel(
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
                            trailing: linked.contains(profile.id)
                                ? null
                                : TextButton(onPressed: () => _request(profile), child: Text(t.add)),
                          ),
                      ],
                    ),
            ),
          ],
          if (incoming.isNotEmpty) ...[
            OnlineSection(t.requests),
            OnlinePanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  for (final link in incoming)
                    ProfileRow(
                      profile: link.other,
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
          OnlineSection(t.yourFriends),
          OnlinePanel(
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
                              profile: link.other,
                              trailing: TextButton(
                                onPressed: () => _act(() => _friends.remove(link.other.id)),
                                child: Text(t.remove),
                              ),
                            ),
                        ],
                      ),
          ),
          if (outgoing.isNotEmpty) ...[
            OnlineSection(t.waiting),
            OnlinePanel(
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
}
