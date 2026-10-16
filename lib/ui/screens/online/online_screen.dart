import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/noir_avatar.dart';
import '../../widgets/scene_scaffold.dart';
import 'friends_screen.dart';
import 'join_room_screen.dart';
import 'online_room_screen.dart';
import 'online_widgets.dart';

/// Il portone del gioco online, dal manifesto «Gioca con amici». Chi non è
/// entrato trova l'ingresso con Apple o Google; chi è entrato la prima
/// volta si prepara il profilo; poi la sala: aprire una stanza, entrare con
/// un codice, gli amici.
///
/// Dove l'app è stata compilata senza server, dice che l'online non c'è.
class OnlineScreen extends StatefulWidget {
  /// Il server da usare. Senza, quello aperto da `main` (se c'è).
  final OnlineServices? services;

  const OnlineScreen({super.key, this.services});

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  late final OnlineServices? _online = widget.services ?? OnlineServices.instance;

  String? _loadedFor;
  Profile? _profile;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _online?.auth.addListener(_accountChanged);
    _accountChanged();
  }

  @override
  void dispose() {
    _online?.auth.removeListener(_accountChanged);
    super.dispose();
  }

  void _accountChanged() {
    final userId = _online?.auth.userId;
    if (userId == _loadedFor) return;
    _loadedFor = userId;
    _profile = null;
    _error = null;
    if (mounted) setState(() {});
    if (userId != null) _loadProfile();
  }

  Future<void> _loadProfile() async {
    final online = _online!;
    final userId = online.auth.userId;
    setState(() => _error = null);
    try {
      final profile = await online.profiles.me();
      if (mounted && online.auth.userId == userId) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final online = _online;
    final (title, body) = switch (online) {
      null => (t.unavailableTitle, _Unavailable(text: t.unavailableBody)),
      _ when !online.auth.signedIn => (t.loginTitle, _Login(auth: online.auth)),
      _ when _error != null => (t.hubTitle, _Retry(error: _error!, onRetry: _loadProfile)),
      _ when _profile == null => (t.hubTitle, const Center(child: CircularProgressIndicator(color: AppColors.gold))),
      _ when !_profile!.isComplete => (
          t.setupTitle,
          ProfileSetup(
            services: online,
            profile: _profile!,
            onSaved: (profile) => setState(() => _profile = profile),
          ),
        ),
      _ => (t.hubTitle, _Hub(services: online, profile: _profile!)),
    };
    return SceneScaffold(
      resizeForKeyboard: false,
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

class _Unavailable extends StatelessWidget {
  final String text;

  const _Unavailable({required this.text});

  @override
  Widget build(BuildContext context) => OnlineBody(
        children: [
          const SizedBox(height: 40),
          OnlinePanel(
            child: Column(
              children: [
                const Icon(Icons.wifi_off, color: AppColors.gold, size: 40),
                const SizedBox(height: 12),
                Text(text, textAlign: TextAlign.center, style: AppText.body),
              ],
            ),
          ),
        ],
      );
}

class _Retry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _Retry({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => OnlineBody(
        children: [
          const SizedBox(height: 40),
          OnlinePanel(
            child: Column(
              children: [
                Text(failureText(context, error), textAlign: TextAlign.center, style: AppText.body),
                const SizedBox(height: 12),
                IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh, color: AppColors.gold)),
              ],
            ),
          ),
        ],
      );
}

/// L'ingresso: Apple, Google, e nient'altro.
class _Login extends StatefulWidget {
  final OnlineAuth auth;

  const _Login({required this.auth});

  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  bool _busy = false;

  Future<void> _signIn(Future<void> Function() method) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    try {
      await method();
    } on OnlineException catch (error) {
      if (mounted && error.failure != OnlineFailure.cancelled) showFailure(context, error);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final auth = widget.auth;
    return OnlineBody(
      children: [
        const SizedBox(height: 24),
        const Center(child: NoirAvatar.drawn(seed: '?', size: 96)),
        const SizedBox(height: 20),
        OnlinePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.loginBody, textAlign: TextAlign.center, style: AppText.body),
              const SizedBox(height: 20),
              if (auth.appleAvailable)
                SignInWithAppleButton(
                  text: t.loginApple,
                  height: 50,
                  style: SignInWithAppleButtonStyle.white,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  onPressed: _busy ? () {} : () => _signIn(auth.signInWithApple),
                ),
              // TODO(google): il pulsante segue le regole di Google; oggi è
              // un pulsante del gioco con la «G», da rivedere col logo ufficiale.
              if (auth.googleAvailable) ...[
                if (auth.appleAvailable) const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _signIn(auth.signInWithGoogle),
                  icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  label: Text(t.loginGoogle),
                ),
              ],
              if (!auth.appleAvailable && !auth.googleAvailable)
                Text(t.loginNoProvider, textAlign: TextAlign.center, style: AppText.body),
              const SizedBox(height: 16),
              Text(t.loginPrivacy, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Il profilo da preparare la prima volta: nome unico e nome da mostrare.
class ProfileSetup extends StatefulWidget {
  final OnlineServices services;
  final Profile profile;
  final ValueChanged<Profile> onSaved;

  const ProfileSetup({super.key, required this.services, required this.profile, required this.onSaved});

  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup> {
  late final _handle = TextEditingController(text: widget.profile.handle ?? '');
  late final _name = TextEditingController(
    text: widget.profile.displayName ?? widget.services.auth.suggestedName ?? '',
  );
  String? _handleError;
  String? _nameError;
  bool _busy = false;

  @override
  void dispose() {
    _handle.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppStrings.of(context);
    final handle = _handle.text.trim().toLowerCase();
    final name = _name.text.trim();
    setState(() {
      _handleError = Profile.handlePattern.hasMatch(handle) ? null : t.online.handleInvalid;
      _nameError = name.isEmpty || name.length > Profile.maxDisplayName ? t.online.nameInvalid : null;
    });
    if (_handleError != null || _nameError != null) return;
    setState(() => _busy = true);
    try {
      final profile = await widget.services.profiles.update(handle: handle, displayName: name, language: t.language);
      widget.onSaved(profile);
    } on OnlineException catch (error) {
      if (!mounted) return;
      if (error.failure == OnlineFailure.handleTaken) {
        setState(() => _handleError = t.online.failure(error.failure));
      } else {
        showFailure(context, error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    return OnlineBody(
      children: [
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: _handle,
          builder: (context, _) => Center(
            child: NoirAvatar.drawn(seed: _handle.text.isEmpty ? widget.profile.id : _handle.text, size: 96),
          ),
        ),
        const SizedBox(height: 20),
        OnlinePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.setupBody, textAlign: TextAlign.center, style: AppText.body),
              const SizedBox(height: 16),
              TextField(
                key: const Key('online.handle'),
                controller: _handle,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 20,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
                  TextInputFormatter.withFunction(
                    (old, value) => value.copyWith(text: value.text.toLowerCase()),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: t.handleLabel,
                  hintText: t.handleHint,
                  prefixText: '@',
                  errorText: _handleError,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('online.name'),
                controller: _name,
                maxLength: Profile.maxDisplayName,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: t.nameLabel, errorText: _nameError),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _busy ? null : _save, child: Text(t.save)),
            ],
          ),
        ),
      ],
    );
  }
}

/// La sala: chi sei, e le tre porte.
class _Hub extends StatefulWidget {
  final OnlineServices services;
  final Profile profile;

  const _Hub({required this.services, required this.profile});

  @override
  State<_Hub> createState() => _HubState();
}

class _HubState extends State<_Hub> {
  bool _busy = false;

  Future<void> _create() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    final language = AppStrings.of(context).language;
    setState(() => _busy = true);
    try {
      final room = await widget.services.rooms.create(language);
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => OnlineRoomScreen(services: widget.services, room: room, me: widget.profile),
      ));
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final profile = widget.profile;
    return OnlineBody(
      children: [
        const SizedBox(height: 12),
        OnlinePanel(
          child: ProfileRow(profile: profile, badges: [OnlineBadge(t.signedInAs(profile.name))]),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _busy ? null : _create,
          icon: const Icon(Icons.meeting_room),
          label: Text(t.hubCreate),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _open(JoinRoomScreen(services: widget.services, me: profile)),
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(t.hubJoin),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _open(FriendsScreen(services: widget.services)),
          icon: const Icon(Icons.people_alt),
          label: Text(t.friends),
        ),
      ],
    );
  }
}
