import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void showWebBrowserNotification({
  required String title,
  required String body,
  required String tag,
  String? icon,
}) {
  try {
    globalContext.callMethod(
      'showWebNotification'.toJS,
      title.toJS,
      body.toJS,
      tag.toJS,
      (icon != null && icon.isNotEmpty ? icon : '/favicon.png').toJS,
    );
  } catch (_) {}
}

bool isIOSWebBrowser() {
  try {
    final res = globalContext.callMethod('isIOSDevice'.toJS);
    if (res != null) {
      return (res as JSBoolean).toDart;
    }
  } catch (_) {}
  return false;
}

bool isStandalonePWA() {
  try {
    final res = globalContext.callMethod('isPWAStandalone'.toJS);
    if (res != null) {
      return (res as JSBoolean).toDart;
    }
  } catch (_) {}
  return false;
}

Future<String> getNotificationPermissionStatus() async {
  try {
    final res = globalContext.callMethod('getWebNotificationStatus'.toJS);
    if (res != null) {
      return (res as JSString).toDart;
    }
  } catch (_) {}
  return 'unsupported';
}

Future<String> requestNotificationPermission() async {
  final completer = Completer<String>();
  try {
    final callback = ((JSAny? status) {
      if (!completer.isCompleted) {
        final statusStr = (status as JSString?)?.toDart ?? 'denied';
        completer.complete(statusStr);
      }
    }).toJS;

    globalContext.callMethod(
      'requestWebNotificationPermission'.toJS,
      callback,
    );

    // Timeout fallback after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.complete('timeout');
      }
    });
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete('denied');
    }
  }
  return completer.future;
}
