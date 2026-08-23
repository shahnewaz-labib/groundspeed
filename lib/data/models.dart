import 'package:flutter/foundation.dart';

/// One satellite reported by the receiver.
@immutable
class SatelliteInfo {
  const SatelliteInfo({
    required this.svid,
    required this.constellation,
    required this.azimuthDeg,
    required this.elevationDeg,
    required this.snrDb,
    required this.usedInFix,
  });

  final int svid;
  final String constellation;
  final double azimuthDeg;
  final double elevationDeg;
  final double snrDb;
  final bool usedInFix;

  static SatelliteInfo fromMap(Object raw) {
    final map = raw as Map;
    return SatelliteInfo(
      svid: (map['id'] as num?)?.toInt() ?? 0,
      constellation: (map['c'] as String?) ?? 'UNKNOWN',
      azimuthDeg: (map['az'] as num?)?.toDouble() ?? 0,
      elevationDeg: (map['el'] as num?)?.toDouble() ?? 0,
      snrDb: (map['snr'] as num?)?.toDouble() ?? 0,
      usedInFix: (map['u'] as bool?) ?? false,
    );
  }
}

/// A single recorded track sample for GPX export.
@immutable
class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.altitudeM,
    required this.timestamp,
  });
  final double latitude;
  final double longitude;
  final double altitudeM;
  final DateTime timestamp;
}

/// A saved trip: metadata plus the full track.
@immutable
class SessionTrack {
  const SessionTrack({
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.moveSeconds,
    required this.maxSpeedMps,
    required this.points,
  });

  final String name;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceM;
  final double moveSeconds;
  final double maxSpeedMps;
  final List<TrackPoint> points;

  /// Space-derived average while moving, m/s.
  double get avgMovingSpeedMps =>
      moveSeconds > 0 ? distanceM / moveSeconds : 0;
}

/// Metadata for a session persisted on disk.
@immutable
class StoredSession {
  const StoredSession({
    required this.file,
    required this.name,
    required this.startedAt,
    required this.distanceM,
    required this.moveSeconds,
    required this.maxSpeedMps,
    required this.pointCount,
  });

  final String file; // file name inside the tracks directory
  final String name;
  final DateTime startedAt;
  final double distanceM;
  final double moveSeconds;
  final double maxSpeedMps;
  final int pointCount;

  Map<String, Object?> toJson() => <String, Object?>{
        'file': file,
        'name': name,
        'startedAt': startedAt.toIso8601String(),
        'distanceM': distanceM,
        'moveSeconds': moveSeconds,
        'maxSpeedMps': maxSpeedMps,
        'points': pointCount,
      };

  static StoredSession fromJson(Map<Object?, Object?> json) {
    return StoredSession(
      file: (json['file'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Session',
      startedAt:
          DateTime.tryParse((json['startedAt'] as String?) ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      distanceM: (json['distanceM'] as num?)?.toDouble() ?? 0,
      moveSeconds: (json['moveSeconds'] as num?)?.toDouble() ?? 0,
      maxSpeedMps: (json['maxSpeedMps'] as num?)?.toDouble() ?? 0,
      pointCount: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}
