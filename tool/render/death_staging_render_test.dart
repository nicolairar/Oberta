// I provini della regia: per ogni regia e per quattro coreografie, una
// striscia di quattro fotogrammi chiave sul telefono (390×844); e un
// confronto della stessa coreografia girata con la regia di sempre e con le
// tre nuove.
//
//   OUT=docs/demo/regia flutter test tool/render/death_staging_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/particle_sprites.dart';

final out = Platform.environment['OUT'] ?? 'build/render/regia';

/// I fotogrammi chiave: l'arrivo, l'attesa col nascondiglio che si apre, il
/// colpo, quello che resta.
const _times = [0.16, 0.44, 0.565, 0.72];
const _beats = ['arrivo', 'attesa', 'colpo', 'dopo'];

/// Il portone ha il suo momento un attimo prima del colpo: il primo piano,
/// con la vittima che ha appena alzato le mani.
List<double> _timesOf(Staging staging) =>
    staging.shot == Shot.closeUp ? const [0.16, 0.44, 0.548, 0.72] : _times;

const _acts = {
  'knife': DeathAct.knife,
  'gun': DeathAct.gun,
  'lupara': DeathAct.lupara,
  'car': DeathAct.car,
};

const _phone = Size(390, 844);
const _gap = 14.0;
const _pad = 22.0;
const _gold = Color(0xFFE0B860);

/// I caratteri veri: Georgia per i titoli, e un nero pesante per le
/// scritte da fumetto, che sul telefono usano quello di sistema (nei test
/// sarebbero rettangoli gialli pieni).
Future<void> _loadFonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$dir/$file');
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  await load('Georgia', ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf']);
  await load('Comic', ['Arial Black.ttf']);
  DeathScenePainter.debugComicFont = 'Comic';
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name, {double ratio = 1}) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _frame(DeathAct act, Staging staging, double t, ParticleSprites? sprites) => SizedBox.fromSize(
  size: _phone,
  child: ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        CityBackdrop(style: SkylineStyle.metropolis, rain: true, child: const SizedBox.expand()),
        CustomPaint(
          painter: DeathScenePainter(t: t, act: act, sprites: sprites, staging: staging),
        ),
      ],
    ),
  ),
);

TextStyle _label(double size, {Color color = _gold, FontWeight weight = FontWeight.w700}) =>
    TextStyle(fontFamily: 'Georgia', fontSize: size, color: color, fontWeight: weight, letterSpacing: 0.6);

Widget _row(DeathAct act, Staging staging, ParticleSprites? sprites) => Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < _times.length; i++) ...[
      if (i > 0) const SizedBox(width: _gap),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _frame(act, staging, _timesOf(staging)[i], sprites),
          const SizedBox(height: 8),
          Text(
            '${_beats[i]} · t ${_timesOf(staging)[i].toStringAsFixed(3)}',
            style: _label(17, color: const Color(0xFF9A9384), weight: FontWeight.w400),
          ),
        ],
      ),
    ],
  ],
);

const _stripWidth = _pad * 2 + 4 * 390 + 3 * _gap;
const _rowHeight = 844 + 8 + 24.0;

String _title(Staging staging) => staging.isClassic ? 'Regia attuale' : 'Regia «${staging.name}»';

String _recipe(Staging staging) {
  if (staging.isClassic) return 'lampione a sinistra · killer dietro l\'angolo a destra · sigaretta · cinepresa che stringe';
  return [
    staging.mirrored ? 'scena ribaltata (killer da sinistra)' : 'killer da destra',
    switch (staging.cover) {
      Cover.corner => 'dietro l\'angolo',
      Cover.kiosk => 'dietro l\'edicola',
      Cover.doorway => 'dal portone',
      Cover.shadow => 'già nell\'androne buio',
    },
    switch (staging.business) {
      Business.smoke => 'sigaretta',
      Business.newspaper => 'legge il giornale',
      Business.umbrella => 'sotto l\'ombrello',
      Business.shoelace => 'si allaccia la scarpa',
    },
    switch (staging.shot) {
      Shot.push => 'cinepresa che stringe',
      Shot.low => 'dal basso',
      Shot.wide => 'larga e ferma',
      Shot.closeUp => 'inclinata + primo piano sul colpo',
    },
    if (staging.light == Light.window) 'controluce sulla vetrina',
    if (staging.arrival == Arrival.door) 'esce dal bar',
    if (staging.reaction == Reaction.turns) 'si gira e alza le mani',
  ].join(' · ');
}

void main() {
  testWidgets('provini della regia', (tester) async {
    await tester.runAsync(_loadFonts);
    final sprites = await tester.runAsync(() => ParticleSprites.shared);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    Future<void> shoot(String name, Widget child, Size size, {double ratio = 1}) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: Material(
              color: const Color(0xFF0E0D0C),
              child: Padding(padding: const EdgeInsets.all(_pad), child: child),
            ),
          ),
        ),
      );
      await tester.pump();
      await _capture(tester, key, name, ratio: ratio);
    }

    Widget heading(Staging staging, String act) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_title(staging)} — $act', style: _label(30)),
        const SizedBox(height: 4),
        Text(_recipe(staging), style: _label(17, color: const Color(0xFFBDB5A2), weight: FontWeight.w400)),
        const SizedBox(height: 14),
      ],
    );

    final only = Platform.environment['ONLY'];
    final stagings = {'S0': Staging.classic, 'S1': Staging.kiosk, 'S2': Staging.backlit, 'S3': Staging.doorway};
    for (final MapEntry(key: code, value: staging) in stagings.entries) {
      for (final MapEntry(key: name, value: act) in _acts.entries) {
        if (only != null && !'${code}_$name'.contains(only)) continue;
        await shoot(
          '${code}_$name',
          SizedBox(
            width: _stripWidth - _pad * 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading(staging, name), _row(act, staging, sprites)],
            ),
          ),
          const Size(_stripWidth, _pad * 2 + 88 + _rowHeight),
        );
      }
    }

    if (only != null) return;
    // Il confronto: lo stesso pugnale, girato in quattro modi.
    await shoot(
      'regia_confronto',
      SizedBox(
        width: _stripWidth - _pad * 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final MapEntry(key: code, value: staging) in stagings.entries) ...[
              if (code != 'S0') const SizedBox(height: 26),
              Text(code == 'S0' ? 'Attuale — com\'è oggi' : '$code — «${staging.name}»', style: _label(30)),
              const SizedBox(height: 4),
              Text(_recipe(staging), style: _label(17, color: const Color(0xFFBDB5A2), weight: FontWeight.w400)),
              const SizedBox(height: 12),
              _row(DeathAct.knife, staging, sprites),
            ],
          ],
        ),
      ),
      Size(_stripWidth, _pad * 2 + 4 * (_rowHeight + 92) + 3 * 26),
      ratio: 0.6,
    );
  });
}
