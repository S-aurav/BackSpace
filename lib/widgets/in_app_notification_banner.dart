import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/apis.dart';
import '../helper/cache_manager.dart';
import '../helper/theme_controller.dart';
import '../models/chat_user.dart';
import '../screens/chat_screen.dart';
import '../screens/group_chat_screen.dart';

class InAppNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show({
    BuildContext? context,
    required ChatUser sender,
    required String message,
    String? title,
    bool isStory = false,
    VoidCallback? onTap,
  }) {
    // If a notification is already visible, remove it
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = APIs.navigatorKey.currentState?.overlay ??
        (context != null ? Overlay.maybeOf(context, rootOverlay: true) : null);

    if (overlay == null) return;

    _currentEntry = OverlayEntry(
      builder: (ctx) => _InAppNotificationBannerWidget(
        sender: sender,
        message: message,
        title: title ?? sender.name,
        isStory: isStory,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
        onTap: () async {
          _currentEntry?.remove();
          _currentEntry = null;
          if (onTap != null) {
            onTap();
          } else {
            final nav = APIs.navigatorKey.currentState;
            if (nav != null) {
              if (sender.id.startsWith('group_') || sender.about == 'Group Chat') {
                final group = await APIs.getGroupById(sender.id);
                if (group != null) {
                  nav.push(MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
                  return;
                }
              }
              nav.push(
                MaterialPageRoute(builder: (_) => ChatScreen(user: sender)),
              );
            }
          }
        },
      ),
    );

    overlay.insert(_currentEntry!);

    // Auto-dismiss after 4.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 4500), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

class _InAppNotificationBannerWidget extends StatefulWidget {
  final ChatUser sender;
  final String message;
  final String title;
  final bool isStory;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _InAppNotificationBannerWidget({
    required this.sender,
    required this.message,
    required this.title,
    required this.isStory,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_InAppNotificationBannerWidget> createState() => _InAppNotificationBannerWidgetState();
}

class _InAppNotificationBannerWidgetState extends State<_InAppNotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = ThemeController.isDark;

    return Positioned(
      top: topPadding + 6,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -4) {
                _dismiss();
              }
            },
            onTap: () {
              _dismiss();
              widget.onTap();
            },
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: ThemeController.cardColor.withValues(alpha: isDark ? 0.88 : 0.94),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: ThemeController.dividerColor.withValues(alpha: 0.4),
                        width: 0.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar / Story Badge
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                imageUrl: APIs.getOptimizedImageUrl(widget.sender.image, width: 90),
                                cacheManager: AvatarCacheManager.instance,
                                errorWidget: (_, __, ___) => CircleAvatar(
                                  radius: 20,
                                  backgroundColor: ThemeController.headerColor,
                                  child: Icon(CupertinoIcons.person_fill, color: ThemeController.subtextColor, size: 20),
                                ),
                              ),
                            ),
                            if (widget.isStory)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF007AFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 8),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Title & Message Preview
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      color: ThemeController.textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Text(
                                    'now',
                                    style: TextStyle(
                                      color: ThemeController.subtextColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                style: TextStyle(
                                  color: ThemeController.textColor.withValues(alpha: 0.85),
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
