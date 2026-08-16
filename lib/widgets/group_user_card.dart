import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/apis.dart';
import '../helper/cache_manager.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../helper/theme_controller.dart';
import '../main.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../screens/group_chat_screen.dart';
import '../screens/group_info_screen.dart';
import 'custom_context_menu_dialog.dart';
import 'full_screen_image_viewer.dart';

class GroupUserCard extends StatefulWidget {
  final GroupChat group;

  const GroupUserCard({super.key, required this.group});

  @override
  State<GroupUserCard> createState() => _GroupUserCardState();
}

class _GroupUserCardState extends State<GroupUserCard> {
  Message? _lastMessage;

  void _showMuteDurationPicker(BuildContext context, GroupChat group, {Offset? targetOffset}) {
    CustomContextMenuDialog.show(
      context: context,
      title: 'Mute "${group.name}"',
      targetOffset: targetOffset,
      items: [
        ContextMenuItem(
          title: '1 Hour',
          icon: CupertinoIcons.clock,
          onTap: () async {
            await APIs.muteChat(group.id, MuteDuration.oneHour);
            if (mounted) setState(() {});
            Dialogs.showSnackbar(context, 'Muted notifications for 1 hour');
          },
        ),
        ContextMenuItem(
          title: '1 Week',
          icon: CupertinoIcons.calendar,
          onTap: () async {
            await APIs.muteChat(group.id, MuteDuration.oneWeek);
            if (mounted) setState(() {});
            Dialogs.showSnackbar(context, 'Muted notifications for 1 week');
          },
        ),
        ContextMenuItem(
          title: 'Always',
          icon: CupertinoIcons.bell_slash_fill,
          isDestructive: true,
          onTap: () async {
            await APIs.muteChat(group.id, MuteDuration.always);
            if (mounted) setState(() {});
            Dialogs.showSnackbar(context, 'Muted notifications');
          },
        ),
      ],
    );
  }

  void _showGroupOptionsSheet(BuildContext context, GroupChat group, {Offset? targetOffset}) {
    final isMuted = APIs.isChatMuted(group.id);

    CustomContextMenuDialog.show(
      context: context,
      title: group.name,
      targetOffset: targetOffset,
      items: [
        ContextMenuItem(
          title: isMuted ? 'Unmute Notifications' : 'Mute Notifications',
          icon: isMuted ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill,
          onTap: () async {
            if (isMuted) {
              await APIs.unmuteChat(group.id);
              if (mounted) setState(() {});
              Dialogs.showSnackbar(context, 'Unmuted notifications');
            } else {
              _showMuteDurationPicker(context, group, targetOffset: targetOffset);
            }
          },
        ),
        ContextMenuItem(
          title: 'Group Info',
          icon: CupertinoIcons.info_circle_fill,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GroupInfoScreen(group: group)),
            );
          },
        ),
        ContextMenuItem(
          title: 'Exit Group',
          icon: CupertinoIcons.square_arrow_right,
          isDestructive: true,
          onTap: () async {
            final confirm = await showCupertinoDialog<bool>(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: Text('Exit "${group.name}"?'),
                content: const Text('You will no longer receive messages from this group.'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: const Text('Exit Group'),
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await APIs.leaveGroup(group);
              if (mounted) Dialogs.showSnackbar(context, 'Left group "${group.name}"');
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final isMuted = APIs.isChatMuted(group.id);
    Offset? tapPos;

    return StreamBuilder(
      stream: APIs.getLastGroupMessage(group),
      builder: (context, snapshot) {
        final data = snapshot.data?.docs;
        final list = data?.map((e) => Message.fromJson(e.data())).toList() ?? [];
        if (list.isNotEmpty) _lastMessage = list[0];

        final isUnread = _lastMessage != null &&
            _lastMessage!.fromId != APIs.user.uid &&
            !_lastMessage!.read.contains(APIs.user.uid);

        return Column(
          children: [
            InkWell(
              onTapDown: (details) => tapPos = details.globalPosition,
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
                );
              },
              onLongPress: () => _showGroupOptionsSheet(context, group, targetOffset: tapPos),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Left Margin Spacer
                    const SizedBox(width: 14),

                    // Group Avatar with Group Icon Badge
                    GestureDetector(
                      onTap: () {
                        if (group.image.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imageUrl: group.image,
                                heroTag: 'group_avatar_${group.id}',
                                title: group.name,
                                subtitle: '${group.members.length} members',
                              ),
                            ),
                          );
                        }
                      },
                      child: Hero(
                        tag: 'group_avatar_${group.id}',
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(mq.height * .035),
                              child: group.image.isNotEmpty
                                  ? CachedNetworkImage(
                                      width: mq.height * .06,
                                      height: mq.height * .06,
                                      fit: BoxFit.cover,
                                      imageUrl: APIs.getOptimizedImageUrl(group.image, width: 150),
                                      cacheManager: AvatarCacheManager.instance,
                                      errorWidget: (context, url, error) => CircleAvatar(
                                        radius: mq.height * .03,
                                        child: const Icon(CupertinoIcons.group_solid),
                                      ),
                                    )
                                  : Container(
                                      width: mq.height * .06,
                                      height: mq.height * .06,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.group_solid,
                                        color: Color(0xFF007AFF),
                                        size: 24,
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: ThemeController.bgColor, width: 2),
                                ),
                                child: const Icon(
                                  CupertinoIcons.group_solid,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Group Title & Message Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ThemeController.textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (_lastMessage != null || group.lastMessageTime.isNotEmpty)
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
                                        time: _lastMessage != null ? _lastMessage!.sent : group.lastMessageTime,
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
                          const SizedBox(height: 3),
                          Text(
                            _lastMessage != null
                                ? (_lastMessage!.senderName != null && _lastMessage!.senderName!.isNotEmpty
                                    ? '${_lastMessage!.senderName}: ${_lastMessage!.type == Type.image ? '📷 Photo' : _lastMessage!.type == Type.video ? '🎥 Video' : _lastMessage!.msg}'
                                    : _lastMessage!.msg)
                                : (group.lastMessageSenderName.isNotEmpty
                                    ? '${group.lastMessageSenderName}: ${group.lastMessage}'
                                    : group.lastMessage),
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
                  ],
                ),
              ),
            ),
            // iOS Inset Divider matching ChatUserCard (82px indent)
            Divider(
              color: ThemeController.dividerColor,
              height: 1,
              indent: 82,
              endIndent: 0,
            ),
          ],
        );
      },
    );
  }
}
