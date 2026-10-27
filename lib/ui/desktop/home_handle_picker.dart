import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/desktop_strings.dart';
import '../../l10n/online_strings.dart';
import '../../online/handle_rules.dart';
import '../../online/handle_suggestions.dart';
import '../../online/online_services.dart';
import '../screens/online/online_widgets.dart';
import '../theme/app_theme.dart';
import '../widgets/noir_avatar.dart';
import '../widgets/platform_marks.dart';
import 'desktop_canvas.dart';
import 'home_modal.dart';

/// Il nome unico sul PC: una finestra al centro del vicolo, il ritratto a
/// sinistra e il nome grande a destra. INVIO salva. Torna il profilo salvato.
Future<Profile?> showDeskHandlePicker(
  BuildContext context, {
  required OnlineServices services,
  required Profile profile,
}) => showDeskModal<Profile>(
  context,
  dismissible: false,
  builder: (context) =>
      DeskHandlePicker(services: services, profile: profile, onSaved: (saved) => Navigator.of(context).pop(saved)),
);

enum _Check { idle, invalid, checking, free, taken }

class DeskHandlePicker extends StatefulWidget {
  final OnlineServices services;
  final Profile profile;
  final ValueChanged<Profile> onSaved;

  const DeskHandlePicker({super.key, required this.services, required this.profile, required this.onSaved});

  @override
  State<DeskHandlePicker> createState() => _DeskHandlePickerState();
}

class _DeskHandlePickerState extends State<DeskHandlePicker> {
  /// Chi entra con Steam trova già scritto il suo nome Steam, adattato alle
  /// regole: se è libero basta salvare.
  late final String? _persona = widget.profile.handle == null ? widget.profile.steamPersona : null;
  late final _handle = TextEditingController(
    text: widget.profile.handle ?? (_persona == null ? null : HandleSuggestions.fromPersona(_persona)) ?? '',
  );

  /// Nomi liberi vicini a quello preso.
  List<String> _suggestions = const [];
  String? _error;
  bool _busy = false;
  _Check _check = _Check.idle;
  HandleProblem? _problem;
  Timer? _debounce;
  int _asked = 0;
  String _lastTyped = '';

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

