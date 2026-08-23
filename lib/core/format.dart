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

/// Moving time as `M:SS` under an hour, `H:MM` above.
String formatMovingTime(double seconds) {
  final total = seconds.round();
  final h = total ~/ 3600;
  if (h > 0) {
    final m = (total % 3600) ~/ 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Altitude in metres (metric units) or feet (imperial).
String formatAltitude(double meters, SpeedUnit unit) {
  if (unit == SpeedUnit.mph) {
    final ft = meters * 3.2808398950131;
    return '${ft.round()} ft';
  }
  return '${meters.round()} m';
}

/// Vertical speed in m/s (metric) or ft/min (imperial).
String formatVerticalSpeed(double metersPerSecond, SpeedUnit unit) {
  if (metersPerSecond.abs() < 0.15) return '0';
  if (unit == SpeedUnit.mph) {
    final fpm = metersPerSecond * 196.8503937007874;
    return '${fpm >= 0 ? '+' : ''}${fpm.round()}';
  }
  return '${metersPerSecond >= 0 ? '+' : ''}${metersPerSecond.toStringAsFixed(1)}';
}
