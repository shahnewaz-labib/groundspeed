import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'ground_speed_estimator.dart';
import 'models.dart';
import 'nmea.dart';
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
    this.headingDeg = 0,
    this.altitudeM = 0,
    this.verticalSpeedMps = 0,
    this.moveSeconds = 0,
    this.avgMovingSpeedMps = 0,
    this.satellites = const [],
    this.trackPointCount = 0,
    this.rmcSpeedMps = 0,
    this.rmcCourseDeg = 0,
    this.nmeaSupported = false,
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

  /// Course over ground in degrees [0, 360).
  final double headingDeg;

  /// Latest reported altitude, m.
  final double altitudeM;

  /// Smoothed climb rate, m/s (positive = up).
  final double verticalSpeedMps;

  /// Seconds accumulated while in motion.
  final double moveSeconds;

  /// Space-derived average while moving, m/s.
  final double avgMovingSpeedMps;

  /// Per-satellite telemetry (Android only).
  final List<SatelliteInfo> satellites;

  /// Track points buffered for the current trip.
  final int trackPointCount;

  /// Latest raw RMC Doppler speed, m/s (0 = unknown). Android only.
  final double rmcSpeedMps;

  /// Latest RMC course over ground, degrees.
  final double rmcCourseDeg;

  /// Whether raw NMEA sentences are available on this platform.
  final bool nmeaSupported;

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
    double? headingDeg,
    double? altitudeM,
    double? verticalSpeedMps,
    double? moveSeconds,
    double? avgMovingSpeedMps,
    List<SatelliteInfo>? satellites,
    int? trackPointCount,
    double? rmcSpeedMps,
    double? rmcCourseDeg,
    bool? nmeaSupported,
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
      headingDeg: headingDeg ?? this.headingDeg,
      altitudeM: altitudeM ?? this.altitudeM,
      verticalSpeedMps: verticalSpeedMps ?? this.verticalSpeedMps,
      moveSeconds: moveSeconds ?? this.moveSeconds,
      avgMovingSpeedMps: avgMovingSpeedMps ?? this.avgMovingSpeedMps,
      satellites: satellites ?? this.satellites,
      trackPointCount: trackPointCount ?? this.trackPointCount,
      rmcSpeedMps: rmcSpeedMps ?? this.rmcSpeedMps,
      rmcCourseDeg: rmcCourseDeg ?? this.rmcCourseDeg,
      nmeaSupported: nmeaSupported ?? this.nmeaSupported,
    );
  }
}

/// Streams GNSS fixes, fuses them into a high-precision ground speed
/// estimate, records trip tracks, and exposes a single [snapshot].
class GnssService extends ChangeNotifier {
  static const EventChannel _gnssChannel = EventChannel('groundspeed/gnss');
  static const EventChannel _nmeaChannel = EventChannel('groundspeed/nmea');

  /// Reject samples whose reported speed accuracy is worse than this (m/s).
  static const double maxTrustedSpeedAccuracy = 6.0;

  /// While parked, only request fixes after this much movement (m).
  static const int parkedDistanceFilter = 10;

  /// Drop distance/track deltas when horizontal accuracy is worse (m).
  static const double maxDistanceAccuracy = 50.0;

  /// Ignore distance jumps that imply impossible motion between fixes.
  static const double maxPlausibleDeltaMeters = 250.0;

  /// Number of samples kept for the trace sparkline.
  static const int historyWindow = 90;

  /// Hard cap on buffered track points (ring-buffer behaviour).
  static const int _maxTrackPoints = 8000;

  GnssService();

  final GroundSpeedEstimator _estimator = GroundSpeedEstimator();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<dynamic>? _satelliteSub;
  StreamSubscription<dynamic>? _nmeaSub;

  bool _streamThrottled = false;
  double _rmcSpeedMps = 0;
  double _rmcCourseDeg = 0;
  bool _nmeaSupported = false;

  GnssSnapshot _snapshot = const GnssSnapshot(phase: GnssPhase.idle);
  GnssSnapshot get snapshot => _snapshot;

