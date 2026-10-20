import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../settings/app_settings.dart';
import '../../settings/display_settings.dart';

/// Il riquadro del gioco su desktop: il rettangolo 16:9 (o 9:16 in
/// verticale) più grande che sta nella finestra, al centro. Il resto è
/// letterbox noir: un ultrawide gioca a 16:9, niente layout stirati.
class DesktopFrame extends StatelessWidget {
  final DesktopOrientation orientation;
  final Widget child;

  const DesktopFrame({super.key, required this.orientation, required this.child});

  static const letterbox = Color(0xFF030305);

  /// Il riquadro dentro uno schermo di queste misure.
  static Size frameFor(Size screen, DesktopOrientation orientation) {
    final aspect = orientation == DesktopOrientation.landscape ? 16 / 9 : 9 / 16;
    if (screen.isEmpty) return screen;
    final width = screen.width / screen.height > aspect ? screen.height * aspect : screen.width;
    return Size(width, width / aspect);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final frame = frameFor(media.size, orientation);
    return ColoredBox(
      color: letterbox,
      child: Center(
        child: SizedBox.fromSize(
          size: frame,
          child: ClipRect(
            child: MediaQuery(
              data: media.copyWith(
                size: frame,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// La finestra vera, con `window_manager`: si apre come dicono le
/// impostazioni e si rimette a posto quando cambiano.
class DesktopWindow {
  final AppSettings settings;
  DesktopWindowMode? _applied;
  Size? _appliedSize;

  DesktopWindow._(this.settings);

  static Future<DesktopWindow> open(AppSettings settings) async {
    await windowManager.ensureInitialized();
    final window = DesktopWindow._(settings);
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        title: 'Obertà',
        size: settings.resolution,
        minimumSize: const Size(960, 540),
        center: true,
        backgroundColor: DesktopFrame.letterbox,
      ),
      () async {
        await window._apply();
        await windowManager.show();
        await windowManager.focus();
      },
    );
    settings.addListener(window._apply);
    return window;
  }

  Future<void> _apply() async {
    final mode = settings.windowMode;
    final size = settings.resolution;
    if (mode == _applied && (mode != DesktopWindowMode.windowed || size == _appliedSize)) return;
    final previous = _applied;
    _applied = mode;
    _appliedSize = size;
    try {
      switch (mode) {
        case DesktopWindowMode.fullscreen:
          if (previous == DesktopWindowMode.borderless) await _leaveBorderless();
          await windowManager.setFullScreen(true);
        case DesktopWindowMode.borderless:
          if (await windowManager.isFullScreen()) await windowManager.setFullScreen(false);
          await windowManager.setAsFrameless();
          await windowManager.maximize();
        case DesktopWindowMode.windowed:
          if (await windowManager.isFullScreen()) await windowManager.setFullScreen(false);
          if (previous == DesktopWindowMode.borderless) await _leaveBorderless();
          await windowManager.setSize(size);
          await windowManager.center();
      }
    } catch (error) {
      debugPrint('Finestra: $error');
    }
  }

  Future<void> _leaveBorderless() async {
    await windowManager.unmaximize();
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
  }
}
