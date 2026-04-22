import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/launch_record.dart';

class HistoryService {
  static const _fileName = 'dongxin_history.json';
  static const _maxRecords = 200;

  static List<LaunchRecord>? _cache;

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<LaunchRecord>> load() async {
    if (_cache != null) return _cache!;
    try {
      final f = await _file;
      if (!await f.exists()) return _cache = [];
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List;
      _cache = list
          .map((e) => LaunchRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      return _cache!;
    } catch (e) {
      debugPrint('HistoryService.load error: $e');
      return _cache = [];
    }
  }

  static Future<void> save(LaunchRecord record) async {
    final records = await load();
    records.removeWhere((r) => r.id == record.id);
    records.insert(0, record);
    if (records.length > _maxRecords) {
      records.removeRange(_maxRecords, records.length);
    }
    _cache = records;
    await _persist();
  }

  static Future<void> _persist() async {
    try {
      final f = await _file;
      final json = jsonEncode(_cache!.map((r) => r.toJson()).toList());
      await f.writeAsString(json);
    } catch (e) {
      debugPrint('HistoryService._persist error: $e');
    }
  }

  static Future<void> delete(String id) async {
    final records = await load();
    records.removeWhere((r) => r.id == id);
    _cache = records;
    await _persist();
  }
}
