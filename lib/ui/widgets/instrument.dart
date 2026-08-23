import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/units.dart';
import '../theme.dart';

/// Status dot + label describing the GNSS link quality.
class StatusPill extends StatefulWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.pulsing = false,
  });

  final String label;
  final Color tone;
  final bool pulsing;

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0.35,
    upperBound: 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulsing) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing == oldWidget.pulsing) return;
    if (widget.pulsing) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: GsColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: GsColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _pulse,
            child: Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: widget.tone, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: GsColors.inkDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The giant speed number with unit caption underneath.
class SpeedReadout extends StatelessWidget {
  const SpeedReadout({
    super.key,
    required this.text,
    required this.unitLabel,
    required this.ready,
    this.fontSize,
  });

  final String text;
  final String unitLabel;
  final bool ready;

  /// Overrides automatic sizing (used when the heading ring constrains us).
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize ?? math.min(
                MediaQuery.sizeOf(context).shortestSide * 0.42,
                172,
              ),
              height: 1.0,
              fontWeight: FontWeight.w200,
              letterSpacing: -5,
              color: ready ? GsColors.ink : GsColors.inkFaint,
              fontFeatures: GsColors.tabularFigures,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          unitLabel,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 7,
            color: GsColors.inkDim,
          ),
        ),
      ],
    );
  }
}

/// Minimal sparkline of the recent filtered-speed window.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.samples});

  final List<double> samples;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: CustomPaint(painter: _SparklinePainter(samples)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.samples);

  final List<double> samples;

  static const _stroke = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) {
      _paintBaseline(canvas, size);
      return;
    }

    var peak = samples.reduce(math.max);
    if (peak <= 0 || peak.isNaN) peak = 1;
    peak *= 1.08;

    final stepX = samples.length == 1
        ? size.width
        : size.width / (samples.length - 1);

    Offset pointAt(int i) {
      final x = i * stepX;
      final y = size.height -
          _stroke -
          (samples[i].clamp(0, peak) / peak) * (size.height - _stroke * 2);
      return Offset(x, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < samples.length; i++) {
      line.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    // Soft fill under the trace.
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
            GsColors.accent.withValues(alpha: 0.16),
            GsColors.accent.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = GsColors.hairline,
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = GsColors.accent,
    );
  }

  void _paintBaseline(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = GsColors.hairline,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      !identical(oldDelegate.samples, samples);
}

/// Underlined segmented control for switching display units.
class UnitSwitcher extends StatelessWidget {
  const UnitSwitcher({
    super.key,
    required this.units,
    required this.selected,
    required this.onChanged,
  });

  final List<SpeedUnit> units;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < units.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Column(
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 3.5,
                      color: i == selected ? GsColors.ink : GsColors.inkFaint,
                    ),
                    child: Text(units[i].label),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: 2,
                    margin: EdgeInsets.symmetric(horizontal: i == selected ? 18 : 42),
                    decoration: BoxDecoration(
                      color: i == selected ? GsColors.accent : GsColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
