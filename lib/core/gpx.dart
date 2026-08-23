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
