import 'package:flutter_test/flutter_test.dart';
import 'package:groundspeed/data/nmea.dart';

void main() {
  test('parses a valid active RMC sentence', () {
    final sentence = withChecksum(
      'GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W',
    );
    final rmc = parseRmc(sentence);
    expect(rmc, isNotNull);
    expect(rmc!.speedMps, closeTo(22.4 * mpsPerKnot, 1e-9));
    expect(rmc.courseDeg, closeTo(84.4, 1e-9));
  });

  test('accepts GNSS-agnostic GNRMC talker', () {
    final sentence = withChecksum(
      'GNRMC,083559.00,A,4717.11437,N,00833.91522,E,0.054,31.4,230826,,,A',
    );
    final rmc = parseRmc(sentence);
    expect(rmc, isNotNull);
    expect(rmc!.speedMps, closeTo(0.054 * mpsPerKnot, 1e-9));
  });

  test('rejects a corrupted checksum', () {
    final good = withChecksum('GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W');
    final bad = '${good.substring(0, good.length - 2)}FF';
    expect(parseRmc(bad), isNull);
  });

  test('rejects void (status V) fixes', () {
    final sentence = withChecksum(
      'GPRMC,123519,V,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W',
    );
    expect(parseRmc(sentence), isNull);
  });

  test('rejects non-RMC sentences', () {
    expect(
      parseRmc(withChecksum('GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,')),
      isNull,
    );
    expect(parseRmc('not even nmea'), isNull);
    expect(parseRmc(''), isNull);
  });

  test('rejects missing speed field', () {
    final sentence = withChecksum('GPRMC,123519,A,4807.038,N,01131.000,E,,,,230394,003.1,W');
    expect(parseRmc(sentence), isNull);
  });
}
