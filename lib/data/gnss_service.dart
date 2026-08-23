import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'ground_speed_estimator.dart';
import 'speed_filter.dart';

/// High-level connection state surfaced to the UI.
enum GnssPhase {
  idle,
  requesting,
  searching,
  locked,
  denied,
  serviceOff,
  error,
}

/// Immutable view of everything the dashboard renders.
@immutable
class GnssSnapshot {
  const GnssSnapshot({
    required this.phase,
    this.hasFix = false,
    this.speedMps = 0,
    this.rawSpeedMps = 0,
    this.accuracyM = 0,
    this.speedAccuracyM = 0,
    this.satsUsed = 0,
    this.satsTotal = 0,
    this.satelliteMonitorSupported = false,
    this.distanceM = 0,
    this.maxSpeedMps = 0,
    this.history = const [],
  });

  final GnssPhase phase;

  /// True once any position fix has been received.
  final bool hasFix;

  /// Kalman-filtered speed, m/s.
  final double speedMps;

  /// Last raw receiver speed, m/s.
  final double rawSpeedMps;

  /// Horizontal accuracy of the latest fix, m.
  final double accuracyM;

  /// Reported speed accuracy, m/s.
  final double speedAccuracyM;

  /// Satellites used in fix / visible (Android only).
  final int satsUsed;
  final int satsTotal;
  final bool satelliteMonitorSupported;

  /// Accumulated session distance, m.
  final double distanceM;

  /// Session peak filtered speed, m/s.
  final double maxSpeedMps;

  /// Rolling window of recent filtered speeds (m/s), oldest first.
  final List<double> history;

  GnssSnapshot copyWith({
    GnssPhase? phase,
    bool? hasFix,
    double? speedMps,
    double? rawSpeedMps,
    double? accuracyM,
    double? speedAccuracyM,
    int? satsUsed,
    int? satsTotal,
    bool? satelliteMonitorSupported,
    double? distanceM,
    double? maxSpeedMps,
    List<double>? history,
  }) {
    return GnssSnapshot(
      phase: phase ?? this.phase,
      hasFix: hasFix ?? this.hasFix,
      speedMps: speedMps ?? this.speedMps,
      rawSpeedMps: rawSpeedMps ?? this.rawSpeedMps,
      accuracyM: accuracyM ?? this.accuracyM,
      speedAccuracyM: speedAccuracyM ?? this.speedAccuracyM,
      satsUsed: satsUsed ?? this.satsUsed,
      satsTotal: satsTotal ?? this.satsTotal,
      satelliteMonitorSupported:
          satelliteMonitorSupported ?? this.satelliteMonitorSupported,
      distanceM: distanceM ?? this.distanceM,
      maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
      history: history ?? this.history,
    );
  }
}

/// Streams GNSS fixes, fuses them into a high-precision ground speed
/// estimate, and exposes a single [snapshot] for the UI.
///
/// The platform folders are generated in CI; on iOS there is no public
/// satellite-telemetry API, so [satelliteMonitorSupported] degrades to false
/// there and everything else keeps working.
class GnssService extends ChangeNotifier {
  static const EventChannel _gnssChannel = EventChannel('groundspeed/gnss');

  /// Reject samples whose reported speed accuracy is worse than this (m/s).
  static const double maxTrustedSpeedAccuracy = 6.0;

  /// Drop distance deltas when horizontal accuracy is worse than this (m).
  static const double maxDistanceAccuracy = 50.0;

  /// Ignore distance jumps that imply impossible motion between fixes.
  static const double maxPlausibleDeltaMeters = 250.0;

  /// Number of samples kept for the trace sparkline.
  static const int historyWindow = 90;

  GnssService();

  final GroundSpeedEstimator _estimator = GroundSpeedEstimator();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<dynamic>? _satelliteSub;

  GnssSnapshot _snapshot = const GnssSnapshot(phase: GnssPhase.idle);
  GnssSnapshot get snapshot => _snapshot;

  double _distance = 0;
  double _maxSpeed = 0;
  final List<double> _history = <double>[];
  Position? _lastAccepted;

