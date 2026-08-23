import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gpx.dart';
import 'models.dart';

/// Persists trip tracks as GPX files in the app documents directory with a
/// lightweight JSON index in SharedPreferences.
class SessionStore {
  static const _indexKey = 'groundspeed.session.index';
  static const _dirName = 'tracks';

  Future<Directory> _directory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_dirName');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Writes the GPX file and appends the index entry. Returns stored meta.
  Future<StoredSession> save(SessionTrack session) async {
    final dir = await _directory();
    final stamp = session.startedAt
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final file = '$stamp.gpx';
    File('${dir.path}/$file').writeAsStringSync(
      buildGpx(name: session.name, points: session.points),
      flush: true,
    );
    final entry = StoredSession(
      file: file,
      name: session.name,
      startedAt: session.startedAt,
      distanceM: session.distanceM,
      moveSeconds: session.moveSeconds,
      maxSpeedMps: session.maxSpeedMps,
      pointCount: session.points.length,
    );
    final index = await list();
    index.insert(0, entry);
    await _writeIndex(index);
    return entry;
  }

  /// Newest first.
  Future<List<StoredSession>> list() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<Object?>;
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(StoredSession.fromJson)
          .toList();
    } on Exception {
      return const [];
    }
  }

  /// Deletes the GPX file and its index entry.
  Future<void> delete(StoredSession session) async {
    try {
      final dir = await _directory();
      final f = File('${dir.path}/${session.file}');
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException catch (e) {
      debugPrint('SessionStore.delete: $e');
    }
    final index = await list()
      ..removeWhere((s) => s.file == session.file);
    await _writeIndex(index);
  }

  /// Absolute path for sharing a stored GPX.
  Future<String> pathOf(StoredSession session) async {
    final dir = await _directory();
    return '${dir.path}/${session.file}';
  }

  Future<void> _writeIndex(List<StoredSession> index) async {
    final prefs = await SharedPreferences.getInstance();
    final capped = index.take(100).toList();
    await prefs.setString(
      _indexKey,
      jsonEncode(capped.map((s) => s.toJson()).toList()),
    );
  }
}
