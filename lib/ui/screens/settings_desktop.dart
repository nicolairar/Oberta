part of 'settings_screen.dart';

/// Le voci a sinistra delle impostazioni sul desktop.
enum _DeskCategory { audio, screen, language, game, account, privacy, about }

/// Le impostazioni su PC: a sinistra l'elenco delle voci (passaggio del
/// puntatore, voce scelta accesa d'oro, frecce su e giù), a destra le
/// opzioni della voce scelta. Esc torna indietro.
class _DesktopSettings extends StatefulWidget {
  final _SettingsScreenState host;

  const _DesktopSettings({required this.host});

  @override
  State<_DesktopSettings> createState() => _DesktopSettingsState();
}

class _DesktopSettingsState extends State<_DesktopSettings> {
  _DeskCategory _selected = _DeskCategory.audio;

  _SettingsScreenState get _host => widget.host;
  AppSettings get _settings => _host.widget.settings;

  List<_DeskCategory> get _categories => [
    _DeskCategory.audio,
    if (DesktopPlatform.isDesktop) _DeskCategory.screen,
    _DeskCategory.language,
    _DeskCategory.game,
    if (_host._auth != null) _DeskCategory.account,
    _DeskCategory.privacy,
    _DeskCategory.about,
  ];

  void _step(int delta) {
    final all = _categories;
    final index = all.indexOf(_selected);
    setState(() => _selected = all[(index + delta).clamp(0, all.length - 1)]);
  }

  IconData _icon(_DeskCategory c) => switch (c) {
    _DeskCategory.audio => Icons.music_note,
    _DeskCategory.screen => Icons.desktop_windows,
    _DeskCategory.language => Icons.translate,
    _DeskCategory.game => Icons.movie_filter,
    _DeskCategory.account => Icons.badge_outlined,
    _DeskCategory.privacy => Icons.privacy_tip_outlined,
    _DeskCategory.about => Icons.info_outline,
  };

  String _title(_DeskCategory c) {
    final s = SettingsStrings.of(context);
    return switch (c) {
      _DeskCategory.audio => s.audio,
      _DeskCategory.screen => DesktopStrings.of(context).screen,
      _DeskCategory.language => s.languageSection,
      _DeskCategory.game => s.game,
      _DeskCategory.account => s.account,
      _DeskCategory.privacy => s.privacy,
      _DeskCategory.about => s.about,
    };
  }

  String _windowLabel(DesktopWindowMode m) {
    final d = DesktopStrings.of(context);
    return switch (m) {
      DesktopWindowMode.windowed => d.windowed,
      DesktopWindowMode.fullscreen => d.fullscreen,
      DesktopWindowMode.borderless => d.borderless,
    };
  }

