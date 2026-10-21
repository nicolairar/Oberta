part of 'barber_mirror_screen.dart';

/// Lo specchio del barbiere sul PC: al centro lo specchio grande sotto la
/// lampada, a sinistra le facce pronte e gli abiti, a destra le schede (in
/// colonna) con le loro scelte; sotto lo specchio «Tengo questa faccia».
extension _DeskMirror on _BarberMirrorScreenState {
  String get _deskTitle => _en ? "The barber's mirror" : 'Lo specchio del barbiere';

  Widget _desktop() => DeskTheme(
    child: DeskEscape(
      onEscape: () {
        if (!_busy) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CityBackdrop(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0x8C000000)),
            child: _asking ? _deskAsk() : _deskChair(),
          ),
        ),
      ),
    ),
  );

  Widget _deskLater() => TextButton(
    key: const Key('mirror.skip'),
    style: TextButton.styleFrom(textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 19)),
    onPressed: _busy ? null : () => Navigator.of(context).pop(),
    child: Text(_en ? 'Later' : 'Dopo'),
  );

  /// Il primo passo, sul PC: tre grandi ritratti tra cui scegliere.
  Widget _deskAsk() {
    final en = _en;
    final seed = widget.profile.avatarSeed;
    Widget card(Presentation p, String title, String? sub) {
      final preview = p == Presentation.other
          ? _look
          : FacePreset.randomize(
              _look.copyWith(features: _look.features.copyWith(presentation: p)),
              Random(stableHash('$seed:${p.name}')),
            );
      final outfits = _suggestedOutfits(p);
      final shown = p == Presentation.other
          ? preview
          : preview.copyWith(outfit: outfits[stableHash(seed) % outfits.length]);
      return DeskHover(
        key: Key('mirror.present.${p.name}'),
        onTap: () => _present(p),
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 380,
          height: 480,
          transform: Matrix4.translationValues(0, hovered ? -10 : 0, 0),
          decoration: DeskPanel.decoration(lit: hovered).copyWith(
            boxShadow: [
              const BoxShadow(color: Color(0xAA000000), blurRadius: 36, offset: Offset(0, 16)),
              if (hovered) BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 40),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayerAvatar(
                seed: '$seed.${p.name}',
                look: shown.copyWith(hat: AvatarHead.slicked),
                size: 250,
              ),
              const SizedBox(height: 32),
              Text(title.toUpperCase(), style: DeskText.display(DeskText.heading).copyWith(letterSpacing: 4)),
              const SizedBox(height: 6),
              SizedBox(
                height: 28,
                child: sub == null ? null : Text(sub, style: DeskText.text(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        DeskTopBar(title: _deskTitle, actions: [if (widget.firstTime) _deskLater()]),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  en ? 'Who sits in the chair?' : 'Chi si siede sulla poltrona?',
                  style: DeskText.display(DeskText.hero, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 900,
                  child: Text(
                    en
                        ? 'The barber suggests cuts, make-up and clothes to match. You can still pick anything with "Show all".'
                        : 'Il barbiere ti propone tagli, trucco e abiti adatti. Con «Mostra tutto» puoi comunque scegliere di tutto.',
                    textAlign: TextAlign.center,
                    style: DeskText.text(size: DeskText.lead, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 56),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    card(Presentation.man, en ? 'Man' : 'Uomo', null),
                    const SizedBox(width: 40),
                    card(Presentation.woman, en ? 'Woman' : 'Donna', null),
                    const SizedBox(width: 40),
                    card(Presentation.other, en ? 'Other' : 'Altro', en ? 'Prefer not to say' : 'Preferisco non dire'),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// La poltrona: le facce pronte e gli abiti, lo specchio, le schede.
  Widget _deskChair() {
    final en = _en;
    final p = _presentation;
    final tabs = [
      for (final tab in _tabs)
        if (tab.optionsFor(p, all: _all).length > 1) tab,
    ];
    final presets = [
      for (final preset in FacePreset.all)
        if (_all || preset.fits(p)) preset,
    ];
    final outfits = widget.services.shop == null
        ? const <AvatarOutfit>[]
        : (_all ? AvatarOutfit.catalog.take(_freeOutfits).toList() : _suggestedOutfits(p));
    final tab = tabs[min(_deskTab, tabs.length - 1)];
    return Column(
      children: [
        DeskTopBar(
          title: _deskTitle,
          onBack: _busy ? null : () => Navigator.of(context).maybePop(),
          actions: [
            for (final option in const [Presentation.man, Presentation.woman, Presentation.other])
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: _DeskToggle(
                  key: Key('mirror.presentation.${option.name}'),
                  label: _presentationLabel(option, en),
                  on: option == p,
                  onTap: () => _present(option),
                ),
              ),
            const SizedBox(width: 28),
            _DeskToggle(
              key: const Key('mirror.showAll'),
              label: en ? 'Show all' : 'Mostra tutto',
              on: _all,
              check: true,
              onTap: () => _update(() => _all = !_all),
            ),
            if (widget.firstTime) ...[const SizedBox(width: 20), _deskLater()],
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(DeskSize.gutter, 8, DeskSize.gutter, 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DeskPanel(
                          title: en ? 'Ready-made faces' : 'Facce pronte',
                          child: _deskWrap([
                            for (final preset in presets)
                              _DeskPick(
                                key: Key('mirror.preset.${preset.id}'),
                                selected: preset.worn(_look),
                                onTap: () => _set(preset.applyTo(_look)),
                                child: PlayerAvatar(seed: preset.id, look: _shown(preset.applyTo(_look)), size: 88),
                              ),
                          ]),
                        ),
                      ),
                      if (outfits.isNotEmpty) ...[
                        const SizedBox(height: DeskSize.gap),
                        Expanded(
                          flex: 2,
                          child: DeskPanel(
                            title: en ? 'Free clothes' : 'Abiti di casa',
                            child: _deskWrap(key: const Key('mirror.outfits'), [
                              for (final outfit in outfits)
                                _DeskPick(
                                  key: Key('mirror.outfit.${outfit.id}'),
                                  selected: _look.outfit == outfit,
                                  onTap: () => _set(_look.copyWith(outfit: outfit)),
                                  child: PlayerAvatar(
                                    seed: outfit.id,
                                    look: _shown(_look.copyWith(outfit: outfit)),
                                    size: 88,
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(child: _deskGlass(en)),
                const SizedBox(width: 32),
                SizedBox(
                  width: 680,
                  child: DeskPanel(
                    padding: EdgeInsets.zero,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 200,
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: AppColors.gold.withValues(alpha: 0.2))),
                          ),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            children: [
                              for (final (i, t) in tabs.indexed)
                                _DeskTabRow(
                                  key: Key('mirror.tab.${t.en.toLowerCase()}'),
                                  label: en ? t.en : t.it,
                                  on: t == tab,
                                  onTap: () => _update(() => _deskTab = i),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(28, 26, 28, 18),
                                child: Text(
                                  (en ? tab.en : tab.it).toUpperCase(),
                                  style: DeskText.overline(color: AppColors.gold),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(28, 0, 20, 20),
                                  child: _deskWrap(key: ValueKey('mirror.options.${tab.en}'), [
                                    for (final option in tab.optionsFor(p, all: _all))
                                      _DeskPick(
                                        key: Key('mirror.${tab.en.toLowerCase()}.${(option as Enum).name}'),
                                        selected: tab.current(_look) == option,
                                        label: option.name,
                                        caption: _caption(option.name),
                                        onTap: () => _set(tab.apply(_look, option)),
                                        child: switch ((tab.swatch, tab.focus)) {
                                          (final swatch?, _) => SizedBox.square(
                                            dimension: 84,
                                            child: Center(
                                              child: Transform.scale(scale: 1.4, child: _Swatch(color: swatch(option))),
                                            ),
                                          ),
                                          (null, final focus?) => _Zoom(
                                            focus: focus,
                                            child: PlayerAvatar(
                                              seed: option.name,
                                              look: _shown(tab.apply(_look, option)),
                                              size: 84,
                                            ),
                                          ),
                                          (null, null) => PlayerAvatar(
                                            seed: option.name,
                                            look: _shown(tab.apply(_look, option)),
                                            size: 84,
                                          ),
                                        },
                                      ),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _deskWrap(List<Widget> children, {Key? key}) => SingleChildScrollView(
    key: key,
    child: Wrap(spacing: 14, runSpacing: 14, children: children),
  );

  /// Lo specchio grande, sotto la lampada; gli attrezzi e i due bottoni.
  Widget _deskGlass(bool en) {
    // Il testo dei bottoni nel carattere dell'app, non in quello di sistema.
    final label = Theme.of(context).textTheme.labelLarge
        ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1.5);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = min(box.maxWidth - 40, box.maxHeight - 40).clamp(200.0, 540.0);
              return DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.2),
                    radius: 0.5,
                    colors: [Color(0x40FFD27A), Color(0x00FFD27A)],
                  ),
                ),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        const BoxShadow(color: Color(0xCC000000), blurRadius: 60, offset: Offset(0, 24)),
                        BoxShadow(color: AppColors.gold.withValues(alpha: 0.22), blurRadius: 60, spreadRadius: 4),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: PlayerAvatar(
                        key: ValueKey(_shown(_look)),
                        seed: 'mirror',
                        look: _shown(_look),
                        size: size,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DeskTool(
              key: const Key('mirror.hat'),
              icon: _hatOn ? Icons.face : Icons.face_retouching_natural,
              label: en ? (_hatOn ? 'Hat off' : 'Hat on') : (_hatOn ? 'Togli il cappello' : 'Metti il cappello'),
              onTap: () => _update(() => _hatOn = !_hatOn),
            ),
            const SizedBox(width: 14),
            _DeskTool(
              key: const Key('mirror.random'),
              icon: Icons.casino_outlined,
              label: en ? 'Random face' : 'A caso',
              onTap: () => _set(FacePreset.randomize(_look, _random)),
            ),
            const SizedBox(width: 14),
            _DeskTool(
              key: const Key('mirror.undo'),
              icon: Icons.undo,
              label: en ? 'As it was' : "Com'era",
              onTap: _look == _start ? null : () => _set(_start),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('mirror.cancel'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 68), textStyle: label),
                onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                child: Text(en ? 'Cancel' : 'Annulla'),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                key: const Key('mirror.save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF1A120C),
                  minimumSize: const Size(0, 68),
                  textStyle: label,
                ),
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Icon(Icons.check),
                label: Text(en ? 'Save this face' : 'Tengo questa faccia'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Un interruttore a pillola della barra in alto: Uomo, Donna, Altro, Mostra tutto.
class _DeskToggle extends StatelessWidget {
  final String label;
  final bool on;
  final bool check;
  final VoidCallback onTap;

  const _DeskToggle({super.key, required this.label, required this.on, required this.onTap, this.check = false});

  @override
  Widget build(BuildContext context) => DeskHover(
    onTap: onTap,
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: on
            ? AppColors.gold.withValues(alpha: 0.22)
            : (hovered ? const Color(0x33C9A227) : const Color(0x99000000)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: on || hovered ? AppColors.gold : AppColors.gold.withValues(alpha: 0.35),
          width: on ? 1.6 : 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (check) ...[
            Text(on ? '☑' : '☐', style: const TextStyle(color: AppColors.gold, fontSize: 20)),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: on || hovered ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 18,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Una scheda nella colonna di destra.
class _DeskTabRow extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _DeskTabRow({super.key, required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) => DeskHover(
    onTap: onTap,
    builder: (context, hovered) => AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        gradient: on || hovered
            ? LinearGradient(
                colors: [
                  AppColors.gold.withValues(alpha: on ? 0.24 : 0.1),
                  Colors.transparent,
                ],
              )
            : null,
        border: Border(left: BorderSide(color: on ? AppColors.gold : Colors.transparent, width: 4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: on ? AppColors.gold : (hovered ? AppColors.textPrimary : AppColors.textSecondary),
          fontSize: 19,
          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

/// Un attrezzo del barbiere sotto lo specchio: icona e nome.
class _DeskTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DeskTool({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.4 : 1,
    child: DeskHover(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: hovered ? const Color(0x33C9A227) : const Color(0xB3000000),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.gold.withValues(alpha: hovered ? 0.9 : 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.gold, size: 24),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(color: hovered ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 17),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Una scelta sul PC: il tondo d'oro se scelta, un alone al passaggio.
class _DeskPick extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String? label;
  final String? caption;

  const _DeskPick({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.label,
    this.caption,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: DeskHover(
      onTap: onTap,
      builder: (context, hovered) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? AppColors.gold
                    : (hovered ? AppColors.gold.withValues(alpha: 0.5) : Colors.transparent),
                width: 3,
              ),
              boxShadow: [
                if (hovered || selected) BoxShadow(color: AppColors.gold.withValues(alpha: 0.28), blurRadius: 16),
              ],
            ),
            child: child,
          ),
          if (caption case final caption?)
            SizedBox(
              width: 100,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? AppColors.gold : (hovered ? AppColors.textPrimary : AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
