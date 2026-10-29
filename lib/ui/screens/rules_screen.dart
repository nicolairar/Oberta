import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/rules_strings.dart';
import '../../rules/role.dart';
import '../../sound/narrator_voice.dart';
import '../../sound/sound_stage.dart';
import '../desktop/desktop_canvas.dart';
import '../widgets/targa.dart';
import '../theme/script_fonts.dart';

const _paper = Color(0xFFEFE4CB);
const _paperShade = Color(0xFFE0D0AC);
const _ink = Color(0xFF1C140E);
const _inkSoft = Color(0xFF5A4632);
const _red = Color(0xFF8E1E24);

/// Le regole del gioco, da leggere ad alta voce a tutto il tavolo prima di
/// una partita su un telefono solo: un avviso affisso, sei passi numerati, in
/// due versioni (sbrigativa e teatrale). In fondo, i ruoli più comuni e il
/// pulsante per cominciare.
class RulesScreen extends StatefulWidget {
  /// Porta alla preparazione della partita su un telefono (dove c'è).
  final VoidCallback? onPlayLocal;

  /// Dove il telefono unico non c'è (il desktop): una stanza con gli amici.
  final VoidCallback? onPlayFriends;

  const RulesScreen({super.key, this.onPlayLocal, this.onPlayFriends});

  /// Apre le regole; il pulsante in fondo chiude la pagina e poi chiama
  /// [onPlayLocal] (o [onPlayFriends]).
  static Future<void> open(BuildContext context, {VoidCallback? onPlayLocal, VoidCallback? onPlayFriends}) {
    final navigator = Navigator.of(context);
    VoidCallback? leaving(VoidCallback? then) => then == null
        ? null
        : () {
            navigator.pop();
            then();
          };
    return navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RulesScreen(onPlayLocal: leaving(onPlayLocal), onPlayFriends: leaving(onPlayFriends)),
      ),
    );
  }

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

/// Il punto della pagina che la voce sta leggendo: un passo e un capoverso
/// (-1 è il titolo del passo).
typedef _At = (int step, int beat);

class _RulesScreenState extends State<RulesScreen> {
  RulesStyle _style = RulesStyle.quick;
  bool _roles = false;
  _At? _at;
  Timer? _timer;
  final _keys = <_At, GlobalKey>{};

  NarratorVoice get _voice => NarratorVoice.instance;

  GlobalKey _key(_At at) => _keys.putIfAbsent(at, GlobalKey.new);

  @override
  void dispose() {
    _timer?.cancel();
    // Chi esce a metà lettura spegne la voce (senza farsi richiamare: qui
    // la pagina non c'è già più).
    if (_at != null) {
      _voice.release(this);
      SoundStage.instance.stopVoice();
    }
    super.dispose();
  }

  void _pick(RulesStyle style) {
    if (style == _style) return;
    HapticFeedback.selectionClick();
    SoundStage.instance.press(Press.tap);
    _stop();
    setState(() {
      _style = style;
      _keys.clear();
    });
  }

  // La voce: un capoverso alla volta, le indicazioni di scena in silenzio.
  void _toggleReading() {
    HapticFeedback.selectionClick();
    if (_at != null) {
      _stop();
      return;
    }
    _voice.claim(this, () {
      _timer?.cancel();
      if (mounted) setState(() => _at = null);
    });
    _go((0, -1));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _voice.release(this);
    SoundStage.instance.stopVoice();
    if (_at != null) setState(() => _at = null);
  }

