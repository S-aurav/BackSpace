const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Trigger when a new message is added to any chat
exports.sendChatNotification = functions
  .region("asia-south1")
  .firestore
  .document("chats/{conversationId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    if (!messageData) return null;

    const { toId, fromId, msg, type } = messageData;
    if (!toId || !fromId) return null;

    try {
      // 1. Fetch recipient's profile info & settings
      const recipientDoc = await admin
        .firestore()
        .collection("users")
        .doc(toId)
        .get();

      if (!recipientDoc.exists) return null;
      const recipientData = recipientDoc.data() || {};
      const pushToken = recipientData.push_token || recipientData.pushToken || null;

      // Check if recipient blocked sender
      const blockedUsers = recipientData.blocked_users || [];
      if (blockedUsers.includes(fromId)) {
        console.log(`Recipient ${toId} has blocked sender ${fromId}. Notification skipped.`);
        return null;
      }

      // Check if recipient muted sender
      const mutedUsers = recipientData.muted_users || {};
      const muteExpiry = mutedUsers[fromId];
      if (muteExpiry !== undefined) {
        if (muteExpiry === -1 || Date.now() < muteExpiry) {
          console.log(`Recipient ${toId} has muted chat with ${fromId}. Notification skipped.`);
          return null;
        }
      }

      // 2. Fetch sender's profile info
      const senderDoc = await admin
        .firestore()
        .collection("users")
        .doc(fromId)
        .get();

      const senderData = senderDoc.exists ? senderDoc.data() : {};
      const senderName = senderData.name || "New Message";
      const senderImage = senderData.image || "";

      // 3. Format message preview
      let bodyText = msg || "";
      let notificationImageUrl = "";

      if (type === "image" || type === "Type.image") {
        bodyText = "📷 Photo";
        if (msg && msg.startsWith("http")) {
          notificationImageUrl = msg;
        }
      } else if (type === "video" || type === "Type.video") {
        bodyText = "🎬 Video";
      } else if (type === "gif" || type === "Type.gif") {
        bodyText = "👾 GIF";
      }

      // 4. Write real-time in-app notification doc for instant web/app delivery
      const now = Date.now().toString();
      await admin
        .firestore()
        .collection("users")
        .doc(toId)
        .collection("notifications")
        .doc(now)
        .set({
          fromId: String(fromId),
          fromName: String(senderName),
          fromImage: String(senderImage),
          msg: String(bodyText),
          type: "chat",
          timestamp: now,
        })
        .catch((err) => console.log("Inbox notification write error:", err));

      // 5. Dispatch FCM push notification (Android + WebPush) if push token exists
      if (!pushToken || pushToken.trim() === "") {
        console.log(`No push token found for recipient: ${toId}. In-app notification delivered.`);
        return null;
      }

      const payload = {
        token: pushToken,
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          senderId: String(fromId),
          fromId: String(fromId),
          senderName: String(senderName),
          senderImage: String(senderImage),
          type: "chat",
          title: String(senderName),
          body: String(bodyText),
          photoUrl: String(notificationImageUrl),
        },
        android: {
          priority: "high",
        },
        webpush: {
          headers: {
            Urgency: "high",
          },
          notification: {
            title: String(senderName),
            body: String(bodyText),
            icon: "/favicon.png",
            badge: "/favicon.png",
            tag: String(fromId),
          },
          fcmOptions: {
            link: "/",
          },
        },
      };

      const response = await admin.messaging().send(payload);
      console.log(`Single rich notification sent to ${toId} successfully: ${response}`);
      return response;
    } catch (error) {
      console.error(`Error sending notification to ${toId}:`, error);
      return null;
    }
  });

// Trigger when a story or general alert is sent to a user's notification inbox
exports.sendInboxNotification = functions
  .region("asia-south1")
  .firestore
  .document("users/{userId}/notifications/{notifId}")
  .onCreate(async (snap, context) => {
    const notifData = snap.data();
    if (!notifData) return null;

    const userId = context.params.userId;
    const { fromId, fromName, fromImage, msg, type } = notifData;

    try {
      // Fetch recipient's push token
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get();

      if (!userDoc.exists) return null;
      const userData = userDoc.data() || {};
      const pushToken = userData.push_token || userData.pushToken || null;

      if (!pushToken || pushToken.trim() === "") return null;

      // Check if recipient blocked sender OR sender status-blocked recipient
      const recipientBlocked = userData.blocked_users || [];
      const recipientStatusBlocked = userData.status_blocked_users || [];
      if (recipientBlocked.includes(fromId) || recipientStatusBlocked.includes(fromId)) {
        console.log(`Recipient ${userId} has blocked or is status-blocked with ${fromId}. Notification skipped.`);
        return null;
      }

      if (fromId) {
        const senderDoc = await admin.firestore().collection("users").doc(fromId).get();
        if (senderDoc.exists) {
          const senderData = senderDoc.data() || {};
          const senderBlocked = senderData.blocked_users || [];
          const senderStatusBlocked = senderData.status_blocked_users || [];
          if (senderBlocked.includes(userId) || senderStatusBlocked.includes(userId)) {
            console.log(`Sender ${fromId} has blocked status/story notifications for ${userId}. Notification skipped.`);
            return null;
          }
        }
      }

      const title = fromName || "BackSpace Story";
      const body = msg || "Shared a new story";

      const payload = {
        token: pushToken,
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          senderId: String(fromId || ""),
          fromId: String(fromId || ""),
          senderName: String(fromName || ""),
          senderImage: String(fromImage || ""),
          type: String(type || "story"),
          title: String(title),
          body: String(body),
          photoUrl: "",
        },
        android: {
          priority: "high",
        },
      };

      const response = await admin.messaging().send(payload);
      console.log(`Story notification sent to ${userId}: ${response}`);
      return response;
    } catch (error) {
      console.error(`Error sending story notification to ${userId}:`, error);
      return null;
    }
  });

