import 'package:flutter/material.dart';

import '../data/gnss_service.dart';
import '../data/models.dart';
import 'theme.dart';
import 'widgets/sky_view.dart';

Future<void> showSignalSheet(BuildContext context, GnssService service) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GsColors.background,
    barrierColor: const Color(0xB2000000),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snapshot = service.snapshot;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GsColors.hairline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      snapshot.satelliteMonitorSupported
                          ? 'SIGNAL · ${snapshot.satsUsed}/${snapshot.satsTotal} USED'
                          : 'SIGNAL',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: GsColors.ink,
                      ),
                    ),
                  ],
                ),
                if (!snapshot.satelliteMonitorSupported)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Constellation telemetry needs Android; speed and '
                      'distance work identically on both platforms.',
                      style:
                          TextStyle(fontSize: 13, height: 1.5, color: GsColors.inkDim),
                    ),
                  )
                else ...[
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: Center(child: SkyView(satellites: snapshot.satellites)),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      for (final c in _presentConstellations(snapshot.satellites))
                        _legend(c),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Filled = used in fix · hollow = tracked · size/brightness = signal strength',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      letterSpacing: 0.2,
                      color: GsColors.ink.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

List<String> _presentConstellations(List<SatelliteInfo> sats) {
  final seen = <String>{};
  for (final s in sats) {
    seen.add(s.constellation);
  }
  return constellationOrder.where(seen.contains).toList();
}

Widget _legend(String constellation) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: constellationColor(constellation),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        constellation == 'GLONASS' ? 'GLN' : constellation,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: GsColors.inkDim,
        ),
      ),
    ],
  );
}