  void _go(_At at) {
    final strings = RulesStrings.of(context);
    final language = AppStrings.of(context).language;
    final steps = strings.steps(_style);
    final (step, beat) = at;
    if (step >= steps.length) {
      _stop();
      return;
    }
    if (beat >= steps[step].beats.length) {
      _go((step + 1, -1));
      return;
    }
    setState(() => _at = at);
    final line = beat < 0 ? steps[step].title : steps[step].beats[beat].text;
    final cue = beat >= 0 && steps[step].beats[beat].cue;
    Duration length;
    if (cue) {
      length = const Duration(milliseconds: 1400);
    } else {
      final clip = _voice.clip(language, line);
      length = clip ?? NarratorVoice.perCharacter * line.length;
      if (clip != null) {
        _voice.say(
          this,
          VoiceStep(
            line: 0,
            part: 0,
            start: Duration.zero,
            length: clip,
            asset: NarratorVoice.assetFor(language, line),
          ),
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[at]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.35,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }
    });
    _timer = Timer(length + NarratorVoice.linePause, () {
      if (mounted) _go((step, beat + 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = RulesStrings.of(context);
    final t = AppStrings.of(context);
    final desk = DesktopCanvas.of(context);
    final steps = r.steps(_style);
    // La voce c'è solo dove le regole sono state incise davvero.
    final canRead = SoundStage.instance.enabled && _voice.clip(t.language, steps.first.title) != null;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final page = Scaffold(
      backgroundColor: const Color(0xFF0B0907),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.3,
            colors: [Color(0xFF2A1A14), Color(0xFF0B0907)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final k = desk ? 1.4 : (box.maxWidth >= 700 ? 1.15 : 1.0);
              final side = box.maxWidth < 420 ? 14.0 : 24.0;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    // La voce sta in alto, fuori dal foglio: mentre legge il
                    // foglio scorre, e il pulsante per fermarla resta lì.
                    child: Row(
                      children: [
                        TargaIconButton(
                          key: const Key('rules.back'),
                          icon: Icons.arrow_back_rounded,
                          size: desk ? 60 : 44,
                          tooltip: r.back,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        if (canRead)
                          TargaButton(
                            key: const Key('rules.read'),
                            label: _at == null ? r.readToMe : r.stopReading,
                            icon: _at == null ? Icons.record_voice_over_outlined : Icons.stop_rounded,
                            kind: TargaKind.secondary,
                            compact: true,
                            desk: desk,
                            onPressed: _toggleReading,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(side, 18, side, 40 + bottom),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 680 * k),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Notice(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _header(r, k),
                                    const SizedBox(height: 18),
                                    _StyleSwitch(value: _style, label: r.style, scale: k, onChanged: _pick),
                                    const SizedBox(height: 10),
                                    Text(
                                      r.styleHint(_style),
                                      textAlign: TextAlign.center,
                                      style: _serif(15 * k, color: _inkSoft, italic: true),
                                    ),
                                    const SizedBox(height: 8),
                                    const _Rule(),
                                    for (final (i, step) in steps.indexed) _step(i, step, k),
                                    const _Rule(),
                                    _rolesBlock(r, t, k),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              _play(r, k),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    return desk ? DeskEscape(onEscape: () => Navigator.of(context).maybePop(), child: page) : page;
  }

  Widget _header(RulesStrings r, double k) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        color: _red,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, size: 13 * k, color: _paper),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  r.banner.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: _serif(12.5 * k, color: _paper, weight: FontWeight.w700, spacing: 2.4),
                ),
              ),
            ),
            Icon(Icons.star_rounded, size: 13 * k, color: _paper),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        r.title.toUpperCase(),
        textAlign: TextAlign.center,
        style: _serif(31 * k, weight: FontWeight.w900, spacing: 1.2, height: 1.05),
      ),
      const SizedBox(height: 10),
      Text(
        r.pitch,
        textAlign: TextAlign.center,
        style: _serif(17 * k, color: _inkSoft, italic: true, height: 1.35),
      ),
    ],
  );

  Widget _step(int i, RulesStep step, double k) {
    final at = _at;
    Widget beat(int b, RulesBeat beat) {
      final lit = at == (i, b);
      final text = beat.cue
          ? Text('— ${beat.text}', style: _serif(16.5 * k, color: _red, italic: true, height: 1.35))
          : Text(beat.text, style: _serif(20 * k, height: 1.42));
      return _Lit(key: _key((i, b)), lit: lit, child: text);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38 * k,
            child: Text(
              '${i + 1}',
              style: _serif(44 * k, color: _red, weight: FontWeight.w900, height: 0.95),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Lit(
                  key: _key((i, -1)),
                  lit: at == (i, -1),
                  child: Text(
                    step.title.toUpperCase(),
                    style: _serif(19 * k, weight: FontWeight.w800, spacing: 1.4, height: 1.2),
                  ),
                ),
                const SizedBox(height: 6),
                for (final (b, part) in step.beats.indexed)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: beat(b, part)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rolesBlock(RulesStrings r, AppStrings t, double k) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        button: true,
        expanded: _roles,
        child: InkWell(
          key: const Key('rules.roles'),
          onTap: () {
            HapticFeedback.selectionClick();
            SoundStage.instance.press(Press.tap);
            setState(() => _roles = !_roles);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.commonRoles.toUpperCase(), style: _serif(17 * k, weight: FontWeight.w800, spacing: 1.4)),
                      const SizedBox(height: 2),
                      Text(r.commonRolesHint, style: _serif(14.5 * k, color: _inkSoft, italic: true)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _roles ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.expand_more_rounded, color: _red, size: 30),
                ),
              ],
            ),
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !_roles
            ? const SizedBox(width: double.infinity)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final role in RulesStrings.commonRoleList)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: t.role(role).label,
                              style: _serif(17.5 * k, weight: FontWeight.w800),
                            ),
                            TextSpan(
                              text: '  ${r.team(role.team).toUpperCase()}\n',
                              style: _serif(
                                11.5 * k,
                                color: role.team == Team.mafia ? _red : _inkSoft,
                                weight: FontWeight.w700,
                                spacing: 1.6,
                              ),
                            ),
                            TextSpan(
                              text: RulesStrings.oneLine(t.role(role).description),
                              style: _serif(16.5 * k, color: _ink, height: 1.38),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ],
  );

  Widget _play(RulesStrings r, double k) {
    final local = widget.onPlayLocal;
    final friends = widget.onPlayFriends;
    if (local == null && friends == null) return const SizedBox.shrink();
    return Column(
      children: [
        TargaButton(
          key: const Key('rules.play'),
          label: local != null ? r.playLocal : r.playFriends,
          icon: Icons.play_arrow_rounded,
          feel: Press.chips,
          expand: true,
          height: 64 * k,
          onPressed: local ?? friends,
        ),
        const SizedBox(height: 10),
        Text(
          local != null ? r.playLocalHint : r.playFriendsHint,
          textAlign: TextAlign.center,
          style: _serif(15 * k, color: const Color(0xFFBFAF95), italic: true),
        ),
      ],
    );
  }
}

TextStyle _serif(
  double size, {
  Color color = _ink,
  FontWeight weight = FontWeight.w400,
  bool italic = false,
  double spacing = 0,
  double? height,
}) => TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: serifFallback,
  fontSize: size,
  color: color,
  fontWeight: weight,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  letterSpacing: spacing,
  height: height,
);

