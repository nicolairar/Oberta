import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../street/street_route.dart';
import '../../street/street_scaffold.dart';
import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../avatar/avatar_look.dart';
import '../../avatar/face_presets.dart';
import '../../desktop/desktop_canvas.dart';
import '../../theme/app_theme.dart';
import '../../widgets/noir_avatar.dart' show AvatarHead;
import '../../widgets/player_avatar.dart';
import '../online/online_widgets.dart';

part 'barber_mirror_desktop.dart';

/// Lo specchio del barbiere: la faccia, gratis. Si sceglie la pelle, la forma
/// della testa, gli occhi, i capelli; i pezzi della bottega restano quelli
/// indossati. Torna il profilo salvato, o null se si esce senza salvare.
class BarberMirrorScreen extends StatefulWidget {
  final OnlineServices services;
  final Profile profile;

  /// La prima volta, subito dopo il nome unico: si può anche saltare.
  final bool firstTime;

  const BarberMirrorScreen({super.key, required this.services, required this.profile, this.firstTime = false});

  static Future<Profile?> open(
    BuildContext context, {
    required OnlineServices services,
    required Profile profile,
    bool firstTime = false,
  }) => StreetRoute.push<Profile>(
    context,
    StreetSection.barber,
    (_) => BarberMirrorScreen(services: services, profile: profile, firstTime: firstTime),
  );

  @override
  State<BarberMirrorScreen> createState() => _BarberMirrorScreenState();
}

/// Una scheda dello specchio: le scelte, come si mostrano, come si indossano.
class _Tab {
  final String it;
  final String en;
  final List<Object> options;
  final Object Function(AvatarLook look) current;
  final AvatarLook Function(AvatarLook look, Object option) apply;

  /// Il colore del campione, per pelle, occhi e capelli; null per le miniature.
  final Color? Function(Object option)? swatch;

  /// Dove guarda la miniatura: il punto del viso ingrandito, o null per il busto.
  final Alignment? focus;

  /// Le scelte proposte a chi si presenta così (null: tutte, sempre).
  final bool Function(Object option, Presentation p)? fits;

  const _Tab(this.it, this.en, this.options, this.current, this.apply, {this.swatch, this.focus, this.fits});

  List<Object> optionsFor(Presentation p, {required bool all}) => all || p == Presentation.other || fits == null
      ? options
      : [
          for (final o in options)
            if (fits!(o, p)) o,
        ];
}

/// Le pettinature proposte: alle signore le loro (e i ricci), ai signori il resto.
bool _hairFits(Object o, Presentation p) {
  final h = o as HairStyle;
  return p == Presentation.woman
      ? h.dame || h == HairStyle.wavy || h == HairStyle.curly || h == HairStyle.coils || h == HairStyle.afro
      : !h.dame || h == HairStyle.long || h == HairStyle.ponytail;
}

/// Il trucco si propone alle signore; ai signori resta «niente».
bool _makeupFits(Object o, Presentation p) => p == Presentation.woman || (o as Enum).name == 'none';

/// Gli abiti gratis suggeriti: abiti e camicette per le signore, giacche per i signori.
List<AvatarOutfit> _suggestedOutfits(Presentation p) => [
  for (final o in AvatarOutfit.catalog.take(_freeOutfits))
    if (p == Presentation.other || (o.pattern.feminine == (p == Presentation.woman))) o,
];

/// I primi abiti del catalogo sono quelli gratis: undici giacche e cinque per le signore.
const _freeOutfits = 16;

/// `victoryRolls` → `victory rolls`: il nome dell'id, da leggere.
String _caption(String id) => id.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');

AvatarLook _f(AvatarLook look, FaceFeatures Function(FaceFeatures f) change) => look.copyWith(features: change(look.features));

