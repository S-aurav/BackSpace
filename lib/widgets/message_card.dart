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
import '../models/message.dart';
import 'custom_context_menu_dialog.dart';
import 'full_screen_image_viewer.dart';
import 'full_screen_video_viewer.dart';
import 'linkify_text.dart';

// Authentic 1:1 iOS iMessage Chat Bubble with Dynamic Light/Dark Theme Support
class MessageCard extends StatefulWidget {
  const MessageCard({
    super.key,
    required this.message,
    this.onSwipeToReply,
  });

  final Message message;
  final Function(Message)? onSwipeToReply;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  @override
  Widget build(BuildContext context) {
    bool isMe = APIs.user.uid == widget.message.fromId;
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
          color: Color(0xFF007AFF),
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
                : (isMe ? Colors.white : const Color(0xFF007AFF)),
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
                              : (isMe ? Colors.white : const Color(0xFF007AFF)),
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

  // Received contact message (iOS Dark Slate / Light Grey Bubble)
  Widget _contactMessage() {
    if (widget.message.read.isEmpty) {
      APIs.updateMessageReadStatus(widget.message);
    }

    final isDark = ThemeController.isDark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: mq.width * .03, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          (widget.message.type == Type.image || widget.message.type == Type.gif)
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
                  : Flexible(
                      child: Container(
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

          // Message Sent Time
          Text(
            MyDateUtil.getFormattedTime(context: context, time: widget.message.sent),
            style: TextStyle(fontSize: 11, color: ThemeController.subtextColor),
          ),
        ],
      ),
    );
  }

  // Sent user message (iOS Solid Blue #007AFF Bubble)
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
              // Message Time
              Text(
                MyDateUtil.getFormattedTime(context: context, time: widget.message.sent),
                style: TextStyle(fontSize: 11, color: ThemeController.subtextColor),
              ),

              const SizedBox(width: 6),

              // iMessage Bubble (Text, Image, or Video)
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
                                  style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.25),
                                ),
                              ],
                            ),
                          ),
                        ),
            ],
          ),

          // iMessage "Read" Status Label
          if (widget.message.read.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                'Read',
                style: TextStyle(fontSize: 11, color: ThemeController.subtextColor, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  // Beautiful, properly constrained iOS iMessage-style Image Bubble
  Widget _imageBubble({required bool isMe}) {
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

    final heroTag = 'chat_img_${widget.message.sent}_${widget.message.fromId}';
    final optimizedUrl = APIs.getOptimizedImageUrl(widget.message.msg, width: 800);

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
                child: FullScreenImageViewer(
                  imageUrl: optimizedUrl,
                  heroTag: heroTag,
                  title: isMe ? 'You' : 'Photo',
                  subtitle: MyDateUtil.getFormattedTime(context: context, time: widget.message.sent),
                  cacheManager: ChatImageCacheManager.instance,
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
            child: CachedNetworkImage(
              imageUrl: optimizedUrl,
              cacheManager: ChatImageCacheManager.instance,
              fadeInDuration: const Duration(milliseconds: 100),
              fit: BoxFit.cover,
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
              errorWidget: (context, url, error) {
                log('Chat image load error for URL $url: $error');
                return Container(
                  width: mq.width * 0.55,
                  height: 140,
                  color: ThemeController.cardColor,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.photo, size: 36, color: ThemeController.subtextColor),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to view',
                        style: TextStyle(fontSize: 11, color: ThemeController.subtextColor),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Beautiful, properly constrained iOS iMessage-style Video Bubble
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

    final heroTag = 'chat_video_${widget.message.sent}_${widget.message.fromId}';
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
                  title: isMe ? 'You' : 'Video',
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
                // Video frame thumbnail
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

                // Dark overlay tint
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                  ),
                ),

                // Frosted glass play icon button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white60, width: 1.5),
                  ),
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Cupertino Context Menu Popover for Message Context Actions
  void _showCupertinoActionSheet(bool isMe, {Offset? targetOffset}) {
    final canEdit = isMe && widget.message.type == Type.text && APIs.canEditMessage(widget.message);
    final canDelete = isMe && APIs.canDeleteMessage(widget.message);

    CustomContextMenuDialog.show(
      context: context,
      targetOffset: targetOffset,
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
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: widget.message.msg));
              if (mounted) Dialogs.showSnackbar(context, 'Text Copied!');
            },
          ),
        if (widget.message.type == Type.image)
          ContextMenuItem(
            title: 'Save to Photos',
            icon: CupertinoIcons.arrow_down_to_line,
            onTap: () async {
              try {
                await Gal.putImage(widget.message.msg);
                if (mounted) Dialogs.showSnackbar(context, 'Image Saved!');
              } catch (e) {
                if (mounted) Dialogs.showSnackbar(context, 'Failed to save image');
              }
            },
          ),
        if (widget.message.type == Type.video)
          ContextMenuItem(
            title: 'Save to Photos',
            icon: CupertinoIcons.arrow_down_to_line,
            onTap: () async {
              try {
                final tempDir = await getTemporaryDirectory();
                final ext = widget.message.msg.split('.').last.split('?').first;
                final tempFilePath = '${tempDir.path}/video_${DateTime.now().millisecondsSinceEpoch}.$ext';
                final response = await http.get(Uri.parse(widget.message.msg));
                final file = File(tempFilePath);
                await file.writeAsBytes(response.bodyBytes);
                await Gal.putVideo(tempFilePath);
                if (mounted) Dialogs.showSnackbar(context, 'Video Saved!');
              } catch (e) {
                if (mounted) Dialogs.showSnackbar(context, 'Failed to save video');
              }
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
              await APIs.deleteMessage(widget.message);
            },
          ),
      ],
    );
  }

  // Dialog for Updating Message Content
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
              APIs.updateMessage(widget.message, updatedMsg);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}