  double _distance = 0;
  double _maxSpeed = 0;
  double _moveSeconds = 0;
  DateTime? _sessionStart;
  final List<double> _history = <double>[];
  Position? _lastAccepted;

  double _verticalSpeed = 0;
  double? _lastAltitude;
  DateTime? _lastAltitudeAt;

  final List<TrackPoint> _track = <TrackPoint>[];

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

      _sessionStart ??= DateTime.now();
      _listenSatellites();
      _listenNmea();
      _streamThrottled = false;
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
    resetSession();
    await start();
  }

  /// Clears trip counters without touching the estimator's motion state.
  void resetSession() {
    _estimator.reset();
    _distance = 0;
    _maxSpeed = 0;
    _moveSeconds = 0;
    _lastAccepted = null;
    _history.clear();
    _track.clear();
    _verticalSpeed = 0;
    _lastAltitude = null;
    _lastAltitudeAt = null;
    _sessionStart = DateTime.now();
    _snapshot = GnssSnapshot(
      phase: _snapshot.phase,
      satelliteMonitorSupported: _snapshot.satelliteMonitorSupported,
    );
    notifyListeners();
  }

  /// Snapshots the current trip for export and resets its counters.
  ///
  /// Motion state is preserved so an ongoing ride doesn't need to re-wake
  /// the stationary gate.
  SessionTrack collectSession() {
    final now = DateTime.now();
    final session = SessionTrack(
      name: 'Groundspeed '
          '${now.year}-${_two(now.month)}-${_two(now.day)} '
          '${_two(now.hour)}:${_two(now.minute)}',
      startedAt: _sessionStart ?? now,
      endedAt: now,
      distanceM: _distance,
      moveSeconds: _moveSeconds,
      maxSpeedMps: _maxSpeed,
      points: List<TrackPoint>.unmodifiable(_track),
    );
    _distance = 0;
    _maxSpeed = 0;
    _moveSeconds = 0;
    _history.clear();
    _track.clear();
    _sessionStart = now;
    _snapshot = _snapshot.copyWith(
      distanceM: 0,
      maxSpeedMps: 0,
      moveSeconds: 0,
      avgMovingSpeedMps: 0,
      history: const [],
      trackPointCount: 0,
    );
    notifyListeners();
    return session;
  }

  /// Battery saver: while the stationary gate has us parked, drop to a
  /// medium-accuracy stream with a distance gate so the GPS radio can doze.
  /// The estimator's hysteresis already debounces the transitions.
  Future<void> _syncStreamThrottle() async {
    final wantThrottled = !_estimator.isMoving;
    if (wantThrottled == _streamThrottled) return;
    _streamThrottled = wantThrottled;
    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _streamThrottled
          ? const LocationSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: parkedDistanceFilter,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
            ),
    ).listen(
      _onPosition,
      onError: (Object _) => _setPhase(GnssPhase.searching),
      cancelOnError: false,
    );
  }

  Future<void> _onPosition(Position position) async {
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
      if (_estimator.isMoving) {
        if (filtered > _maxSpeed) _maxSpeed = filtered;
        _history.add(filtered);
        while (_history.length > historyWindow) {
          _history.removeAt(0);
        }
      }
    }

    // Fix-quality gate shared by distance, track recording, altitude.
    final qualityOk = !position.accuracy.isNaN &&
        position.accuracy <= maxDistanceAccuracy;

    final last = _lastAccepted;
    final dtSec = last == null
        ? null
        : at.difference(last.timestamp).inMilliseconds / 1000.0;
    final deltaOk = dtSec != null && dtSec > 0 && dtSec < 30;

    if (qualityOk) {
      if (_estimator.isMoving) {
        if (deltaOk && last != null) {
          final d = haversineMeters(
            last.latitude,
            last.longitude,
            position.latitude,
            position.longitude,
          );
          if (d <= maxPlausibleDeltaMeters) {
            _distance += d;
            _moveSeconds += dtSec.clamp(0, 5);
          }
        }
        _bufferTrack(position);
      }
      _lastAccepted = position;
    }

    // Vertical speed: EMA over gated altitude deltas (works even parked).
    final alt = position.altitude;
    if (qualityOk && !alt.isNaN) {
      final lastAlt = _lastAltitude;
      final lastAt = _lastAltitudeAt;
      if (lastAlt != null && lastAt != null) {
        final adt = at.difference(lastAt).inMilliseconds / 1000.0;
        if (adt > 0.2 && adt < 5) {
          final rawVs = (alt - lastAlt) / adt;
          if (rawVs.abs() < 30) {
            _verticalSpeed =
                _verticalSpeed + 0.22 * (rawVs - _verticalSpeed);
          }
        }
      }
      _lastAltitude = alt;
      _lastAltitudeAt = at;
    }

    final avgMoving =
        _moveSeconds > 0 ? _distance / _moveSeconds : 0.0;

    _snapshot = _snapshot.copyWith(
      phase: GnssPhase.locked,
      hasFix: true,
      speedMps: _estimator.value,
      rawSpeedMps: speed.isNaN ? 0 : (speed < 0 ? 0 : speed),
      accuracyM: position.accuracy.isNaN ? 0 : position.accuracy,
      speedAccuracyM: speedAcc.isNaN ? 0 : (speedAcc < 0 ? 0 : speedAcc),
      distanceM: _distance,
      maxSpeedMps: _maxSpeed,
      moveSeconds: _moveSeconds,
      avgMovingSpeedMps: avgMoving,
      history: List<double>.unmodifiable(_history),
      headingDeg: _normalizeHeading(position.heading),
      altitudeM: alt.isNaN ? 0 : alt,
      verticalSpeedMps: _verticalSpeed,
      trackPointCount: _track.length,
      rmcSpeedMps: _rmcSpeedMps,
      rmcCourseDeg: _rmcCourseDeg,
      nmeaSupported: _nmeaSupported,
    );
    notifyListeners();
    await _syncStreamThrottle();
  }

  void _bufferTrack(Position p) {
    _track.add(
      TrackPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        altitudeM: p.altitude.isNaN ? 0 : p.altitude,
        timestamp: p.timestamp,
      ),
    );
    if (_track.length > _maxTrackPoints) {
      _track.removeRange(0, _track.length - _maxTrackPoints);
    }
  }

  double _normalizeHeading(double h) {
    if (h.isNaN || h < 0) return 0;
    final normalized = h % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  /// Android-only GNSS constellation telemetry via platform channel.
  void _listenSatellites() {
    try {
      _satelliteSub?.cancel();
      _satelliteSub = _gnssChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final used = (event['used'] as num?)?.toInt() ?? 0;
            final total = (event['total'] as num?)?.toInt() ?? 0;
            final rawSats = event['sats'];
            final sats = rawSats is List
                ? rawSats
                      .map((s) => SatelliteInfo.fromMap(s))
                      .toList()
                : <SatelliteInfo>[];
            _snapshot = _snapshot.copyWith(
              satsUsed: used,
              satsTotal: total,
              satellites: sats,
              satelliteMonitorSupported: true,
            );
            notifyListeners();
          }
        },
        onError: (Object _) {
          _snapshot = _snapshot.copyWith(satelliteMonitorSupported: false);
        },
        cancelOnError: false,
      );
    } on Exception {
      // Platform without the channel (e.g. iOS): degrade quietly.
    }
  }

  /// Android-only raw NMEA feed; we cross-validate the RMC Doppler speed
  /// against the fused estimate.
  void _listenNmea() {
    try {
      _nmeaSub?.cancel();
      _nmeaSub = _nmeaChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is String) {
            final rmc = parseRmc(event);
            if (rmc == null) return;
            _rmcSpeedMps = rmc.speedMps;
            _rmcCourseDeg = rmc.courseDeg;
            _nmeaSupported = true;
            notifyListeners();
          }
        },
        onError: (Object _) {
          _nmeaSupported = false;
        },
        cancelOnError: false,
      );
    } on Exception {
      _nmeaSupported = false;
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
    _nmeaSub?.cancel();
    super.dispose();
  }
}
