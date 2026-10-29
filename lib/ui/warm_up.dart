import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'avatar/avatar_look.dart';
import 'avatar/look_painter.dart';
import 'street/street_facade.dart';
import 'street/street_section.dart';
import 'street/street_wall.dart';
import 'widgets/death_scene.dart';
import 'widgets/home_alley.dart';
import 'widgets/particle_sprites.dart';
import 'widgets/player_avatar.dart';

/// Il riscaldamento all'avvio, come nei giochi: mentre si apre il vicolo, in
/// un angolo che nessuno vede si disegna una volta un po' di tutto (i
/// mattoni, una facciata, i ritratti con le scene e gli effetti della
/// bottega, qualche fotogramma dei film) e si caricano le scintille dei film. Così la prima volta che queste cose
/// compaiono davvero il motore ha già pronti i suoi programmi e i caratteri,
/// e il primo fotogramma non si inceppa. Dura una frazione di secondo e non
/// blocca niente: si fa un pezzo per fotogramma, dopo il primo.
abstract final class WarmUp {
  static bool _done = false;

  static void start() {
    if (_done) return;
    _done = true;
    unawaited(_run());
  }

  static Future<void> _run() async {
    // Le scintille dei film si decodificano una volta sola.
    final sprites = await ParticleSprites.shared.then<ParticleSprites?>((s) => s, onError: (_) => null);
    const size = Size(480, 270);
    final steps = <void Function(Canvas)>[
      (c) {
        final layout = HomeAlleyLayout(size, EdgeInsets.zero);
        StreetWallPainter(wall: layout.wall, index: 0, lights: layout.lights).paint(c, size);
        HomeWallPainter(layout, plaque: 'VICOLO', signIn: false).paint(c, size);
      },
      (c) => StreetFacadePainter(
        layout: StreetFacadeLayout(size, EdgeInsets.zero, desk: true),
        section: StreetSection.shop,
        open: 0.5,
      ).paint(c, size),
      (c) => AvatarBustPainter(AvatarLook.of('warm'), faded: true).paint(c, const Size.square(96)),
      // I pezzi cari della bottega, uno per scena: le sfumature, gli aloni
      // e gli effetti davanti e dietro che si vedono al tavolo e in vetrina.
      for (var i = 1; i < Aura.values.length; i++)
        (c) => LookPainter.bust(
          c,
          AvatarLook.of('warm').copyWith(
            aura: Aura.values[i],
            back: BackItem.values[i % BackItem.values.length],
            headFx: HeadFx.values[i % HeadFx.values.length],
            eyeShine: EyeShine.values[i % EyeShine.values.length],
            heldR: HeldItem.values[i % HeldItem.values.length],
            frontFx: FrontFx.values[i % FrontFx.values.length],
          ),
          96,
        ),
      for (final act in const [DeathAct.knife, DeathAct.gun, DeathAct.grab, DeathAct.blast])
        for (final t in const [0.2, 0.56, 0.62, 0.95])
          (c) => DeathScenePainter(t: t, act: act, sprites: sprites).paint(c, size),
      (c) => DeathScenePainter(t: 0.7, act: DeathAct.knife, save: DeathAct.rescue, sprites: sprites).paint(c, size),
    ];
    for (final step in steps) {
      await _nextFrame();
      try {
        final recorder = ui.PictureRecorder();
        step(Canvas(recorder));
        final picture = recorder.endRecording();
        final image = picture.toImageSync(size.width.toInt(), size.height.toInt());
        picture.dispose();
        // L'immagine si butta appena il motore l'ha disegnata.
        unawaited(image.toByteData().whenComplete(image.dispose));
      } catch (error) {
        debugPrint('Riscaldamento: $error');
      }
    }
  }

  static Future<void> _nextFrame() {
    final done = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => done.complete());
    WidgetsBinding.instance.scheduleFrame();
    return done.future;
  }
}
