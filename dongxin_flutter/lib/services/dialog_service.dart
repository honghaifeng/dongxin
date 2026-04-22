import 'dart:async';

import 'package:flutter/services.dart';

class DialogEvent {
  DialogEvent({required this.event, required this.type, required this.data});

  final String event;
  final int type;
  final String data;
}

class DialogService {
  static const _method = MethodChannel('com.dongxin/dialog');
  static const _event = EventChannel('com.dongxin/dialog_events');

  static StreamSubscription? _subscription;
  static final _controller = StreamController<DialogEvent>.broadcast();
  static Stream<DialogEvent> get events => _controller.stream;
  static bool _listening = false;

  static String? lastError;

  static void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _subscription = _event.receiveBroadcastStream().listen(
      (data) {
        if (data is Map) {
          _controller.add(
            DialogEvent(
              event: (data['event'] ?? 'unknown').toString(),
              type: (data['type'] ?? 0) as int,
              data: (data['data'] ?? '').toString(),
            ),
          );
        }
      },
      onError: (e) {
        _controller.add(
          DialogEvent(event: 'error', type: -1, data: e.toString()),
        );
      },
    );
  }

  static Future<bool> init({
    required String appId,
    String appKey = '',
    required String token,
    String resourceId = 'volc.speech.dialog',
    String uid = 'dongxin_user',
  }) async {
    _ensureListening();
    lastError = null;
    try {
      final result = await _method.invokeMethod('init', {
        'appId': appId,
        'appKey': appKey,
        'token': token,
        'resourceId': resourceId,
        'uid': uid,
      });
      return result == true;
    } on PlatformException catch (e) {
      lastError = 'init: ${e.code} ${e.message}';
      return false;
    }
  }

  static Future<bool> start({
    String botName = '懂心',
    String systemRole = '',
    String speakingStyle = '',
    String model = '1.2.1.1',
    String speaker = '',
  }) async {
    lastError = null;
    try {
      final result = await _method.invokeMethod('start', {
        'botName': botName,
        'systemRole': systemRole,
        'speakingStyle': speakingStyle,
        'model': model,
        'speaker': speaker,
      });
      return result == true;
    } on PlatformException catch (e) {
      lastError = 'start: ${e.code} ${e.message}';
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      final result = await _method.invokeMethod('stop');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> destroy() async {
    try {
      final result = await _method.invokeMethod('destroy');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _listening = false;
  }
}
