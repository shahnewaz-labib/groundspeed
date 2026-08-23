import 'dart:math' as math;

/// Scalar Kalman filter tuned for GNSS ground speed.
///
/// Model: random-acceleration random walk. The process noise grows with the
/// square of the sample interval scaled by an assumed acceleration jitter,
/// and the measurement noise comes from the receiver-reported speed accuracy
/// (floored so overconfident chips can't slam the estimate around).
class SpeedFilter {
  SpeedFilter({
    this.accelNoiseStd = 1.4,
    this.minSpeedAccuracy = 0.6,
    this.maxSpeedAccuracy = 12.0,
  });

  /// Assumed receiver acceleration jitter, m/s².
  final double accelNoiseStd;

  /// Floor applied to reported speed accuracy, m/s.
  final double minSpeedAccuracy;

  /// Ceiling applied to reported speed accuracy, m/s.
  final double maxSpeedAccuracy;

  double _state = 0;
  double _variance = 1e9;
  DateTime? _lastAt;
  bool _primed = false;

  /// Whether at least one sample has been fused.
  bool get primed => _primed;

  /// Current filtered estimate, m/s.
  double get value => _state;

  void reset() {
    _state = 0;
    _variance = 1e9;
    _lastAt = null;
    _primed = false;
  }

  /// Fuses one raw speed sample (m/s). Returns the filtered estimate.
  ///
  /// Samples with NaN/negative inputs are ignored and `null` is returned.
  double? update({
    required double rawSpeed,
    required double speedAccuracy,
    required DateTime at,
  }) {
    if (rawSpeed.isNaN || speedAccuracy.isNaN) return null;
    if (rawSpeed < 0 || speedAccuracy < 0) return null;

    final last = _lastAt;
    var dt = 1.0;
    if (last != null) {
      dt = at.difference(last).inMilliseconds / 1000.0;
      if (dt <= 0 || dt > 10) dt = 1.0;
      dt = dt.clamp(0.05, 10);
    }
    _lastAt = at;

    // Predict: inflate uncertainty by acceleration jitter over the interval.
    final q = accelNoiseStd * accelNoiseStd * dt * dt;
    _variance += q;

    // Update: trust the measurement in proportion to its reported quality.
    final r = math.max(speedAccuracy, minSpeedAccuracy);
    final rVar = r * r;
    final gain = _variance / (_variance + rVar);
    _state += gain * (rawSpeed - _state);
    _variance *= (1 - gain);

    // Ground speed is a magnitude; never let noise pull it negative.
    if (_state < 0) _state = 0;
    _primed = true;
    return _state;
  }
}

/// Great-circle distance between two WGS84 points, in meters.
double haversineMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371008.8;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _deg2rad(double deg) => deg * math.pi / 180.0;
