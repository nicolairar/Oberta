import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../sound/screen_music.dart';
import '../../../sound/sound_stage.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/online_strings.dart';
import '../../../online/handle_rules.dart';
import '../../../online/online_services.dart';
import '../../../l10n/desktop_online_strings.dart';
import '../../../l10n/desktop_strings.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import '../../avatar/avatar_look.dart';
import '../../widgets/noir_avatar.dart';
import '../../widgets/player_avatar.dart';
import '../../street/street_scaffold.dart';
import '../../widgets/scene_scaffold.dart';
import '../../widgets/targa.dart';
import 'cafe_room.dart';
import 'friends_screen.dart';
import 'game/noir_ui.dart';
import 'join_room_screen.dart';
import 'online_room_screen.dart';
import '../avatar/barber_mirror_screen.dart';
import 'online_desktop.dart';
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

class _OnlineScreenState extends State<OnlineScreen> with ScreenMusic {
  @override
  MusicMood get screenMood => MusicMood.menu;

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
    // Il caffè visto dalla strada: l'uomo entra dalla porta, e dentro c'è la sala.
    final desk = DesktopCanvas.of(context);
    return StreetBackdrop(
      section: StreetSection.friends,
      desk: desk,
      builder: (context, _) =>
          desk ? CafeDesk(title: title, child: body) : CafeScaffold(resizeForKeyboard: false, title: title, child: body),
    );
  }
}

class _Unavailable extends StatelessWidget {
  final String text;

  const _Unavailable({required this.text});

  @override
  Widget build(BuildContext context) => DesktopCanvas.of(context)
      ? DeskNotice(
          children: [
            const Icon(Icons.wifi_off, color: AppColors.gold, size: 64),
            const SizedBox(height: 24),
            Text(text, textAlign: TextAlign.center, style: DeskText.text(size: DeskText.lead)),
          ],
        )
      : OnlineBody(
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
  Widget build(BuildContext context) => DesktopCanvas.of(context)
      ? DeskNotice(
          children: [
            Text(failureText(context, error), textAlign: TextAlign.center, style: DeskText.text(size: DeskText.lead)),
            const SizedBox(height: 32),
            Center(
              child: OutlinedButton.icon(
                autofocus: true,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(MaterialLocalizations.of(context).refreshIndicatorSemanticLabel.toUpperCase()),
              ),
            ),
          ],
        )
      : OnlineBody(
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
class _Login extends StatefulWidget {
  final OnlineAuth auth;

  const _Login({required this.auth});

  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  /// Sul PC: INVIO entra col primo modo d'accesso.
  final _enter = ValueNotifier(0);

  OnlineAuth get auth => widget.auth;

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopCanvas.of(context)) return _phone(context);
    final t = AppStrings.of(context).online;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () => _enter.value++,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () => _enter.value++,
      },
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const NoirAvatar.drawn(seed: '?', size: 160),
                  const SizedBox(height: 40),
                  Text(t.posterTitle, style: DeskText.display(DeskText.hero).copyWith(height: 1.05)),
                  const SizedBox(height: 24),
                  Text(t.posterBlurb, style: DeskText.text(size: DeskText.lead, color: AppColors.textSecondary).copyWith(height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 120),
            Container(
              width: 640,
              padding: const EdgeInsets.fromLTRB(48, 44, 48, 40),
              decoration: DeskPanel.decoration(lit: true),
              child: SignInPanel(auth: auth, sheet: false, enterKey: _enter),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phone(BuildContext context) => OnlineBody(
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
    if (DesktopCanvas.of(context)) return _desk(context, t);
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
              _field(t),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _busy ? null : _save, child: Text(t.save)),
            ],
          ),
        ),
      ],
    );
  }

  /// Sul PC: la faccia grande a sinistra, il nome da scegliere a destra.
  Widget _desk(BuildContext context, OnlineStrings t) => Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: _handle,
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NoirAvatar.drawn(seed: _handle.text.isEmpty ? widget.profile.id : _handle.text, size: 260),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 360,
                    child: Text(
                      _handle.text.isEmpty ? '@…' : '@${Profile.normalizeHandle(_handle.text)}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DeskText.display(DeskText.title),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 100),
            Container(
              width: 720,
              padding: const EdgeInsets.fromLTRB(56, 48, 56, 44),
              decoration: DeskPanel.decoration(lit: true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.setupBody, style: DeskText.text(size: DeskText.lead).copyWith(height: 1.4)),
                  const SizedBox(height: 36),
                  _field(t, desk: true),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          DesktopStrings.of(context).enterHint,
                          style: DeskText.overline(color: AppColors.textSecondary),
                        ),
                      ),
                      ElevatedButton(onPressed: _busy ? null : _save, child: Text(t.save)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _field(OnlineStrings t, {bool desk = false}) => TextField(
                key: const Key('online.handle'),
                autofocus: desk,
                style: desk ? DeskText.text(size: DeskText.title) : null,
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
                  helperStyle: TextStyle(color: _handleHelper(t).$2, fontSize: desk ? 16 : 12),
                  labelStyle: desk ? const TextStyle(fontSize: 20) : null,
                  errorStyle: desk ? const TextStyle(fontSize: 16) : null,
                  contentPadding: desk ? const EdgeInsets.symmetric(horizontal: 20, vertical: 22) : null,
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
              );
}