  /// La riga piccola sotto il nome della voce: com'è messa adesso.
  Widget _summary(_DeskCategory c, TextStyle style) {
    final t = AppStrings.of(context);
    final s = SettingsStrings.of(context);
    String pct(double v) => '${(v * 100).round()}%';
    Text text(String value) => Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final settings = _settings;
    switch (c) {
      case _DeskCategory.audio:
        return text(
          settings.soundOn
              ? '${t.musicVolumeLabel} ${pct(settings.musicVolume)} · ${t.effectsVolumeLabel} ${pct(settings.effectsVolume)}'
              : '${t.musicVolumeLabel} — · ${t.effectsVolumeLabel} —',
        );
      case _DeskCategory.screen:
        return text('${_windowLabel(settings.windowMode)} · ${DesktopResolutions.label(settings.resolution)}');
      case _DeskCategory.language:
        return text(settings.language?.nativeName ?? t.languageAutomatic);
      case _DeskCategory.game:
        return text(t.rehearsal);
      case _DeskCategory.account:
        final auth = _host._auth!;
        if (!auth.signedIn) return text(s.notSignedIn);
        return FutureBuilder<Profile?>(
          future: _host._profileOf(auth.userId),
          builder: (context, snapshot) => text(switch (snapshot.data?.handle) {
            final handle? => '@$handle',
            null => s.signedInNoHandle,
          }),
        );
      case _DeskCategory.privacy:
        return text('${SafetyStrings.of(context).rulesTitle} · ${s.privacyPolicy}');
      case _DeskCategory.about:
        return FutureBuilder<String>(
          future: _host._versionText(),
          builder: (context, snapshot) => text('${s.version} ${snapshot.data ?? '…'}'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final categories = _categories;
    if (!categories.contains(_selected)) _selected = categories.first;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DeskTheme(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _step(-1),
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _step(1),
          },
          child: DeskEscape(
            onEscape: () => Navigator.of(context).maybePop(),
            child: Stack(
              children: [
                // L'ufficio di legno scuro: una lampada calda in alto a sinistra.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.7, -1.1),
                        radius: 1.5,
                        colors: [Color(0xFF3A2A1F), Color(0xFF1C1511), AppColors.background],
                        stops: [0, 0.5, 1],
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DeskTopBar(title: t.settingsTitle),
                    Container(
                      height: 1.5,
                      margin: const EdgeInsets.symmetric(horizontal: DeskSize.gutter),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.gold.withValues(alpha: 0.7), AppColors.gold.withValues(alpha: 0.15)],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(DeskSize.gutter, 32, DeskSize.gutter, DeskSize.gutter),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 500, child: _rail(categories)),
                            const SizedBox(width: 32),
                            Expanded(child: _pane()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_host._busy)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x88000000),
                      child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rail(List<_DeskCategory> categories) => DecoratedBox(
    decoration: DeskPanel.decoration(),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _CategoryTile(
                key: Key('settings.category.${c.name}'),
                icon: _icon(c),
                title: _title(c),
                selected: c == _selected,
                summary: (style) => _summary(c, style),
                onTap: () => setState(() => _selected = c),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                const _KeyCap(icon: Icons.keyboard_arrow_up),
                const SizedBox(width: 6),
                const _KeyCap(icon: Icons.keyboard_arrow_down),
                const SizedBox(width: 22),
                const _KeyCap(label: 'Esc'),
                const Spacer(),
                Text('OBERTÀ', style: DeskText.overline(color: AppColors.gold.withValues(alpha: 0.45))),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pane() => DecoratedBox(
    decoration: DeskPanel.decoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(44, 36, 44, 0),
          child: Row(
            children: [
              Icon(_icon(_selected), color: AppColors.gold, size: 40),
              const SizedBox(width: 20),
              Expanded(child: Text(_title(_selected), style: DeskText.display(DeskText.heading))),
            ],
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.fromLTRB(44, 24, 44, 8),
          color: AppColors.gold.withValues(alpha: 0.3),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
            // Le opzioni partono dall'alto, non al centro del pannello.
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, alignment: Alignment.topCenter, children: [...previous, ?current]),
            child: SingleChildScrollView(
              key: ValueKey(_selected),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _options(_selected)),
            ),
          ),
        ),
      ],
    ),
  );

  List<Widget> _options(_DeskCategory c) {
    final t = AppStrings.of(context);
    final s = SettingsStrings.of(context);
    final d = DesktopStrings.of(context);
    final settings = _settings;
    switch (c) {
      case _DeskCategory.audio:
        return [
          _DeskRow(
            icon: Icons.music_note,
            title: t.sound,
            subtitle: t.soundHint,
            onTap: () => settings.soundOn = !settings.soundOn,
            trailing: _DeskSwitch(value: settings.soundOn, onChanged: (on) => settings.soundOn = on),
          ),
          _DeskSlider(
            icon: Icons.library_music,
            label: t.musicVolumeLabel,
            value: settings.musicVolume,
            enabled: settings.soundOn,
            onChanged: (v) => settings.musicVolume = v,
          ),
          _DeskSlider(
            icon: Icons.graphic_eq,
            label: t.effectsVolumeLabel,
            value: settings.effectsVolume,
            enabled: settings.soundOn,
            onChanged: (v) => settings.effectsVolume = v,
          ),
          _DeskRow(
            icon: Icons.sentiment_very_satisfied,
            title: t.memeMode,
            subtitle: t.memeModeHint,
            enabled: settings.soundOn,
            onTap: settings.soundOn ? () => settings.memeMode = !settings.memeMode : null,
            trailing: _DeskSwitch(
              value: settings.memeMode,
              onChanged: settings.soundOn ? (on) => settings.memeMode = on : null,
            ),
          ),
        ];
      case _DeskCategory.screen:
        return [
          _DeskChoices<DesktopWindowMode>(
            icon: Icons.desktop_windows,
            title: d.windowMode,
            keyPrefix: 'window',
            values: DesktopWindowMode.values,
            selected: settings.windowMode,
            label: _windowLabel,
            onPick: (m) => settings.windowMode = m,
          ),
          _DeskChoices<Size>(
            icon: Icons.aspect_ratio,
            title: d.resolution,
            subtitle: d.resolutionHint,
            keyPrefix: 'resolution',
            values: DesktopResolutions.all,
            selected: settings.resolution,
            label: DesktopResolutions.label,
            // La risoluzione conta solo in finestra.
            enabled: settings.windowMode == DesktopWindowMode.windowed,
            onPick: (r) => settings.resolution = r,
          ),
          _DeskChoices<DesktopOrientation>(
            icon: Icons.screen_rotation,
            title: d.orientation,
            keyPrefix: 'orientation',
            values: DesktopOrientation.values,
            selected: settings.orientation,
            label: (o) => o == DesktopOrientation.landscape ? d.landscape : d.portrait,
            onPick: (o) => settings.orientation = o,
          ),
        ];
      case _DeskCategory.language:
        return [
          _DeskChoices<AppLanguage?>(
            icon: Icons.translate,
            title: t.languageSetting,
            keyPrefix: 'language',
            values: [null, ...AppLanguage.values],
            selected: settings.language,
            label: (l) => l?.nativeName ?? t.languageAutomatic,
            onPick: (l) => settings.language = l,
          ),
        ];
      case _DeskCategory.game:
        return [
          _DeskRow(
            icon: Icons.movie_filter,
            title: t.rehearsal,
            subtitle: t.rehearsalHint,
            chevron: true,
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ScreeningRoomScreen())),
          ),
        ];
      case _DeskCategory.account:
        final auth = _host._auth!;
        if (!auth.signedIn) return [_DeskRow(icon: Icons.person_outline, title: s.notSignedIn)];
        return [
          FutureBuilder<Profile?>(
            future: _host._profileOf(auth.userId),
            builder: (context, snapshot) {
              final handle = snapshot.data?.handle;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DeskRow(
                    icon: Icons.badge_outlined,
                    title: handle != null ? s.signedInAs(handle) : s.signedInNoHandle,
                  ),
                  if (_host.widget.online?.links case final links?)
                    _DeskRow(
                      key: const Key('settings.link'),
                      icon: Icons.link,
                      title: d.linkAccount,
                      subtitle: d.linkHint,
                      chevron: true,
                      onTap: () => showLinkAccount(context, links: links),
                    ),
                  _DeskRow(icon: Icons.logout, title: t.online.signOut, onTap: auth.signOut),
                  if (_host.widget.online?.account != null) ...[
                    const SizedBox(height: 28),
                    _DeskRow(
                      key: const Key('settings.delete'),
                      icon: Icons.delete_forever,
                      title: s.deleteAccount,
                      subtitle: s.deleteHint,
                      danger: true,
                      onTap: _host._busy ? null : () => _host._delete(handle),
                    ),
                  ],
                ],
              );
            },
          ),
        ];
      case _DeskCategory.privacy:
        final safety = SafetyStrings.of(context);
        final signedIn = _host._auth?.signedIn ?? false;
        return [
          _DeskRow(
            key: const Key('settings.rules'),
            icon: Icons.menu_book_outlined,
            title: safety.rulesTitle,
            subtitle: safety.rulesHint,
            chevron: true,
            onTap: () => showCommunityRules(context),
          ),
          if (signedIn && _host.widget.online?.safety != null)
            _DeskRow(
              key: const Key('settings.blocked'),
              icon: Icons.block,
              title: safety.blockedPlayers,
              subtitle: safety.blockedHint,
              chevron: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => BlockedPlayersScreen(safety: _host.widget.online!.safety!)),
              ),
            ),
          _DeskRow(
            icon: Icons.privacy_tip_outlined,
            title: s.privacyPolicy,
            chevron: true,
            onTap: () => _host._openLegal(s.privacyPolicy, 'privacy', privacyPolicyUrl),
          ),
          _DeskRow(
            icon: Icons.gavel,
            title: s.terms,
            chevron: true,
            onTap: () => _host._openLegal(s.terms, 'terms', termsUrl),
          ),
          if (signedIn && _host.widget.online?.account != null)
            _DeskRow(
              key: const Key('settings.export'),
              icon: Icons.download,
              title: s.exportData,
              subtitle: s.exportHint,
              onTap: _host._busy ? null : _host._export,
            ),
        ];
      case _DeskCategory.about:
        return [
          FutureBuilder<String>(
            future: _host._versionText(),
            builder: (context, snapshot) => _DeskRow(
              icon: Icons.info_outline,
              title: s.version,
              trailing: Text(
                snapshot.data ?? '…',
                style: DeskText.text(size: DeskText.lead, color: AppColors.gold),
              ),
            ),
          ),
          _DeskRow(icon: Icons.favorite_border, title: s.credits, subtitle: s.creditsBody),
        ];
    }
  }
}

