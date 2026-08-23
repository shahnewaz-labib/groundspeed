import '../data/models.dart';

/// Builds a GPX 1.1 track document from recorded points.
String buildGpx({required String name, required List<TrackPoint> points}) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="Groundspeed" '
      'xmlns="http://www.topografix.com/GPX/1/1">',
    )
    ..writeln('  <trk>')
    ..writeln('    <name>${_escape(name)}</name>')
    ..writeln('    <trkseg>');
  for (final point in points) {
    buffer
      ..writeln(
        '      <trkpt lat="${point.latitude.toStringAsFixed(7)}" '
        'lon="${point.longitude.toStringAsFixed(7)}">',
      )
      ..writeln('        <ele>${point.altitudeM.toStringAsFixed(2)}</ele>')
      ..writeln(
        '        <time>${point.timestamp.toUtc().toIso8601String()}</time>',
      )
      ..writeln('      </trkpt>');
  }
  buffer
    ..writeln('    </trkseg>')
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return buffer.toString();
}

String _escape(String raw) => raw
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

final _trkptRegex = RegExp(
  r'<trkpt\s+lat="(-?[\d.]+)"\s+lon="(-?[\d.]+)"\s*>(.*?)</trkpt>',
  dotAll: true,
);
final _eleRegex = RegExp(r'<ele>(-?[\d.]+)</ele>');
final _timeRegex = RegExp(r'<time>([^<]+)</time>');

/// Reads track points back out of a Groundspeed (or any standard) GPX.
List<TrackPoint> parseGpxPoints(String xml) {
  final points = <TrackPoint>[];
  for (final match in _trkptRegex.allMatches(xml)) {
    final lat = double.tryParse(match.group(1)!);
    final lon = double.tryParse(match.group(2)!);
    if (lat == null || lon == null) continue;
    final inner = match.group(3) ?? '';
    final ele =
        double.tryParse(_eleRegex.firstMatch(inner)?.group(1) ?? '') ?? 0;
    final iso = _timeRegex.firstMatch(inner)?.group(1);
    final ts = (iso != null ? DateTime.tryParse(iso) : null) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    points.add(
      TrackPoint(
        latitude: lat,
        longitude: lon,
        altitudeM: ele,
        timestamp: ts,
      ),
    );
  }
  return points;
}
