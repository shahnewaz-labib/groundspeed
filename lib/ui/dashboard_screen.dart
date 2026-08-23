import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/units.dart';
import '../data/gnss_service.dart';
import 'theme.dart';
import 'widgets/instrument.dart';

const _unitPrefKey = 'groundspeed.unit';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.service});

  final GnssService service;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _units = SpeedUnit.values;

  late SpeedUnit _unit = SpeedUnit.kmh;

  @override
  void initState() {
    super.initState();
    widget.service.start();
    _loadUnit();
  }

  @override
  void dispose() {
    widget.service.dispose();
    super.dispose();
  }

  Future<void> _loadUnit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _unit = SpeedUnit.fromStorage(prefs.getString(_unitPrefKey)));
    } on Exception {
      // First run or unavailable prefs: default unit stays.
    }
  }

  Future<void> _changeUnit(int index) async {
    final unit = _units[index];
    setState(() => _unit = unit);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_unitPrefKey, unit.name);
    } on Exception {
      // Preference persistence is best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: GsColors.background,
        systemNavigationBarColor: GsColors.background,
      ),
      child: Scaffold(
        backgroundColor: GsColors.background,
        body: ListenableBuilder(
          listenable: widget.service,
          builder: (context, _) {
            final snapshot = widget.service.snapshot;
            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                    child:
                        snapshot.phase == GnssPhase.denied ||
                                snapshot.phase == GnssPhase.serviceOff ||
                                snapshot.phase == GnssPhase.error
                            ? _BlockedView(
                                phase: snapshot.phase,
                                onRetry: () => widget.service.restart(),
                              )
                            : _LiveView(
                                snapshot: snapshot,
                                unit: _unit,
                                onUnitChanged: _changeUnit,
                              ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LiveView extends StatelessWidget {
  const _LiveView({
    required this.snapshot,
    required this.unit,
    required this.onUnitChanged,
  });

  final GnssSnapshot snapshot;
  final SpeedUnit unit;
  final ValueChanged<int> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final locked = snapshot.hasFix;
    final acquiring = !locked;
    final pillLabel = acquiring
        ? 'ACQUIRING SATELLITES'
        : _lockedLabel(snapshot);
    final tone = acquiring ? GsColors.amber : GsColors.accent;

    final speedText = locked && snapshot.speedMps > 0.05
        ? formatSpeed(snapshot.speedMps, unit)
        : locked
            ? formatSpeed(0, unit)
            : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Center(
          child: StatusPill(label: pillLabel, tone: tone, pulsing: acquiring),
        ),
        Expanded(
          flex: 5,
          child: Center(
            child: SpeedReadout(
              text: speedText,
              unitLabel: unit.label,
              ready: locked,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'TRACE · LAST 90 S',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
              color: GsColors.inkFaint,
            ),
          ),
        ),
        Sparkline(samples: snapshot.history),
        const SizedBox(height: 26),
        StatTiles(
          maxText: locked
              ? formatSpeed(snapshot.maxSpeedMps, unit)
              : '--',
          distanceText:
              locked ? formatDistance(snapshot.distanceM) : '--',
          satellitesText: snapshot.satelliteMonitorSupported
              ? '${snapshot.satsUsed}/${snapshot.satsTotal}'
              : '—',
        ),
        const SizedBox(height: 26),
        UnitSwitcher(
          units: SpeedUnit.values,
          selected: SpeedUnit.values.indexOf(unit),
          onChanged: onUnitChanged,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  String _lockedLabel(GnssSnapshot s) {
    final accuracy = formatAccuracy(s.accuracyM);
    if (!s.satelliteMonitorSupported) return 'LOCKED · $accuracy';
    return 'LOCKED · $accuracy · ${s.satsUsed} SV';
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.phase, required this.onRetry});

  final GnssPhase phase;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body, action, actionFn) = switch (phase) {
      GnssPhase.denied => (
          Icons.location_off_outlined,
          'Permission required',
          'Groundspeed needs precise location access to measure speed from GNSS fixes.',
          'Open Settings',
          () => Geolocator.openAppSettings(),
        ),
      GnssPhase.serviceOff => (
          Icons.satellite_alt_outlined,
          'Location services off',
          'Enable location services so the receiver can lock onto satellites.',
          'Open Settings',
          () => Geolocator.openLocationSettings(),
        ),
      _ => (
          Icons.error_outline_rounded,
          'GPS unavailable',
          'The position stream could not be started on this device.',
          'Retry',
          onRetry,
        ),
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 44, color: GsColors.inkFaint),
        const SizedBox(height: 22),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: GsColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: GsColors.inkDim),
        ),
        const SizedBox(height: 30),
        OutlinedButton(
          onPressed: actionFn,
          style: OutlinedButton.styleFrom(
            foregroundColor: GsColors.ink,
            side: const BorderSide(color: GsColors.hairline, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}
