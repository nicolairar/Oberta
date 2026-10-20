import 'dart:ui' show Size;

/// Come sta la finestra del gioco su desktop.
enum DesktopWindowMode {
  /// Una finestra normale, della risoluzione scelta.
  windowed,

  /// Schermo intero vero (lo spazio a sé su macOS).
  fullscreen,

  /// Una finestra senza bordi grande quanto lo schermo.
  borderless,
}

/// Orizzontale: due colonne, tavolo e pannello ruoli. Verticale: il layout
/// del telefono, in un riquadro 9:16 al centro.
enum DesktopOrientation { landscape, portrait }

/// Le risoluzioni della lista fissa (docs/steam.md, 1.2): tutte 16:9.
abstract final class DesktopResolutions {
  static const all = [Size(1280, 720), Size(1600, 900), Size(1920, 1080), Size(2560, 1440)];

  static const fallback = Size(1280, 720);

  static String label(Size size) => '${size.width.round()}×${size.height.round()}';

  static Size? parse(String? text) {
    for (final size in all) {
      if (label(size) == text) return size;
    }
    return null;
  }
}
