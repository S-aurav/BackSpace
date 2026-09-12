import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../api/apis.dart';
import '../helper/cache_manager.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../helper/theme_controller.dart';
import '../main.dart';
import '../models/chat_user.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../screens/profile_screen.dart';
import '../screens/view_profile_screen.dart';
import 'custom_context_menu_dialog.dart';
import 'full_screen_image_viewer.dart';
import 'full_screen_video_viewer.dart';
import 'linkify_text.dart';

// Authentic Group iOS iMessage Chat Bubble matching MessageCard 1:1
class GroupMessageCard extends StatefulWidget {
  final Message message;
  final GroupChat group;
  final bool showSenderHeader;

  const GroupMessageCard({
    super.key,
    required this.message,
    required this.group,
    this.showSenderHeader = true,
    this.onSwipeToReply,
  });

  final Function(Message)? onSwipeToReply;

  @override
  State<GroupMessageCard> createState() => _GroupMessageCardState();
}

class _GroupMessageCardState extends State<GroupMessageCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.message.type == Type.system) {
      return _systemMessage();
    }

    final bool isMe = APIs.user.uid == widget.message.fromId;
    Offset? tapPos;
    return Dismissible(
      key: Key(widget.message.sent),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        HapticFeedback.lightImpact();
        if (widget.onSwipeToReply != null) {
          widget.onSwipeToReply!(widget.message);
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        color: Colors.transparent,
        child: const Icon(
          CupertinoIcons.reply,
          color: Color(0xFF34C759),
          size: 22,
        ),
      ),
      child: InkWell(
        onTapDown: (details) => tapPos = details.globalPosition,
        onLongPress: () => _showCupertinoActionSheet(isMe, targetOffset: tapPos),
        child: isMe ? _myMessage() : _contactMessage(),
      ),
    );
  }

  // WhatsApp-style system message bubble (centered pill for group changes)
  Widget _systemMessage() {
    final bool isDark = ThemeController.isDark;
    final bool isMe = APIs.user.uid == widget.message.fromId;
    String displayMsg = widget.message.msg;
    final sender = widget.message.senderName ?? APIs.me.name;
    if (isMe && displayMsg.startsWith(sender)) {
      displayMsg = 'You${displayMsg.substring(sender.length)}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
        child: Text(
          displayMsg,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ThemeController.subtextColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }

  // Quoted reply box preview (WhatsApp style)
  Widget _buildReplyPreviewBox(Message message, bool isMe, bool isDark) {
    if (message.replyToMsg == null || message.replyToMsg!.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isStory = message.replyToType == 'story';
    final String title = isStory
        ? '${message.replyToSenderName ?? "Contact"}\'s Status'
        : (message.replyToSenderName ?? 'Replied Message');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.black.withValues(alpha: 0.18)
            : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isStory
                ? const Color(0xFFFF9500)
                : (isMe ? Colors.white : const Color(0xFF34C759)),
            width: 3.5,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isStory) ...[
                      const Icon(CupertinoIcons.sparkles, size: 12, color: Color(0xFFFF9500)),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isStory
                              ? const Color(0xFFFF9500)
                              : (isMe ? Colors.white : const Color(0xFF34C759)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message.replyToMsg!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.9)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (message.replyToMediaUrl != null && message.replyToMediaUrl!.isNotEmpty) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                imageUrl: APIs.getOptimizedImageUrl(message.replyToMediaUrl!, width: 100),
                errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 18, color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Incoming Group Message (WhatsApp-style: Larger Profile Pic & Sender Name above, Indented Bubble below Name)
  Widget _contactMessage() {
    if (!widget.message.read.contains(APIs.user.uid)) {
      APIs.updateGroupMessageReadStatus(widget.group, widget.message);
    }

    final isDark = ThemeController.isDark;
    final hasSenderName = widget.message.senderName != null && widget.message.senderName!.isNotEmpty;
    final showHeader = widget.showSenderHeader;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mq.width * .03, vertical: showHeader ? 3 : 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row ABOVE Chat Bubble: Larger Profile Picture + Sender Name (Clickable to view profile)
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final fromId = widget.message.fromId;
                  if (fromId.isEmpty) return;
                  if (fromId == APIs.user.uid) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(user: APIs.me)),
                    );
                    return;
                  }

                  Dialogs.showProgressBar(context);
                  final targetUser = await APIs.getUserById(fromId);
                  if (mounted) {
                    Navigator.pop(context); // dismiss progress dialog
                    if (targetUser != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ViewProfileScreen(user: targetUser)),
                      );
                    } else {
                      final fallbackUser = ChatUser(
                        id: fromId,
                        name: widget.message.senderName ?? 'User',
                        email: '',
                        about: '',
                        image: widget.message.senderImage ?? '',
                        createdAt: '',
                        isOnline: false,
                        lastActive: '',
                        pushToken: '',
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ViewProfileScreen(user: fallbackUser)),
                      );
                    }
                  }
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Sender Avatar (Increased to 28x28 for crisp aesthetic)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: (widget.message.senderImage != null && widget.message.senderImage!.isNotEmpty)
                            ? CachedNetworkImage(
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                                imageUrl: APIs.getOptimizedImageUrl(widget.message.senderImage!, width: 70),
                                cacheManager: AvatarCacheManager.instance,
                                errorWidget: (context, url, error) => CircleAvatar(
                                  radius: 14,
                                  backgroundColor: ThemeController.cardColor,
                                  child: Icon(CupertinoIcons.person_fill, size: 14, color: ThemeController.subtextColor),
                                ),
                              )
                            : CircleAvatar(
                                radius: 14,
                                backgroundColor: ThemeController.cardColor,
                                child: Icon(CupertinoIcons.person_fill, size: 14, color: ThemeController.subtextColor),
                              ),
                      ),
                      const SizedBox(width: 8),

                      // Sender Name
                      if (hasSenderName)
                        Text(
                          widget.message.senderName!,
                          style: const TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Message Bubble + Timestamp Row (Indented 36px under Sender Name)
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 36), // Aligns bubble gracefully under the sender's name

              Flexible(
                child: (widget.message.type == Type.image || widget.message.type == Type.gif)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.message.replyToMsg != null && widget.message.replyToMsg!.isNotEmpty)
                            _buildReplyPreviewBox(widget.message, false, isDark),
                          _imageBubble(isMe: false),
                        ],
                      )
                    : widget.message.type == Type.video
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.message.replyToMsg != null && widget.message.replyToMsg!.isNotEmpty)
                                _buildReplyPreviewBox(widget.message, false, isDark),
                              _videoBubble(isMe: false),
                            ],
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: ThemeController.receivedBubbleColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
                                bottomRight: Radius.circular(18),
                                bottomLeft: Radius.circular(4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.message.replyToMsg != null && widget.message.replyToMsg!.isNotEmpty)
                                  _buildReplyPreviewBox(widget.message, false, isDark),
                                LinkifyText(
                                  text: widget.message.msg,
                                  isMe: false,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark ? Colors.white : Colors.black,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
              const SizedBox(width: 6),

              // Timestamp
              Text(
                MyDateUtil.getFormattedTime(context: context, time: widget.message.sent),
                style: TextStyle(fontSize: 11, color: ThemeController.subtextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sent User Message (iOS Solid Blue #007AFF Bubble matching MessageCard 1:1)
  Widget _myMessage() {
    final isDark = ThemeController.isDark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mq.width * .03, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Sent Time
              Text(
                MyDateUtil.getFormattedTime(context: context, time: widget.message.sent),
                style: TextStyle(fontSize: 11, color: ThemeController.subtextColor),
              ),

              const SizedBox(width: 6),

              (widget.message.type == Type.image || widget.message.type == Type.gif)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.message.replyToMsg != null && widget.message.replyToMsg!.isNotEmpty)
                          _buildReplyPreviewBox(widget.message, true, isDark),
                        _imageBubble(isMe: true),
                      ],
                    )
                  : widget.message.type == Type.video
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.message.replyToMsg != null && widget.message.replyToMsg!.isNotEmpty)
                              _buildReplyPreviewBox(widget.message, true, isDark),
                            _videoBubble(isMe: true),
                          ],
                        )
                      : Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF007AFF),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
                                bottomLeft: Radius.circular(18),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.message.replyToMsg != null && widget.message.replyToMsg!.isNotEmpty)
                                  _buildReplyPreviewBox(widget.message, true, isDark),
                                LinkifyText(
                                  text: widget.message.msg,
                                  isMe: true,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ],
          ),
        ],
      ),
    );
  }

  // Image Message Bubble
  Widget _imageBubble({required bool isMe}) {
    final imageWidth = mq.width * .62;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              imageUrl: widget.message.msg,
              heroTag: 'msg_img_${widget.message.sent}',
              title: widget.message.senderName ?? widget.group.name,
              subtitle: MyDateUtil.getFormattedTime(context: context, time: widget.message.sent),
            ),
          ),
        );
      },
      child: Hero(
        tag: 'msg_img_${widget.message.sent}',
        child: Container(
          width: imageWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThemeController.dividerColor.withValues(alpha: 0.3), width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: widget.message.msg,
              fit: BoxFit.cover,
              placeholder: (context, url) => const SizedBox(
                height: 180,
                child: Center(child: CupertinoActivityIndicator(color: Color(0xFF007AFF))),
              ),
              errorWidget: (context, url, error) => Container(
                height: 140,
                color: ThemeController.cardColor,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.redAccent, size: 28),
                    SizedBox(height: 6),
                    Text('Failed to load image', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Video Message Bubble matching MessageCard 1:1 with Video Thumbnail
  Widget _videoBubble({required bool isMe}) {
    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          );

    final heroTag = 'group_video_${widget.message.sent}_${widget.message.fromId}';
    final thumbnailUrl = APIs.getVideoThumbnailUrl(widget.message.msg, width: 800);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black87,
            pageBuilder: (context, animation, secondaryAnimation) {
              return FadeTransition(
                opacity: animation,
                child: FullScreenVideoViewer(
                  videoUrl: widget.message.msg,
                  heroTag: heroTag,
                  title: widget.message.senderName ?? widget.group.name,
                  subtitle: MyDateUtil.getFormattedTime(context: context, time: widget.message.sent),
                ),
              );
            },
          ),
        );
      },
      child: Hero(
        tag: heroTag,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: mq.width * 0.65,
            maxHeight: mq.height * 0.32,
            minWidth: mq.width * 0.40,
            minHeight: 140,
          ),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF007AFF) : ThemeController.cardColor,
            borderRadius: borderRadius,
            border: Border.all(
              color: ThemeController.dividerColor.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video frame thumbnail from Cloudinary
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  cacheManager: ChatImageCacheManager.instance,
                  fadeInDuration: const Duration(milliseconds: 100),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  useOldImageOnUrlChange: true,
                  placeholder: (context, url) => Container(
                    width: mq.width * 0.55,
                    height: 180,
                    color: isMe
                        ? const Color(0xFF007AFF).withValues(alpha: 0.25)
                        : ThemeController.cardColor,
                    child: Center(
                      child: CupertinoActivityIndicator(
                        color: isMe ? Colors.white : const Color(0xFF007AFF),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: mq.width * 0.55,
                    height: 140,
                    color: ThemeController.cardColor,
                    child: Center(
                      child: Icon(CupertinoIcons.videocam_fill, size: 40, color: ThemeController.subtextColor),
                    ),
                  ),
                ),

                // Dark Overlay Gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Semi-transparent play button icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                  ),
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                // Video Badge (Bottom Right)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.videocam_fill, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Video',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Cupertino Context Menu Popover (Copy, Save, Edit, Delete)
  void _showCupertinoActionSheet(bool isMe, {Offset? targetOffset}) {
    final canEdit = isMe && widget.message.type == Type.text && APIs.canEditMessage(widget.message);
    final canDelete = isMe && APIs.canDeleteMessage(widget.message);

    CustomContextMenuDialog.show(
      context: context,
      targetOffset: targetOffset,
      title: widget.message.senderName != null ? 'Message by ${widget.message.senderName}' : null,
      items: [
        ContextMenuItem(
          title: 'Reply',
          icon: CupertinoIcons.reply,
          onTap: () {
            if (widget.onSwipeToReply != null) {
              widget.onSwipeToReply!(widget.message);
            }
          },
        ),
        if (widget.message.type == Type.text)
          ContextMenuItem(
            title: 'Copy',
            icon: CupertinoIcons.doc_on_doc,
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.message.msg));
              Dialogs.showSnackbar(context, 'Text Copied!');
            },
          ),
        if (widget.message.type == Type.image || widget.message.type == Type.video)
          ContextMenuItem(
            title: 'Save to Photos',
            icon: CupertinoIcons.arrow_down_to_line,
            onTap: () {
              _saveMediaToGallery();
            },
          ),
        if (canEdit)
          ContextMenuItem(
            title: 'Edit',
            icon: CupertinoIcons.pencil,
            onTap: () {
              _showMessageUpdateDialog();
            },
          ),
        if (canDelete)
          ContextMenuItem(
            title: 'Delete',
            icon: CupertinoIcons.trash,
            isDestructive: true,
            onTap: () async {
              await APIs.deleteGroupMessage(widget.group, widget.message);
            },
          ),
      ],
    );
  }

  // Dialog for Updating Group Message Content
  void _showMessageUpdateDialog() {
    String updatedMsg = widget.message.msg;

    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Update Message'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: TextEditingController(text: updatedMsg),
            maxLines: null,
            style: TextStyle(color: ThemeController.textColor),
            onChanged: (value) => updatedMsg = value,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              APIs.updateGroupMessage(widget.group, widget.message, updatedMsg);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // Save Media to Gallery
  Future<void> _saveMediaToGallery() async {
    try {
      Dialogs.showProgressBar(context);
      final response = await http.get(Uri.parse(widget.message.msg));
      final tempDir = await getTemporaryDirectory();
      final ext = widget.message.type == Type.image ? 'jpg' : 'mp4';
      final file = File('${tempDir.path}/media_${widget.message.sent}.$ext');
      await file.writeAsBytes(response.bodyBytes);

      if (widget.message.type == Type.image) {
        await Gal.putImage(file.path);
      } else {
        await Gal.putVideo(file.path);
      }
      if (mounted) {
        Navigator.pop(context);
        Dialogs.showSnackbar(context, 'Saved to Photos!');
      }
    } catch (e) {
      log('Error saveMediaToGallery: $e');
      if (mounted) {
        Navigator.pop(context);
        Dialogs.showSnackbar(context, 'Failed to save media');
      }
    }
  }
}
