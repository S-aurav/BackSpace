import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_compress/video_compress.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config_models.dart';
import '../models/chat_user.dart';
import '../models/gif_item.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/story.dart';
import '../screens/chat_screen.dart';
import '../screens/group_chat_screen.dart';
import '../widgets/in_app_notification_banner.dart';

class APIs {
  // Cached KLIPY API key
  static String? _cachedKlipyApiKey;

  /// Fetches App Update Info and release notes from Firestore config/app_version
  static Future<AppUpdateInfo?> fetchAppUpdateInfo() async {
    try {
      final doc = await firestore.collection('config').doc('app_version').get();
      if (doc.exists && doc.data() != null) {
        final rawData = doc.data()!;
        final Map<String, dynamic> data = {};
        rawData.forEach((key, value) => data[key.trim()] = value);
        return AppUpdateInfo.fromJson(data);
      }
    } catch (e) {
      log('Error fetching app update info: $e');
    }
    return null;
  }

  /// Fetches Public Announcement from Firestore config/announcement
  /// Returns null if inactive, empty, or already dismissed by the user
  static Future<AppAnnouncement?> fetchPublicAnnouncement() async {
    try {
      final doc = await firestore.collection('config').doc('announcement').get();
      if (doc.exists && doc.data() != null) {
        final rawData = doc.data()!;
        final Map<String, dynamic> data = {};
        rawData.forEach((key, value) => data[key.trim()] = value);

        final announcement = AppAnnouncement.fromJson(data);
        if (!announcement.isActive || announcement.id.isEmpty) {
          return null;
        }

        final prefs = await SharedPreferences.getInstance();
        final dismissedId = prefs.getString('dismissed_announcement_id');
        if (dismissedId == announcement.id) {
          // User already dismissed this specific announcement
          return null;
        }

        return announcement;
      }
    } catch (e) {
      log('Error fetching public announcement: $e');
    }
    return null;
  }

