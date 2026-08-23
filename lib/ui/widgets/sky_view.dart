import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../theme.dart';

const constellationOrder = [
  'GPS',
  'GLONASS',
  'GALILEO',
  'BEIDOU',
  'QZSS',
  'SBAS',
  'NAVIC',
  'UNKNOWN',
];

Color constellationColor(String c) => switch (c) {
      'GPS' => GsColors.accent,
      'GLONASS' => GsColors.amber,
      'GALILEO' => const Color(0xFF6FA8FF),
      'BEIDOU' => GsColors.red,
      'QZSS' => const Color(0xFFB58CFF),
      'NAVIC' => const Color(0xFFFF9E80),
      _ => GsColors.inkDim,
    };

/// Polar sky plot: azimuth rotates, elevation shrinks the radius.
/// Used satellites are filled dots; unused ones are hollow.
class SkyView extends StatelessWidget {
  const SkyView({super.key, required this.satellites});

  final List<SatelliteInfo> satellites;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            math.min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox(
          width: side,
          height: side,
          child: CustomPaint(painter: _SkyPainter(satellites)),
        );
      },
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.satellites);

  final List<SatelliteInfo> satellites;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 6;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = GsColors.hairline;

    for (final f in [1.0, 2.0 / 3, 1.0 / 3]) {
      canvas.drawCircle(center, radius * f, grid);
    }
    canvas.drawLine(center - Offset(radius, 0), center + Offset(radius, 0), grid);
    canvas.drawLine(center - Offset(0, radius), center + Offset(0, radius), grid);

    // North marker.
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: GsColors.accent,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - radius - 14));

    for (final sat in satellites) {
      if (sat.snrDb <= 0 && !sat.usedInFix) continue;
      final el = sat.elevationDeg.clamp(0, 90).toDouble();
      final r = radius * (1 - el / 90);
      final azRad = sat.azimuthDeg * math.pi / 180;
      final pos = Offset(
        center.dx + r * math.sin(azRad),
        center.dy - r * math.cos(azRad),
      );
      final strength = (sat.snrDb / 45).clamp(0.25, 1.0);
      final color = constellationColor(sat.constellation);
      final fill = Paint()
        ..color = sat.usedInFix
            ? color.withValues(alpha: 0.35 + 0.55 * strength)
            : GsColors.background.withValues(alpha: 0.85);
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sat.usedInFix ? 1 : 1.4
        ..color =
            sat.usedInFix ? GsColors.background.withValues(alpha: 0.4) : color;
      canvas.drawCircle(pos, 2.5 + 2.5 * strength, fill);
      canvas.drawCircle(pos, 2.5 + 2.5 * strength, outline);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) =>
      !identical(oldDelegate.satellites, satellites);
}
