import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/units.dart';
import '../data/models.dart';
import '../data/session_store.dart';
import 'theme.dart';

Future<void> showHistorySheet(
  BuildContext context,
  SessionStore store,
  SpeedUnit unit,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GsColors.background,
    barrierColor: const Color(0xB2000000),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _HistorySheet(store: store, unit: unit),
  );
}

class _HistorySheet extends StatefulWidget {
  const _HistorySheet({required this.store, required this.unit});

  final SessionStore store;
  final SpeedUnit unit;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late Future<List<StoredSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.list();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.store.list());
  }

  Future<void> _share(StoredSession s) async {
    try {
      final path = await widget.store.pathOf(s);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: s.name),
      );
    } on Exception catch (e) {
      debugPrint('share failed: $e');
    }
  }

  Future<void> _delete(StoredSession s) async {
    await widget.store.delete(s);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 12, 12),
          child: Column(
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
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 16, 12, 6),
                child: Text(
                  'TRIPS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: GsColors.ink,
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<StoredSession>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: GsColors.accent,
                        ),
                      );
                    }
                    final sessions = snapshot.data ?? const <StoredSession>[];
                    if (sessions.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 12, right: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.route_outlined,
                              size: 36,
                              color: GsColors.inkFaint,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No trips yet.\nTap the bookmark while tracking to save one as GPX.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: GsColors.ink.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      itemCount: sessions.length,
                      separatorBuilder: (_, _) =>
                          Container(height: 1, color: GsColors.hairline),
                      itemBuilder: (context, i) =>
                          _row(context, sessions[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, StoredSession s) {
    final dateLabel =
        '${s.startedAt.year}-${_two(s.startedAt.month)}-${_two(s.startedAt.day)}';
    final timeLabel =
        '${_two(s.startedAt.hour)}:${_two(s.startedAt.minute)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateLabel · $timeLabel',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: GsColors.ink,
                    fontFeatures: GsColors.tabularFigures,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDistance(s.distanceM)} · '
                  '${formatMovingTime(s.moveSeconds)} moving · '
                  'avg ${formatSpeed(s.avgMovingSpeedMps, widget.unit)} '
                  '${widget.unit.label.toLowerCase()} · '
                  'max ${formatSpeed(s.maxSpeedMps, widget.unit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: GsColors.ink.withValues(alpha: 0.45),
                    fontFeatures: GsColors.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _share(s),
            icon: const Icon(Icons.ios_share, size: 18),
            color: GsColors.inkDim,
            tooltip: 'Share GPX',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _delete(s),
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: GsColors.inkFaint,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}
