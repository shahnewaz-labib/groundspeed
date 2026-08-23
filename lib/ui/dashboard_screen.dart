import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/units.dart';
import '../data/gnss_service.dart';
import '../data/session_store.dart';
import 'history_sheet.dart';
import 'signal_sheet.dart';
import 'theme.dart';
import 'widgets/heading_ring.dart';
import 'widgets/instrument.dart';
import 'widgets/stats_grid.dart';

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
  double _hapticMax = 0;
  bool _saving = false;

  final SessionStore _store = SessionStore();

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
      setState(
          () => _unit = SpeedUnit.fromStorage(prefs.getString(_unitPrefKey)));
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

  bool _canSave(GnssSnapshot s) =>
      s.trackPointCount >= 20 &&
      (s.distanceM > 150 || s.moveSeconds > 45);

  Future<void> _saveTrip() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final session = widget.service.collectSession();
      await _store.save(session);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF14171B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: GsColors.hairline),
            ),
            content: Text(
              'Trip saved · ${session.points.length} points',
              style: const TextStyle(color: GsColors.ink, fontSize: 13),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on Exception catch (e) {
      debugPrint('save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1B1113),
            content: const Text('Could not save trip',
                style: TextStyle(color: GsColors.red, fontSize: 13)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Fires a subtle tick whenever the session max climbs while moving.
  void _tickHaptics(GnssSnapshot s) {
    if (s.maxSpeedMps < _hapticMax) _hapticMax = 0; // trip was reset
    if (s.speedMps > 0.4 && s.maxSpeedMps > _hapticMax + 0.05) {
      _hapticMax = s.maxSpeedMps;
      HapticFeedback.selectionClick();
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
            _tickHaptics(snapshot);
            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
                                canSave: _canSave(snapshot),
                                saving: _saving,
                                onUnitChanged: _changeUnit,
                                onSaveTrip: _saveTrip,
                                onShowHistory: () => showHistorySheet(
                                    context, _store, _unit),
                                onShowSignal: () =>
                                    showSignalSheet(context, widget.service),
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
    required this.canSave,
    required this.saving,
    required this.onUnitChanged,
    required this.onSaveTrip,
    required this.onShowHistory,
    required this.onShowSignal,
  });

  final GnssSnapshot snapshot;
  final SpeedUnit unit;
  final bool canSave;
  final bool saving;
  final ValueChanged<int> onUnitChanged;
  final VoidCallback onSaveTrip;
  final VoidCallback onShowHistory;
  final VoidCallback onShowSignal;

  @override
  Widget build(BuildContext context) {
    final locked = snapshot.hasFix;
    final acquiring = !locked;
    final pillLabel =
        acquiring ? 'ACQUIRING SATELLITES' : _lockedLabel(snapshot);
    final tone = acquiring ? GsColors.amber : GsColors.accent;
    final showRing = locked && snapshot.speedMps > 0.4;

    final speedText = !locked
        ? '--'
        : formatSpeed(snapshot.speedMps, unit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onShowHistory,
              icon: const Icon(Icons.history_rounded, size: 21),
              color: GsColors.inkDim,
              tooltip: 'Trips',
            ),
            Expanded(
              child: Center(
                child: StatusPill(
                    label: pillLabel, tone: tone, pulsing: acquiring),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onShowSignal,
              icon: const Icon(Icons.satellite_alt_outlined, size: 20),
              color: GsColors.inkDim,
              tooltip: 'Signal',
            ),
          ],
        ),
        Expanded(
          flex: 5,
          child: LayoutBuilder(builder: (context, constraints) {
            if (!showRing) {
              return Center(
                child: SpeedReadout(
                  text: speedText,
                  unitLabel: unit.label,
                  ready: locked,
                ),
              );
            }
            final side =
                math.min(constraints.maxWidth, constraints.maxHeight);
            return Center(
              child: SizedBox(
                width: side * 0.98,
                height: side * 0.98,
                child: Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    HeadingRing(headingDeg: snapshot.headingDeg),
                    Center(
                      child: SpeedReadout(
                        text: speedText,
                        unitLabel: unit.label,
                        ready: locked,
                        fontSize: side * 0.34,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Text(
                'TRACE · LAST 90 S',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: GsColors.inkFaint,
                ),
              ),
              const Spacer(),
              Text(
                'HDG ${snapshot.headingDeg.round().toString().padLeft(3)}°',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: GsColors.accent.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        Sparkline(samples: snapshot.history),
        const SizedBox(height: 14),
        StatsGrid(tiles: _tiles()),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedScale(
            scale: canSave ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            child: Opacity(
              opacity: canSave ? 1 : 0,
              child: IconButton.outlined(
                onPressed: saving ? null : onSaveTrip,
                style: IconButton.styleFrom(
                  side: const BorderSide(color: GsColors.hairline),
                  foregroundColor: GsColors.accent,
                ),
                tooltip: 'Save trip as GPX',
                icon: saving
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: GsColors.accent))
                    : const Icon(Icons.bookmark_border_rounded, size: 19),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        UnitSwitcher(
          units: SpeedUnit.values,
          selected: SpeedUnit.values.indexOf(unit),
          onChanged: onUnitChanged,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  List<StatTileData> _tiles() {
    final locked = snapshot.hasFix;
    final vsSuffix = unit == SpeedUnit.mph ? ' fpm' : ' m/s';
    return [
      StatTileData(
        'MAX',
        locked ? formatSpeed(snapshot.maxSpeedMps, unit) : '--',
      ),
      StatTileData('DIST', locked ? formatDistance(snapshot.distanceM) : '--'),
      StatTileData(
        'MOVE',
        locked ? formatMovingTime(snapshot.moveSeconds) : '--',
      ),
      StatTileData(
        'AVG',
        locked && snapshot.avgMovingSpeedMps > 0
            ? formatSpeed(snapshot.avgMovingSpeedMps, unit)
            : '--',
        muted: true,
      ),
      StatTileData(
        'ELEV',
        locked ? formatAltitude(snapshot.altitudeM, unit) : '--',
        muted: true,
      ),
      StatTileData(
        'V/S',
        locked
            ? '${formatVerticalSpeed(snapshot.verticalSpeedMps, unit)}$vsSuffix'
            : '--',
        muted: true,
      ),
    ];
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
          style: const TextStyle(
              fontSize: 13.5, height: 1.5, color: GsColors.inkDim),
        ),
        const SizedBox(height: 30),
        OutlinedButton(
          onPressed: actionFn,
          style: OutlinedButton.styleFrom(
            foregroundColor: GsColors.ink,
            side: const BorderSide(color: GsColors.hairline, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}
