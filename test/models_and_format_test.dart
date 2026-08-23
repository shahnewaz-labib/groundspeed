import 'package:flutter_test/flutter_test.dart';
import 'package:groundspeed/core/format.dart';
import 'package:groundspeed/core/gpx.dart';
import 'package:groundspeed/core/units.dart';
import 'package:groundspeed/data/models.dart';

void main() {
  group('moving time', () {
    test('formats minutes and seconds under an hour', () {
      expect(formatMovingTime(0), '0:00');
      expect(formatMovingTime(59), '0:59');
      expect(formatMovingTime(61), '1:01');
      expect(formatMovingTime(3599), '59:59');
    });
    test('switches to hours above one hour', () {
      expect(formatMovingTime(3661), '1:01');
      expect(formatMovingTime(7322), '2:02');
    });
  });

  group('altitude and vertical speed', () {
    test('metric altitude uses metres', () {
      expect(formatAltitude(512.4, SpeedUnit.kmh), '512 m');
    });
    test('imperial altitude converts to feet', () {
      expect(formatAltitude(100, SpeedUnit.mph), '328 ft');
    });
    test('small vertical speeds read as zero', () {
      expect(formatVerticalSpeed(0.05, SpeedUnit.kmh), '0');
    });
    test('metric climb rate keeps one decimal', () {
      expect(formatVerticalSpeed(1.24, SpeedUnit.kmh), '+1.2');
      expect(formatVerticalSpeed(-2, SpeedUnit.kmh), '-2.0');
    });
    test('imperial climb rate is feet per minute', () {
      expect(formatVerticalSpeed(1, SpeedUnit.mph), '+197');
    });
  });

  group('gpx builder', () {
    test('emits a valid track with points', () {
      final base = DateTime.utc(2026, 8, 23, 10, 30);
      final gpx = buildGpx(
        name: 'Groundspeed 2026-08-23 10:30',
        points: [
          TrackPoint(
              latitude: 23.810332,
              longitude: 90.4125181,
              altitudeM: 12.34,
              timestamp: base),
          TrackPoint(
              latitude: 23.810400,
              longitude: 90.4126000,
              altitudeM: 12.5,
              timestamp: base.add(const Duration(seconds: 1))),
        ],
      );

      expect(gpx, startsWith('<?xml version="1.0"'));
      expect(gpx, contains('version="1.1" creator="Groundspeed"'));
      expect('<trkpt '.allMatches(gpx).length, 2);
      expect(gpx, contains('lat="23.8103320" lon="90.4125181"'));
      expect(gpx, contains('<ele>12.34</ele>'));
      expect(gpx, contains('<time>2026-08-23T10:30:00.000Z</time>'));
      expect(gpx.trim(), endsWith('</gpx>'));
    });
  });
}