// Trigger when a new message is added to any group chat
exports.sendGroupChatNotification = functions
  .region("asia-south1")
  .firestore
  .document("groups/{groupId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    if (!messageData) return null;

    const groupId = context.params.groupId;
    const { fromId, senderName, senderImage, msg, type } = messageData;

    try {
      // Fetch group details
      const groupDoc = await admin.firestore().collection("groups").doc(groupId).get();
      if (!groupDoc.exists) return null;

      const groupData = groupDoc.data();
      const groupName = groupData ? groupData.name || "Group Chat" : "Group Chat";
      const groupImage = groupData ? groupData.image || "" : "";
      const members = groupData ? groupData.members || [] : [];

      let bodyText = msg || "";
      if (type === "image" || type === "Type.image") bodyText = "📷 Photo";
      if (type === "video" || type === "Type.video") bodyText = "🎬 Video";
      if (type === "gif" || type === "Type.gif") bodyText = "👾 GIF";

      const formattedBody = `${senderName || "Member"}: ${bodyText}`;

      // Notify all members except sender
      const recipientIds = members.filter((id) => id !== fromId);
      console.log(`Sending group notification for group ${groupId} (${groupName}) to ${recipientIds.length} members: ${recipientIds.join(", ")}`);

      for (const recipientId of recipientIds) {
        try {
          const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
          if (!userDoc.exists) {
            console.log(`User doc missing for recipient ${recipientId}`);
            continue;
          }

          const userData = userDoc.data() || {};

          // Check if recipient blocked group sender
          const blockedUsers = userData.blocked_users || [];
          if (blockedUsers.includes(fromId)) {
            console.log(`Recipient ${recipientId} has blocked group sender ${fromId}. Notification skipped.`);
            continue;
          }

          // Check if recipient muted this group
          const mutedUsers = userData.muted_users || {};
          const muteExpiry = mutedUsers[groupId];
          if (muteExpiry !== undefined) {
            if (muteExpiry === -1 || Date.now() < muteExpiry) {
              console.log(`Recipient ${recipientId} has muted group ${groupId}. Notification skipped.`);
              continue;
            }
          }

          // 1. Write real-time in-app notification doc for instant web/app sync
          const now = Date.now().toString();
          admin
            .firestore()
            .collection("users")
            .doc(recipientId)
            .collection("notifications")
            .doc(now)
            .set({
              fromId: String(groupId),
              fromName: String(groupName),
              fromImage: String(groupImage || senderImage || ""),
              msg: String(formattedBody),
              type: "group_chat",
              timestamp: now,
            })
            .catch((err) => console.log("Group inbox notification write error:", err));

          // 2. Dispatch FCM push notification (Android + WebPush) if push token exists
          const pushToken = userData.push_token || userData.pushToken || null;
          if (!pushToken || pushToken.trim() === "") {
            console.log(`No push token found for group recipient ${recipientId}. In-app notification delivered.`);
            continue;
          }

          const payload = {
            token: pushToken,
            data: {
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              senderId: String(groupId),
              fromId: String(fromId),
              senderName: String(groupName),
              senderImage: String(groupImage || senderImage || ""),
              type: "group_chat",
              title: String(groupName),
              body: String(formattedBody),
            },
            android: {
              priority: "high",
            },
            webpush: {
              headers: {
                Urgency: "high",
              },
              notification: {
                title: String(groupName),
                body: String(formattedBody),
                icon: "/favicon.png",
                badge: "/favicon.png",
                tag: String(groupId),
              },
              fcmOptions: {
                link: "/",
              },
            },
          };

          const res = await admin.messaging().send(payload);
          console.log(`Group notification sent to member ${recipientId} (${pushToken}): ${res}`);
        } catch (memberErr) {
          console.error(`Error sending group notification to recipient ${recipientId}:`, memberErr.message || memberErr);
          if (
            memberErr.code === "messaging/registration-token-not-registered" ||
            memberErr.code === "messaging/invalid-registration-token"
          ) {
            console.log(`Clearing stale push token for member ${recipientId}`);
            await admin.firestore().collection("users").doc(recipientId).update({ push_token: "" }).catch(() => {});
          }
        }
      }

      console.log(`Group notification completed for group ${groupId}`);
      return true;
    } catch (error) {
      console.error(`Error sending group notification for ${groupId}:`, error);
      return null;
    }
  });

