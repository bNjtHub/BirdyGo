import 'package:birdnet_live/fork/live/inference_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('percentile, nearest rank', () {
    final values = [for (var i = 1; i <= 20; i++) i * 10];
    expect(percentile(values, 0.5), 100);
    expect(percentile(values, 0.95), 190);
    expect(percentile(const [], 0.5), 0);
    expect(percentile(const [7], 0.95), 7);
  });

  test('logs p50 and p95 every batch, then starts over', () {
    final lines = <String>[];
    final timing = InferenceTiming(cycles: 4, log: lines.add);
    for (final ms in [100, 400, 200, 300]) {
      timing.add(
        Duration(milliseconds: ms),
        delay: Duration(milliseconds: ms + 1000),
      );
    }
    expect(lines, hasLength(1));
    expect(lines.single, contains('analysis p50=200 ms p95=400 ms'));
    expect(lines.single, contains('display p50=1200 ms p95=1400 ms'));
    expect(timing.inferMs, isEmpty);

    timing.add(const Duration(milliseconds: 50), delay: Duration.zero);
    expect(lines, hasLength(1));
    expect(timing.inferMs, [50]);
  });

  testWidgets('record measures the delay after the next frame', (tester) async {
    final timing = InferenceTiming(cycles: 100, log: (_) {});
    final windowEnd = DateTime.now().subtract(const Duration(seconds: 1));
    timing.record(const Duration(milliseconds: 300), windowEnd: windowEnd);
    expect(timing.inferMs, isEmpty);
    await tester.pump();
    expect(timing.inferMs, [300]);
    expect(timing.delayMs.single, greaterThanOrEqualTo(1000));
  });
}
