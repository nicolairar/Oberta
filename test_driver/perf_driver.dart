// Il driver di integration_test/perf_test.dart: dalle tracce di ogni
// scenario tiene i tempi di build e raster e li scrive in
// build/perf/profile_$PERF_LABEL.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 40),
  // A scenario that times out must not throw away the others' numbers.
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    if (data == null) return;
    final label = Platform.environment['PERF_LABEL'] ?? 'latest';
    final out = <String, Object?>{};
    for (final MapEntry(:key, :value) in data.entries) {
      if (value is! Map<String, dynamic>) continue;
      // PERF_RAW=1: the whole trace too, for chrome://tracing or a script.
      if (Platform.environment['PERF_RAW'] != null) {
        File('build/perf/timeline_${label}_${key.replaceAll(' ', '_')}.json')
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(value));
      }
      final summary = TimelineSummary.summarize(Timeline.fromJson(value)).summaryJson;
      out[key] = {
        for (final k in [
          'average_frame_build_time_millis',
          '90th_percentile_frame_build_time_millis',
          '99th_percentile_frame_build_time_millis',
          'worst_frame_build_time_millis',
          'average_frame_rasterizer_time_millis',
          '90th_percentile_frame_rasterizer_time_millis',
          '99th_percentile_frame_rasterizer_time_millis',
          'worst_frame_rasterizer_time_millis',
          'frame_count',
          'frame_rasterizer_count',
          'missed_frame_build_budget_count',
          'missed_frame_rasterizer_budget_count',
        ])
          k: summary[k],
      };
      stdout.writeln(
        '${key.padRight(34)} build ${_ms(summary['average_frame_build_time_millis'])}'
        ' p90 ${_ms(summary['90th_percentile_frame_build_time_millis'])}'
        '  raster ${_ms(summary['average_frame_rasterizer_time_millis'])}'
        ' p90 ${_ms(summary['90th_percentile_frame_rasterizer_time_millis'])}'
        '  frames ${summary['frame_count']}',
      );
    }
    // Added to what earlier runs with the same label measured.
    final file = File('build/perf/profile_$label.json');
    final old = file.existsSync() ? jsonDecode(file.readAsStringSync()) as Map<String, Object?> : <String, Object?>{};
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert({...old, ...out}));
  },
);

String _ms(Object? v) => v is num ? v.toStringAsFixed(2).padLeft(6) : '     -';