final _tabs = <_Tab>[
  _Tab(
    'Pelle',
    'Skin',
    SkinTone.ordered,
    (l) => l.base.tone,
    (l, o) => l.copyWith(base: AvatarBase.of(o as SkinTone, l.base.mark)),
    swatch: (o) => (o as SkinTone).color,
  ),
  _Tab('Testa', 'Head', FaceShape.values, (l) => l.features.shape, (l, o) => _f(l, (f) => f.copyWith(shape: o as FaceShape))),
  _Tab(
    'Capelli',
    'Hair',
    HairStyle.values,
    (l) => l.features.hair,
    (l, o) => _f(l, (f) => f.copyWith(hair: o as HairStyle)),
    fits: _hairFits,
  ),
  _Tab(
    'Colore',
    'Colour',
    HairColor.values,
    (l) => l.features.hairColor,
    (l, o) => _f(l, (f) => f.copyWith(hairColor: o as HairColor)),
    swatch: (o) => (o as HairColor).color,
  ),
  _Tab(
    'Occhi',
    'Eyes',
    EyeShape.values,
    (l) => l.features.eyes,
    (l, o) => _f(l, (f) => f.copyWith(eyes: o as EyeShape)),
    focus: const Alignment(0, -0.1),
  ),
  _Tab(
    'Iride',
    'Iris',
    EyeColor.values,
    (l) => l.features.eyeColor,
    (l, o) => _f(l, (f) => f.copyWith(eyeColor: o as EyeColor)),
    swatch: (o) => (o as EyeColor).color,
  ),
  _Tab(
    'Sopracciglia',
    'Brows',
    BrowShape.values,
    (l) => l.features.brows,
    (l, o) => _f(l, (f) => f.copyWith(brows: o as BrowShape)),
    focus: const Alignment(0, -0.14),
  ),
  _Tab(
    'Naso',
    'Nose',
    NoseShape.values,
    (l) => l.features.nose,
    (l, o) => _f(l, (f) => f.copyWith(nose: o as NoseShape)),
    focus: const Alignment(0, 0.02),
  ),
  _Tab(
    'Bocca',
    'Mouth',
    MouthShape.values,
    (l) => l.features.mouth,
    (l, o) => _f(l, (f) => f.copyWith(mouth: o as MouthShape)),
    focus: const Alignment(0, 0.13),
    fits: (o, p) => p == Presentation.woman || !(o as MouthShape).painted,
  ),
  _Tab(
    'Rossetto',
    'Lipstick',
    LipColor.values,
    (l) => l.features.lips,
    (l, o) => _f(l, (f) => f.copyWith(lips: o as LipColor)),
    swatch: (o) => o == LipColor.none ? null : (o as LipColor).color,
    fits: _makeupFits,
  ),
  _Tab(
    'Trucco',
    'Make-up',
    EyeShadow.values,
    (l) => l.features.shadow,
    (l, o) => _f(l, (f) => f.copyWith(shadow: o as EyeShadow)),
    focus: const Alignment(0, -0.1),
    fits: _makeupFits,
  ),
  _Tab(
    'Segni',
    'Marks',
    FaceDetail.values,
    (l) => l.features.detail,
    (l, o) => _f(l, (f) => f.copyWith(detail: o as FaceDetail)),
    focus: const Alignment(0, -0.02),
  ),
  _Tab(
    'Età',
    'Age',
    FaceAge.values,
    (l) => l.features.age,
    (l, o) => _f(l, (f) => f.copyWith(age: o as FaceAge)),
    focus: const Alignment(0, -0.02),
  ),
];

class _BarberMirrorScreenState extends State<BarberMirrorScreen> {
  late final AvatarLook _start = widget.profile.look;
  late AvatarLook _look = _start;

  /// Il primo passo: «Uomo / Donna / Altro», finché non si è mai scelto.
  late bool _asking = widget.profile.avatar['presentation'] == null;

  /// «Mostra tutto»: le scelte di tutti, non solo quelle proposte.
  bool _all = false;
  bool _hatOn = false;
  bool _busy = false;
  final _random = Random();

  /// Sul PC: la scheda aperta nella colonna di destra.
  int _deskTab = 0;

  /// [setState] per l'estensione del layout PC.
  void _update(VoidCallback change) => setState(change);

  bool get _en => AppStrings.of(context).language == AppLanguage.en;

  /// Lo specchio mostra la testa nuda, per vedere i capelli; il cappello si
  /// rimette con un tocco.
  AvatarLook _shown(AvatarLook look) => _hatOn || look.bareHead ? look : look.copyWith(hat: AvatarHead.slicked);

  void _set(AvatarLook look) {
    HapticFeedback.selectionClick();
    setState(() => _look = look);
  }

  Presentation get _presentation => _look.features.presentation;

