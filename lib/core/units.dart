/// Supported display units for ground speed.
enum SpeedUnit {
  kmh('KM/H', 3.6),
  mph('MPH', 2.2369362920469),
  knots('KN', 1.9438444924406);

  const SpeedUnit(this.label, this.factor);

  /// Short uppercase label used in the UI.
  final String label;

  /// Multiplier from m/s to this unit.
  final double factor;

  static SpeedUnit fromStorage(String? raw) =>
      SpeedUnit.values.asNameMap()[raw] ?? SpeedUnit.kmh;
}