  /// Le regole subito, poi (con calma) il server: il nome è libero?
  void _typed() {
    final handle = Profile.normalizeHandle(_handle.text);
    if (handle == _lastTyped) return;
    _lastTyped = handle;
    _debounce?.cancel();
    final ask = ++_asked;
    final problem = handle.isEmpty ? null : HandleRules.check(handle);
    setState(() {
      _error = null;
      _suggestions = const [];
      _problem = problem == HandleProblem.tooShort ? null : problem;
      _check = handle.isEmpty || problem == HandleProblem.tooShort
          ? _Check.idle
          : problem == null
          ? _Check.checking
          : _Check.invalid;
    });
    if (_check != _Check.checking) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      bool? free;
      try {
        free = await widget.services.profiles.handleAvailable(handle);
      } catch (error) {
        debugPrint('Controllo del nome non riuscito: $error');
      }
      if (!mounted || ask != _asked) return;
      setState(
        () => _check = switch (free) {
          true => _Check.free,
          false => _Check.taken,
          null => _Check.idle,
        },
      );
      if (free == false) _suggest(handle, ask);
    });
  }

  /// Il nome è preso: si cercano due o tre nomi liberi lì vicino.
  Future<void> _suggest(String handle, int ask) async {
    List<String> free;
    try {
      free = await HandleSuggestions.freeVariants(handle, widget.services.profiles.handleAvailable);
    } catch (error) {
      debugPrint('Nomi vicini non trovati: $error');
      return;
    }
    if (!mounted || ask != _asked) return;
    setState(() => _suggestions = free);
  }

  void _take(String handle) {
    _handle.value = TextEditingValue(text: handle, selection: TextSelection.collapsed(offset: handle.length));
  }

  Future<void> _save() async {
    if (_busy) return;
    final t = AppStrings.of(context);
    final handle = Profile.normalizeHandle(_handle.text);
    final problem = HandleRules.check(handle);
    setState(() {
      _error = problem != null
          ? t.online.handleProblem(problem)
          : _check == _Check.taken
          ? t.online.failure(OnlineFailure.handleTaken)
          : null;
    });
    if (_error != null) return;
    setState(() => _busy = true);
    try {
      final profile = await widget.services.profiles.update(handle: handle, language: t.language);
      widget.onSaved(profile);
    } on OnlineException catch (error) {
      if (!mounted) return;
      if (error.failure == OnlineFailure.handleTaken) {
        setState(() {
          _check = _Check.taken;
          _error = t.online.failure(error.failure);
        });
      } else if (error.failure == OnlineFailure.invalidHandle || error.failure == OnlineFailure.handleNotAllowed) {
        setState(() => _error = t.online.failure(error.failure));
      } else {
        showFailure(context, error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  (String, Color, IconData?) _status(OnlineStrings t) => switch (_check) {
    _Check.idle => (t.handleInvalid, AppColors.textSecondary, null),
    _Check.invalid => (_problem == null ? t.handleInvalid : t.handleProblem(_problem!), AppColors.accent, Icons.cancel),
    _Check.checking => (t.handleChecking, AppColors.textSecondary, null),
    _Check.free => (t.handleFree, const Color(0xFF7FB77E), Icons.check_circle),
    _Check.taken => (t.failure(OnlineFailure.handleTaken), AppColors.accent, Icons.cancel),
  };

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final (line, color, icon) = _error != null ? (_error!, AppColors.accent, Icons.cancel) : _status(t);
    return DeskModal(
      overline: AppStrings.of(context).homeTitle,
      title: t.setupTitle,
      width: 960,
      hint: DesktopStrings.of(context).enterHint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Il ritratto cambia mentre si scrive.
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF08080B),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 2.5),
              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.16), blurRadius: 40)],
            ),
            padding: const EdgeInsets.all(10),
            child: ListenableBuilder(
              listenable: _handle,
              builder: (context, _) =>
                  NoirAvatar.drawn(seed: _handle.text.isEmpty ? widget.profile.id : _handle.text, size: 216),
            ),
          ),
          const SizedBox(width: 56),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.setupBody,
                  style: DeskText.text(size: DeskText.lead, color: AppColors.textSecondary),
                ),
                if (_persona case final persona?) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SteamLogo(size: 18, color: AppColors.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.handleFromSteam(persona),
                          key: const Key('desk.handleFromSteam'),
                          style: DeskText.text(color: AppColors.gold),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                Text(t.handleLabel.toUpperCase(), style: DeskText.overline(color: AppColors.gold)),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('online.handle'),
                  controller: _handle,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: Profile.maxHandle,
                  keyboardType: TextInputType.visiblePassword,
                  inputFormatters: [
                    TextInputFormatter.withFunction((old, value) => value.copyWith(text: value.text.toLowerCase())),
                    FilteringTextInputFormatter.allow(HandleRules.allowedCharacters),
                  ],
                  style: DeskText.display(36, color: AppColors.textPrimary).copyWith(letterSpacing: 1.5),
                  cursorColor: AppColors.gold,
                  decoration: InputDecoration(
                    hintText: t.handleHint,
                    hintStyle: DeskText.display(36, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    prefixText: '@ ',
                    prefixStyle: DeskText.display(36, color: AppColors.gold),
                    counterStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.35),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DeskSize.radius),
                      borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DeskSize.radius),
                      borderSide: BorderSide(color: _check == _Check.idle ? AppColors.gold : color, width: 2),
                    ),
                    suffixIcon: _check == _Check.checking
                        ? const Padding(
                            padding: EdgeInsets.all(22),
                            child: SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.gold),
                            ),
                          )
                        : icon == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(icon, color: color, size: 32),
                          ),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 6),
                Text(
                  line,
                  key: const Key('desk.handleStatus'),
                  style: DeskText.text(color: color),
                ),
                if (_suggestions.isNotEmpty && _check == _Check.taken) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(t.handleSuggestions, style: DeskText.text(color: AppColors.textSecondary)),
                      for (final name in _suggestions)
                        ActionChip(
                          key: Key('desk.handleSuggestion.$name'),
                          label: Text('@$name', style: DeskText.text(color: AppColors.textPrimary)),
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
                          onPressed: () => _take(name),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  key: const Key('desk.handleSave'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(68)),
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.gold),
                        )
                      : Text(t.save.toUpperCase(), style: const TextStyle(fontSize: 22, letterSpacing: 3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
