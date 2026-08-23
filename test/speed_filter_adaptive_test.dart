import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:groundspeed/data/speed_filter.dart';

void main() {
  final t0 = DateTime(2026, 8, 23);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  const jitter = [0.8, -0.6, 1.1, -1.2, 0.4, -0.2, 0.9, -0.7];

  double std(List<double> xs) {
    final mean = xs.reduce((a, b) => a + b) / xs.length;
    final variance = xs
            .map((x) => (x - mean) * (x - mean))
            .reduce((a, b) => a + b) /
        xs.length;
    return math.sqrt(variance);
  }

  test('converges on a constant-speed cruise', () {
    final filter = SpeedFilter(accelNoiseStd: 0.9, minSpeedAccuracy: 0.8);
    for (var i = 0; i < 40; i++) {
      filter.update(
        rawSpeed: 10 + jitter[i % jitter.length],
        speedAccuracy: 0.5,
        at: at(i),
      );
    }
    expect((filter.value - 10).abs(), lessThan(0.5));
  });

  test('smooths receiver jitter while cruising', () {
    final filter = SpeedFilter(accelNoiseStd: 0.9, minSpeedAccuracy: 0.8);
    final outputs = <double>[];
    for (var i = 0; i < 60; i++) {
      final out = filter.update(
        rawSpeed: 12 + jitter[i % jitter.length],
        speedAccuracy: 0.5,
        at: at(i),
      );
      if (i >= 30 && out != null) outputs.add(out);
    }
    expect(
      std(outputs),
      lessThan(0.45),
      reason: 'filtered output should be calmer than the ±~1 m/s input',
    );
  });

  test('adaptive gain catches up after hard acceleration', () {
    final filter = SpeedFilter(accelNoiseStd: 0.9, minSpeedAccuracy: 0.8);
    var i = 0;
    for (; i < 25; i++) {
      filter.update(rawSpeed: 10, speedAccuracy: 0.5, at: at(i));
    }
    for (; i < 60; i++) {
      filter.update(
        rawSpeed: 16 + jitter[i % jitter.length] * 0.5,
        speedAccuracy: 0.5,
        at: at(i),
      );
    }
    expect(
      (filter.value - 16).abs(),
      lessThan(0.75),
      reason: 'innovation-adaptive Q must close a step change quickly',
    );
  });
}
