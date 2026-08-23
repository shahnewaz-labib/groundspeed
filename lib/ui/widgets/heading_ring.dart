import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Compass-style ring drawn around the speed readout while in motion.
///
/// A 270° arc with 15° ticks, cardinal labels, and an accent needle
/// pointing at course-over-ground. Purely decorative below 5°/s of turn —
/// it simply follows [headingDeg].
class HeadingRing extends StatelessWidget {
  const HeadingRing({super.key, required this.headingDeg});

  final double headingDeg;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            math.min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox(
          width: side,
          height: side,
          child: CustomPaint(painter: _HeadingRingPainter(headingDeg)),
        );
      },
    );
  }
}

class _HeadingRingPainter extends CustomPainter {
  _HeadingRingPainter(this.headingDeg);

  final double headingDeg;

  static const _startDeg = 135.0;
  static const _sweepDeg = 270.0;
  static const _stroke = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 10;

    // Main arc.
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = GsColors.hairline
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _deg2rad(_startDeg),
      _deg2rad(_sweepDeg),
      false,
      arcPaint,
    );

    // Ticks every 15°, stronger every 45°.
    for (var deg = 0.0; deg < 360; deg += 15) {
      if (!_withinSweep(deg)) continue;
      final major = deg % 45 == 0;
      final tickPaint = Paint()
        ..strokeWidth = major ? 1.8 : 1.0
        ..color = major ? GsColors.inkFaint : GsColors.hairline;
      final dir = _unitVector(deg);
      canvas.drawLine(
        center + dir * (radius - (major ? 12.0 : 7.0)),
        center + dir * radius,
        tickPaint,
      );
    }

    // Cardinal letters.
    final labels = {0.0: 'N', 90.0: 'E', 180.0: 'S', 270.0: 'W'};
    for (final entry in labels.entries) {
      final deg = entry.key;
      if (!_withinSweep(deg)) continue;
      final dir = _unitVector(deg);
      final pos = center + dir * (radius - 26);
      final tp = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: TextStyle(
            fontSize: deg == 0 ? 13.0 : 11.0,
            fontWeight: FontWeight.w600,
            color: deg == 0 ? GsColors.accent : GsColors.inkDim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - tp.size.center(Offset.zero));
    }

    // Needle wedge pointing at course over ground.
    final needleAngle =
        _startDeg + (headingDeg % 360) / 360 * _sweepDeg;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_deg2rad(needleAngle));
    final needle = Path()
      ..moveTo(radius - 3, 0)
      ..lineTo(radius - 14, -5)
      ..lineTo(radius - 14, 5)
      ..close();
    canvas.drawPath(needle, Paint()..color = GsColors.accent);
    canvas.restore();
  }

  bool _withinSweep(double deg) {
    var d = deg - _startDeg;
    while (d < 0) {
      d += 360;
    }
    return d <= _sweepDeg;
  }

  Offset _unitVector(double compassDeg) {
    // Compass 0° = up, clockwise.
    final rad = _deg2rad(compassDeg - 90);
    return Offset(math.cos(rad), math.sin(rad));
  }

  double _deg2rad(double deg) => deg * math.pi / 180.0;

  @override
  bool shouldRepaint(_HeadingRingPainter oldDelegate) =>
      oldDelegate.headingDeg != headingDeg;
}
