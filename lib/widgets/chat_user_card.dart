import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/apis.dart';
import '../helper/cache_manager.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../helper/theme_controller.dart';
import '../main.dart';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../screens/chat_screen.dart';
import '../screens/view_profile_screen.dart';
import 'custom_context_menu_dialog.dart';
import 'dialogs/profile_dialog.dart';

// Authentic iOS iMessage Contact List Item with Light/Dark Theme Support
class ChatUserCard extends StatefulWidget {
  final ChatUser user;

  const ChatUserCard({super.key, required this.user});

  @override
  State<ChatUserCard> createState() => _ChatUserCardState();
}

class _ChatUserCardState extends State<ChatUserCard> {
  Message? _message;

  @override
  Widget build(BuildContext context) {
    final isMuted = APIs.isChatMuted(widget.user.id);

    Offset? tapPos;
    return Column(
      children: [
        InkWell(
          onTapDown: (details) => tapPos = details.globalPosition,
          onTap: () {
            FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
            FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(user: widget.user)),
            );
          },
          onLongPress: () => _showContactOptionsSheet(context, widget.user, targetOffset: tapPos),
          child: StreamBuilder(
            stream: APIs.getLastMessage(widget.user),
            builder: (context, snapshot) {
              final data = snapshot.data?.docs;
              final list = data?.map((e) => Message.fromJson(e.data())).toList() ?? [];
              if (list.isNotEmpty) _message = list[0];

              final isUnread = _message != null &&
                  _message!.read.isEmpty &&
                  _message!.fromId != APIs.user.uid;

              return StreamBuilder(
                stream: APIs.getUserInfo(widget.user),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data?.docs;
                  final userList = userData?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];
                  final user = userList.isNotEmpty ? userList[0] : widget.user;
                  final isOnline = MyDateUtil.isUserOnline(
                    isOnline: user.isOnline,
                    lastActive: user.lastActive,
                  );

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        // Left Margin Spacer
                        const SizedBox(width: 14),

                        // User Avatar with Online Dot
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => ProfileDialog(user: widget.user),
                            );
                          },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(mq.height * .035),
                                child: CachedNetworkImage(
                                  width: mq.height * .06,
                                  height: mq.height * .06,
                                  fit: BoxFit.cover,
                                  imageUrl: APIs.getOptimizedImageUrl(widget.user.image, width: 150),
                                  cacheManager: AvatarCacheManager.instance,
                                  fadeInDuration: const Duration(milliseconds: 100),
                                  useOldImageOnUrlChange: true,
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(backgroundColor: ThemeController.cardColor, child: Icon(CupertinoIcons.person_fill, color: ThemeController.subtextColor)),
                                ),
                              ),
                              if (isOnline)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF34C759),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: ThemeController.bgColor, width: 2.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Name & Subtitle Preview
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.user.name,
                                style: TextStyle(
                                  color: ThemeController.textColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _message != null
                                    ? _message!.type == Type.image
                                        ? '📷 Photo'
                                        : _message!.type == Type.video
                                            ? '🎥 Video'
                                            : _message!.type == Type.gif
                                                ? '👾 GIF'
                                                : _message!.msg
                                    : widget.user.about,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isUnread ? ThemeController.textColor : ThemeController.subtextColor,
                                  fontSize: 15,
                                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Time, Mute Icon, Unread Blue Dot & Right Chevron
                        if (_message != null)
                          Row(
                            children: [
                              if (isMuted)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(
                                    CupertinoIcons.bell_slash_fill,
                                    color: Color(0xFF8E8E93),
                                    size: 14,
                                  ),
                                ),
                              Text(
                                MyDateUtil.getLastMessageTime(
                                  context: context,
                                  time: _message!.sent,
                                ),
                                style: TextStyle(
                                  color: isUnread ? const Color(0xFF007AFF) : ThemeController.subtextColor,
                                  fontSize: 14,
                                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              if (isUnread) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF007AFF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 4),
                              Icon(
                                CupertinoIcons.chevron_right,
                                color: ThemeController.subtextColor,
                                size: 14,
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Thin Separator Line
        Padding(
          padding: const EdgeInsets.only(left: 78),
          child: Divider(
            height: 1,
            color: ThemeController.dividerColor.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  void _showContactOptionsSheet(BuildContext context, ChatUser user, {Offset? targetOffset}) {
    final isMuted = APIs.isChatMuted(user.id);
    final isBlocked = APIs.isUserBlocked(user.id);

    CustomContextMenuDialog.show(
      context: context,
      title: user.name,
      targetOffset: targetOffset,
      items: [
        ContextMenuItem(
          title: isMuted ? 'Unmute' : 'Mute',
          icon: isMuted ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash,
          onTap: () {
            if (isMuted) {
              APIs.unmuteChat(user.id);
              Dialogs.showSnackbar(context, 'Unmuted ${user.name}');
              setState(() {});
            } else {
              _showMuteDurationPicker(context, user.id, user.name);
            }
          },
        ),
        ContextMenuItem(
          title: isBlocked ? 'Unblock Contact' : 'Block Contact',
          icon: isBlocked ? CupertinoIcons.checkmark_shield : CupertinoIcons.slash_circle,
          isDestructive: !isBlocked,
          onTap: () async {
            if (isBlocked) {
              await APIs.unblockUser(user.id);
              Dialogs.showSnackbar(context, 'Unblocked ${user.name}');
            } else {
              await APIs.blockUser(user.id);
              Dialogs.showSnackbar(context, 'Blocked ${user.name}');
            }
            setState(() {});
          },
        ),
        ContextMenuItem(
          title: 'View Profile',
          icon: CupertinoIcons.person_crop_circle,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ViewProfileScreen(user: user)),
            );
          },
        ),
      ],
    );
  }

  void _showMuteDurationPicker(BuildContext context, String id, String name) {
    CustomContextMenuDialog.show(
      context: context,
      title: 'Mute Notifications',
      items: [
        ContextMenuItem(
          title: '1 Hour',
          icon: CupertinoIcons.clock,
          onTap: () async {
            await APIs.muteChat(id, MuteDuration.oneHour);
            Dialogs.showSnackbar(context, 'Muted $name for 1 Hour');
            setState(() {});
          },
        ),
        ContextMenuItem(
          title: '1 Week',
          icon: CupertinoIcons.calendar,
          onTap: () async {
            await APIs.muteChat(id, MuteDuration.oneWeek);
            Dialogs.showSnackbar(context, 'Muted $name for 1 Week');
            setState(() {});
          },
        ),
        ContextMenuItem(
          title: 'Always',
          icon: CupertinoIcons.bell_slash_fill,
          isDestructive: true,
          onTap: () async {
            await APIs.muteChat(id, MuteDuration.always);
            Dialogs.showSnackbar(context, 'Muted $name Always');
            setState(() {});
          },
        ),
      ],
    );
  }
}