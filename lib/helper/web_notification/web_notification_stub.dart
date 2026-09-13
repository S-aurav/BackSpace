import 'package:firebase_messaging/firebase_messaging.dart';

void showWebBrowserNotification({
  required String title,
  required String body,
  required String tag,
  String? icon,
}) {}

bool isIOSWebBrowser() => false;

bool isStandalonePWA() => false;

Future<String> getNotificationPermissionStatus() async {
  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      return 'granted';
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return 'denied';
    }
    return 'prompt';
  } catch (_) {
    return 'prompt';
  }
}

Future<String> requestNotificationPermission() async {
  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      return 'granted';
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return 'denied';
    }
    return 'prompt';
  } catch (_) {
    return 'denied';
  }
}
