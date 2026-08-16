import 'package:flutter/material.dart';

class MyDateUtil {
  // Threshold in milliseconds to consider a user online (120 seconds / 2 mins)
  static const int onlineThresholdMs = 120000;

  /// Robust check if a user is currently online.
  /// User must have is_online == true AND have sent a heartbeat/activity within 90 seconds.
  static bool isUserOnline({
    required bool isOnline,
    required String lastActive,
  }) {
    if (!isOnline) return false;
    final int lastActiveMs = int.tryParse(lastActive) ?? -1;
    if (lastActiveMs == -1) return false;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    return (nowMs - lastActiveMs).abs() <= onlineThresholdMs;
  }

  // for getting formatted time from milliSecondsSinceEpochs String
  static String getFormattedTime(
      {required BuildContext context, required String time}) {
    final date = DateTime.fromMillisecondsSinceEpoch(int.parse(time));
    return TimeOfDay.fromDateTime(date).format(context);
  }

  // for getting formatted time for sent & read
  static String getMessageTime(
      {required BuildContext context, required String time}) {
    final DateTime sent = DateTime.fromMillisecondsSinceEpoch(int.parse(time));
    final DateTime now = DateTime.now();

    final formattedTime = TimeOfDay.fromDateTime(sent).format(context);
    if (now.day == sent.day &&
        now.month == sent.month &&
        now.year == sent.year) {
      return formattedTime;
    }

    return now.year == sent.year
        ? '$formattedTime - ${sent.day} ${_getMonth(sent)}'
        : '$formattedTime - ${sent.day} ${_getMonth(sent)} ${sent.year}';
  }

  // get last message time (used in chat user card)
  static String getLastMessageTime(
      {required BuildContext context,
      required String time,
      bool showYear = false}) {
    final int timestamp = int.tryParse(time) ?? -1;
    if (timestamp == -1) return '';

    final DateTime sent = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();

    if (now.day == sent.day &&
        now.month == sent.month &&
        now.year == sent.year) {
      return TimeOfDay.fromDateTime(sent).format(context);
    }

    // Yesterday check
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.day == sent.day &&
        yesterday.month == sent.month &&
        yesterday.year == sent.year) {
      return 'Yesterday';
    }

    return showYear
        ? '${sent.day} ${_getMonth(sent)} ${sent.year}'
        : '${sent.day} ${_getMonth(sent)}';
  }

  // get formatted last active time of user in chat screen & profile
  static String getLastActiveTime({
    required BuildContext context,
    required String lastActive,
    bool isOnline = false,
  }) {
    // 1. If user is actively online within threshold
    if (isUserOnline(isOnline: isOnline, lastActive: lastActive)) {
      return 'Online';
    }

    final int timestamp = int.tryParse(lastActive) ?? -1;
    if (timestamp == -1) return 'Offline';

    final DateTime time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();

    final diff = now.difference(time);
    if (diff.inSeconds < 120 && diff.inSeconds >= 0) {
      return 'Last seen just now';
    }

    final String formattedTime = TimeOfDay.fromDateTime(time).format(context);

    // Today
    if (time.day == now.day &&
        time.month == now.month &&
        time.year == now.year) {
      return 'Last seen today at $formattedTime';
    }

    // Yesterday
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (time.day == yesterday.day &&
        time.month == yesterday.month &&
        time.year == yesterday.year) {
      return 'Last seen yesterday at $formattedTime';
    }

    final String month = _getMonth(time);

    // Same year
    if (time.year == now.year) {
      return 'Last seen on ${time.day} $month at $formattedTime';
    }

    // Different year
    return 'Last seen on ${time.day} $month ${time.year} at $formattedTime';
  }

  // get month name from month no. or index
  static String _getMonth(DateTime date) {
    switch (date.month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sept';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
    }
    return 'NA';
  }
}