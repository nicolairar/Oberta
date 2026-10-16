import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/app_language.dart';
import '../narration/narrator_script.dart';
import '../narration/voice_lines.dart';
import 'sound_stage.dart';

/// Un pezzo di battuta messo in tempo: quando comincia, quanto dura e quale
/// clip suona (nessuna per i nomi, la punteggiatura e quello che manca).
class VoiceStep {
  final int line;
  final int part;
  final Duration start;
  final Duration length;
  final String? asset;

  const VoiceStep({required this.line, required this.part, required this.start, required this.length, this.asset});

  Duration get end => start + length;
}

/// Una pagina di copione messa in tempo, dalla prima clip all'ultima.
class VoicePlan {
  final List<VoiceStep> steps;
  final Duration length;

  const VoicePlan(this.steps, this.length);
}

/// La voce del narratore automatico: clip già incise (vedi `tool/voice/`),
/// una per ogni pezzo fisso del copione, e la loro durata.
///
/// Mette in tempo le battute di una pagina ([plan]); chi le mostra ([say])
/// fa partire ogni clip al suo momento sul lettore del narratore del palco.
/// Una pagina alla volta: chi comincia a parlare ([claim]) zittisce chi
/// parlava prima.
class NarratorVoice {
  /// La voce in uso. Senza indice non ha niente da dire: il copione torna da
  /// leggere ad alta voce. `main` carica quello vero con [load].
  static NarratorVoice instance = NarratorVoice();

  /// Il silenzio dove nella frase c'è il nome di un giocatore: la voce lo
  /// lascia al tavolo, e sullo schermo il nome si accende.
  static const nameGap = Duration(milliseconds: 520);

  /// La pausa tra una battuta e l'altra: lì respirano il sottofondo e gli effetti.
  static const linePause = Duration(milliseconds: 850);

  /// Per una frase che non ha ancora la sua clip: i sottotitoli scorrono lo
  /// stesso, a passo di voce.
  static const perCharacter = Duration(milliseconds: 62);

  final Map<String, Map<String, int>> _index;

  NarratorVoice([Map<String, Map<String, int>> index = const {}]) : _index = index;

  /// L'indice delle clip, `{lingua: {chiave: millisecondi}}`.
  factory NarratorVoice.fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return NarratorVoice({
      for (final entry in data.entries)
        entry.key: {
          for (final clip in (entry.value as Map<String, dynamic>).entries) clip.key: (clip.value as num).toInt(),
        },
    });
  }

  static const indexAsset = 'assets/voice/index.json';

  /// Legge l'indice dalle risorse dell'app. Se non c'è, il narratore resta muto.
  static Future<NarratorVoice> load([AssetBundle? bundle]) async {
    try {
      final data = await (bundle ?? rootBundle).load(indexAsset);
      return NarratorVoice.fromJson(utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
    } catch (error) {
      debugPrint('Voce: $error');
      return NarratorVoice();
    }
  }

  /// Vero se in questa lingua c'è qualcosa di inciso.
  bool speaks(AppLanguage language) => _index[language.name]?.isNotEmpty ?? false;

  /// Quanto dura la clip di [say], se c'è.
  Duration? clip(AppLanguage language, String say) {
    final ms = _index[language.name]?[voiceKey(language.name, say)];
    return ms == null ? null : Duration(milliseconds: ms);
  }

  /// Dove sta la clip di [say], tra le risorse dell'app.
  static String assetFor(AppLanguage language, String say) => 'voice/${language.name}/${voiceKey(language.name, say)}.m4a';

  /// Mette in tempo [lines] a partire da [from], dopo [leadIn] di silenzio.
  /// Le battute senza pezzi (mai incise) scorrono a passo di voce, mute.
  VoicePlan plan(List<ScriptLine> lines, AppLanguage language, {int from = 0, Duration leadIn = Duration.zero}) {
    final steps = <VoiceStep>[];
    var at = leadIn;
    for (var line = from; line < lines.length; line++) {
      if (line > from) at += linePause;
      final parts = lines[line].voice.isEmpty ? [VoicePart.spoken(lines[line].text, say: '')] : lines[line].voice;
      for (var part = 0; part < parts.length; part++) {
        final piece = parts[part];
        final say = piece.say;
        final Duration length;
        String? asset;
        if (piece.isName) {
          length = nameGap;
        } else if (say == null) {
          length = _pauseFor(piece.display, wholeLine: lines[line].voice.isEmpty);
        } else {
          final clip = this.clip(language, say);
          if (clip != null) asset = assetFor(language, say);
          length = clip ?? perCharacter * say.length;
        }
        steps.add(VoiceStep(line: line, part: part, start: at, length: length, asset: asset));
        at += length;
      }
    }
    return VoicePlan(steps, at);
  }

  Duration _pauseFor(String display, {required bool wholeLine}) {
    if (wholeLine) return perCharacter * display.length;
    if (RegExp(r'[.!?…:;]').hasMatch(display)) return const Duration(milliseconds: 260);
    if (display.contains(',')) return const Duration(milliseconds: 140);
    return Duration.zero;
  }

  Object? _owner;
  VoidCallback? _onHush;

  /// [owner] comincia a parlare: chi parlava prima tace, e la musica si
  /// abbassa. [onHush] avvisa [owner] se qualcun altro lo zittisce.
  void claim(Object owner, VoidCallback onHush) {
    if (_owner != owner) hush();
    _owner = owner;
    _onHush = onHush;
    SoundStage.instance.duckForVoice(true);
  }

  /// Una clip, se [owner] ha ancora la parola.
  void say(Object owner, VoiceStep step) {
    final asset = step.asset;
    if (owner != _owner || asset == null) return;
    SoundStage.instance.voice(asset);
  }

  /// [owner] ha finito: la musica torna su. Chi non ha la parola non tocca niente.
  void release(Object owner) {
    if (owner != _owner) return;
    _owner = null;
    _onHush = null;
    SoundStage.instance.duckForVoice(false);
  }

  /// [owner] se ne va a metà: se aveva ancora la parola, la voce tace.
  void drop(Object owner) {
    if (owner == _owner) hush();
  }

  /// Zittisce chiunque stia parlando: si va avanti.
  void hush() {
    final onHush = _onHush;
    final speaking = _owner != null;
    _owner = null;
    _onHush = null;
    if (!speaking) return;
    SoundStage.instance.stopVoice();
    SoundStage.instance.duckForVoice(false);
    onHush?.call();
  }
}