/// Una voce dell'elenco a sinistra.
class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final Widget Function(TextStyle style) summary;
  final VoidCallback onTap;

  const _CategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => DeskHover(
    onTap: onTap,
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: selected
            ? LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.24), AppColors.gold.withValues(alpha: 0.04)])
            : null,
        color: selected ? null : (hovered ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
        border: Border.all(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.65)
              : (hovered ? AppColors.gold.withValues(alpha: 0.28) : Colors.transparent),
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 5,
            margin: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: selected ? AppColors.gold : Colors.transparent,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.gold.withValues(alpha: 0.18) : const Color(0x33000000),
              border: Border.all(color: AppColors.gold.withValues(alpha: selected || hovered ? 0.8 : 0.35)),
            ),
            child: Icon(icon, color: AppColors.gold, size: 26),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DeskText.display(21, color: selected || hovered ? AppColors.gold : AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                summary(DeskText.text(size: DeskText.label, color: AppColors.textSecondary).copyWith(height: 1.2)),
              ],
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: selected ? 1 : (hovered ? 0.5 : 0),
            child: const Icon(Icons.chevron_right, color: AppColors.gold, size: 28),
          ),
          const SizedBox(width: 12),
        ],
      ),
    ),
  );
}

/// Un tasto disegnato, per ricordare le scorciatoie.
class _KeyCap extends StatelessWidget {
  final String? label;
  final IconData? icon;