  Future<void> start() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _setPhase(GnssPhase.requesting);
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setPhase(GnssPhase.denied);
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setPhase(GnssPhase.serviceOff);
        return;
      }

      _listenSatellites();
      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen(
        _onPosition,
        onError: (Object _) => _setPhase(GnssPhase.searching),
        cancelOnError: false,
      );
      _setPhase(GnssPhase.searching);
    } on Exception {
      _setPhase(GnssPhase.error);
    }
  }

  /// Stops streaming, clears session state, and starts over.
  Future<void> restart() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _estimator.reset();
    _distance = 0;
    _maxSpeed = 0;
    _lastAccepted = null;
    _history.clear();
    _snapshot = GnssSnapshot(
      phase: _snapshot.phase,
      satelliteMonitorSupported: _snapshot.satelliteMonitorSupported,
    );
    notifyListeners();
    await start();
  }

  void _onPosition(Position position) {
    final at = position.timestamp;
    final speed = position.speed;
    final speedAcc = position.speedAccuracy;

    final speedUsable = !speed.isNaN &&
        !speedAcc.isNaN &&
        speed >= 0 &&
        speedAcc >= 0 &&
        speedAcc <= maxTrustedSpeedAccuracy;

    if (speedUsable) {
      final filtered = _estimator.update(
        rawSpeed: speed,
        speedAccuracy: speedAcc,
        at: at,
      );
      if (_estimator.isMoving && filtered > _maxSpeed) {
        _maxSpeed = filtered;
      }
      if (_estimator.isMoving) {
        _history.add(filtered);
        while (_history.length > historyWindow) {
          _history.removeAt(0);
        }
      }
    }

    // Distance: only while the estimator believes we're moving (kills
    // parked-drift), and gate by fix quality + plausibility to reject jumps.
    final last = _lastAccepted;
    final dtSec = last == null
        ? null
        : at.difference(last.timestamp).inMilliseconds / 1000.0;
    final deltaOk = dtSec != null && dtSec > 0 && dtSec < 30;
    if (_estimator.isMoving && position.accuracy <= maxDistanceAccuracy) {
      if (last != null && deltaOk) {
        final d = haversineMeters(
          last.latitude,
          last.longitude,
          position.latitude,
          position.longitude,
        );
        if (d <= maxPlausibleDeltaMeters) {
          _distance += d;
        }
      }
      _lastAccepted = position;
    }

    _snapshot = _snapshot.copyWith(
      phase: GnssPhase.locked,
      hasFix: true,
      speedMps: _estimator.value,
      rawSpeedMps: speed.isNaN ? 0 : (speed < 0 ? 0 : speed),
      accuracyM: position.accuracy.isNaN ? 0 : position.accuracy,
      speedAccuracyM: speedAcc.isNaN ? 0 : (speedAcc < 0 ? 0 : speedAcc),
      distanceM: _distance,
      maxSpeedMps: _maxSpeed,
      history: List<double>.unmodifiable(_history),
    );
    notifyListeners();
  }

  /// Android-only GNSS constellation telemetry via platform channel.
  void _listenSatellites() {
    try {
      _satelliteSub?.cancel();
      _satelliteSub = _gnssChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final used = (event['used'] as num?)?.toInt() ?? 0;
            final total = (event['total'] as num?)?.toInt() ?? 0;
            if (used == _snapshot.satsUsed &&
                total == _snapshot.satsTotal &&
                _snapshot.satelliteMonitorSupported) {
              return;
            }
            _snapshot = _snapshot.copyWith(
              satsUsed: used,
              satsTotal: total,
              satelliteMonitorSupported: true,
            );
            notifyListeners();
          }
        },
        onError: (Object _) {
          _snapshot =
              _snapshot.copyWith(satelliteMonitorSupported: false);
        },
        cancelOnError: false,
      );
    } on Exception {
      // Platform without the channel (e.g. iOS): degrade quietly.
    }
  }

  void _setPhase(GnssPhase phase) {
    if (_snapshot.phase == phase) return;
    _snapshot = _snapshot.copyWith(phase: phase);
    notifyListeners();
  }

  @visibleForTesting
  void debugEmit(GnssSnapshot snapshot) {
    _snapshot = snapshot;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _satelliteSub?.cancel();
    super.dispose();
  }
}
