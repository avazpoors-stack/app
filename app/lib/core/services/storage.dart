import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// ذخیره‌سازی کلید-مقدار — قرارداد اینترفیس (نقشهٔ راه ۲.۵).
/// پیاده‌سازی‌ها: حافظه (تست) و فایل (دستگاه).
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class InMemoryStore implements KeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}

class FileStore implements KeyValueStore {
  FileStore(this.directory);

  final String directory;

  String _pathFor(String key) => '$directory/$key';

  Future<void> _ensureDir() async {
    final dir = Directory(directory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  @override
  Future<String?> read(String key) async {
    final file = File(_pathFor(key));
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String value) async {
    await _ensureDir();
    await File(_pathFor(key)).writeAsString(value, flush: true);
  }

  @override
  Future<void> remove(String key) async {
    final file = File(_pathFor(key));
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// کانال ارتباط با اندروید — مسیر ذخیره‌سازی اختصاصی اپ.
class StorageChannel {
  static const MethodChannel _channel = MethodChannel('ir.badane/storage');

  static Future<String?> getFilesDir() async {
    try {
      return await _channel.invokeMethod<String>('getFilesDir');
    } on MissingPluginException {
      return null;
    }
  }
}

/// ساعت تزریق‌پذیر — برای تست مرز شبانه‌روز و ثابت‌نگه‌داشتن زمان.
class Clock {
  Clock({DateTime? fixed}) : _fixed = fixed;

  final DateTime? _fixed;

  DateTime now() => _fixed ?? DateTime.now();

  static String dateStr(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}
