import 'dart:io';
import 'dart:math';

import 'package:flutter_native_ocr/flutter_native_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

const Map<String, String> gaugeBoxLabels = {
  'fuel_level': 'سطح سوخت',
  'cool_temp': 'دما آب موتور',
  'sys_volt': 'ولتاژ سیستم',
  'oil_press': 'فشار روغن',
  'mach_hours': 'ساعت کارکرد',
  'rpm': 'دور موتور (RPM)',
};

const List<String> gaugeBoxOrder = [
  'fuel_level',
  'cool_temp',
  'sys_volt',
  'oil_press',
  'mach_hours',
  'rpm',
];

class GaugeOcrException implements Exception {
  GaugeOcrException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GaugeOcrService {
  GaugeOcrService({FlutterNativeOcr? ocr}) : _ocr = ocr ?? FlutterNativeOcr();

  final FlutterNativeOcr _ocr;

  Future<Map<String, String>> read(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw GaugeOcrException('تصویر پردازش‌شده پیدا نشد.');
    }

    final bytes = await file.readAsBytes();
    final picture = img.decodeImage(bytes);
    if (picture == null) {
      throw GaugeOcrException('فرمت تصویر پشتیبانی نمی‌شود.');
    }

    final tempDir = await getTemporaryDirectory();
    final results = <String, String>{};
    final tempFiles = <File>[];

    try {
      for (final entry in _boxes.entries) {
        final bounds = _bounds(entry.value, picture.width, picture.height);
        if (bounds.width <= 0 || bounds.height <= 0) {
          continue;
        }
        final crop = img.copyCrop(
          picture,
          x: bounds.left,
          y: bounds.top,
          width: bounds.width,
          height: bounds.height,
        );
        final cropFile = File('${tempDir.path}/gauge_${entry.key}_${DateTime.now().microsecondsSinceEpoch}.png');
        await cropFile.writeAsBytes(img.encodePng(crop));
        tempFiles.add(cropFile);

        final text = await _ocr.recognizeText(cropFile.path);
        final cleaned = _normalizeReading(entry.key, _cleanNumeric(text));
        if (cleaned.isNotEmpty) {
          results[entry.key] = cleaned;
        }
      }
    } catch (error) {
      throw GaugeOcrException('خطا در OCR گیج‌ها: $error');
    } finally {
      for (final temp in tempFiles) {
        if (await temp.exists()) {
          await temp.delete();
        }
      }
    }

    return results;
  }
}

class _GaugeBox {
  const _GaugeBox(this.y1, this.y2, this.x1, this.x2);

  final double y1;
  final double y2;
  final double x1;
  final double x2;
}

final Map<String, _GaugeBox> _boxes = {
  'fuel_level': _GaugeBox(298.0, 348.15, 606.51, 766.06),
  'cool_temp': _GaugeBox(298.0, 348.15, 20.72, 194.80),
  'sys_volt': _GaugeBox(378.55, 428.28, 20.72, 194.80),
  'oil_press': _GaugeBox(454.53, 511.18, 20.72, 194.80),
  'mach_hours': _GaugeBox(377.17, 429.67, 518.09, 739.14),
  'rpm': _GaugeBox(204.47, 256.97, 334.34, 462.82),
};

_Bounds _bounds(_GaugeBox box, int width, int height) {
  final top = min(box.y1, box.y2).round().clamp(0, height);
  final bottom = max(box.y1, box.y2).round().clamp(0, height);
  final left = min(box.x1, box.x2).round().clamp(0, width);
  final right = max(box.x1, box.x2).round().clamp(0, width);
  return _Bounds(left: left, top: top, right: right, bottom: bottom);
}

class _Bounds {
  const _Bounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => max(0, right - left);
  int get height => max(0, bottom - top);
}

String _cleanNumeric(String text) {
  final buffer = StringBuffer();
  var hasDecimal = false;
  for (final char in text.split('')) {
    if (char == '.' && !hasDecimal) {
      hasDecimal = true;
      buffer.write(char);
    } else if (RegExp(r'\d').hasMatch(char)) {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

String _normalizeReading(String name, String raw) {
  if (name == 'cool_temp' &&
      raw.length == 2 &&
      raw.startsWith('0') &&
      raw.trim().length == 2 &&
      !raw.contains('.')) {
    return raw.split('').reversed.join();
  }
  return raw;
}
