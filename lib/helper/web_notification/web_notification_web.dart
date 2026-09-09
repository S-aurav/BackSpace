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
