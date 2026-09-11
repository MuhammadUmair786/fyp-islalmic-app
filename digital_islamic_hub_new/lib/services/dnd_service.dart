import 'package:flutter/services.dart';

class DndService {
  static const MethodChannel _channel = MethodChannel('dnd_channel');

  static Future<bool> isNotificationPolicyAccessGranted() async {
    try {
      final bool? isGranted = await _channel.invokeMethod('checkDndPermission');
      return isGranted ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationPolicySettings() async {
    try {
      await _channel.invokeMethod('openDndSettings');
    } on PlatformException catch (_) {}
  }

  static Future<bool> enableDnd() async {
    try {
      final bool? success = await _channel.invokeMethod('enableDND');
      return success ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> disableDnd() async {
    try {
      final bool? success = await _channel.invokeMethod('disableDND');
      return success ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
