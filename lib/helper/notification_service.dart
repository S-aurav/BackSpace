import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../api/apis.dart';
import '../screens/chat_screen.dart';
import '../screens/group_chat_screen.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Initialize local notifications plugin
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final rawPayload = response.payload;
        if (rawPayload != null && rawPayload.isNotEmpty) {
          final nav = APIs.navigatorKey.currentState;
          if (nav != null) {
            final isGroup = rawPayload.startsWith('group:') || rawPayload.startsWith('group_');
            final cleanId = rawPayload.replaceAll(RegExp(r'^(group:|user:)'), '');

            if (isGroup) {
              final group = await APIs.getGroupById(cleanId) ?? await APIs.getGroupById('group_$cleanId');
              if (group != null) {
                nav.push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
                return;
              }
            }

            // Fallback 1: Try getGroupById first to prevent opening blank individual ChatScreen
            final group = await APIs.getGroupById(cleanId);
            if (group != null) {
              nav.push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
              return;
            }

            // Fallback 2: Direct User ChatScreen
            final senderUser = await APIs.getUserById(cleanId);
            if (senderUser != null) {
              nav.push(MaterialPageRoute(builder: (_) => ChatScreen(user: senderUser)));
            }
          }
        }
      },
    );

    _isInitialized = true;
    log('NotificationService initialized successfully');
  }

  // Helper to download image bytes for largeIcon avatar or big picture
  static Future<Uint8List?> _getImageBytes(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return null;
    }
    try {
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      log('Error downloading notification image: $e');
    }
    return null;
  }

  // Helper to crop rectangular image bytes into a smooth anti-aliased circular PNG avatar
  static Future<Uint8List?> _cropToCircle(Uint8List rawBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final size = image.width < image.height ? image.width : image.height;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final paint = Paint()..isAntiAlias = true;
      final radius = size / 2.0;

      // Draw anti-aliased circular clip mask
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius)),
      );

      // Center crop source image onto square canvas
      final srcRect = Rect.fromCenter(
        center: Offset(image.width / 2.0, image.height / 2.0),
        width: size.toDouble(),
        height: size.toDouble(),
      );
      final dstRect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

      canvas.drawImageRect(image, srcRect, dstRect, paint);

      final picture = recorder.endRecording();
      final circularImage = await picture.toImage(size, size);
      final byteData = await circularImage.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      log('Error cropping avatar to circle: $e');
      return rawBytes;
    }
  }

  // Display WhatsApp-style notification with circular profile avatar on left
  static Future<void> showMessageNotification({
    required String title,
    required String body,
    required String senderId,
    String? senderImage,
    String? photoUrl,
    bool isGroup = false,
  }) async {
    try {
      await initialize();

      // Download and crop sender's profile picture into a circular avatar
      final rawAvatarBytes = await _getImageBytes(senderImage);
      final avatarBytes = rawAvatarBytes != null
          ? await _cropToCircle(rawAvatarBytes)
          : null;

      // If photo message, download photo for expandable big picture
      final photoBytes = (photoUrl != null && photoUrl.startsWith('http'))
          ? await _getImageBytes(photoUrl)
          : null;

      // Create Person for Android Conversation / Messaging Style (WhatsApp layout)
      final person = Person(
        name: title,
        key: senderId,
        icon: avatarBytes != null ? ByteArrayAndroidIcon(avatarBytes) : null,
        important: true,
        bot: false,
      );

      StyleInformation styleInformation;
      if (photoBytes != null) {
        styleInformation = BigPictureStyleInformation(
          ByteArrayAndroidBitmap(photoBytes),
          hideExpandedLargeIcon: true,
          contentTitle: title,
          summaryText: body,
        );
      } else {
        styleInformation = MessagingStyleInformation(
          person,
          conversationTitle: isGroup ? title : null,
          groupConversation: isGroup,
          messages: [
            Message(
              body,
              DateTime.now(),
              person,
            ),
          ],
        );
      }

      final androidDetails = AndroidNotificationDetails(
        'chats_v2',
        'BackSpace Messages',
        channelDescription: 'Notifications for incoming messages and stories',
        importance: Importance.max,
        priority: Priority.max,
        color: const Color(0xFF007AFF),
        largeIcon: avatarBytes != null ? ByteArrayAndroidBitmap(avatarBytes) : null,
        styleInformation: styleInformation,
        tag: senderId,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        ticker: '$title: $body',
        channelShowBadge: true,
        subText: isGroup ? 'Group Chat' : 'BackSpace',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notifId = senderId.hashCode;
      await _localNotifications.show(
        notifId,
        title,
        body,
        notificationDetails,
        payload: isGroup ? 'group:$senderId' : 'user:$senderId',
      );
    } catch (e) {
      log('Error showing notification: $e');
    }
  }
}
