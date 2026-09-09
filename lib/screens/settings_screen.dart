// ignore_for_file: use_build_context_synchronously

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../helper/theme_controller.dart';
import '../main.dart';
import '../widgets/adaptive_blur.dart';
import 'auth/login_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        final isDark = ThemeController.isDark;

        return Scaffold(
          backgroundColor: ThemeController.bgColor,
          extendBodyBehindAppBar: true,

          appBar: AppBar(
            toolbarHeight: 56,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: AdaptiveBlur(
              sigmaX: 30,
              sigmaY: 30,
              child: Container(
                decoration: BoxDecoration(
                  color: ThemeController.headerColor.withValues(alpha: ThemeController.headerAlpha),
                  border: Border(
                    bottom: BorderSide(
                      color: ThemeController.dividerColor.withValues(alpha: 0.4),
                      width: 0.5,
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
              'Settings',
              style: TextStyle(
                color: ThemeController.textColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),

          body: SingleChildScrollView(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 70, left: 16, right: 16, bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Frosted Profile Section Card
                AdaptiveBlur(
                  borderRadius: BorderRadius.circular(18),
                  sigmaX: 20,
                  sigmaY: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: ThemeController.cardColor.withValues(alpha: ThemeController.cardAlpha),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: ThemeController.dividerColor.withValues(alpha: 0.35),
                          width: 0.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProfileScreen(user: APIs.me)),
                            ).then((_) => setState(() {}));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(mq.height * .035),
                                  child: CachedNetworkImage(
                                    width: mq.height * .065,
                                    height: mq.height * .065,
                                    fit: BoxFit.cover,
                                    imageUrl: APIs.getOptimizedImageUrl(APIs.me.image, width: 150),
                                    errorWidget: (context, url, error) =>
                                        CircleAvatar(backgroundColor: const Color(0xFF2C2C2E), child: Icon(CupertinoIcons.person_fill, color: ThemeController.textColor, size: 28)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        APIs.me.name,
                                        style: TextStyle(
                                          color: ThemeController.textColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        APIs.me.email,
                                        style: TextStyle(
                                          color: ThemeController.subtextColor,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Edit Profile >',
                                        style: TextStyle(
                                          color: Color(0xFF007AFF),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
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
                  ),

                const SizedBox(height: 24),

                // Appearance & Theme Group
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'APPEARANCE',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                AdaptiveBlur(
                  borderRadius: BorderRadius.circular(16),
                  sigmaX: 20,
                  sigmaY: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: ThemeController.cardColor.withValues(alpha: ThemeController.cardAlpha),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ThemeController.dividerColor.withValues(alpha: 0.35),
                        width: 0.5,
                      ),
                    ),
                    child: ListTile(
                      leading: const Icon(CupertinoIcons.moon_stars_fill, color: Color(0xFF5856D6)),
                      title: Text(
                        'Dark Mode',
                        style: TextStyle(
                          color: ThemeController.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: CupertinoSwitch(
                        activeTrackColor: const Color(0xFF34C759),
                        value: isDark,
                        onChanged: (val) {
                          ThemeController.toggleTheme(val);
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Frosted Glass "Sign Out" Destructive Button
                AdaptiveBlur(
                  borderRadius: BorderRadius.circular(16),
                  sigmaX: 20,
                  sigmaY: 20,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        Dialogs.showProgressBar(context);
                        await APIs.updateActiveStatus(false);

                        await APIs.auth.signOut().then((value) async {
                          await GoogleSignIn().signOut().then((value) {
                            Navigator.pop(context);
                            Navigator.pop(context);
                            APIs.auth = FirebaseAuth.instance;

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          });
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: ThemeController.cardColor.withValues(alpha: ThemeController.cardAlpha),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.25),
                            width: 0.5,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