/// Il foglio affisso: carta color crema, un filetto rosso a un dito dal
/// bordo, due strisce di nastro adesivo in alto.
class _Notice extends StatelessWidget {
  final Widget child;

  const _Notice({required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_paper, _paperShade],
          ),
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: _red.withValues(alpha: 0.85), width: 1.6)),
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 10), child: child),
          ),
        ),
      ),
      for (final (x, turn) in [(-0.92, -0.10), (0.92, 0.09)])
        Positioned.fill(
          top: -12,
          child: Align(
            alignment: Alignment(x, -1),
            child: Transform.rotate(
              angle: turn * 3.14159,
              child: Container(width: 74, height: 24, color: const Color(0xB3D9CCAE)),
            ),
          ),
        ),
    ],
  );
}

/// Un filetto con un rombo in mezzo, tra le parti del foglio.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(child: Container(height: 1.2, color: _ink.withValues(alpha: 0.35))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Transform.rotate(angle: 0.785398, child: Container(width: 7, height: 7, color: _red)),
        ),
        Expanded(child: Container(height: 1.2, color: _ink.withValues(alpha: 0.35))),
      ],
    ),
  );
}

/// La riga che la voce sta leggendo: un colpo di evidenziatore giallo.
class _Lit extends StatelessWidget {
  final bool lit;
  final Widget child;

  const _Lit({super.key, required this.lit, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: lit ? const Color(0x66E8C25A) : const Color(0x00E8C25A),
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
}

/// Le due versioni, come due bottoni di smalto affiancati: quello scelto è
/// rosso, l'altro solo inciso.
class _StyleSwitch extends StatelessWidget {
  final RulesStyle value;
  final String Function(RulesStyle) label;
  final double scale;
  final ValueChanged<RulesStyle> onChanged;

  const _StyleSwitch({required this.value, required this.label, required this.scale, required this.onChanged});

  @override
  Widget build(BuildContext context) => Center(
    // Dove le parole non ci stanno (un telefono stretto, caratteri grandi)
    // l'interruttore si rimpicciolisce tutto insieme.
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(color: _ink, width: 1.6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final style in RulesStyle.values)
              KeyedSubtree(
                child: Semantics(
                  button: true,
                  selected: style == value,
                  child: GestureDetector(
                    key: Key('rules.style.${style.name}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(style),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      constraints: BoxConstraints(minWidth: 112 * scale, minHeight: 42 * scale),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: style == value ? _red : Colors.transparent,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label(style).toUpperCase(),
                          maxLines: 1,
                          style: _serif(
                            14.5 * scale,
                            color: style == value ? _paper : _ink,
                            weight: FontWeight.w800,
                            spacing: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
