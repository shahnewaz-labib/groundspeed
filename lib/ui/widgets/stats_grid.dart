import 'package:flutter/material.dart';

import '../theme.dart';

class StatTileData {
  const StatTileData(this.label, this.value, {this.muted = false});
  final String label;
  final String value;
  final bool muted;
}

/// Two rows of three stat tiles with hairline separators. The second row
/// renders dimmer for secondary metrics.
class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.tiles});

  /// Exactly six tiles: row-major.
  final List<StatTileData> tiles;

  @override
  Widget build(BuildContext context) {
    assert(tiles.length == 6, 'StatsGrid expects six tiles');
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _tile(tiles[0], primary: true)),
              const _Divider(),
              Expanded(child: _tile(tiles[1], primary: true)),
              const _Divider(),
              Expanded(child: _tile(tiles[2], primary: true)),
            ],
          ),
        ),
        Container(height: 1, color: GsColors.hairline),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _tile(tiles[3], primary: false)),
              const _Divider(),
              Expanded(child: _tile(tiles[4], primary: false)),
              const _Divider(),
              Expanded(child: _tile(tiles[5], primary: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(StatTileData tile, {required bool primary}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tile.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
              color: primary ? GsColors.inkFaint : GsColors.hairline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tile.value,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: TextStyle(
              fontSize: primary
                  ? (tile.value.length > 8 ? 15 : 19)
                  : (tile.value.length > 8 ? 13 : 15),
              fontWeight: FontWeight.w500,
              color: primary ? GsColors.ink : GsColors.inkDim,
              fontFeatures: GsColors.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: GsColors.hairline);
  }
}
