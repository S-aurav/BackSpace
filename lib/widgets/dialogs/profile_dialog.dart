import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../helper/cache_manager.dart';
import '../../helper/theme_controller.dart';
import '../../main.dart';
import '../../models/chat_user.dart';
import '../../screens/view_profile_screen.dart';
import '../full_screen_image_viewer.dart';

class ProfileDialog extends StatelessWidget {
  const ProfileDialog({super.key, required this.user});

  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      backgroundColor: ThemeController.cardColor.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
          width: mq.width * .6,
          height: mq.height * .35,
          child: Stack(
            children: [
              // User profile picture — tap to open full screen viewer
              Positioned(
                top: mq.height * .075,
                left: mq.width * .1,
                child: GestureDetector(
                  onTap: () {
                    // Close the dialog first
                    Navigator.pop(context);
                    // Open full screen zoomable image viewer
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        opaque: false,
                        barrierColor: Colors.black87,
                        pageBuilder: (context, animation, secondaryAnimation) {
                          return FadeTransition(
                            opacity: animation,
                            child: FullScreenImageViewer(
                              imageUrl: user.image,
                              heroTag: 'profile_${user.id}',
                              title: user.name,
                              showDownload: false,
                              cacheManager: AvatarCacheManager.instance,
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'profile_${user.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(mq.height * .25),
                      child: CachedNetworkImage(
                        width: mq.width * .5,
                        fit: BoxFit.cover,
                        imageUrl: user.image,
                        cacheManager: AvatarCacheManager.instance,
                        fadeInDuration: Duration.zero,
                        errorWidget: (context, url, error) =>
                            CircleAvatar(
                              backgroundColor: ThemeController.dividerColor,
                              child: Icon(CupertinoIcons.person, color: ThemeController.subtextColor),
                            ),
                      ),
                    ),
                  ),
                ),
              ),

              // User name
              Positioned(
                left: mq.width * .04,
                top: mq.height * .02,
                width: mq.width * .45,
                child: Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ThemeController.textColor,
                  ),
                ),
              ),

              // Info button — navigate to profile screen
              Positioned(
                  right: 8,
                  top: 6,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ViewProfileScreen(user: user)));
                    },
                    child: const Icon(CupertinoIcons.info_circle,
                        color: Color(0xFF007AFF), size: 26),
                  ))
            ],
          )),
    );
  }
}