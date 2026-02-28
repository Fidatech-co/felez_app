import 'package:flutter/services.dart';

class ScreenProcessorException implements Exception {
  ScreenProcessorException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ScreenProcessorService {
  static const _channel = MethodChannel('screen_processor');

  Future<String> process(String imagePath) async {
    try {
      final output = await _channel.invokeMethod<String>(
        'processImage',
        {'path': imagePath},
      );
      if (output == null || output.isEmpty) {
        throw ScreenProcessorException('پردازش تصویر ناموفق بود.');
      }
      return output;
    } on PlatformException catch (error) {
      throw ScreenProcessorException(error.message ?? 'خطای ناشناخته در پردازش تصویر.');
    }
  }
}
