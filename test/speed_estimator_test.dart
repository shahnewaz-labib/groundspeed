import 'package:flutter_test/flutter_test.dart';
import 'package:groundspeed/data/ground_speed_estimator.dart';

void main() {
  final t0 = DateTime(2026, 8, 23);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  test('parks at exactly zero under stationary jitter', () {
    final est = GroundSpeedEstimator();
    // Typical parked receiver noise, m/s.
    const jitter = [0.08, 0.31, 0.14, 0.42, 0.05, 0.27, 0.19, 0.5, 0.11, 0.33];
    for (var i = 0; i < jitter.length; i++) {
      final v = est.update(
        rawSpeed: jitter[i],
        speedAccuracy: 0.4,
        at: at(i),
      );
      expect(v, 0, reason: 'sample $i (${jitter[i]}) should read as 0');
    }
    expect(est.isMoving, isFalse);
  });

  test('single spikes while parked do not wake the estimator', () {
    final est = GroundSpeedEstimator();
    const samples = [0.1, 1.2, 0.15, 0.2, 0.9, 0.12, 0.18];
    for (var i = 0; i < samples.length; i++) {
      final v = est.update(
        rawSpeed: samples[i],
        speedAccuracy: 0.4,
        at: at(i),
      );
      expect(v, 0, reason: 'spike ${samples[i]} must be gated');
    }
    expect(est.isMoving, isFalse);
  });

  test('wakes after sustained motion above threshold', () {
    final est = GroundSpeedEstimator();
    // Two sub-threshold warmups, then sustained walking pace.
    const samples = [0.3, 0.45, 0.9, 1.1, 1.3, 1.4];
    double v = 0;
    for (var i = 0; i < samples.length; i++) {
      v = est.update(rawSpeed: samples[i], speedAccuracy: 0.4, at: at(i));
    }
    expect(est.isMoving, isTrue);
    expect(v, greaterThan(0.8), reason: 'estimate should track live speed');
  });

  test('parks again shortly after stopping', () {
    final est = GroundSpeedEstimator();
    const walk = [0.6, 0.9, 1.2, 1.3, 1.4];
    for (var i = 0; i < walk.length; i++) {
      est.update(rawSpeed: walk[i], speedAccuracy: 0.4, at: at(i));
    }
    expect(est.isMoving, isTrue);

    // Come to a halt: two low samples are enough to sleep.
    const halt = [0.15, 0.05, 0.02];
    double v = 1;
    for (var i = 0; i < halt.length; i++) {
      v = est.update(
        rawSpeed: halt[i],
        speedAccuracy: 0.4,
        at: at(10 + i),
      );
    }
    expect(est.isMoving, isFalse);
    expect(v, 0);
  });

  test('reset returns to parked state', () {
    final est = GroundSpeedEstimator();
    for (var i = 0; i < 5; i++) {
      est.update(rawSpeed: 3 + i * 0.1, speedAccuracy: 0.4, at: at(i));
    }
    est.reset();
    expect(est.isMoving, isFalse);
    expect(est.value, 0);
  });
}
