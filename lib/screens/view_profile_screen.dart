import 'dart:ui';

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
import '../widgets/custom_context_menu_dialog.dart';
import '../widgets/full_screen_image_viewer.dart';

// View profile screen -- to view profile of another user with Light/Dark Theme Support
class ViewProfileScreen extends StatefulWidget {
  final ChatUser user;

  const ViewProfileScreen({super.key, required this.user});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: ThemeController.bgColor,
            extendBodyBehindAppBar: true,

            appBar: AppBar(
              toolbarHeight: 56,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: ClipRect(
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
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    SizedBox(width: 8),
                    Icon(CupertinoIcons.chevron_left, color: Color(0xFF007AFF), size: 22),
                  ],
                ),
              ),
              title: Text(
                widget.user.name,
                style: TextStyle(
                  color: ThemeController.textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),

            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Joined On: ',
                    style: TextStyle(color: ThemeController.subtextColor, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  Text(
                    MyDateUtil.getLastMessageTime(context: context, time: widget.user.createdAt, showYear: true),
                    style: const TextStyle(color: Color(0xFF007AFF), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            body: StreamBuilder(
              stream: APIs.getUserInfo(widget.user),
              builder: (context, snapshot) {
                final data = snapshot.data?.docs;
                final list = data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];
                final user = list.isNotEmpty ? list[0] : widget.user;

                final isOnline = MyDateUtil.isUserOnline(
                  isOnline: user.isOnline,
                  lastActive: user.lastActive,
                );
                final statusText = MyDateUtil.getLastActiveTime(
                  context: context,
                  lastActive: user.lastActive,
                  isOnline: user.isOnline,
                );

                return Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 60,
                    left: mq.width * .05,
                    right: mq.width * .05,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(width: mq.width, height: mq.height * .03),

                        // User Info Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: ThemeController.cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ThemeController.dividerColor.withValues(alpha: 0.4), width: 0.5),
                          ),
                          child: Column(
                            children: [
                              // User Profile Picture
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      opaque: false,
                                      barrierColor: Colors.black87,
                                      pageBuilder: (context, animation, secondaryAnimation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: FullScreenImageViewer(
                                            imageUrl: APIs.getOptimizedImageUrl(user.image, width: 800),
                                            heroTag: 'view_profile_${user.id}',
                                            title: user.name,
                                            showDownload: false,
                                            cacheManager: AvatarCacheManager.instance,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    Hero(
                                      tag: 'view_profile_${user.id}',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(mq.height * .1),
                                        child: CachedNetworkImage(
                                          width: mq.height * .16,
                                          height: mq.height * .16,
                                          fit: BoxFit.cover,
                                          imageUrl: APIs.getOptimizedImageUrl(user.image, width: 300),
                                          cacheManager: AvatarCacheManager.instance,
                                          fadeInDuration: Duration.zero,
                                          errorWidget: (context, url, error) => CircleAvatar(
                                            backgroundColor: ThemeController.headerColor,
                                            child: Icon(CupertinoIcons.person_fill, color: ThemeController.subtextColor, size: 50),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isOnline)
                                      Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF34C759),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: ThemeController.cardColor, width: 3.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // User Name
                              Text(
                                user.name,
                                style: TextStyle(
                                  color: ThemeController.textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // User Presence Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF34C759).withValues(alpha: 0.15)
                                      : ThemeController.dividerColor.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: isOnline ? const Color(0xFF34C759) : ThemeController.subtextColor,
                                    fontSize: 12,
                                    fontWeight: isOnline ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // User Email Label
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: ThemeController.subtextColor,
                                  fontSize: 14,
                                ),
                              ),

                              const SizedBox(height: 16),
                              Divider(color: ThemeController.dividerColor, height: 1, thickness: 0.5),
                              const SizedBox(height: 16),

                               // User About
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'About: ',
                                    style: TextStyle(color: ThemeController.subtextColor, fontWeight: FontWeight.w500, fontSize: 15),
                                  ),
                                  Expanded(
                                    child: Text(
                                      user.about.isNotEmpty ? user.about : 'Hey there! I am using BackSpace.',
                                      style: TextStyle(
                                        color: ThemeController.textColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),
                              Divider(color: ThemeController.dividerColor.withValues(alpha: 0.4), height: 1, thickness: 0.5),
                              const SizedBox(height: 16),

                              // Mute Notifications Tile
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  APIs.isChatMuted(widget.user.id)
                                      ? CupertinoIcons.bell_slash_fill
                                      : CupertinoIcons.bell_fill,
                                  color: const Color(0xFF007AFF),
                                ),
                                title: Text(
                                  'Mute Notifications',
                                  style: TextStyle(
                                    color: ThemeController.textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  APIs.isChatMuted(widget.user.id) ? 'Currently Muted' : 'Off',
                                  style: TextStyle(
                                    color: ThemeController.subtextColor,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Icon(
                                  CupertinoIcons.chevron_right,
                                  color: ThemeController.subtextColor,
                                  size: 16,
                                ),
                                onTap: () {
                                  if (APIs.isChatMuted(widget.user.id)) {
                                    APIs.unmuteChat(widget.user.id);
                                    Dialogs.showSnackbar(context, 'Unmuted ${widget.user.name}');
                                    setState(() {});
                                  } else {
                                    _showMuteDurationPicker(context);
                                  }
                                },
                              ),

                              Divider(color: ThemeController.dividerColor.withValues(alpha: 0.3), height: 1, thickness: 0.5),

                              // Block / Unblock Contact Tile
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  APIs.isUserBlocked(widget.user.id)
                                      ? CupertinoIcons.checkmark_shield_fill
                                      : CupertinoIcons.slash_circle_fill,
                                  color: APIs.isUserBlocked(widget.user.id)
                                      ? const Color(0xFF007AFF)
                                      : Colors.red,
                                ),
                                title: Text(
                                  APIs.isUserBlocked(widget.user.id) ? 'Unblock Contact' : 'Block Contact',
                                  style: TextStyle(
                                    color: APIs.isUserBlocked(widget.user.id)
                                        ? const Color(0xFF007AFF)
                                        : Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onTap: () async {
                                  if (APIs.isUserBlocked(widget.user.id)) {
                                    await APIs.unblockUser(widget.user.id);
                                    Dialogs.showSnackbar(context, 'Unblocked ${widget.user.name}');
                                  } else {
                                    await APIs.blockUser(widget.user.id);
                                    Dialogs.showSnackbar(context, 'Blocked ${widget.user.name}');
                                  }
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showMuteDurationPicker(BuildContext context) {
    CustomContextMenuDialog.show(
      context: context,
      title: 'Mute Notifications',
      items: [
        ContextMenuItem(
          title: '1 Hour',
          icon: CupertinoIcons.clock,
          onTap: () async {
            await APIs.muteChat(widget.user.id, MuteDuration.oneHour);
            Dialogs.showSnackbar(context, 'Muted for 1 Hour');
            setState(() {});
          },
        ),
        ContextMenuItem(
          title: '1 Week',
          icon: CupertinoIcons.calendar,
          onTap: () async {
            await APIs.muteChat(widget.user.id, MuteDuration.oneWeek);
            Dialogs.showSnackbar(context, 'Muted for 1 Week');
            setState(() {});
          },
        ),
        ContextMenuItem(
          title: 'Always',
          icon: CupertinoIcons.bell_slash_fill,
          isDestructive: true,
          onTap: () async {
            await APIs.muteChat(widget.user.id, MuteDuration.always);
            Dialogs.showSnackbar(context, 'Muted Always');
            setState(() {});
          },
        ),
      ],
    );
  }
}