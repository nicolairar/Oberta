// Il cronometro dei fotogrammi: quanto costa un fotogramma, fermo e durante
// le animazioni, schermata per schermata. Vedi frame_cost_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/baked.dart';

/// 120 Hz: il passo di un fotogramma su ProMotion.
const frame = Duration(microseconds: 8333);

/// The two screens of the pass: an iPhone 15/16 and a 1080p desktop window.
const phone = (name: 'phone', size: Size(393, 852), ratio: 3.0, top: 59.0, bottom: 34.0);
const desktop = (name: 'desktop', size: Size(1920, 1080), ratio: 1.0, top: 0.0, bottom: 0.0);

typedef Screen = ({String name, Size size, double ratio, double top, double bottom});

void useScreen(WidgetTester tester, Screen s) {
  tester.view.physicalSize = s.size * s.ratio;
  tester.view.devicePixelRatio = s.ratio;
  tester.view.padding = FakeViewPadding(top: s.top * s.ratio, bottom: s.bottom * s.ratio);
  addTearDown(tester.view.reset);
  // PERF_STILL=1: everything stands still (reduced motion), so the frames
  // saved with PERF_SHOTS can be compared pixel by pixel before and after.
  if (Platform.environment['PERF_STILL'] != null) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
}

/// The Mac's Georgia for every family the app asks for, so text costs what it
/// costs on the phone (the test font draws boxes).
Future<void> loadFonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  for (final (family, files) in [
    ('Georgia', ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf']),
    ('serif', ['Georgia.ttf', 'Georgia Bold.ttf']),
    ('Courier', ['Courier New.ttf', 'Courier New Bold.ttf']),
    ('Roboto', ['Georgia.ttf', 'Georgia Bold.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$dir/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
  final material = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}/bin/cache/artifacts/material_fonts';
  final icons = File('$material/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

class Scenario {
  final String name;
  final List<double> ui = [];
  final List<double> raster = [];
  int frames = 0;
  int rebuilds = 0;
  int paints = 0;
  int pictures = 0;
  int bakes = 0;
  int layers = 0;
  int effects = 0;
  int rasterFrames = 0;

  Scenario(this.name);

  static double _pct(List<double> v, double p) {
    if (v.isEmpty) return 0;
    final s = [...v]..sort();
    return s[min(s.length - 1, (p * s.length).floor())];
  }

  double get ui50 => _pct(ui, 0.5);
  double get ui90 => _pct(ui, 0.9);
  double get raster50 => _pct(raster, 0.5);
  double get raster90 => _pct(raster, 0.9);

  Map<String, Object> toJson() => {
    'ui50': ui50,
    'ui90': ui90,
    'raster50': raster50,
    'raster90': raster90,
    'rebuilds': rebuilds / max(frames, 1),
    'paints': paints / max(frames, 1),
    'pictures': pictures / max(frames, 1),
    'bakes': bakes / max(frames, 1),
    'layers': layers / max(rasterFrames, 1),
    'effects': effects / max(rasterFrames, 1),
  };

  String row() {
    String f(double v) => v.toStringAsFixed(2).padLeft(7);
    String c(int v, int n) => (v / max(n, 1)).toStringAsFixed(1).padLeft(7);
    return '${name.padRight(34)}${f(ui50)}${f(ui90)}${f(raster50)}${f(raster90)}'
        '${c(rebuilds, frames)}${c(paints, frames)}${c(pictures, frames)}${c(bakes, frames)}'
        '${c(layers, rasterFrames)}${c(effects, rasterFrames)}';
  }

  static const header =
      'scenario                            ui50   ui90  ras50  ras90  build  paint   pict   bake layers    fx';
}

final List<Scenario> results = [];

/// The pictures of the last frame: a picture not among them was recorded
/// again this frame.
Set<ui.Picture> _lastPictures = {};

ContainerLayer get _root => RendererBinding.instance.renderViews.first.debugLayer!;

void _walk(Layer layer, void Function(Layer) visit) {
  visit(layer);
  if (layer is ContainerLayer) {
    for (var child = layer.firstChild; child != null; child = child.nextSibling) {
      _walk(child, visit);
    }
  }
}

/// Layers that make the GPU set an offscreen pass (a saveLayer) or a filter.
bool _effect(Layer layer) =>
    layer is ImageFilterLayer ||
    layer is BackdropFilterLayer ||
    layer is ShaderMaskLayer ||
    layer is ColorFilterLayer ||
    (layer is OpacityLayer && (layer.alpha ?? 255) < 255 && (layer.alpha ?? 255) > 0);

double? _emptyRaster;

/// Rasterises the whole frame on the test engine and reads it back: the
/// readback of an empty frame of the same size is taken off.
Future<double> _rasterise(WidgetTester tester) async {
  final size = tester.view.physicalSize;
  Future<double> time(Layer Function() make) async {
    final watch = Stopwatch();
    await tester.runAsync(() async {
      final layer = make() as OffsetLayer;
      watch.start();
      final image = layer.toImageSync(Offset.zero & size);
      await image.toByteData();
      watch.stop();
      image.dispose();
    });
    return watch.elapsedMicroseconds / 1000;
  }

  if (_emptyRaster == null) {
    final samples = [for (var i = 0; i < 5; i++) await time(OffsetLayer.new)]..sort();
    _emptyRaster = samples[2];
  }
  return max(0, await time(() => _root) - _emptyRaster!);
}

/// Pumps [frames] frames of 8.3 ms, calling [step] before each one, and adds
/// the costs to the table: ui is the framework's work for the frame (build,
/// layout, paint, compositing) on this machine in the test's debug JIT;
/// raster is the test engine drawing that frame on the CPU, every
/// [rasterEvery] frames.
Future<Scenario> measureFrames(
  WidgetTester tester,
  String name, {
  int frames = 48,
  Future<void> Function(int i)? step,
  int rasterEvery = 4,
}) async {
  final s = Scenario(name);
  // The first frame catches up with whatever came before.
  await tester.pump(frame);
  _lastPictures = _pictures();
  var rebuilds = 0, paints = 0;
  debugOnRebuildDirtyWidget = (_, _) => rebuilds++;
  debugOnProfilePaint = (_) => paints++;
  try {
    for (var i = 0; i < frames; i++) {
      await step?.call(i);
      rebuilds = 0;
      paints = 0;
      final bakes = RenderBaked.debugBakes;
      final watch = Stopwatch()..start();
      await tester.pump(frame);
      watch.stop();
      s.ui.add(watch.elapsedMicroseconds / 1000);
      s.frames++;
      s.rebuilds += rebuilds;
      s.paints += paints;
      s.bakes += RenderBaked.debugBakes - bakes;
      final now = _pictures();
      s.pictures += now.difference(_lastPictures).length;
      _lastPictures = now;
      if (i % rasterEvery == rasterEvery - 1) {
        var layers = 0, effects = 0;
        _walk(_root, (l) {
          layers++;
          if (_effect(l)) effects++;
        });
        s.layers += layers;
        s.effects += effects;
        s.rasterFrames++;
        s.raster.add(await _rasterise(tester));
      }
    }
  } finally {
    debugOnRebuildDirtyWidget = null;
    debugOnProfilePaint = null;
  }
  results.add(s);
  debugPrint(s.row());
  await dig(tester, name);
  return s;
}

Set<ui.Picture> _pictures() {
  final out = <ui.Picture>{};
  _walk(_root, (l) {
    if (l is PictureLayer && l.picture != null) out.add(l.picture!);
  });
  return out;
}

/// Writes the table to build/perf/[label].json and prints it.
void report(String label) {
  debugPrint('\n${Scenario.header}');
  for (final s in results) {
    debugPrint(s.row());
  }
  final file = File('build/perf/$label.json')..createSync(recursive: true);
  final old = file.existsSync() && file.lengthSync() > 0
      ? (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)
      : <String, Object?>{};
  file.writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({...old, for (final s in results) s.name: s.toJson()}),
  );
}

/// Saves the frame on screen as a PNG, for the before/after comparison.
Future<void> snapshotFrame(WidgetTester tester, String name) async {
  final dir = Platform.environment['PERF_SHOTS'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final image = _root is OffsetLayer
        ? (_root as OffsetLayer).toImageSync(Offset.zero & tester.view.physicalSize)
        : throw StateError('root');
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

String _owner(Layer layer) {
  for (Layer? l = layer; l != null; l = l.parent) {
    final creator = l.debugCreator;
    if (creator is RenderObject && creator.debugCreator != null) {
      final element = creator.debugCreator.toString();
      return element.length > 100 ? element.substring(0, 100) : element;
    }
    if (creator != null) return creator.toString();
  }
  return '?';
}

/// DIG=1: the pictures of the frame on screen that cost the most to draw,
/// with the widget that painted them.
Future<void> dig(WidgetTester tester, String name) async {
  if (Platform.environment['DIG'] == null) return;
  final ratio = tester.view.devicePixelRatio;
  final size = tester.view.physicalSize;
  final costs = <(double, String, int)>[];
  final pictures = <PictureLayer>[];
  _walk(_root, (l) {
    if (l is PictureLayer && l.picture != null) pictures.add(l);
  });
  for (final layer in pictures) {
    final watch = Stopwatch();
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..scale(ratio)
        ..drawPicture(layer.picture!);
      final picture = recorder.endRecording();
      watch.start();
      final image = picture.toImageSync(size.width.ceil(), size.height.ceil());
      await image.toByteData();
      watch.stop();
      image.dispose();
      picture.dispose();
    });
    costs.add((watch.elapsedMicroseconds / 1000 - (_emptyRaster ?? 0), _owner(layer), layer.picture!.approximateBytesUsed));
  }
  // Who repaints in one more frame, by repaint boundary.
  final painted = <RenderObject, int>{};
  debugOnProfilePaint = (o) {
    RenderObject? b = o;
    while (b != null && !b.isRepaintBoundary) {
      b = b.parent;
    }
    if (b != null) painted[b] = (painted[b] ?? 0) + 1;
  };
  final rebuilt = <String, int>{};
  final dirty = <String>[];
  debugOnRebuildDirtyWidget = (e, builtOnce) {
    final k = e.widget.runtimeType.toString();
    rebuilt[k] = (rebuilt[k] ?? 0) + 1;
    if (dirty.length < 8) {
      final chain = e.debugGetCreatorChain(7);
      dirty.add(chain.length > 160 ? chain.substring(0, 160) : chain);
    }
  };
  await tester.pump(frame);
  debugOnProfilePaint = null;
  debugOnRebuildDirtyWidget = null;
  // Who asks for paint: the first app frames of each markNeedsPaint stack.
  final print = debugPrint;
  final asked = <String, int>{};
  var current = <String>[];
  final raw = <String>[];
  debugPrint = (String? message, {int? wrapWidth}) {
    for (final line in (message ?? '').split('\n')) {
      if (raw.length < 400) raw.add(line);
      if (line.contains('markNeedsPaint')) current = [];
      if (line.contains('package:oberta/') && current.length < 2) {
        current.add(line.replaceAll(RegExp(r'^#\d+\s+'), '').trim());
        if (current.length == 2 || line.contains('ui/')) {
          final k = current.join(' < ');
          asked[k] = (asked[k] ?? 0) + 1;
        }
      }
    }
  };
  debugPrintMarkNeedsPaintStacks = true;
  await tester.pump(frame);
  debugPrintMarkNeedsPaintStacks = false;
  debugPrint = print;
  if (Platform.environment['DIG'] == 'raw') {
    final f = File('build/perf/raw_${name.replaceAll(' ', '_')}.txt')..createSync(recursive: true);
    f.writeAsStringSync(raw.join('\n'));
  }
  final ids = {for (final m in RegExp(r'markNeedsPaint\(\) called for (\S+)').allMatches(raw.join('\n'))) m.group(1)!};
  void visit(RenderObject o) {
    if (ids.contains(describeIdentity(o))) {
      final c = o.debugCreator.toString();
      final stack = raw.indexWhere((l) => l.contains(describeIdentity(o)));
      final cause = stack < 0 ? '' : raw.skip(stack + 2).take(14).map((l) => l.replaceAll(RegExp(r'^#\d+\s+'), '').split(' (').first).where((l) => !l.contains('markNeedsPaint')).take(5).join(' < ');
      debugPrint('  marks ${describeIdentity(o)} ${c.length > 140 ? c.substring(0, 140) : c}\n        by $cause');
    }
    o.visitChildren(visit);
  }

  visit(RendererBinding.instance.renderViews.first);
  for (final e in (asked.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(6)) {
    final k = e.key;
    debugPrint('  asks ${e.value}  ${k.length > 200 ? k.substring(0, 200) : k}');
  }
  final byCount = painted.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in byCount.take(6)) {
    final c = e.key.debugCreator.toString();
    debugPrint('  repaint ${e.value.toString().padLeft(4)}  ${c.length > 110 ? c.substring(0, 110) : c}');
  }
  final rb = rebuilt.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  if (rb.isNotEmpty) debugPrint('  rebuilt ${rb.take(8).map((e) => '${e.key}×${e.value}').join(', ')}');
  for (final d in dirty) {
    debugPrint('  dirty $d');
  }
  costs.sort((a, b) => b.$1.compareTo(a.$1));
  debugPrint('--- $name: ${pictures.length} pictures');
  for (final (ms, owner, bytes) in costs.take(8)) {
    debugPrint('${ms.toStringAsFixed(1).padLeft(7)} ms ${(bytes ~/ 1024).toString().padLeft(6)} KB  $owner');
  }
}