/// La saletta riservata: chi sei, il pulsante per aprire una stanza, il
/// codice per entrare in quella di un altro, gli amici.
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

  void _join() => _open(JoinRoomScreen(services: widget.services, me: widget.profile));

  void _friends() => _open(FriendsScreen(services: widget.services));

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final profile = widget.profile;
    if (DesktopCanvas.of(context)) return _desk(context, t, profile);
    // Il quadro grande appeso nella saletta, chi sei, e sotto le targhe
    // larghe: aprire una stanza, entrare con un codice, gli amici.
    return LayoutBuilder(
      builder: (context, box) {
        final short = box.maxHeight < 640;
        final bottom = 16 + MediaQuery.paddingOf(context).bottom;
        final plate = short ? 52.0 : 58.0;
        final gap = short ? 10.0 : 12.0;
        final rejoin = _current;
        // Quello che sta sotto il quadro: il cartellino e le targhe.
        final below = 84 + (short ? 14 : 22) + (plate + 8) + 2 * (gap + plate) + (rejoin == null ? 0 : plate + gap);
        final painting = (box.maxHeight - bottom - below - (short ? 10 : 18)).clamp(150.0, 520.0);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, short ? 4 : 10, 18, bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - bottom - (short ? 4 : 10)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox(
                        height: painting,
                        // Un quadro, non un poster steso: mai più largo che alto.
                        width: min(box.maxWidth - 36, painting * 1.05),
                        child: CafePainting(key: const Key('online.painting'), title: t.posterTitle),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: short ? 10 : 18),
                        _Card(profile: profile),
                        SizedBox(height: short ? 14 : 22),
                        if (rejoin != null) ...[
                          TargaButton(
                            key: const Key('online.rejoin'),
                            icon: Icons.login,
                            label: '${t.rejoin} · ${rejoin.code}',
                            expand: true,
                            height: plate,
                            onPressed: () => _rejoin(rejoin),
                          ),
                          SizedBox(height: gap),
                        ],
                        TargaButton(
                          key: const Key('online.create'),
                          icon: Icons.meeting_room,
                          label: t.hubCreate,
                          feel: Press.confirm,
                          expand: true,
                          height: plate + 8,
                          onPressed: _busy ? null : _create,
                        ),
                        SizedBox(height: gap),
                        TargaButton(
                          key: const Key('online.join'),
                          kind: TargaKind.secondary,
                          icon: Icons.dialpad,
                          label: t.hubJoin,
                          expand: true,
                          height: plate,
                          onPressed: _join,
                        ),
                        SizedBox(height: gap),
                        TargaButton(
                          key: const Key('online.friends'),
                          kind: TargaKind.secondary,
                          icon: Icons.people_alt,
                          label: t.friends,
                          expand: true,
                          height: plate,
                          onPressed: _friends,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Sul PC, come l'ingresso della classificata: la saletta grande a
  /// sinistra; a destra chi sei, le porte e il pulsante grande (INVIO).
  Widget _desk(BuildContext context, OnlineStrings t, Profile profile) {
    final d = DesktopOnlineStrings.of(context);
    final current = _current;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!_busy) _create();
        },
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
          if (!_busy) _create();
        },
      },
      child: Focus(
        autofocus: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Il quadro grande, appeso a sinistra.
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 0.86,
                  child: CafePainting(key: const Key('online.painting'), title: t.posterTitle),
                ),
              ),
            ),
            const SizedBox(width: 72),
            Container(
              width: 700,
              padding: const EdgeInsets.fromLTRB(48, 44, 48, 44),
              decoration: Saloon.scrim(radius: DeskSize.radius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Card(profile: profile),
                  const SizedBox(height: 44),
                  Text(d.hubDoors.toUpperCase(), style: DeskText.overline(color: Saloon.brass)),
                  const SizedBox(height: 16),
                  _DoorRow(
                    key: const Key('online.desk.join'),
                    icon: Icons.dialpad,
                    title: t.hubJoin,
                    body: d.hubJoinBody,
                    onTap: _join,
                  ),
                  const SizedBox(height: 12),
                  _DoorRow(
                    key: const Key('online.desk.friends'),
                    icon: Icons.people_alt,
                    title: t.friends,
                    body: d.hubFriendsBody,
                    onTap: _friends,
                  ),
                  const Spacer(),
                  if (current != null) ...[
                    NoirButton(
                      key: const Key('online.rejoin'),
                      kind: NoirButtonKind.brass,
                      icon: Icons.login,
                      label: '${t.rejoin} · ${current.code}',
                      onPressed: () => _rejoin(current),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    d.hubCreateBody,
                    textAlign: TextAlign.center,
                    style: DeskText.text(color: Saloon.paper.withValues(alpha: 0.82)).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  NoirButton(
                    key: const Key('online.desk.create'),
                    icon: Icons.meeting_room,
                    label: t.hubCreate,
                    feel: Press.confirm,
                    onPressed: _busy ? null : _create,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    DesktopStrings.of(context).enterHint,
                    textAlign: TextAlign.center,
                    style: DeskText.overline(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chi sei: la faccia, il nome, il livello, come il grado nella classificata.
class _Card extends StatelessWidget {
  final Profile profile;

  const _Card({required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final desk = DesktopCanvas.of(context);
    final face = desk ? 120.0 : 56.0;
    return Container(
      padding: desk ? EdgeInsets.zero : const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: desk ? null : Saloon.scrim(),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Saloon.brass.withValues(alpha: 0.4), blurRadius: 14)],
            ),
            child: PlayerAvatar(seed: profile.avatarSeed, look: profile.look, picture: profile.pictureUrl, size: face),
          ),
          SizedBox(width: desk ? 32 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(desk ? DeskText.heading : 20, color: Saloon.paper),
                ),
                SizedBox(height: desk ? 10 : 4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: desk ? 10 : 6, vertical: desk ? 3 : 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Saloon.brass, Saloon.brassDeep]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        t.levelShort(profile.level),
                        style: AppText.body.copyWith(fontSize: desk ? 15 : 10, fontWeight: FontWeight.w700, color: Saloon.paperInk),
                      ),
                    ),
                    SizedBox(width: desk ? 12 : 8),
                    Flexible(
                      child: Text(
                        t.signedInAs(profile.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: desk
                            ? DeskText.text(size: DeskText.label, color: AppColors.textSecondary)
                            : AppText.body.copyWith(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una porta nel banco del PC: icona, titolo, due righe; si accende sotto
/// il mouse.
class _DoorRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _DoorRow({super.key, required this.icon, required this.title, required this.body, required this.onTap});

  @override
  Widget build(BuildContext context) => DeskHover(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
          decoration: BoxDecoration(
            color: hovered ? Saloon.brass.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(DeskSize.radius),
            border: Border.all(color: Saloon.brass.withValues(alpha: hovered ? 0.8 : 0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Saloon.brass, size: 34),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.display(DeskText.title, color: Saloon.paper)),
                    const SizedBox(height: 4),
                    Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: DeskText.text(size: DeskText.label, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Saloon.brass.withValues(alpha: hovered ? 1 : 0.5), size: 32),
            ],
          ),
        ),
      );
}
