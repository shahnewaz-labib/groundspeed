/// Minimal NMEA 0183 support for cross-validating the fused speed against
/// raw receiver Doppler speed reported in RMC sentences.
library;

/// knots → m/s
const double mpsPerKnot = 0.5144444;

/// Parsed payload of a valid RMC sentence.
class NmeaRmc {
  const NmeaRmc({required this.speedMps, required this.courseDeg});

  /// Ground speed from receiver Doppler, m/s.
  final double speedMps;

  /// Course over ground, degrees true [0, 360).
  final double courseDeg;
}

/// XOR checksum check over the body between `$` and `*`.
bool checksumOk(String sentence) {
  final trimmed = sentence.trim();
  if (!trimmed.startsWith(r'$')) return false;
  final star = trimmed.lastIndexOf('*');
  if (star < 0) return false;
  final body = trimmed.substring(1, star);
  final provided = int.tryParse(trimmed.substring(star + 1), radix: 16);
  if (provided == null) return false;
  var computed = 0;
  for (final code in body.codeUnits) {
    computed ^= code;
  }
  return computed == provided;
}

/// Parses `$GPRMC` / `$GNRMC` sentences. Returns null for anything that
/// isn't a valid, checksum-clean, active (status `A`) RMC fix with a
/// numeric speed field.
NmeaRmc? parseRmc(String sentence) {
  final trimmed = sentence.trim();
  if (!checksumOk(trimmed)) return null;
  final star = trimmed.lastIndexOf('*');
  final body = trimmed.substring(1, star);
  final fields = body.split(',');
  if (fields.isEmpty || fields.first.length < 5) return null;
  if (!fields.first.substring(2).endsWith('RMC')) return null;
  if (fields.length < 8) return null;
  if (fields[2] != 'A') return null; // void fix
  final knots = double.tryParse(fields[7]);
  if (knots == null) return null;

  var course = 0.0;
  if (fields.length > 8) {
    final c = double.tryParse(fields[8]);
    if (c != null) course = c % 360;
  }
  return NmeaRmc(speedMps: knots * mpsPerKnot, courseDeg: course);
}

/// Builds a checksummed NMEA sentence body (test helper, also handy for
/// replay tooling).
String withChecksum(String body) {
  var computed = 0;
  for (final code in body.codeUnits) {
    computed ^= code;
  }
  return '\$$body*${computed.toRadixString(16).toUpperCase().padLeft(2, '0')}';
}