  /// Marks a public announcement as dismissed so it is not shown again
  static Future<void> dismissAnnouncement(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dismissed_announcement_id', id);
    } catch (e) {
      log('Error dismissing announcement: $e');
    }
  }

  /// Retrieves the KLIPY API key dynamically:
  /// 1. In-memory cache
  /// 2. Compile-time --dart-define=KLIPY_API_KEY=...
  /// 3. Local SharedPreferences persistent cache
  /// 4. Firestore collection('config').doc('services')
  static Future<String> getKlipyApiKey() async {
    // 1. In-memory cache
    if (_cachedKlipyApiKey != null && _cachedKlipyApiKey!.isNotEmpty) {
      return _cachedKlipyApiKey!;
    }

    // 2. Compile-time --dart-define
    const envKey = String.fromEnvironment('KLIPY_API_KEY');
    if (envKey.isNotEmpty) {
      _cachedKlipyApiKey = envKey;
      return envKey;
    }

    // 3. Local SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final localKey = prefs.getString('cached_klipy_api_key');
      if (localKey != null && localKey.isNotEmpty) {
        _cachedKlipyApiKey = localKey;
        // Background refresh from Firestore without blocking
        _refreshKlipyApiKeyFromFirestore();
        return localKey;
      }
    } catch (e) {
      log('Error reading local KLIPY key: $e');
    }

    // 4. Fetch from Firestore
    return await _refreshKlipyApiKeyFromFirestore();
  }

  static Future<String> _refreshKlipyApiKeyFromFirestore() async {
    try {
      final doc = await firestore.collection('config').doc('services').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final key = (data['klipy_api_key'] ?? data['klipyApiKey'] ?? '').toString().trim();
        if (key.isNotEmpty) {
          _cachedKlipyApiKey = key;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_klipy_api_key', key);
          return key;
        }
      }
    } catch (e) {
      log('Error fetching remote KLIPY key: $e');
    }
    return _cachedKlipyApiKey ?? '';
  }

  // Cloudinary Configurations
  static const String cloudinaryCloudName = 'a9nbxo3b';
  static const String cloudinaryUploadPreset = 'backspace_app';
  static const String deleteProxyUrl = 'YOUR_CLOUDFLARE_WORKER_URL';
  static const String deleteProxyAuthToken = 'YOUR_PROXY_AUTH_TOKEN';

  // for authentication
  static FirebaseAuth auth = FirebaseAuth.instance;

  // for accessing cloud firestore database
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  // for accessing firebase storage
  static FirebaseStorage storage = FirebaseStorage.instance;

  // for storing self information
  static ChatUser me = ChatUser(
    id: auth.currentUser?.uid ?? '',
    name: auth.currentUser?.displayName ?? '',
    email: auth.currentUser?.email ?? '',
    about: "Hey, I'm using BackSpace!",
    image: auth.currentUser?.photoURL ?? '',
    createdAt: '',
    isOnline: false,
    lastActive: '',
    pushToken: '',
  );

  // to return current user
  static User get user => auth.currentUser!;

  // Global Navigator Key for context-free routing and top banner alerts
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Tracks currently opened chat user to avoid duplicate banners
  static String? activeChatUserId;

  // for accessing firebase messaging (Push Notification)
  static FirebaseMessaging fMessaging = FirebaseMessaging.instance;

  // for getting firebase messaging token & registering handlers
  static Future<void> getFirebaseMessagingToken() async {
    try {
      final settings = await fMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      log('User granted notification permission: ${settings.authorizationStatus}');

      await fMessaging.getToken().then((t) {
        if (t != null) {
          me.pushToken = t;
          log('Push Token: $t');
          if (auth.currentUser != null) {
            firestore.collection('users').doc(user.uid).update({'push_token': t});
          }
        }
      });

      // Handle Foreground FCM Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        log('Foreground FCM received: ${message.data}');
        final senderId = message.data['senderId'] ?? message.data['fromId'] ?? '';
        final type = message.data['type'] ?? 'chat';
        final isStory = type == 'story';
        final isGroupChat = type == 'group_chat';

        // If user is currently looking at this sender's chat, ignore banner
        if (!isStory && senderId.isNotEmpty && activeChatUserId == senderId) {
          return;
        }

        final title = message.data['title'] ?? message.notification?.title ?? 'New Message';
        final body = message.data['body'] ?? message.notification?.body ?? 'You received a message';
        final senderImage = message.data['senderImage'] ?? '';

        ChatUser? senderUser;
        if (isGroupChat) {
          final group = await getGroupById(senderId);
          InAppNotification.show(
            sender: ChatUser(
              id: senderId,
              name: title,
              email: '',
              about: 'Group Chat',
              image: senderImage,
              createdAt: '',
              isOnline: true,
              lastActive: '',
              pushToken: '',
            ),
            title: title,
            message: body,
            isStory: false,
            onTap: () async {
              final nav = navigatorKey.currentState;
              if (nav != null) {
                final targetGroup = group ?? await getGroupById(senderId);
                if (targetGroup != null) {
                  nav.push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: targetGroup)));
                }
              }
            },
          );
          return;
        } else if (senderId.isNotEmpty) {
          senderUser = await getUserById(senderId);
        }

        senderUser ??= ChatUser(
          id: senderId,
          name: title,
          email: '',
          about: '',
          image: senderImage,
          createdAt: '',
          isOnline: true,
          lastActive: '',
          pushToken: '',
        );

        InAppNotification.show(
          sender: senderUser,
          title: title,
          message: body,
          isStory: isStory,
        );
      });

      // Handle Background / System Tray Notification Tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        log('Notification opened app: ${message.data}');
        final type = message.data['type'] ?? '';
        final senderId = message.data['senderId'] ?? message.data['groupId'] ?? message.data['fromId'] ?? '';

        if (senderId.isNotEmpty) {
          final nav = navigatorKey.currentState;
          if (nav != null) {
            if (type == 'group_chat' || senderId.startsWith('group_')) {
              final group = await getGroupById(senderId);
              if (group != null) {
                nav.push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
                return;
              }
            }

            // Fallback group check before user lookup
            final group = await getGroupById(senderId);
            if (group != null) {
              nav.push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
              return;
            }

            if (type != 'story') {
              final senderUser = await getUserById(senderId);
              if (senderUser != null) {
                nav.push(MaterialPageRoute(builder: (_) => ChatScreen(user: senderUser)));
              }
            }
          }
        }
      });

      // Handle Terminated / Cold Start Notification Tap
      final initialMessage = await fMessaging.getInitialMessage();
      if (initialMessage != null) {
        log('Terminated notification launch: ${initialMessage.data}');
        final type = initialMessage.data['type'] ?? '';
        final senderId = initialMessage.data['senderId'] ?? initialMessage.data['groupId'] ?? initialMessage.data['fromId'] ?? '';

        if (senderId.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 750), () async {
            final nav = navigatorKey.currentState;
            if (nav != null) {
              if (type == 'group_chat' || senderId.startsWith('group_')) {
                final group = await getGroupById(senderId);
                if (group != null) {
                  nav.push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
                  return;
                }
              }

              // Fallback group check before user lookup
              final group = await getGroupById(senderId);
              if (group != null) {
                nav.push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
                return;
              }

              if (type != 'story') {
                final senderUser = await getUserById(senderId);
                if (senderUser != null) {
                  nav.push(MaterialPageRoute(builder: (_) => ChatScreen(user: senderUser)));
                }
              }
            }
          });
        }
      }
    } catch (e) {
      log('getFirebaseMessagingToken error: $e');
    }
  }

  static StreamSubscription? _inAppMessageSubscription;

  // Real-time Firestore stream listener for instant cross-chat in-app banners
  static void initInAppMessageListener() {
    _inAppMessageSubscription?.cancel();
    if (auth.currentUser == null) return;

    try {
      _inAppMessageSubscription = firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .snapshots()
          .listen((snapshot) async {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;
            final fromId = data['fromId'] ?? '';
            final fromName = data['fromName'] ?? 'New Message';
            final fromImage = data['fromImage'] ?? '';
            final msg = data['msg'] ?? '';
            final type = data['type'] ?? 'chat';
            final timestamp = int.tryParse(data['timestamp'] ?? '0') ?? 0;
            final now = DateTime.now().millisecondsSinceEpoch;

            // Only show if sent within the last 60 seconds (fresh)
            if ((now - timestamp).abs() < 60000) {
              // If user is currently looking at this sender's chat, ignore banner
              if (type != 'story' && activeChatUserId != null && activeChatUserId == fromId) {
                // Silenced
              } else {
                final context = navigatorKey.currentContext;
                if (context != null) {
                  final senderUser = ChatUser(
                    id: fromId,
                    name: fromName,
                    email: '',
                    about: '',
                    image: fromImage,
                    createdAt: '',
                    isOnline: true,
                    lastActive: '',
                    pushToken: '',
                  );

                  InAppNotification.show(
                    context: context,
                    sender: senderUser,
                    title: fromName,
                    message: msg,
                    isStory: type == 'story',
                  );
                }
              }
            }
            // Auto delete notification document to keep database clean
            change.doc.reference.delete();
          }
        }
      }, onError: (err) {
        log('initInAppMessageListener error: $err');
      });
    } catch (e) {
      log('Error starting initInAppMessageListener: $e');
    }
  }

  // for sending push notification
  static Future<void> sendPushNotification(
      ChatUser chatUser, String msg, {String type = 'chat'}) async {
    if (chatUser.pushToken.isEmpty) return;

    try {
      final body = {
        "to": chatUser.pushToken,
        "priority": "high",
        "notification": {
          "title": me.name,
          "body": msg,
          "android_channel_id": "chats",
          "sound": "default",
        },
        "data": {
          "click_action": "FLUTTER_NOTIFICATION_CLICK",
          "senderId": user.uid,
          "fromId": user.uid,
          "senderName": me.name,
          "type": type,
          "title": me.name,
          "body": msg,
        },
      };

      await post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader:
              'key=AAAAsPRItBA:APA91bFQgWvxdvzdTwlI3z7lYhph4QnoxDFWh0PvXFN5dIok1Wcl6aQgrMmq1WsGsxuxQjTayz14ECes-cwDZ0wijEqVU_GBRta-zPhVwUXVnZPG67nw4JzbI2e6XJXpEuzLINWXw266'
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      log('sendPushNotification error: $e');
    }
  }

  // Notify all added contacts when a new story is created
  static Future<void> notifyContactsAboutNewStory(bool isVideo) async {
    try {
      final myUsersSnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .get();

      final contactIds = myUsersSnapshot.docs.map((e) => e.id).toList();
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      final storyText = isVideo ? '🎬 Shared a new video story' : '📸 Shared a new photo story';

      for (final contactId in contactIds) {
        // Skip blocked contacts or contacts blocked from status
        if (me.blockedUsers.contains(contactId) || me.statusBlockedUsers.contains(contactId)) {
          log('Skipping story notification for blocked contact: $contactId');
          continue;
        }

        // Write in-app notification inbox doc
        firestore
            .collection('users')
            .doc(contactId)
            .collection('notifications')
            .doc(now)
            .set({
          'fromId': user.uid,
          'fromName': me.name,
          'fromImage': me.image,
          'msg': storyText,
          'type': 'story',
          'timestamp': now,
        });

        final contactUser = await getUserById(contactId);
        if (contactUser != null && contactUser.pushToken.isNotEmpty) {
          await sendPushNotification(contactUser, storyText, type: 'story');
        }
      }
    } catch (e) {
      log('notifyContactsAboutNewStory error: $e');
    }
  }

  // for checking if user exists or not?
  static Future<bool> userExists() async {
    return (await firestore.collection('users').doc(user.uid).get()).exists;
  }

  // for adding an chat user for our conversation
  static Future<bool> addChatUser(String email) async {
    final data = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    log('data: ${data.docs}');

    if (data.docs.isNotEmpty && data.docs.first.id != user.uid) {
      //user exists

      log('user exists: ${data.docs.first.data()}');

      firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .doc(data.docs.first.id)
          .set({});

      return true;
    } else {
      //user doesn't exists

      return false;
    }
  }

  // for directly adding a user to my_users by their user ID
  static Future<bool> addChatUserById(String userId) async {
    try {
      if (userId.isEmpty || userId == user.uid) return false;
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .doc(userId)
          .set({});
      return true;
    } catch (e) {
      log('Error addChatUserById: $e');
      return false;
    }
  }

  static StreamSubscription? _selfInfoSubscription;

  // for getting current user info in real-time
  static Future<void> getSelfInfo() async {
    _selfInfoSubscription?.cancel();
    _selfInfoSubscription = firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((userDoc) async {
      if (userDoc.exists && userDoc.data() != null) {
        me = ChatUser.fromJson(userDoc.data()!);
        log('Self Info Updated Real-Time: ${userDoc.data()}');
      } else {
        await createUser().then((value) => getSelfInfo());
      }
    });

    await getFirebaseMessagingToken();
    APIs.updateActiveStatus(true);
  }

  // for creating a new user
  static Future<void> createUser() async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();

    final chatUser = ChatUser(
        id: user.uid,
        name: user.displayName.toString(),
        email: user.email.toString(),
        about: "Hey, I'm using BackSpace!",
        image: user.photoURL.toString(),
        createdAt: time,
        isOnline: false,
        lastActive: time,
        pushToken: '');

    return await firestore
        .collection('users')
        .doc(user.uid)
        .set(chatUser.toJson());
  }

  // for getting id's of known users from firestore database
  static Stream<QuerySnapshot<Map<String, dynamic>>> getMyUsersId() {
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('my_users')
        .snapshots();
  }

  // for getting all users from firestore database
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers(
      List<String> userIds) {
    log('\nUserIds: $userIds');

    return firestore
        .collection('users')
        .where('id',
            whereIn: userIds.isEmpty
                ? ['']
                : userIds) //because empty list throws an error
        // .where('id', isNotEqualTo: user.uid)
        .snapshots();
  }

  // for adding an user to my user when first message is send
  static Future<void> sendFirstMessage(
      ChatUser chatUser, String msg, Type type) async {
    await firestore
        .collection('users')
        .doc(chatUser.id)
        .collection('my_users')
        .doc(user.uid)
        .set({}).then((value) => sendMessage(chatUser, msg, type));
  }

  // for updating user information
  static Future<void> updateUserInfo() async {
    await firestore.collection('users').doc(user.uid).update({
      'name': me.name,
      'about': me.about,
    });
  }

  // update profile picture of user
  static Future<void> updateProfilePicture(File file) async {
    final ext = file.path.split('.').last;
    log('Updating profile picture with Cloudinary, extension: $ext');

    final cloudinaryUrl = await uploadToCloudinary(
      file: file,
      filename: 'profile_${user.uid}.$ext',
      resourceType: 'image',
    );

    if (cloudinaryUrl != null) {
      me.image = cloudinaryUrl;
      await firestore
          .collection('users')
          .doc(user.uid)
          .update({'image': me.image});
      log('Profile picture updated successfully: $cloudinaryUrl');
    } else {
      log('Failed to upload profile picture to Cloudinary.');
    }
  }

  // for getting specific user info by user ID
  static Future<ChatUser?> getUserById(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return ChatUser.fromJson(doc.data()!);
      }
    } catch (e) {
      log('Error getUserById: $e');
    }
    return null;
  }

  // for getting specific user info
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(
      ChatUser chatUser) {
    return firestore
        .collection('users')
        .where('id', isEqualTo: chatUser.id)
        .snapshots();
  }

  static Timer? _heartbeatTimer;

  // Start periodic heartbeat while app is in foreground
  static void startHeartbeat() {
    stopHeartbeat();
    updateActiveStatus(true);
    // Send lightweight ping every 60 seconds to keep last_active fresh
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (auth.currentUser != null) {
        updateActiveStatus(true);
      }
    });
  }

  // Stop periodic heartbeat when app is paused/backgrounded/detached
  static void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // update online or last active status of user
  static Future<void> updateActiveStatus(bool isOnline) async {
    try {
      if (auth.currentUser == null) return;
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      await firestore.collection('users').doc(user.uid).update({
        'is_online': isOnline,
        'last_active': now,
        'push_token': me.pushToken,
      });
    } catch (e) {
      log('Error updating active status: $e');
    }
  }

  ///************** Chat Screen Related APIs **************

  // chats (collection) --> conversation_id (doc) --> messages (collection) --> message (doc)

  // useful for getting conversation id
  static String getConversationID(String id) => user.uid.hashCode <= id.hashCode
      ? '${user.uid}_$id'
      : '${id}_${user.uid}';

  // for getting all messages of a specific conversation from firestore database
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllMessages(
      ChatUser user) {
    return firestore
        .collection('chats/${getConversationID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .snapshots();
  }

  // for sending message (with optional quoted reply parameters)
  static Future<void> sendMessage(
    ChatUser chatUser,
    String msg,
    Type type, {
    String? replyToMsg,
    String? replyToSenderName,
    String? replyToType,
    String? replyToMediaUrl,
  }) async {
    //message sending time (also used as id)
    final time = DateTime.now().millisecondsSinceEpoch.toString();

    //message to send
    final Message message = Message(
      toId: chatUser.id,
      msg: msg,
      read: '',
      type: type,
      fromId: user.uid,
      sent: time,
      replyToMsg: replyToMsg,
      replyToSenderName: replyToSenderName,
      replyToType: replyToType,
      replyToMediaUrl: replyToMediaUrl,
    );

    final ref = firestore
        .collection('chats/${getConversationID(chatUser.id)}/messages/');
    await ref.doc(time).set(message.toJson());

    // Update last_message_time in both users' my_users collections for instant top sorting
    firestore
        .collection('users')
        .doc(user.uid)
        .collection('my_users')
        .doc(chatUser.id)
        .set({'last_message_time': time}, SetOptions(merge: true));

    firestore
        .collection('users')
        .doc(chatUser.id)
        .collection('my_users')
        .doc(user.uid)
        .set({'last_message_time': time}, SetOptions(merge: true));

    // Re-establish chat relationship: remove sender from recipient's blocked_users list
    // (chat becomes visible in recipient's chat list again, but sender remains status-blocked)
    firestore.collection('users').doc(chatUser.id).update({
      'blocked_users': FieldValue.arrayRemove([user.uid]),
    }).catchError((e) => log('Error re-establishing relationship: $e'));
  }

  //update read status of message
  static Future<void> updateMessageReadStatus(Message message) async {
    firestore
        .collection('chats/${getConversationID(message.fromId)}/messages/')
        .doc(message.sent)
        .update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
  }

  //get only last message of a specific chat
  static Stream<QuerySnapshot<Map<String, dynamic>>> getLastMessage(
      ChatUser user) {
    return firestore
        .collection('chats/${getConversationID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .limit(1)
        .snapshots();
  }

  // send chat GIF (direct KLIPY CDN streaming, zero Cloudinary storage)
  static Future<void> sendChatGif(
    ChatUser chatUser,
    GifItem gif, {
    String? replyToMsg,
    String? replyToSenderName,
    String? replyToType,
    String? replyToMediaUrl,
  }) async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();
    final Message message = Message(
      toId: chatUser.id,
      msg: gif.mediaUrl,
      read: '',
      type: Type.gif,
      fromId: user.uid,
      sent: time,
      replyToMsg: replyToMsg,
      replyToSenderName: replyToSenderName,
      replyToType: replyToType,
      replyToMediaUrl: replyToMediaUrl,
      gifId: gif.id,
      gifProvider: gif.provider,
      gifPreviewUrl: gif.previewUrl,
    );

    final ref = firestore
        .collection('chats/${getConversationID(chatUser.id)}/messages/');
    await ref.doc(time).set(message.toJson());

    firestore
        .collection('users')
        .doc(user.uid)
        .collection('my_users')
        .doc(chatUser.id)
        .set({'last_message_time': time}, SetOptions(merge: true));

    firestore
        .collection('users')
        .doc(chatUser.id)
        .collection('my_users')
        .doc(user.uid)
        .set({'last_message_time': time}, SetOptions(merge: true));
  }

  //send chat image
  static Future<void> sendChatImage(ChatUser chatUser, File file) async {
    final ext = file.path.split('.').last;

    final cloudinaryUrl = await uploadToCloudinary(
      file: file,
      filename: 'chat_${DateTime.now().millisecondsSinceEpoch}.$ext',
      resourceType: 'image',
    );

    if (cloudinaryUrl != null) {
      await sendMessage(chatUser, cloudinaryUrl, Type.image);
    } else {
      log('Failed to upload chat image to Cloudinary.');
    }
  }

  //send chat video with WhatsApp-style compression and quality retention
  static Future<void> sendChatVideo(ChatUser chatUser, File file) async {
    File uploadFile = file;

    try {
      final originalSize = (await file.length()) / (1024 * 1024);
      log('Original video size: ${originalSize.toStringAsFixed(2)}MB');

      // WhatsApp-style compression: 720p HD, high bitrate quality, standard AAC audio
      final mediaInfo = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo != null && mediaInfo.file != null) {
        final compressedSize = (await mediaInfo.file!.length()) / (1024 * 1024);
        log('Compressed video size: ${compressedSize.toStringAsFixed(2)}MB (Saved ${(100 - (compressedSize / originalSize * 100)).toStringAsFixed(1)}%)');
        uploadFile = mediaInfo.file!;
      }
    } catch (e) {
      log('Video compression exception, proceeding with original file: $e');
    }

    final ext = uploadFile.path.split('.').last;

    final cloudinaryUrl = await uploadToCloudinary(
      file: uploadFile,
      filename: 'video_${DateTime.now().millisecondsSinceEpoch}.$ext',
      resourceType: 'video',
    );

    // Clean up temporary local compression cache
    try {
      await VideoCompress.deleteAllCache();
    } catch (_) {}

    if (cloudinaryUrl != null) {
      await sendMessage(chatUser, cloudinaryUrl, Type.video);
    } else {
      log('Failed to upload chat video to Cloudinary.');
    }
  }

  // Generate Cloudinary video thumbnail URL
  static String getVideoThumbnailUrl(String videoUrl, {int width = 800}) {
    if (videoUrl.isEmpty) return videoUrl;
    if (videoUrl.contains('cloudinary.com') && videoUrl.contains('/upload/')) {
      final withoutExt = videoUrl.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.jpg');
      if (withoutExt.contains('/upload/so_0') || withoutExt.contains('/upload/f_auto')) {
        return withoutExt;
      }
      return withoutExt.replaceFirst('/upload/', '/upload/so_0,f_auto,q_auto,w_$width,c_limit/');
    }
    return videoUrl;
  }

  //delete message
  static Future<void> deleteMessage(Message message) async {
    await firestore
        .collection('chats/${getConversationID(message.toId)}/messages/')
        .doc(message.sent)
        .delete();

    if (message.type == Type.image || message.type == Type.video) {
      if (message.msg.contains('firebasestorage.googleapis.com')) {
        try {
          await storage.refFromURL(message.msg).delete();
        } catch (e) {
          log('Error deleting media from Firebase Storage: $e');
        }
      } else if (message.msg.contains('cloudinary.com')) {
        await deleteFromCloudinary(message.msg);
      }
    }
  }

  // helper method to delete image from Cloudinary via Cloudflare Worker proxy
  static Future<void> deleteFromCloudinary(String imageUrl) async {
    try {
      if (deleteProxyUrl == 'YOUR_CLOUDFLARE_WORKER_URL' || deleteProxyUrl.isEmpty) {
        log('Cloudinary deletion proxy URL not configured. Skipping remote deletion.');
        return;
      }

      // extract public_id from Cloudinary URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex >= pathSegments.length - 1) return;

      // public_id is segments after upload (ignoring version prefix like v123456789)
      List<String> idSegments = pathSegments.sublist(uploadIndex + 1);
      if (idSegments.isNotEmpty &&
          idSegments.first.startsWith('v') &&
          int.tryParse(idSegments.first.substring(1)) != null) {
        idSegments = idSegments.sublist(1);
      }
      String publicIdWithExt = idSegments.join('/');
      String publicId = publicIdWithExt.split('.').first;

      final proxyResponse = await post(
        Uri.parse('$deleteProxyUrl/destroy'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $deleteProxyAuthToken',
        },
        body: jsonEncode({'public_id': publicId}),
      );

      log('Cloudinary delete proxy response: ${proxyResponse.statusCode} - ${proxyResponse.body}');
    } catch (e) {
      log('Error deleteFromCloudinary: $e');
    }
  }

  //update message
  static Future<void> updateMessage(Message message, String updatedMsg) async {
    await firestore
        .collection('chats/${getConversationID(message.toId)}/messages/')
        .doc(message.sent)
        .update({'msg': updatedMsg});
  }

  // Helper to check if message is within 1 hour edit window (WhatsApp rule)
  static bool canEditMessage(Message message) {
    final sentTime = int.tryParse(message.sent) ?? 0;
    if (sentTime == 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - sentTime) <= (60 * 60 * 1000); // 1 hour
  }

  // Helper to check if message is within 6 hours delete window (WhatsApp rule)
  static bool canDeleteMessage(Message message) {
    final sentTime = int.tryParse(message.sent) ?? 0;
    if (sentTime == 0) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - sentTime) <= (6 * 60 * 60 * 1000); // 6 hours
  }

  // delete group message
  static Future<void> deleteGroupMessage(GroupChat group, Message message) async {
    await firestore
        .collection('groups/${group.id}/messages/')
        .doc(message.sent)
        .delete();

    if (message.type == Type.image || message.type == Type.video) {
      if (message.msg.contains('firebasestorage.googleapis.com')) {
        try {
          await storage.refFromURL(message.msg).delete();
        } catch (e) {
          log('Error deleting media from Firebase Storage: $e');
        }
      } else if (message.msg.contains('cloudinary.com')) {
        await deleteFromCloudinary(message.msg);
      }
    }
  }

  // update group message
  static Future<void> updateGroupMessage(GroupChat group, Message message, String updatedMsg) async {
    await firestore
        .collection('groups/${group.id}/messages/')
        .doc(message.sent)
        .update({'msg': updatedMsg});
  }

  // Optimize Cloudinary URLs with auto-format (WebP/AVIF), auto-quality compression, and responsive resizing
  static String getOptimizedImageUrl(String url, {int? width}) {
    if (url.isEmpty) return url;
    if (url.contains('cloudinary.com') && url.contains('/upload/')) {
      if (url.contains('/upload/f_auto') || url.contains('/upload/q_auto')) {
        return url;
      }
      final transform = width != null ? 'f_auto,q_auto,w_$width,c_limit' : 'f_auto,q_auto';
      return url.replaceFirst('/upload/', '/upload/$transform/');
    }
    return url;
  }

  // upload file or bytes to Cloudinary
  static Future<String?> uploadToCloudinary({
    File? file,
    Uint8List? bytes,
    required String filename,
    required String resourceType,
  }) async {
    try {
      if (cloudinaryCloudName == 'YOUR_CLOUD_NAME' || cloudinaryUploadPreset == 'YOUR_UPLOAD_PRESET') {
        log('Error: Cloudinary credentials not configured in apis.dart!');
        return null;
      }
      final url = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/$resourceType/upload');
      final request = MultipartRequest('POST', url);
      request.fields['upload_preset'] = cloudinaryUploadPreset;

      if (file != null) {
        request.files.add(await MultipartFile.fromPath('file', file.path));
      } else if (bytes != null) {
        request.files.add(MultipartFile.fromBytes('file', bytes, filename: filename));
      } else {
        return null;
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        return jsonMap['secure_url'] as String;
      } else {
        log('Cloudinary upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error uploadToCloudinary: $e');
      return null;
    }
  }

  // migrate existing Firebase Storage media files to Cloudinary
  static Future<void> migrateFirebaseStorageToCloudinary({
    required Function(String status) onProgress,
  }) async {
    try {
      onProgress('Starting migration...\nFetching users...');
      
      // 1. Migrate user profile pictures
      final usersSnapshot = await firestore.collection('users').get();
      int userCount = 0;
      for (var doc in usersSnapshot.docs) {
        final userImage = doc.data()['image']?.toString() ?? '';
        if (userImage.contains('firebasestorage.googleapis.com')) {
          onProgress('Migrating profile image for user: ${doc.data()['name'] ?? doc.id}...');
          try {
            final res = await get(Uri.parse(userImage));
            if (res.statusCode == 200) {
              final cloudinaryUrl = await uploadToCloudinary(
                bytes: res.bodyBytes,
                filename: 'profile_${doc.id}.jpg',
                resourceType: 'image',
              );
              if (cloudinaryUrl != null) {
                await firestore.collection('users').doc(doc.id).update({'image': cloudinaryUrl});
                userCount++;
              }
            }
          } catch (e) {
            log('Error migrating profile image for user ${doc.id}: $e');
          }
        }
      }
      onProgress('Profile images migration done (Migrated: $userCount).\nFetching all chat messages...');

      // 2. Migrate ALL chat message media using Collection Group Query
      final messagesSnapshot = await firestore.collectionGroup('messages').get();
      int messageCount = 0;
      int totalFound = 0;

      for (var msgDoc in messagesSnapshot.docs) {
        final msgData = msgDoc.data();
        final msgText = msgData['msg']?.toString() ?? '';
        final msgType = msgData['type']?.toString() ?? '';
        
        if (msgType == 'image' || msgText.contains('firebasestorage.googleapis.com')) {
          totalFound++;
          onProgress('Migrating chat media ($totalFound): ${msgDoc.id}...');
          try {
            final res = await get(Uri.parse(msgText));
            if (res.statusCode == 200) {
              final cloudinaryUrl = await uploadToCloudinary(
                bytes: res.bodyBytes,
                filename: 'chat_${msgDoc.id}.jpg',
                resourceType: 'image',
              );
              if (cloudinaryUrl != null) {
                await msgDoc.reference.update({'msg': cloudinaryUrl});
                messageCount++;
              }
            } else {
              log('Failed to download image from Firebase (${res.statusCode}): $msgText');
            }
          } catch (e) {
            log('Error migrating message ${msgDoc.id}: $e');
          }
        }
      }
      onProgress('Migration complete!\nSuccessfully Migrated:\n- $userCount profile pictures\n- $messageCount out of $totalFound chat media files.');
    } catch (e) {
      log('Error during migration: $e');
      onProgress('Migration failed with error: $e');
    }
  }

  ///************** Story / Status Related APIs **************

  // Upload photo or video story to Cloudinary (native quality, up to 100MB) and save to Firestore
  static Future<bool> uploadStoryMedia(File file, String caption, {bool isVideo = false}) async {
    try {
      final ext = file.path.split('.').last;
      final now = DateTime.now().millisecondsSinceEpoch;
      final cloudinaryUrl = await uploadToCloudinary(
        file: file,
        filename: 'story_${user.uid}_$now.$ext',
        resourceType: isVideo ? 'video' : 'image',
      );

      if (cloudinaryUrl == null) return false;

      final storyId = now.toString();
      final expiresAt = (now + 86400000).toString(); // 24 hours in ms

      final story = Story(
        id: storyId,
        userId: user.uid,
        userName: me.name,
        userImage: me.image,
        mediaUrl: cloudinaryUrl,
        caption: caption,
        createdAt: storyId,
        expiresAt: expiresAt,
        views: [user.uid],
        isText: false,
        isVideo: isVideo,
        bgColor: '',
      );

      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('stories')
          .doc(storyId)
          .set(story.toJson());

      // Notify contacts about new story
      notifyContactsAboutNewStory(isVideo);

      return true;
    } catch (e) {
      log('Error uploadStoryMedia: $e');
      return false;
    }
  }

  // Post text-based story with custom background color
  static Future<bool> postTextStory(String text, String bgColor) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final storyId = now.toString();
      final expiresAt = (now + 86400000).toString();

      final story = Story(
        id: storyId,
        userId: user.uid,
        userName: me.name,
        userImage: me.image,
        mediaUrl: text,
        caption: '',
        createdAt: storyId,
        expiresAt: expiresAt,
        views: [user.uid],
        isText: true,
        bgColor: bgColor,
      );

      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('stories')
          .doc(storyId)
          .set(story.toJson());

      // Notify contacts about new text story
      notifyContactsAboutNewStory(false);

      return true;
    } catch (e) {
      log('Error postTextStory: $e');
      return false;
    }
  }

  // Stream active stories for a specific user ID
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserStoriesStream(String targetUserId) {
    final nowStr = DateTime.now().millisecondsSinceEpoch.toString();
    return firestore
        .collection('users')
        .doc(targetUserId)
        .collection('stories')
        .where('expires_at', isGreaterThan: nowStr)
        .orderBy('expires_at', descending: false)
        .snapshots();
  }

  // Mark story as viewed by current user
  static Future<void> markStoryViewed(String storyOwnerId, String storyId) async {
    try {
      await firestore
          .collection('users')
          .doc(storyOwnerId)
          .collection('stories')
          .doc(storyId)
          .update({
        'views': FieldValue.arrayUnion([user.uid])
      });
    } catch (e) {
      log('Error markStoryViewed: $e');
    }
  }

  // Delete a story
  static Future<void> deleteStory(String storyId, String mediaUrl, bool isText) async {
    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('stories')
          .doc(storyId)
          .delete();

      if (!isText && mediaUrl.contains('cloudinary.com')) {
        await deleteFromCloudinary(mediaUrl);
      }
    } catch (e) {
      log('Error deleteStory: $e');
    }
  }

  ///************** Group Chat Related APIs **************

  // Create a new group chat
  static Future<GroupChat?> createGroup({
    required String name,
    required String description,
    required List<String> memberIds,
    File? imageFile,
  }) async {
    try {
      final time = DateTime.now().millisecondsSinceEpoch.toString();
      final groupId = 'group_$time';

      String imageUrl = '';
      if (imageFile != null) {
        imageUrl = await uploadToCloudinary(
              file: imageFile,
              filename: 'group_$groupId.jpg',
              resourceType: 'image',
            ) ??
            '';
      }

      // Ensure current user is included in members and admins
      final allMembers = {...memberIds, user.uid}.toList();
      final admins = [user.uid];

      final group = GroupChat(
        id: groupId,
        name: name,
        image: imageUrl,
        description: description,
        createdBy: user.uid,
        createdAt: time,
        members: allMembers,
        admins: admins,
        lastMessage: 'Group Created',
        lastMessageTime: time,
        lastMessageSenderName: me.name,
      );

      await firestore.collection('groups').doc(groupId).set(group.toJson());
      return group;
    } catch (e) {
      log('Error createGroup: $e');
      return null;
    }
  }

  // Get stream of all groups current user belongs to
  static Stream<QuerySnapshot<Map<String, dynamic>>> getMyGroups() {
    return firestore
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .snapshots();
  }

  // Get stream of messages for a group
  static Stream<QuerySnapshot<Map<String, dynamic>>> getGroupMessages(GroupChat group) {
    return firestore
        .collection('groups')
        .doc(group.id)
        .collection('messages')
        .orderBy('sent', descending: true)
        .snapshots();
  }

  // Get stream of last message for a group
  static Stream<QuerySnapshot<Map<String, dynamic>>> getLastGroupMessage(GroupChat group) {
    return firestore
        .collection('groups')
        .doc(group.id)
        .collection('messages')
        .orderBy('sent', descending: true)
        .limit(1)
        .snapshots();
  }

  // Update group message read status
  static Future<void> updateGroupMessageReadStatus(GroupChat group, Message message) async {
    if (message.fromId != user.uid && !message.read.contains(user.uid)) {
      final updatedRead = message.read.isEmpty ? user.uid : '${message.read},${user.uid}';
      await firestore
          .collection('groups')
          .doc(group.id)
          .collection('messages')
          .doc(message.sent)
          .update({'read': updatedRead});
    }
  }

  // Send message to group (with optional quoted reply parameters)
  static Future<void> sendGroupMessage(
    GroupChat group,
    String msg,
    Type type, {
    String? replyToMsg,
    String? replyToSenderName,
    String? replyToType,
    String? replyToMediaUrl,
  }) async {
    try {
      // Membership check: Verify current user is still in group members list
      final doc = await firestore.collection('groups').doc(group.id).get();
      if (doc.exists) {
        final freshGroup = GroupChat.fromJson(doc.data()!);
        if (!freshGroup.members.contains(user.uid)) {
          log('User ${user.uid} is no longer a member of group ${group.id}. Blocked sending message.');
          return;
        }
      }
      final time = DateTime.now().millisecondsSinceEpoch.toString();
      final message = Message(
        toId: group.id,
        msg: msg,
        read: '',
        type: type,
        fromId: user.uid,
        sent: time,
        senderName: me.name,
        senderImage: me.image,
        replyToMsg: replyToMsg,
        replyToSenderName: replyToSenderName,
        replyToType: replyToType,
        replyToMediaUrl: replyToMediaUrl,
      );

      await firestore
          .collection('groups')
          .doc(group.id)
          .collection('messages')
          .doc(time)
          .set(message.toJson());

      String msgPreview = msg;
      if (type == Type.image) msgPreview = '📷 Photo';
      if (type == Type.video) msgPreview = '🎬 Video';

      await firestore.collection('groups').doc(group.id).update({
        'lastMessage': msgPreview,
        'lastMessageTime': time,
        'lastMessageSenderName': me.name,
      });
    } catch (e) {
      log('Error sendGroupMessage: $e');
    }
  }

  // send group GIF (direct KLIPY CDN streaming, zero Cloudinary storage)
  static Future<void> sendGroupGif(
    GroupChat group,
    GifItem gif, {
    String? replyToMsg,
    String? replyToSenderName,
    String? replyToType,
    String? replyToMediaUrl,
  }) async {
    try {
      final time = DateTime.now().millisecondsSinceEpoch.toString();
      final message = Message(
        toId: group.id,
        msg: gif.mediaUrl,
        read: '',
        type: Type.gif,
        fromId: user.uid,
        sent: time,
        senderName: me.name,
        senderImage: me.image,
        replyToMsg: replyToMsg,
        replyToSenderName: replyToSenderName,
        replyToType: replyToType,
        replyToMediaUrl: replyToMediaUrl,
        gifId: gif.id,
        gifProvider: gif.provider,
        gifPreviewUrl: gif.previewUrl,
      );

      await firestore
          .collection('groups')
          .doc(group.id)
          .collection('messages')
          .doc(time)
          .set(message.toJson());

      await firestore.collection('groups').doc(group.id).update({
        'lastMessage': '👾 GIF',
        'lastMessageTime': time,
        'lastMessageSenderName': me.name,
      });
    } catch (e) {
      log('Error sendGroupGif: $e');
    }
  }

  // Send reply to a story/status as a 1:1 chat message
  static Future<bool> sendStoryReply({
    required String storyOwnerId,
    required String replyText,
    required String storyCaption,
    required String storyMediaUrl,
    required bool isVideo,
    required bool isText,
    String? storyOwnerName,
  }) async {
    try {
      ChatUser? recipient = await getUserById(storyOwnerId);
      if (recipient == null) return false;

      // Make sure contact is in user's my_users list so chat opens in home screen
      await addChatUser(recipient.email);

      String previewMsg = storyCaption.isNotEmpty
          ? storyCaption
          : (isText ? 'Status' : (isVideo ? '🎬 Video Status' : '📷 Photo Status'));

      await sendMessage(
        recipient,
        replyText,
        Type.text,
        replyToMsg: previewMsg,
        replyToSenderName: storyOwnerName ?? recipient.name,
        replyToType: 'story',
        replyToMediaUrl: storyMediaUrl,
      );

      return true;
    } catch (e) {
      log('Error sendStoryReply: $e');
      return false;
    }
  }

  // Send image to group
  static Future<void> sendGroupImage(GroupChat group, File file) async {
    final imageUrl = await uploadToCloudinary(
      file: file,
      filename: 'group_${group.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      resourceType: 'image',
    );
    if (imageUrl != null) {
      await sendGroupMessage(group, imageUrl, Type.image);
    }
  }

  // Send video to group
  static Future<void> sendGroupVideo(GroupChat group, File file) async {
    final videoUrl = await uploadToCloudinary(
      file: file,
      filename: 'group_${group.id}_${DateTime.now().millisecondsSinceEpoch}.mp4',
      resourceType: 'video',
    );
    if (videoUrl != null) {
      await sendGroupMessage(group, videoUrl, Type.video);
    }
  }

  // Update group info
  static Future<void> updateGroupInfo(GroupChat group, String name, String description, File? newImage) async {
    try {
      // Fetch fresh existing data from Firestore so we accurately detect differences
      // even if local state was already modified.
      final doc = await firestore.collection('groups').doc(group.id).get();
      final freshData = doc.data() ?? {};
      final String prevDesc = (freshData['description'] ?? group.description ?? '').toString();
      final String prevName = (freshData['name'] ?? group.name ?? '').toString();
      final String prevImage = (freshData['image'] ?? group.image ?? '').toString();

      String imageUrl = prevImage.isNotEmpty ? prevImage : group.image;
      bool imageChanged = false;

      if (newImage != null) {
        final uploaded = await uploadToCloudinary(
          file: newImage,
          filename: 'group_${group.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          resourceType: 'image',
        );
        if (uploaded != null && uploaded.isNotEmpty) {
          imageUrl = uploaded;
          imageChanged = true;
        }
      }

      final bool descChanged = description.trim() != prevDesc.trim();
      final bool nameChanged = name.trim() != prevName.trim();

      await firestore.collection('groups').doc(group.id).update({
        'name': name.trim(),
        'description': description.trim(),
        'image': imageUrl,
      });

      final sender = me.name.isNotEmpty ? me.name : (user.displayName ?? 'A member');

      if (imageChanged) {
        await sendGroupMessage(group, '$sender changed this group\'s icon', Type.system);
      }
      if (descChanged) {
        await sendGroupMessage(group, '$sender changed the group description', Type.system);
      }
      if (nameChanged) {
        await sendGroupMessage(group, '$sender changed the group name to "$name"', Type.system);
      }
    } catch (e) {
      log('Error updateGroupInfo: $e');
    }
  }

  // Add members to group
  static Future<void> addGroupMembers(GroupChat group, List<String> newMemberIds) async {
    try {
      await firestore.collection('groups').doc(group.id).update({
        'members': FieldValue.arrayUnion(newMemberIds),
      });
    } catch (e) {
      log('Error addGroupMembers: $e');
    }
  }

  // Remove member from group
  static Future<void> removeGroupMember(GroupChat group, String memberId) async {
    try {
      await firestore.collection('groups').doc(group.id).update({
        'members': FieldValue.arrayRemove([memberId]),
        'admins': FieldValue.arrayRemove([memberId]),
      });
    } catch (e) {
      log('Error removeGroupMember: $e');
    }
  }

  // Leave group
  static Future<void> leaveGroup(GroupChat group) async {
    await removeGroupMember(group, user.uid);
  }

  // Get single group details by ID
  static Future<GroupChat?> getGroupById(String groupId) async {
    try {
      final doc = await firestore.collection('groups').doc(groupId).get();
      if (doc.exists && doc.data() != null) {
        return GroupChat.fromJson(doc.data()!);
      }
    } catch (e) {
      log('Error getGroupById: $e');
    }
    return null;
  }

  // Make member admin
  static Future<void> makeGroupAdmin(GroupChat group, String memberId) async {
    try {
      await firestore.collection('groups').doc(group.id).update({
        'admins': FieldValue.arrayUnion([memberId]),
      });
    } catch (e) {
      log('Error makeGroupAdmin: $e');
    }
  }

  // Dismiss/Remove group admin
  static Future<void> removeGroupAdmin(GroupChat group, String memberId) async {
    try {
      await firestore.collection('groups').doc(group.id).update({
        'admins': FieldValue.arrayRemove([memberId]),
      });
    } catch (e) {
      log('Error removeGroupAdmin: $e');
    }
  }

  // Mute notification for a contact or group
  static Future<void> muteChat(String id, MuteDuration duration) async {
    try {
      int expiry = -1;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (duration == MuteDuration.oneHour) {
        expiry = now + 3600000;
      } else if (duration == MuteDuration.oneWeek) {
        expiry = now + 604800000;
      }
      await firestore.collection('users').doc(user.uid).update({
        'muted_users.$id': expiry,
      });
      me.mutedUsers[id] = expiry;
    } catch (e) {
      log('Error muteChat: $e');
    }
  }

  // Unmute notification for a contact or group
  static Future<void> unmuteChat(String id) async {
    try {
      await firestore.collection('users').doc(user.uid).update({
        'muted_users.$id': FieldValue.delete(),
      });
      me.mutedUsers.remove(id);
    } catch (e) {
      log('Error unmuteChat: $e');
    }
  }

  // Check if contact or group is muted
  static bool isChatMuted(String id) {
    if (!me.mutedUsers.containsKey(id)) return false;
    final val = me.mutedUsers[id];
    if (val == -1) return true;
    if (val is int) {
      final isMuted = DateTime.now().millisecondsSinceEpoch < val;
      if (!isMuted) {
        unmuteChat(id);
      }
      return isMuted;
    }
    return false;
  }

  // Block a user (hides from blocker's chat list & blocks from viewing blocker's status)
  static Future<void> blockUser(String userId) async {
    try {
      await firestore.collection('users').doc(user.uid).update({
        'blocked_users': FieldValue.arrayUnion([userId]),
        'status_blocked_users': FieldValue.arrayUnion([userId]),
      });
      if (!me.blockedUsers.contains(userId)) me.blockedUsers.add(userId);
      if (!me.statusBlockedUsers.contains(userId)) me.statusBlockedUsers.add(userId);
    } catch (e) {
      log('Error blockUser: $e');
    }
  }

  // Unblock a user
  static Future<void> unblockUser(String userId) async {
    try {
      await firestore.collection('users').doc(user.uid).update({
        'blocked_users': FieldValue.arrayRemove([userId]),
        'status_blocked_users': FieldValue.arrayRemove([userId]),
      });
      me.blockedUsers.remove(userId);
      me.statusBlockedUsers.remove(userId);
    } catch (e) {
      log('Error unblockUser: $e');
    }
  }

  // Check if current user blocked or status-blocked specific user
  static bool isUserBlocked(String userId) {
    return me.blockedUsers.contains(userId) || me.statusBlockedUsers.contains(userId);
  }

  // Check if current user is blocked from viewing a contact's status/stories
  static Future<bool> isUserBlockedFromStatus(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final list = List<String>.from(doc.data()!['status_blocked_users'] ?? []);
        return list.contains(user.uid);
      }
    } catch (e) {
      log('Error isUserBlockedFromStatus: $e');
    }
    return false;
  }

  // Launch external URL in browser
  // Launch external URL in browser
  static Future<void> openUrl(String urlStr) async {
    try {
      String cleanUrl = urlStr.trim();
      if (cleanUrl.isEmpty) return;
      if (cleanUrl.contains('@') && !cleanUrl.startsWith(RegExp(r'mailto:', caseSensitive: false))) {
        cleanUrl = 'mailto:$cleanUrl';
      } else if (!cleanUrl.startsWith(RegExp(r'^(https?:\/\/|mailto:|tel:)', caseSensitive: false))) {
        cleanUrl = 'https://$cleanUrl';
      }
      final uri = Uri.parse(cleanUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        log('Could not launch via externalApplication. Trying platformDefault mode...');
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      log('Error openUrl: $e');
    }
  }
}

enum MuteDuration { oneHour, oneWeek, always }