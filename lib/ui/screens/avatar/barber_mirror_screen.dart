import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../online/online_services.dart';
import '../../avatar/avatar_look.dart';
import '../../avatar/face_presets.dart';
import '../../theme/app_theme.dart';
import '../../widgets/noir_avatar.dart' show AvatarHead;
import '../../widgets/player_avatar.dart';
import '../../widgets/scene_scaffold.dart';
import '../online/online_widgets.dart';

/// Lo specchio del barbiere: la faccia, gratis. Si sceglie la pelle, la forma
/// della testa, gli occhi, i capelli; i pezzi della bottega restano quelli
/// indossati. Torna il profilo salvato, o null se si esce senza salvare.
class BarberMirrorScreen extends StatefulWidget {
  final OnlineServices services;
  final Profile profile;

  /// La prima volta, subito dopo il nome unico: si può anche saltare.
  final bool firstTime;

  const BarberMirrorScreen({super.key, required this.services, required this.profile, this.firstTime = false});

  static Future<Profile?> open(BuildContext context, {required OnlineServices services, required Profile profile, bool firstTime = false}) =>
      Navigator.of(context).push<Profile>(
        MaterialPageRoute(builder: (_) => BarberMirrorScreen(services: services, profile: profile, firstTime: firstTime)),
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

  const _Tab(this.it, this.en, this.options, this.current, this.apply, {this.swatch, this.focus});
}

/// `victoryRolls` → `victory rolls`: il nome dell'id, da leggere.
String _caption(String id) => id.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');

AvatarLook _f(AvatarLook look, FaceFeatures Function(FaceFeatures f) change) =>
    look.copyWith(features: change(look.features));

final _tabs = <_Tab>[
  _Tab('Pelle', 'Skin', SkinTone.ordered, (l) => l.base.tone,
      (l, o) => l.copyWith(base: AvatarBase.of(o as SkinTone, l.base.mark)),
      swatch: (o) => (o as SkinTone).color),
  _Tab('Testa', 'Head', FaceShape.values, (l) => l.features.shape, (l, o) => _f(l, (f) => f.copyWith(shape: o as FaceShape))),
  _Tab('Capelli', 'Hair', HairStyle.values, (l) => l.features.hair, (l, o) => _f(l, (f) => f.copyWith(hair: o as HairStyle))),
  _Tab('Colore', 'Colour', HairColor.values, (l) => l.features.hairColor,
      (l, o) => _f(l, (f) => f.copyWith(hairColor: o as HairColor)),
      swatch: (o) => (o as HairColor).color),
  _Tab('Occhi', 'Eyes', EyeShape.values, (l) => l.features.eyes, (l, o) => _f(l, (f) => f.copyWith(eyes: o as EyeShape)),
      focus: const Alignment(0, -0.1)),
  _Tab('Iride', 'Iris', EyeColor.values, (l) => l.features.eyeColor,
      (l, o) => _f(l, (f) => f.copyWith(eyeColor: o as EyeColor)),
      swatch: (o) => (o as EyeColor).color),
  _Tab('Sopracciglia', 'Brows', BrowShape.values, (l) => l.features.brows, (l, o) => _f(l, (f) => f.copyWith(brows: o as BrowShape)),
      focus: const Alignment(0, -0.14)),
  _Tab('Naso', 'Nose', NoseShape.values, (l) => l.features.nose, (l, o) => _f(l, (f) => f.copyWith(nose: o as NoseShape)),
      focus: const Alignment(0, 0.02)),
  _Tab('Bocca', 'Mouth', MouthShape.values, (l) => l.features.mouth, (l, o) => _f(l, (f) => f.copyWith(mouth: o as MouthShape)),
      focus: const Alignment(0, 0.13)),
  _Tab('Rossetto', 'Lipstick', LipColor.values, (l) => l.features.lips, (l, o) => _f(l, (f) => f.copyWith(lips: o as LipColor)),
      swatch: (o) => o == LipColor.none ? null : (o as LipColor).color),
  _Tab('Trucco', 'Make-up', EyeShadow.values, (l) => l.features.shadow, (l, o) => _f(l, (f) => f.copyWith(shadow: o as EyeShadow)),
      focus: const Alignment(0, -0.1)),
  _Tab('Segni', 'Marks', FaceDetail.values, (l) => l.features.detail, (l, o) => _f(l, (f) => f.copyWith(detail: o as FaceDetail)),
      focus: const Alignment(0, -0.02)),
  _Tab('Età', 'Age', FaceAge.values, (l) => l.features.age, (l, o) => _f(l, (f) => f.copyWith(age: o as FaceAge)),
      focus: const Alignment(0, -0.02)),
];

class _BarberMirrorScreenState extends State<BarberMirrorScreen> {
  late final AvatarLook _start = widget.profile.look;
  late AvatarLook _look = _start;
  bool _hatOn = false;
  bool _busy = false;
  final _random = Random();

  bool get _en => AppStrings.of(context).language == AppLanguage.en;

  /// Lo specchio mostra la testa nuda, per vedere i capelli; il cappello si
  /// rimette con un tocco.
  AvatarLook _shown(AvatarLook look) => _hatOn || look.bareHead ? look : look.copyWith(hat: AvatarHead.slicked);

  void _set(AvatarLook look) {
    HapticFeedback.selectionClick();
    setState(() => _look = look);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final profile = await widget.services.profiles.saveFace(
        _look.features.toJson(),
        tone: _look.base.tone.name,
        mark: _look.base.mark.name,
      );
      if (mounted) Navigator.of(context).pop(profile);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final en = _en;
    return DefaultTabController(
      length: _tabs.length,
      child: SceneScaffold(
        appBar: AppBar(
          title: Text(en ? "The barber's mirror" : 'Lo specchio del barbiere'),
          actions: [
            if (widget.firstTime)
              TextButton(
                key: const Key('mirror.skip'),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(en ? 'Later' : 'Dopo'),
              ),
          ],
        ),
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
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final preset in FacePreset.all)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Pick(
                          key: Key('mirror.preset.${preset.id}'),
                          selected: preset.tone == _look.base.tone && preset.features == _look.features,
                          onTap: () => _set(preset.applyTo(_look)),
                          child: PlayerAvatar(seed: preset.id, look: _shown(preset.applyTo(_look)), size: 56),
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
                tabs: [for (final tab in _tabs) Tab(text: en ? tab.en : tab.it)],
              ),
              Expanded(
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.82),
                  child: TabBarView(
                    children: [
                      for (final tab in _tabs)
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final option in tab.options)
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
        child: ClipOval(child: Transform.scale(scale: 2.3, alignment: focus, child: child)),
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
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.textSecondary, width: 1.5)),
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