  /// Sceglie come presentarsi. Chi non ha mai salvato una faccia riceve una
  /// proposta adatta, diversa per ogni nome; e l'abito gratis si accorda.
  void _present(Presentation p) {
    var look = _f(_look, (f) => f.copyWith(presentation: p));
    final neverFaced = widget.profile.avatar['hair'] == null;
    final mismatch = p != Presentation.other && _hairFits(look.features.hair, p) == false;
    if (neverFaced || mismatch) {
      look = FacePreset.randomize(look, Random(stableHash('${widget.profile.avatarSeed}:${p.name}')));
    }
    final outfits = _suggestedOutfits(p);
    final freeNow = AvatarOutfit.catalog.take(_freeOutfits).contains(look.outfit);
    if (freeNow && !outfits.contains(look.outfit) && outfits.isNotEmpty) {
      look = look.copyWith(outfit: outfits[stableHash(widget.profile.avatarSeed) % outfits.length]);
    }
    HapticFeedback.selectionClick();
    setState(() {
      _look = look;
      _asking = false;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      var profile = await widget.services.profiles.saveFace(
        _look.features.toJson(),
        tone: _look.base.tone.name,
        mark: _look.base.mark.name,
      );
      // L'abito gratis suggerito: lo si indossa come dalla bottega.
      final shop = widget.services.shop;
      if (shop != null && _look.outfit != _start.outfit) {
        profile = await shop.equip('outfit.${_look.outfit.id}', tone: _look.base.tone.name, current: _look.toJson());
      }
      if (mounted) Navigator.of(context).pop(profile);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (DesktopCanvas.of(context)) return _desktop();
    final en = _en;
    if (_asking) {
      return StreetScaffold(
        section: StreetSection.barber,
        title: en ? "The barber's mirror" : 'Lo specchio del barbiere',
        actions: [
            if (widget.firstTime)
              TextButton(key: const Key('mirror.skip'), onPressed: () => Navigator.of(context).pop(), child: Text(en ? 'Later' : 'Dopo')),
        ],
        body: SafeArea(
          child: _PresentationStep(en: en, seed: widget.profile.avatarSeed, look: _look, onPick: _present),
        ),
      );
    }
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
    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: StreetScaffold(
        section: StreetSection.barber,
        title: en ? "The barber's mirror" : 'Lo specchio del barbiere',
        actions: [
            if (widget.firstTime)
              TextButton(
                key: const Key('mirror.skip'),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(en ? 'Later' : 'Dopo'),
              ),
        ],
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              _Preview(
                look: _shown(_look),
                hatOn: _hatOn,
                en: en,
                onHat: () => setState(() => _hatOn = !_hatOn),
                onRandom: () => _set(FacePreset.randomize(_look, _random)),
                onUndo: _look == _start ? null : () => _set(_start),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<Presentation>(
                        key: const Key('mirror.presentation'),
                        showSelectedIcon: false,
                        segments: [
                          for (final option in Presentation.values)
                            ButtonSegment(
                              value: option,
                              label: Text(_presentationLabel(option, en), overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        selected: {p},
                        onSelectionChanged: (s) => _present(s.first),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      key: const Key('mirror.showAll'),
                      label: Text(en ? 'Show all' : 'Mostra tutto'),
                      selected: _all,
                      onSelected: (v) => setState(() => _all = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final preset in presets)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Pick(
                          key: Key('mirror.preset.${preset.id}'),
                          selected: preset.worn(_look),
                          onTap: () => _set(preset.applyTo(_look)),
                          child: PlayerAvatar(seed: preset.id, look: _shown(preset.applyTo(_look)), size: 56),
                        ),
                      ),
                  ],
                ),
              ),
              if (outfits.isNotEmpty)
                SizedBox(
                  height: 74,
                  child: ListView(
                    key: const Key('mirror.outfits'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    children: [
                      for (final outfit in outfits)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _Pick(
                            key: Key('mirror.outfit.${outfit.id}'),
                            selected: _look.outfit == outfit,
                            onTap: () => _set(_look.copyWith(outfit: outfit)),
                            child: PlayerAvatar(
                              seed: outfit.id,
                              look: _shown(_look.copyWith(outfit: outfit)),
                              size: 56,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.gold,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.gold,
                tabs: [for (final tab in tabs) Tab(text: en ? tab.en : tab.it)],
              ),
              Expanded(
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.82),
                  child: TabBarView(
                    children: [
                      for (final tab in tabs)
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final option in tab.optionsFor(p, all: _all))
                                _Pick(
                                  key: Key('mirror.${tab.en.toLowerCase()}.${(option as Enum).name}'),
                                  selected: tab.current(_look) == option,
                                  label: option.name,
                                  caption: _caption(option.name),
                                  onTap: () => _set(tab.apply(_look, option)),
                                  child: switch ((tab.swatch, tab.focus)) {
                                    (final swatch?, _) => _Swatch(color: swatch(option)),
                                    (null, final focus?) => _Zoom(
                                      focus: focus,
                                      child: PlayerAvatar(seed: option.name, look: _shown(tab.apply(_look, option)), size: 66),
                                    ),
                                    (null, null) => PlayerAvatar(seed: option.name, look: _shown(tab.apply(_look, option)), size: 66),
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('mirror.save'),
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(en ? 'Save this face' : 'Tengo questa faccia'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _presentationLabel(Presentation p, bool en) => switch (p) {
  Presentation.man => en ? 'Man' : 'Uomo',
  Presentation.woman => en ? 'Woman' : 'Donna',
  Presentation.other => en ? 'Other' : 'Altro',
};

/// Il primo passo dello specchio: come ti presenti? Filtra le proposte;
/// «Altro / Preferisco non dire» lascia tutto aperto.
class _PresentationStep extends StatelessWidget {
  final bool en;
  final String seed;
  final AvatarLook look;
  final ValueChanged<Presentation> onPick;

  const _PresentationStep({required this.en, required this.seed, required this.look, required this.onPick});

  @override
  Widget build(BuildContext context) {
    Widget card(Presentation p, String title, String? sub) {
      final preview = p == Presentation.other
          ? look
          : FacePreset.randomize(look.copyWith(features: look.features.copyWith(presentation: p)), Random(stableHash('$seed:${p.name}')));
      final outfits = _suggestedOutfits(p);
      final shown = p == Presentation.other ? preview : preview.copyWith(outfit: outfits[stableHash(seed) % outfits.length]);
      return Expanded(
        child: Material(
          color: AppColors.background.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
          child: InkWell(
            key: Key('mirror.present.${p.name}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => onPick(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              child: Column(
                children: [
                  PlayerAvatar(
                    seed: '$seed.${p.name}',
                    look: shown.copyWith(hat: AvatarHead.slicked),
                    size: 84,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.display(18, color: AppColors.gold),
                  ),
                  if (sub != null)
                    Text(
                      sub,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            en ? 'Who sits in the chair?' : 'Chi si siede sulla poltrona?',
            textAlign: TextAlign.center,
            style: AppText.display(26, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            en
                ? 'The barber suggests cuts, make-up and clothes to match. You can still pick anything with "Show all".'
                : 'Il barbiere ti propone tagli, trucco e abiti adatti. Con «Mostra tutto» puoi comunque scegliere di tutto.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              card(Presentation.man, en ? 'Man' : 'Uomo', null),
              const SizedBox(width: 10),
              card(Presentation.woman, en ? 'Woman' : 'Donna', null),
              const SizedBox(width: 10),
              card(Presentation.other, en ? 'Other' : 'Altro', en ? 'Prefer not to say' : 'Preferisco non dire'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final AvatarLook look;
  final bool hatOn;
  final bool en;
  final VoidCallback onHat;
  final VoidCallback onRandom;
  final VoidCallback? onUndo;

  const _Preview({
    required this.look,
    required this.hatOn,
    required this.en,
    required this.onHat,
    required this.onRandom,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            key: const Key('mirror.hat'),
            tooltip: en ? (hatOn ? 'Take the hat off' : 'Put the hat on') : (hatOn ? 'Togli il cappello' : 'Metti il cappello'),
            onPressed: onHat,
            icon: Icon(hatOn ? Icons.face : Icons.face_retouching_natural),
          ),
          const SizedBox(height: 8),
          IconButton.filledTonal(
            key: const Key('mirror.undo'),
            tooltip: en ? 'Back to how it was' : 'Com\'era prima',
            onPressed: onUndo,
            icon: const Icon(Icons.undo),
          ),
        ],
      ),
      const SizedBox(width: 16),
      PlayerAvatar(seed: 'mirror', look: look, size: 190),
      const SizedBox(width: 16),
      IconButton.filledTonal(
        key: const Key('mirror.random'),
        tooltip: en ? 'Random face' : 'Una faccia a caso',
        onPressed: onRandom,
        icon: const Icon(Icons.casino_outlined),
      ),
    ],
  );
}

class _Pick extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String? label;

  /// Il nome sotto la miniatura.
  final String? caption;

  const _Pick({super.key, required this.selected, required this.onTap, required this.child, this.label, this.caption});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? AppColors.gold : Colors.transparent, width: 2.5),
            ),
            child: child,
          ),
          if (caption case final caption?)
            SizedBox(
              width: 76,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: selected ? AppColors.gold : AppColors.textSecondary),
              ),
            ),
        ],
      ),
    ),
  );
}

/// La miniatura ingrandita su un punto del viso, dentro un tondo.
class _Zoom extends StatelessWidget {
  final Alignment focus;
  final Widget child;

  const _Zoom({required this.focus, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF221C18)),
    child: ClipOval(
      child: Transform.scale(scale: 2.3, alignment: focus, child: child),
    ),
  );
}

class _Swatch extends StatelessWidget {
  /// Null: niente, un tondo vuoto barrato.
  final Color? color;

  const _Swatch({required this.color});

  @override
  Widget build(BuildContext context) => color == null
      ? Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textSecondary, width: 1.5),
          ),
          child: const Icon(Icons.block, color: AppColors.textSecondary),
        )
      : _filled(color!);

  Widget _filled(Color color) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: [Color.lerp(color, Colors.white, 0.25)!, color, Color.lerp(color, Colors.black, 0.45)!],
        stops: const [0, 0.5, 1],
      ),
      border: Border.all(color: Colors.black.withValues(alpha: 0.5), width: 1.5),
    ),
  );
}
