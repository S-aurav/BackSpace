// ignore_for_file: use_build_context_synchronously

import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/apis.dart';
import '../helper/cache_manager.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../helper/theme_controller.dart';
import '../main.dart';
import '../models/chat_user.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../widgets/custom_context_menu_dialog.dart';
import '../widgets/gif_picker_sheet.dart';
import '../widgets/group_message_card.dart';
import 'group_info_screen.dart';

// Authentic Group Chat Screen -- Identical 1:1 Design & Controls to ChatScreen
class GroupChatScreen extends StatefulWidget {
  final GroupChat group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  Message? _replyMessage;
  List<Message> _list = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _hasTextNotifier = ValueNotifier<bool>(false);
  bool _showEmoji = false, _isUploading = false;

  late GroupChat _currentGroup;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _groupDocStream;

  double _safeTop = 0;
  double _safeBottom = 0;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
    APIs.activeChatUserId = widget.group.id;
    _messagesStream = APIs.getGroupMessages(widget.group);
    _groupDocStream = APIs.firestore.collection('groups').doc(widget.group.id).snapshots();

    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (_hasTextNotifier.value != hasText) {
        _hasTextNotifier.value = hasText;
      }
    });
  }

  @override
  void dispose() {
    if (APIs.activeChatUserId == widget.group.id) {
      APIs.activeChatUserId = '';
    }
    _scrollController.dispose();
    _focusNode.dispose();
    _hasTextNotifier.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final padding = MediaQuery.of(context).padding;
    if (_safeTop == 0) _safeTop = padding.top;
    if (_safeBottom == 0) _safeBottom = padding.bottom;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = _safeTop + 80.0;
    final bottomListPadding = (_safeBottom > 0 ? _safeBottom : 10.0) + 64.0;
    final bool isParticipant = _currentGroup.members.contains(APIs.user.uid);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        return GestureDetector(
          onTap: () {
            _focusNode.unfocus();
            if (_showEmoji) setState(() => _showEmoji = false);
          },
          child: PopScope(
            canPop: !_showEmoji,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (_showEmoji) {
                setState(() => _showEmoji = false);
              }
            },
            child: Scaffold(
              backgroundColor: ThemeController.bgColor,
              extendBodyBehindAppBar: true,
              extendBody: true,
              resizeToAvoidBottomInset: false,

              // Authentic Acrylic / Frosted Glass Top Bar (Identical to ChatScreen)
              appBar: AppBar(
                toolbarHeight: 76,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: RepaintBoundary(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: ThemeController.headerColor.withValues(alpha: 0.55),
                          border: Border(
                            bottom: BorderSide(
                              color: ThemeController.dividerColor.withValues(alpha: 0.4),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                titleSpacing: 0,
                title: _appBar(),
              ),

              // Stack Body (Identical to ChatScreen)
              body: Stack(
                children: [
                  // Layer 0: Messages ListView (cached stream + RepaintBoundary for smooth 60fps keyboard slide)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: StreamBuilder(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          switch (snapshot.connectionState) {
                            case ConnectionState.waiting:
                            case ConnectionState.none:
                              if (_list.isNotEmpty) {
                                return _buildMessageList(topPadding, bottomListPadding);
                              }
                              return const SizedBox();

                            case ConnectionState.active:
                            case ConnectionState.done:
                              final data = snapshot.data?.docs;
                              _list = data?.map((e) => Message.fromJson(e.data())).toList() ?? [];

                              if (_list.isNotEmpty) {
                                return _buildMessageList(topPadding, bottomListPadding);
                              } else {
                                return Padding(
                                  padding: EdgeInsets.only(top: topPadding),
                                  child: const Center(
                                    child: Text(
                                      'Say Hi to the Group! 👋',
                                      style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
                                    ),
                                  ),
                                );
                              }
                          }
                        },
                      ),
                    ),
                  ),

                  // Layer 1: Floating Bottom Controls
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    child: RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Uploading Indicator
                          if (_isUploading)
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                                child: CupertinoActivityIndicator(color: Color(0xFF007AFF)),
                              ),
                            ),

                          if (!isParticipant)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: ThemeController.cardColor.withValues(alpha: 0.95),
                                border: Border(
                                  top: BorderSide(
                                    color: ThemeController.dividerColor.withValues(alpha: 0.3),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              padding: EdgeInsets.only(
                                top: 14,
                                bottom: _safeBottom > 0 ? _safeBottom + 8 : 14,
                                left: 16,
                                right: 16,
                              ),
                              child: const Text(
                                "You can't send messages to this group because you're no longer a participant.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else ...[
                            // Transparent Floating Input Bar
                            _chatInput(),

                            // Emoji Picker
                            if (_showEmoji)
                              Container(
                                height: mq.height * .35,
                                color: ThemeController.bgColor,
                                padding: EdgeInsets.only(bottom: _safeBottom),
                                child: EmojiPicker(
                                  textEditingController: _textController,
                                  config: Config(
                                    bgColor: ThemeController.bgColor,
                                    columns: 8,
                                    emojiSizeMax: 32 * (Platform.isIOS ? 1.30 : 1.0),
                                    indicatorColor: const Color(0xFF007AFF),
                                    iconColorSelected: const Color(0xFF007AFF),
                                    iconColor: ThemeController.subtextColor,
                                    backspaceColor: const Color(0xFF007AFF),
                                    skinToneDialogBgColor: ThemeController.cardColor,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Message list builder
  Widget _buildMessageList(double topPadding, double bottomListPadding) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final emojiHeight = _showEmoji ? mq.height * .35 : 0.0;
    final effectiveBottomPadding = (keyboardHeight > 0 || _showEmoji)
        ? (keyboardHeight > 0 ? keyboardHeight : emojiHeight) + 54
        : bottomListPadding;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      itemCount: _list.length,
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: effectiveBottomPadding,
      ),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final currentMsg = _list[index];
        final prevMsg = (index + 1 < _list.length) ? _list[index + 1] : null;
        final showSenderHeader = (prevMsg == null || prevMsg.fromId != currentMsg.fromId);

        return GroupMessageCard(
          message: currentMsg,
          group: _currentGroup,
          showSenderHeader: showSenderHeader,
          onSwipeToReply: (msg) {
            setState(() {
              _replyMessage = msg;
            });
            _focusNode.requestFocus();
          },
        );
      },
    );
  }

  // Acrylic Frosted Header Widget (Matching ChatScreen 1:1)
  Widget _appBar() {
    return StreamBuilder(
      stream: _groupDocStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.data() != null) {
          _currentGroup = GroupChat.fromJson(snapshot.data!.data()!);
        }

        final name = _currentGroup.name;
        final image = _currentGroup.image;
        final memberCount = _currentGroup.members.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Back Button (< Messages)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(CupertinoIcons.chevron_left, color: Color(0xFF007AFF), size: 18),
                    SizedBox(width: 2),
                    Text(
                      'Messages',
                      style: TextStyle(color: Color(0xFF007AFF), fontSize: 14, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),

              // Centered Group Profile Pic (40px), Title & Subtitle
              GestureDetector(
                onTap: () {
                  _focusNode.unfocus();
                  FocusScope.of(context).unfocus();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupInfoScreen(group: _currentGroup),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: image.isNotEmpty
                          ? CachedNetworkImage(
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              imageUrl: APIs.getOptimizedImageUrl(image, width: 100),
                              cacheManager: AvatarCacheManager.instance,
                              fadeInDuration: const Duration(milliseconds: 100),
                              useOldImageOnUrlChange: true,
                              errorWidget: (context, url, error) => CircleAvatar(
                                radius: 20,
                                backgroundColor: ThemeController.cardColor,
                                child: Icon(CupertinoIcons.group_solid, color: ThemeController.subtextColor, size: 20),
                              ),
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                              child: const Icon(CupertinoIcons.group_solid, color: Color(0xFF007AFF), size: 20),
                            ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            color: ThemeController.textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(CupertinoIcons.chevron_right, color: Color(0xFF8E8E93), size: 10),
                      ],
                    ),
                    StreamBuilder(
                      stream: APIs.getAllUsers(_currentGroup.members),
                      builder: (context, membersSnapshot) {
                        int onlineCount = 0;
                        if (membersSnapshot.hasData) {
                          final docs = membersSnapshot.data?.docs ?? [];
                          for (var d in docs) {
                            final u = ChatUser.fromJson(d.data());
                            if (MyDateUtil.isUserOnline(isOnline: u.isOnline, lastActive: u.lastActive)) {
                              onlineCount++;
                            }
                          }
                        }

                        final String subtitleText = onlineCount > 0
                            ? '$onlineCount of $memberCount online'
                            : '$memberCount members';

                        return Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: onlineCount > 0 ? const Color(0xFF34C759) : ThemeController.subtextColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Right spacer for header symmetry
              const SizedBox(width: 75),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuotedReplyBanner() {
    if (_replyMessage == null) return const SizedBox.shrink();

    final isMe = _replyMessage!.fromId == APIs.user.uid;
    final senderName = isMe
        ? 'You'
        : (_replyMessage!.senderName != null && _replyMessage!.senderName!.isNotEmpty
            ? _replyMessage!.senderName!
            : 'Member');
    String previewText = _replyMessage!.msg;
    if (_replyMessage!.type == Type.image) previewText = '📷 Photo';
    if (_replyMessage!.type == Type.video) previewText = '🎬 Video';
    if (_replyMessage!.type == Type.gif) previewText = '👾 GIF';

    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ThemeController.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF34C759), width: 3.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $senderName',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF34C759),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeController.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyMessage = null),
            child: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  // Compact iMessage-style Floating Bottom Input Bar (Identical to ChatScreen)
  Widget _chatInput() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = (keyboardHeight > 0 || _showEmoji) ? 4.0 : (_safeBottom > 0 ? _safeBottom + 2 : 8.0);

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        top: 4,
        left: 8,
        right: 8,
        bottom: bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuotedReplyBanner(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // iOS App / Photo Action Button (+) — iMessage blue
              GestureDetector(
                onTap: _showMediaPickerBottomSheet,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(CupertinoIcons.plus_circle_fill, color: Color(0xFF007AFF), size: 30),
                ),
              ),

              const SizedBox(width: 6),

              // Compact iMessage Capsule Input Field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: ThemeController.cardColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ThemeController.dividerColor, width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.multiline,
                          maxLines: 5,
                          minLines: 1,
                          style: TextStyle(color: ThemeController.textColor, fontSize: 16, height: 1.25),
                          onTap: () {
                            if (_showEmoji) setState(() => _showEmoji = false);
                          },
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),

                      // GIF button — just before emoji picker button
                      GestureDetector(
                        onTap: () {
                          GifPickerSheet.show(
                            context: context,
                            onGifSelected: (gif) async {
                              if (_replyMessage != null) {
                                final isMe = _replyMessage!.fromId == APIs.user.uid;
                                final senderName = isMe
                                    ? APIs.me.name
                                    : (_replyMessage!.senderName != null && _replyMessage!.senderName!.isNotEmpty
                                        ? _replyMessage!.senderName!
                                        : 'Member');
                                String replyText = _replyMessage!.msg;
                                if (_replyMessage!.type == Type.image) replyText = '📷 Photo';
                                if (_replyMessage!.type == Type.video) replyText = '🎬 Video';
                                if (_replyMessage!.type == Type.gif) replyText = '👾 GIF';

                                await APIs.sendGroupGif(
                                  _currentGroup,
                                  gif,
                                  replyToMsg: replyText,
                                  replyToSenderName: senderName,
                                  replyToType: _replyMessage!.type.name,
                                  replyToMediaUrl: (_replyMessage!.type == Type.image ||
                                          _replyMessage!.type == Type.video ||
                                          _replyMessage!.type == Type.gif)
                                      ? _replyMessage!.msg
                                      : null,
                                );
                                setState(() => _replyMessage = null);
                              } else {
                                await APIs.sendGroupGif(_currentGroup, gif);
                              }
                              _scrollToBottom();
                            },
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6, right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.3), width: 0.5),
                          ),
                          child: const Text(
                            'GIF',
                            style: TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      // Emoji button
                      GestureDetector(
                        onTap: _toggleEmojiKeyboard,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6, right: 8),
                          child: Icon(
                            _showEmoji ? CupertinoIcons.keyboard : CupertinoIcons.smiley,
                            color: const Color(0xFF007AFF),
                            size: 22,
                          ),
                        ),
                      ),

                      // Camera quick action
                      GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                          if (image != null) {
                            log('Image Path: ${image.path}');
                            setState(() => _isUploading = true);
                            await APIs.sendGroupImage(_currentGroup, File(image.path));
                            setState(() => _isUploading = false);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Icon(CupertinoIcons.camera_fill, color: Color(0xFF007AFF), size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // iMessage Blue Up Arrow Send Button
              GestureDetector(
                onTap: () {
                  if (_textController.text.trim().isNotEmpty) {
                    final text = _textController.text.trim();
                    _textController.text = '';
                    _focusNode.unfocus();

                    if (_replyMessage != null) {
                      final isMe = _replyMessage!.fromId == APIs.user.uid;
                      final senderName = isMe
                          ? APIs.me.name
                          : (_replyMessage!.senderName != null && _replyMessage!.senderName!.isNotEmpty
                              ? _replyMessage!.senderName!
                              : 'Member');
                      String replyText = _replyMessage!.msg;
                      if (_replyMessage!.type == Type.image) replyText = '📷 Photo';
                      if (_replyMessage!.type == Type.video) replyText = '🎬 Video';
                      if (_replyMessage!.type == Type.gif) replyText = '👾 GIF';

                      APIs.sendGroupMessage(
                        _currentGroup,
                        text,
                        Type.text,
                        replyToMsg: replyText,
                        replyToSenderName: senderName,
                        replyToType: _replyMessage!.type.name,
                        replyToMediaUrl: (_replyMessage!.type == Type.image ||
                                _replyMessage!.type == Type.video ||
                                _replyMessage!.type == Type.gif)
                            ? _replyMessage!.msg
                            : null,
                      );
                      setState(() => _replyMessage = null);
                    } else {
                      APIs.sendGroupMessage(_currentGroup, text, Type.text);
                    }
                    _scrollToBottom();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _hasTextNotifier,
                    builder: (context, hasText, _) {
                      return Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: hasText ? const Color(0xFF007AFF) : const Color(0xFF007AFF).withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 18),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleEmojiKeyboard() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      Future.delayed(const Duration(milliseconds: 50), () {
        _focusNode.requestFocus();
      });
    } else {
      _focusNode.unfocus();
      setState(() => _showEmoji = true);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _showMediaPickerBottomSheet() {
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    CustomContextMenuDialog.show(
      context: context,
      items: [
        ContextMenuItem(
          title: 'Photo Library',
          icon: CupertinoIcons.photo_on_rectangle,
          onTap: () async {
            final picker = ImagePicker();
            final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
            for (var i in images) {
              log('Image Path: ${i.path}');
              setState(() => _isUploading = true);
              await APIs.sendGroupImage(_currentGroup, File(i.path));
              setState(() => _isUploading = false);
            }
          },
        ),
        ContextMenuItem(
          title: 'Camera',
          icon: CupertinoIcons.camera,
          onTap: () async {
            final picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
            if (image != null) {
              log('Image Path: ${image.path}');
              setState(() => _isUploading = true);
              await APIs.sendGroupImage(_currentGroup, File(image.path));
              setState(() => _isUploading = false);
            }
          },
        ),
        ContextMenuItem(
          title: 'Video Library',
          icon: CupertinoIcons.film,
          onTap: () async {
            final picker = ImagePicker();
            final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
            if (video != null) {
              await _handleVideoSelection(File(video.path));
            }
          },
        ),
        ContextMenuItem(
          title: 'Record Video',
          icon: CupertinoIcons.videocam_fill,
          onTap: () async {
            final picker = ImagePicker();
            final XFile? video = await picker.pickVideo(source: ImageSource.camera);
            if (video != null) {
              await _handleVideoSelection(File(video.path));
            }
          },
        ),
      ],
    );
  }

  // Handle video size validation (50MB limit) and upload
  Future<void> _handleVideoSelection(File videoFile) async {
    try {
      final sizeInBytes = await videoFile.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      log('Selected group video size: ${sizeInMB.toStringAsFixed(2)}MB');

      if (sizeInMB > 50) {
        if (mounted) {
          Dialogs.showSnackbar(
            context,
            'Video too large (${sizeInMB.toStringAsFixed(1)}MB). Max size is 50MB.',
          );
        }
        return;
      }

      setState(() => _isUploading = true);
      await APIs.sendGroupVideo(_currentGroup, videoFile);
      if (mounted) setState(() => _isUploading = false);
      _scrollToBottom();
    } catch (e) {
      log('Error _handleVideoSelection: $e');
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
