import 'speed_filter.dart';

/// Fuses raw GNSS ground speed into a clean instrument reading.
///
/// Wraps [SpeedFilter] with an asymmetric-hysteresis stationary gate:
/// receivers never report exactly 0 while parked (Doppler noise,
/// multipath), so small readings must be actively squashed — while real
/// slow motion must still register.
///
/// Wake ("go") requires sustained samples above [goThresholdMps] and is
/// deliberately conservative; sleep ("stop") triggers quickly below
/// [stopThresholdMps]. While parked the estimate is pinned to exactly 0
/// and the inner filter is reset, so no noise or drift leaks through.
class GroundSpeedEstimator {
  GroundSpeedEstimator({
    this.stopThresholdMps = 0.25,
    this.goThresholdMps = 0.55,
    int stopStreakSamples = 2,
    int goStreakSamples = 3,
    SpeedFilter? filter,
  })  : _stopStreakNeeded = stopStreakSamples,
        _goStreakNeeded = goStreakSamples,
        _filter = filter ??
            SpeedFilter(accelNoiseStd: 0.9, minSpeedAccuracy: 0.8);

  /// Below this raw speed (m/s) a sample counts toward parking.
  final double stopThresholdMps;

  /// Above this raw speed (m/s) a sample counts toward waking.
  final double goThresholdMps;

  final int _stopStreakNeeded;
  final int _goStreakNeeded;
  final SpeedFilter _filter;

  bool _moving = false;
  int _streak = 0;

  /// Whether the estimator currently believes the device is in motion.
  bool get isMoving => _moving;

  /// Filtered speed, m/s. Exactly `0` while parked.
  double get value => _moving ? _filter.value : 0;

  void reset() {
    _moving = false;
    _streak = 0;
    _filter.reset();
  }

  /// Feeds one usable raw sample (m/s) and returns the smoothed reading.
  ///
  /// Invalid inputs return the current estimate unchanged.
  double update({
    required double rawSpeed,
    required double speedAccuracy,
    required DateTime at,
  }) {
    if (rawSpeed.isNaN || speedAccuracy.isNaN) return value;
    if (rawSpeed < 0 || speedAccuracy < 0) return value;

    if (!_moving) {
      if (rawSpeed >= goThresholdMps) {
        _streak++;
        if (_streak >= _goStreakNeeded) {
          _wake(at: at, rawSpeed: rawSpeed, speedAccuracy: speedAccuracy);
          return value;
        }
      } else {
        _streak = 0;
      }
      return 0;
    }

    if (rawSpeed <= stopThresholdMps) {
      _streak++;
      if (_streak >= _stopStreakNeeded) {
        _park();
        return 0;
      }
    } else {
      _streak = 0;
    }

    final filtered =
        _filter.update(rawSpeed: rawSpeed, speedAccuracy: speedAccuracy, at: at);
    return filtered ?? value;
  }

  void _park() {
    _moving = false;
    _streak = 0;
    _filter.reset();
  }

  void _wake({
    required DateTime at,
    required double rawSpeed,
    required double speedAccuracy,
  }) {
    _moving = true;
    _streak = 0;
    // Filter was reset on park, so the first update snaps straight to the
    // live sample — no stale ramp-up from zero.
    _filter.update(
      rawSpeed: rawSpeed,
      speedAccuracy: speedAccuracy,
      at: at,
    );
  }
}
