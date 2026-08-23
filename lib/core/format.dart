import 'units.dart';

/// Formats a m/s value for the big readout.
///
/// Sub-100 values keep one decimal (instrument feel); above that the decimal
/// is dropped so the number stays legible at size 150.
String formatSpeed(double metersPerSecond, SpeedUnit unit) {
  final value = metersPerSecond * unit.factor;
  if (value >= 99.95) return value.round().toString();
  return value.toStringAsFixed(1);
}

/// Human distance with sensible precision steps.
String formatDistance(double meters) {
  if (meters >= 1000) {
    final km = meters / 1000;
    if (km >= 100) return '${km.round()} km';
    if (km >= 10) return '${km.toStringAsFixed(1)} km';
    return '${km.toStringAsFixed(2)} km';
  }
  if (meters >= 10) return '${meters.round()} m';
  return '${meters.toStringAsFixed(1)} m';
}

/// Horizontal accuracy chip text, e.g. `±3.2 m`.
String formatAccuracy(double meters) {
  if (meters >= 9.95) return '±${meters.round()} m';
  return '±${meters.toStringAsFixed(1)} m';
}