const cloudinary = require("cloudinary").v2;

// Cloudinary Admin Configuration
const CLOUDINARY_CLOUD_NAME = process.env.CLOUDINARY_CLOUD_NAME || (functions.config().cloudinary && functions.config().cloudinary.cloud_name) || "";
const CLOUDINARY_API_KEY = process.env.CLOUDINARY_API_KEY || (functions.config().cloudinary && functions.config().cloudinary.api_key) || "";
const CLOUDINARY_API_SECRET = process.env.CLOUDINARY_API_SECRET || (functions.config().cloudinary && functions.config().cloudinary.api_secret) || "";

if (CLOUDINARY_CLOUD_NAME && CLOUDINARY_API_KEY && CLOUDINARY_API_SECRET) {
  cloudinary.config({
    cloud_name: CLOUDINARY_CLOUD_NAME,
    api_key: CLOUDINARY_API_KEY,
    api_secret: CLOUDINARY_API_SECRET,
  });
}

// Helper function to extract Cloudinary public_id from media URL
function getCloudinaryPublicId(url) {
  if (!url || !url.includes("cloudinary.com")) return null;
  try {
    const parts = url.split("/upload/");
    if (parts.length < 2) return null;
    let path = parts[1];
    const pathSegments = path.split("/");
    let startIndex = 0;
    for (let i = 0; i < pathSegments.length; i++) {
      if (pathSegments[i].startsWith("v") && /^\d+$/.test(pathSegments[i].substring(1))) {
        startIndex = i + 1;
        break;
      }
    }
    const relevantSegments = pathSegments.slice(startIndex);
    const fullPathWithExt = relevantSegments.join("/");
    return fullPathWithExt.replace(/\.[^/.]+$/, "") || null;
  } catch (err) {
    console.error("Error parsing Cloudinary public_id:", err);
    return null;
  }
}

// Trigger when a 1:1 chat message document is deleted from Firestore
exports.deleteChatMediaOnCloudinary = functions
  .region("asia-south1")
  .firestore
  .document("chats/{conversationId}/messages/{messageId}")
  .onDelete(async (snap, context) => {
    const messageData = snap.data();
    if (!messageData) return null;

    const { msg, type } = messageData;
    if (!msg || !msg.includes("cloudinary.com")) return null;

    const resourceType = (type === "video" || type === "Type.video") ? "video" : "image";
    const publicId = getCloudinaryPublicId(msg);

    if (!publicId) {
      console.log(`Cloudinary public_id could not be extracted from URL: ${msg}`);
      return null;
    }

    try {
      console.log(`Deleting Cloudinary asset: ${publicId} (${resourceType}) for deleted 1:1 message`);
      const result = await cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
      console.log(`Cloudinary deletion result for ${publicId}:`, result);
      return result;
    } catch (error) {
      console.error(`Error deleting Cloudinary asset ${publicId}:`, error);
      return null;
    }
  });

// Trigger when a group chat message document is deleted from Firestore
exports.deleteGroupChatMediaOnCloudinary = functions
  .region("asia-south1")
  .firestore
  .document("groups/{groupId}/messages/{messageId}")
  .onDelete(async (snap, context) => {
    const messageData = snap.data();
    if (!messageData) return null;

    const { msg, type } = messageData;
    if (!msg || !msg.includes("cloudinary.com")) return null;

    const resourceType = (type === "video" || type === "Type.video") ? "video" : "image";
    const publicId = getCloudinaryPublicId(msg);

    if (!publicId) {
      console.log(`Cloudinary public_id could not be extracted from URL: ${msg}`);
      return null;
    }

    try {
      console.log(`Deleting Cloudinary asset: ${publicId} (${resourceType}) for deleted group message`);
      const result = await cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
      console.log(`Cloudinary group deletion result for ${publicId}:`, result);
      return result;
    } catch (error) {
      console.error(`Error deleting group Cloudinary asset ${publicId}:`, error);
      return null;
    }
  });

// Trigger when a story/status document is deleted from Firestore (manual or expired)
exports.deleteStoryMediaOnCloudinary = functions
  .region("asia-south1")
  .firestore
  .document("users/{userId}/stories/{storyId}")
  .onDelete(async (snap, context) => {
    const storyData = snap.data();
    if (!storyData) return null;

    const { media_url, mediaUrl, is_text, isText, type } = storyData;
    const url = media_url || mediaUrl || "";
    const isTextStory = is_text || isText || type === "text";

    if (isTextStory || !url || !url.includes("cloudinary.com")) return null;

    const resourceType = (type === "video" || url.includes(".mp4")) ? "video" : "image";
    const publicId = getCloudinaryPublicId(url);

    if (!publicId) {
      console.log(`Cloudinary public_id could not be extracted from story URL: ${url}`);
      return null;
    }

    try {
      console.log(`Deleting Cloudinary asset for deleted story: ${publicId} (${resourceType})`);
      const result = await cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
      console.log(`Cloudinary story deletion result for ${publicId}:`, result);
      return result;
    } catch (error) {
      console.error(`Error deleting Cloudinary story asset ${publicId}:`, error);
      return null;
    }
  });
