import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/format.dart';
import '../core/gpx.dart';
import '../core/units.dart';
import '../data/models.dart';
import '../data/session_store.dart';
import '../data/speed_filter.dart';
import 'theme.dart';
import 'widgets/line_chart.dart';

/// Full-screen trip view: dark map with the track polyline, plus speed and
/// elevation profiles derived from the recorded points.
class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({
    super.key,
    required this.session,
    required this.store,
    required this.unit,
  });

  final StoredSession session;
  final SessionStore store;
  final SpeedUnit unit;

  Future<List<TrackPoint>> _loadPoints() async {
    final path = await store.pathOf(session);
    final xml = await File(path).readAsString();
    final points = parseGpxPoints(xml);
    if (points.isEmpty) {
      throw const FormatException('no track points in file');
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GsColors.background,
      appBar: AppBar(
        backgroundColor: GsColors.background,
        surfaceTintColor: GsColors.background,
        foregroundColor: GsColors.ink,
        elevation: 0,
        title: Text(
          'TRIP · ${_dateLabel()}',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
      ),
      body: FutureBuilder<List<TrackPoint>>(
        future: _loadPoints(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: GsColors.accent),
            );
          }
          final error = snapshot.error;
          if (error != null || snapshot.data == null) {
            return _CenterMessage(
              icon: Icons.map_outlined,
              text: 'Could not read this trip.\n${error ?? ''}',
            );
          }
          return _TripBody(points: snapshot.data!, session: session, unit: unit);
        },
      ),
    );
  }

  String _dateLabel() {
    final s = session.startedAt;
    return '${s.year}-${_two(s.month)}-${_two(s.day)} ${_two(s.hour)}:${_two(s.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}

class _TripBody extends StatelessWidget {
  const _TripBody({
    required this.points,
    required this.session,
    required this.unit,
  });

  final List<TrackPoint> points;
  final StoredSession session;
  final SpeedUnit unit;

  @override
  Widget build(BuildContext context) {
    final latLngs =
        points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final speeds = _speedSeries();
    final elevations = points.map((p) => p.altitudeM).toList();
    final maxSpeed = speeds.isEmpty ? 0.0 : speeds.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(latLngs),
                    padding: const EdgeInsets.all(48),
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
                    userAgentPackageName: 'com.shahnewaz.groundspeed',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: latLngs,
                        strokeWidth: 3.5,
                        color: GsColors.accent,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      _dot(latLngs.first, GsColors.inkDim),
                      _dot(latLngs.last, GsColors.accent),
                    ],
                  ),
                ],
              ),
              const Positioned(
                right: 8,
                bottom: 6,
                child: Text(
                  '© OpenStreetMap · CARTO',
                  style: TextStyle(fontSize: 9, color: GsColors.inkFaint),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _stat('DIST', formatDistance(session.distanceM)),
                    _stat('MOVE', formatMovingTime(session.moveSeconds)),
                    _stat(
                      'AVG',
                      formatSpeed(session.avgMovingSpeedMps, unit),
                    ),
                    _stat('MAX', formatSpeed(session.maxSpeedMps, unit)),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'SPEED · ${unit.label}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.2,
                    color: GsColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 6),
                LineChart(
                  samples: speeds.map((s) => s * unit.factor).toList(),
                  height: 84,
                  valueSuffix: '',
                ),
                const SizedBox(height: 16),
                Text(
                  'ELEVATION · ${unit == SpeedUnit.mph ? 'FT' : 'M'}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.2,
                    color: GsColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 6),
                LineChart(
                  samples: unit == SpeedUnit.mph
                      ? elevations
                          .map((e) => e * 3.2808398950131)
                          .toList()
                      : elevations,
                  color: GsColors.amber,
                  height: 72,
                ),
                const SizedBox(height: 8),
                Text(
                  'PEAK ${formatSpeed(maxSpeed, unit)} ${unit.label} · ${points.length} POINTS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: GsColors.ink.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Marker _dot(LatLng point, Color color) {
    return Marker(
      point: point,
      width: 14,
      height: 14,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: GsColors.background, width: 2),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: GsColors.inkFaint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: GsColors.ink,
              fontFeatures: GsColors.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  List<double> _speedSeries() {
    final speeds = <double>[0];
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final dt = cur.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
      if (dt <= 0 || dt > 30) {
        speeds.add(speeds.last);
        continue;
      }
      final d = haversineMeters(
        prev.latitude,
        prev.longitude,
        cur.latitude,
        cur.longitude,
      );
      speeds.add(d / dt);
    }
    return speeds;
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: GsColors.inkFaint),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: GsColors.inkDim),
            ),
          ],
        ),
      ),
    );
  }
}
