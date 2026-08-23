import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/apis.dart';
import '../../helper/theme_controller.dart';
import '../../models/app_config_models.dart';

class WhatsNewDialog {
  static void show({
    required BuildContext context,
    required AppUpdateInfo updateInfo,
  }) {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => PopScope(
        canPop: !updateInfo.forceUpdate,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: ThemeController.cardColor.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: ThemeController.dividerColor.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Icon & Version Badge
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.sparkles,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Title
                    Text(
                      updateInfo.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ThemeController.textColor,
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Version Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        'Version ${updateInfo.latestVersion}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Release Notes List
                    if (updateInfo.releaseNotes.isNotEmpty) ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: updateInfo.releaseNotes.map((note) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2, right: 8),
                                      child: Icon(
                                        CupertinoIcons.checkmark_alt_circle_fill,
                                        size: 16,
                                        color: Color(0xFF34C759),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        note,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.35,
                                          color: ThemeController.textColor.withValues(alpha: 0.88),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else ...[
                      Text(
                        'A new update is available with performance improvements and bug fixes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: ThemeController.subtextColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        if (!updateInfo.forceUpdate) ...[
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              color: ThemeController.dividerColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                'Later',
                                style: TextStyle(
                                  color: ThemeController.textColor.withValues(alpha: 0.8),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: updateInfo.forceUpdate ? 1 : 2,
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(14),
                            onPressed: () {
                              if (!updateInfo.forceUpdate) Navigator.pop(ctx);
                              APIs.openUrl(updateInfo.downloadUrl);
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.arrow_down_circle_fill, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Update Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnnouncementDialog {
  static void show({
    required BuildContext context,
    required AppAnnouncement announcement,
    required VoidCallback onDismiss,
  }) {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                color: ThemeController.cardColor.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: ThemeController.dividerColor.withValues(alpha: 0.35),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Optional Banner Image Header
                  if (announcement.imageUrl != null && announcement.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: CachedNetworkImage(
                        imageUrl: announcement.imageUrl!,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 150,
                          color: ThemeController.dividerColor.withValues(alpha: 0.2),
                          child: const Center(child: CupertinoActivityIndicator()),
                        ),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon if no banner image
                        if (announcement.imageUrl == null || announcement.imageUrl!.isEmpty) ...[
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF9500), Color(0xFFFF2D55)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.speaker_2_fill,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Title
                        Text(
                          announcement.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: ThemeController.textColor,
                            letterSpacing: -0.4,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Message Body
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              announcement.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.45,
                                color: ThemeController.textColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(14),
                            onPressed: () {
                              Navigator.pop(ctx);
                              onDismiss();
                              if (announcement.actionUrl != null && announcement.actionUrl!.isNotEmpty) {
                                APIs.openUrl(announcement.actionUrl!);
                              }
                            },
                            child: Text(
                              announcement.buttonText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
    );
  }
}
