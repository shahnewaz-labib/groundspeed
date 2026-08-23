import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Axis-less line chart for post-trip speed / elevation series.
/// Draws a soft fill under the curve plus min/max value labels.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.samples,
    this.color = GsColors.accent,
    this.height = 72,
    this.valueSuffix = '',
  });

  final List<double> samples;
  final Color color;
  final double height;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final maxText = samples.isEmpty
        ? ''
        : '${_fmt(samples.reduce(math.max))}$valueSuffix';
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _LineChartPainter(samples, color)),
          ),
          if (maxText.isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                maxText,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: color.withValues(alpha: 0.8),
                  fontFeatures: GsColors.tabularFigures,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100) return v.round().toString();
    return v.toStringAsFixed(v >= 10 ? 1 : 2);
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.samples, this.color);

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = GsColors.hairline,
    );
    if (samples.length < 2) return;

    var peak = samples.reduce(math.max);
    if (peak <= 0 || peak.isNaN) peak = 1;
    peak *= 1.12;

    final stepX = size.width / (samples.length - 1);
    final usable = size.height - 6;
    Offset pointAt(int i) {
      final y = size.height -
          3 -
          (samples[i].clamp(0, peak) / peak) * usable;
      return Offset(i * stepX, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < samples.length; i++) {
      line.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      !identical(oldDelegate.samples, samples) || oldDelegate.color != color;
}
