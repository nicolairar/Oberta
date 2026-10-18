import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_strings.dart';
import '../../../l10n/online_strings.dart';
import '../../../online/handle_rules.dart';
import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/noir_avatar.dart';
import '../../widgets/scene_scaffold.dart';
import 'friends_screen.dart';
import 'join_room_screen.dart';
import 'online_room_screen.dart';
import '../avatar/barber_mirror_screen.dart';
import 'online_widgets.dart';
import 'sign_in_sheet.dart';

enum _HandleCheck { idle, invalid, checking, free, taken }

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
            onSaved: (profile) async {
              setState(() => _profile = profile);
              final faced = await BarberMirrorScreen.open(context, services: online, profile: profile, firstTime: true);
              if (faced != null && mounted) setState(() => _profile = faced);
            },
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

/// L'ingresso: Apple, Google, e nient'altro (più l'account di prova, nascosto).
class _Login extends StatelessWidget {
  final OnlineAuth auth;

  const _Login({required this.auth});

  @override
  Widget build(BuildContext context) => OnlineBody(
        children: [
          const SizedBox(height: 24),
          const Center(child: NoirAvatar.drawn(seed: '?', size: 96)),
          const SizedBox(height: 20),
          OnlinePanel(child: SignInPanel(auth: auth, sheet: false)),
        ],
      );
}

/// Il profilo da preparare, da solo su una pagina: ci si arriva dal vicolo
/// subito dopo il primo accesso (o quando il vecchio nome unico non vale
/// più). Torna il profilo salvato.
class ProfileSetupScreen extends StatelessWidget {
  final OnlineServices services;
  final Profile profile;

  const ProfileSetupScreen({super.key, required this.services, required this.profile});

  @override
  Widget build(BuildContext context) => SceneScaffold(
        resizeForKeyboard: false,
        appBar: AppBar(title: Text(AppStrings.of(context).online.setupTitle)),
        body: ProfileSetup(
          services: services,
          profile: profile,
          onSaved: (profile) => Navigator.of(context).pop(profile),
        ),
      );
}

/// Il profilo da preparare la prima volta: il nome unico, che è anche il
/// nome che tutti vedono.
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
  String? _handleError;
  bool _busy = false;

  /// Il controllo dal vivo del nome unico, mentre lo si scrive.
  _HandleCheck _check = _HandleCheck.idle;
  HandleProblem? _problem;
  Timer? _debounce;
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    _handle.addListener(_typed);
    if (_handle.text.isNotEmpty) _typed();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _handle.dispose();
    super.dispose();
  }

  String _lastTyped = '';

  /// A ogni lettera si controllano le regole qui, subito; se vanno bene si
  /// aspetta un attimo e si chiede al server se il nome è libero. Risponde
  /// solo l'ultima domanda: le vecchie si buttano.
  void _typed() {
    final handle = Profile.normalizeHandle(_handle.text);
    if (handle == _lastTyped) return;
    _lastTyped = handle;
    _debounce?.cancel();
    final ask = ++_asked;
    final problem = handle.isEmpty ? null : HandleRules.check(handle);
    setState(() {
      _handleError = null;
      // Mentre si scrive, «troppo corto» non è ancora un errore.
      _problem = problem == HandleProblem.tooShort ? null : problem;
      _check = handle.isEmpty || problem == HandleProblem.tooShort
          ? _HandleCheck.idle
          : problem == null
              ? _HandleCheck.checking
              : _HandleCheck.invalid;
    });
    if (_check != _HandleCheck.checking) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      bool? free;
      try {
        free = await widget.services.profiles.handleAvailable(handle);
      } catch (error) {
        debugPrint('Controllo del nome non riuscito: $error');
      }
      if (!mounted || ask != _asked) return;
      setState(() => _check = switch (free) {
            true => _HandleCheck.free,
            false => _HandleCheck.taken,
            null => _HandleCheck.idle,
          });
    });
  }

  Future<void> _save() async {
    final t = AppStrings.of(context);
    final handle = Profile.normalizeHandle(_handle.text);
    final problem = HandleRules.check(handle);
    setState(() {
      _handleError = problem != null
          ? t.online.handleProblem(problem)
          : _check == _HandleCheck.taken
              ? t.online.failure(OnlineFailure.handleTaken)
              : null;
    });
    if (_handleError != null) return;
    setState(() => _busy = true);
    try {
      final profile = await widget.services.profiles.update(handle: handle, language: t.language);
      widget.onSaved(profile);
    } on OnlineException catch (error) {
      if (!mounted) return;
      if (error.failure == OnlineFailure.handleTaken) {
        setState(() {
          _check = _HandleCheck.taken;
          _handleError = t.online.failure(error.failure);
        });
      } else if (error.failure == OnlineFailure.invalidHandle || error.failure == OnlineFailure.handleNotAllowed) {
        setState(() => _handleError = t.online.failure(error.failure));
      } else {
        showFailure(context, error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// La riga sotto il nome unico: che regole ha, cosa non va, e se è libero.
  (String?, Color) _handleHelper(OnlineStrings t) => switch (_check) {
        _HandleCheck.idle => (t.handleInvalid, AppColors.textSecondary),
        _HandleCheck.invalid => (_problem == null ? t.handleInvalid : t.handleProblem(_problem!), AppColors.accent),
        _HandleCheck.checking => (t.handleChecking, AppColors.textSecondary),
        _HandleCheck.free => (t.handleFree, const Color(0xFF7FB77E)),
        _HandleCheck.taken => (t.failure(OnlineFailure.handleTaken), AppColors.accent),
      };

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
                maxLength: Profile.maxHandle,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.visiblePassword,
                // Sempre minuscolo, mentre si scrive: lettere, cifre, «.» e «_».
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (old, value) => value.copyWith(text: value.text.toLowerCase()),
                  ),
                  FilteringTextInputFormatter.allow(HandleRules.allowedCharacters),
                ],
                decoration: InputDecoration(
                  labelText: t.handleLabel,
                  hintText: t.handleHint,
                  prefixText: '@',
                  errorText: _handleError,
                  helperText: _handleHelper(t).$1,
                  helperMaxLines: 2,
                  helperStyle: TextStyle(color: _handleHelper(t).$2, fontSize: 12),
                  suffixIcon: switch (_check) {
                    _HandleCheck.checking => const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                        ),
                      ),
                    _HandleCheck.free => const Icon(Icons.check_circle, color: Color(0xFF7FB77E)),
                    _HandleCheck.taken || _HandleCheck.invalid => const Icon(Icons.cancel, color: AppColors.accent),
                    _HandleCheck.idle => null,
                  },
                ),
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

  /// La stanza in cui si siede ancora (l'app chiusa a metà partita).
  Room? _current;

  @override
  void initState() {
    super.initState();
    _lookForTable();
  }

  Future<void> _lookForTable() async {
    try {
      final room = await widget.services.rooms.current();
      if (mounted) setState(() => _current = room);
    } catch (_) {
      // Senza risposta il pulsante per rientrare semplicemente non c'è.
    }
  }

  Future<void> _rejoin(Room room) async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OnlineRoomScreen(services: widget.services, room: room, me: widget.profile),
    ));
    if (mounted) _lookForTable();
  }

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
      if (mounted) _lookForTable();
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
        if (_current case final room?) ...[
          ElevatedButton.icon(
            key: const Key('online.rejoin'),
            onPressed: () => _rejoin(room),
            icon: const Icon(Icons.login),
            label: Text('${t.rejoin} · ${room.code}'),
          ),
          const SizedBox(height: 12),
        ],
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