  const _KeyCap({this.label, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 34),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.4)),
      boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(0, 2))],
    ),
    child: icon != null
        ? Icon(icon, size: 20, color: AppColors.textSecondary)
        : Text(
            label!,
            textAlign: TextAlign.center,
            style: DeskText.text(size: 14, color: AppColors.textSecondary),
          ),
  );
}

/// Una riga di opzione: icona, titolo, spiegazione e il comando a destra.
/// Col puntatore sopra si accende, se fa qualcosa.
class _DeskRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final bool chevron;
  final bool enabled;

  const _DeskRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.chevron = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tint = danger ? AppColors.accent : AppColors.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DeskHover(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: hovered
                ? (danger ? AppColors.accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.045))
                : (danger ? AppColors.accent.withValues(alpha: 0.04) : Colors.transparent),
            border: Border.all(
              color: hovered
                  ? tint.withValues(alpha: 0.5)
                  : (danger ? AppColors.accent.withValues(alpha: 0.3) : Colors.transparent),
            ),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Row(
              children: [
                Icon(icon, color: tint, size: 30),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: DeskText.text(
                          size: DeskText.lead,
                          weight: FontWeight.w600,
                          color: danger ? AppColors.accent : AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: DeskText.text(size: 17, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 20), trailing!],
                if (chevron)
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 140),
                    offset: Offset(hovered ? 0.2 : 0, 0),
                    child: Icon(Icons.chevron_right, color: tint, size: 30),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeskSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _DeskSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: 1.2,
    child: Switch(
      value: value,
      activeThumbColor: AppColors.gold,
      activeTrackColor: AppColors.gold.withValues(alpha: 0.4),
      mouseCursor: WidgetStateMouseCursor.clickable,
      onChanged: onChanged,
    ),
  );
}

/// Un volume: nome a sinistra, percentuale grande a destra, la canna larga
/// sotto.
class _DeskSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _DeskSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
    child: Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 30),
              const SizedBox(width: 22),
              Expanded(
                child: Text(
                  label,
                  style: DeskText.text(size: DeskText.lead, weight: FontWeight.w600),
                ),
              ),
              Text('${(value * 100).round()}%', style: DeskText.display(DeskText.lead)),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: AppColors.gold,
                inactiveTrackColor: AppColors.gold.withValues(alpha: 0.18),
                thumbColor: const Color(0xFFE2C46A),
                overlayColor: AppColors.gold.withValues(alpha: 0.16),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 26),
                showValueIndicator: ShowValueIndicator.never,
                tickMarkShape: SliderTickMarkShape.noTickMark,
              ),
              child: Slider(
                value: value,
                divisions: 20,
                mouseCursor: WidgetStateMouseCursor.clickable,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Una scelta fra pochi valori: un titolo e una fila di tasselli grandi,
/// quello scelto acceso d'oro con la spunta.
class _DeskChoices<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String keyPrefix;
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onPick;
  final bool enabled;

  const _DeskChoices({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.keyPrefix,
    required this.values,
    required this.selected,
    required this.label,
    required this.onPick,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
    child: Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 30),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DeskText.text(size: DeskText.lead, weight: FontWeight.w600),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: DeskText.text(size: 17, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final value in values)
                  _ChoiceTile(
                    key: Key('settings.$keyPrefix.${label(value)}'),
                    label: label(value),
                    selected: value == selected,
                    onTap: () => onPick(value),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => DeskHover(
    onTap: onTap,
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 62,
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: selected
            ? AppColors.gold.withValues(alpha: 0.2)
            : (hovered ? AppColors.surfaceHigh : AppColors.surface.withValues(alpha: 0.7)),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.gold.withValues(alpha: hovered ? 0.6 : 0.2),
          width: selected ? 1.8 : 1,
        ),
        boxShadow: selected ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.18), blurRadius: 16)] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selected) ...[const Icon(Icons.check, color: AppColors.gold, size: 22), const SizedBox(width: 10)],
          Text(
            label,
            style: DeskText.text(
              size: DeskText.body,
              weight: FontWeight.w600,
              color: selected ? AppColors.gold : (hovered ? AppColors.textPrimary : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    ),
  );
}
