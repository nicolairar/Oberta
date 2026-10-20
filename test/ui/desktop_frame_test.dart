import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';

void main() {
  test('gli ultrawide giocano a 16:9 col letterbox', () {
    expect(DesktopFrame.frameFor(const Size(2560, 1080), DesktopOrientation.landscape), const Size(1920, 1080));
    expect(DesktopFrame.frameFor(const Size(1600, 900), DesktopOrientation.landscape), const Size(1600, 900));
    expect(DesktopFrame.frameFor(const Size(1600, 900), DesktopOrientation.portrait).aspectRatio, closeTo(9 / 16, 1e-9));
  });

  test('lo schermo si ricorda per dispositivo', () {
    final store = MemorySettingsStore();
    AppSettings(store)
      ..windowMode = DesktopWindowMode.borderless
      ..resolution = const Size(1920, 1080)
      ..orientation = DesktopOrientation.portrait;
    final again = AppSettings(store);
    expect(again.windowMode, DesktopWindowMode.borderless);
    expect(again.resolution, const Size(1920, 1080));
    expect(again.orientation, DesktopOrientation.portrait);
    again.resolution = const Size(1000, 1000);
    expect(again.resolution, const Size(1920, 1080));
  });
}
