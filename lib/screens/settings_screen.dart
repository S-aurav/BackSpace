// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../helper/theme_controller.dart';
import '../main.dart';
import '../widgets/adaptive_blur.dart';
import '../helper/web_notification/web_notification.dart';
import 'auth/login_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _notifStatus = 'loading';
  bool _isLoadingNotif = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final status = await getNotificationPermissionStatus();
    if (mounted) {
      setState(() => _notifStatus = status);
    }
  }

  Future<void> _handleNotificationAction() async {
    if (_isLoadingNotif) return;

    if (_notifStatus == 'ios_safari_needs_pwa') {
      _showIOSPwaGuideSheet(context);
      return;
    }

    if (_notifStatus == 'granted') {
      // Send a test notification
      await APIs.sendTestNotification();
      if (mounted) {
        Dialogs.showSnackbar(context, '🔔 Test notification sent!');
      }
      return;
    }

    if (_notifStatus == 'denied') {
      _showBlockedDialog(context);
      return;
    }

    // Otherwise (prompt or default), request permission
    setState(() => _isLoadingNotif = true);
    final result = await APIs.enableNotifications();
    if (mounted) {
      setState(() {
        _notifStatus = result;
        _isLoadingNotif = false;
      });

      if (result == 'granted') {
        Dialogs.showSnackbar(context, 'Notifications enabled successfully!');
        APIs.sendTestNotification();
      } else if (result == 'ios_safari_needs_pwa') {
        _showIOSPwaGuideSheet(context);
      } else if (result == 'denied') {
        Dialogs.showSnackbar(context, 'Notification permission was denied.');
      }
    }
  }

  void _showBlockedDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Notifications Blocked'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Notifications are blocked in your browser or device settings. Please allow notifications for BackSpace to receive message alerts.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showIOSPwaGuideSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.themeMode,
        builder: (context, mode, child) {
          final isDark = ThemeController.isDark;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.bell_fill, color: Color(0xFF007AFF), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable on iPhone',
                              style: TextStyle(
                                color: ThemeController.textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Apple requires adding to Home Screen first',
                              style: TextStyle(
                                color: ThemeController.subtextColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildGuideStep(
                    stepNumber: '1',
                    icon: CupertinoIcons.share,
                    title: 'Tap the Share button',
                    description: 'Look for the share icon at the bottom of Safari (or browser menu).',
                  ),
                  const SizedBox(height: 14),
                  _buildGuideStep(
                    stepNumber: '2',
                    icon: CupertinoIcons.plus_square,
                    title: 'Select "Add to Home Screen"',
                    description: 'Scroll down the share sheet and tap "Add to Home Screen".',
                  ),
                  const SizedBox(height: 14),
                  _buildGuideStep(
                    stepNumber: '3',
                    icon: CupertinoIcons.app_badge,
                    title: 'Launch from Home Screen',
                    description: 'Open the BackSpace icon created on your iPhone Home Screen.',
                  ),
                  const SizedBox(height: 14),
                  _buildGuideStep(
                    stepNumber: '4',
                    icon: CupertinoIcons.checkmark_seal_fill,
                    title: 'Turn on Notifications in Settings',
                    description: 'Go to Settings in the installed app and tap Enable Notifications to allow alerts!',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Got It',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuideStep({
    required String stepNumber,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            stepNumber,
            style: const TextStyle(
              color: Color(0xFF007AFF),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: ThemeController.textColor),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: ThemeController.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: ThemeController.subtextColor,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getNotifIcon() {
    if (_notifStatus == 'granted') return CupertinoIcons.bell_fill;
    if (_notifStatus == 'denied') return CupertinoIcons.bell_slash_fill;
    if (_notifStatus == 'ios_safari_needs_pwa') return CupertinoIcons.bell_circle_fill;
    return CupertinoIcons.bell;
  }

  Color _getNotifIconColor() {
    if (_notifStatus == 'granted') return const Color(0xFF34C759);
    if (_notifStatus == 'denied') return Colors.redAccent;
    if (_notifStatus == 'ios_safari_needs_pwa') return const Color(0xFFFF9500);
    return const Color(0xFF007AFF);
  }

  String _getNotifSubtitle() {
    if (_isLoadingNotif) return 'Requesting permission...';
    if (_notifStatus == 'loading') return 'Checking status...';
    if (_notifStatus == 'granted') return 'Enabled • Tap to send test alert';
    if (_notifStatus == 'denied') return 'Blocked in settings • Tap for info';
    if (_notifStatus == 'ios_safari_needs_pwa') return 'iPhone setup required • Tap for steps';
    return 'Tap to enable push notifications';
  }

  Color _getNotifSubtitleColor() {
    if (_notifStatus == 'granted') return const Color(0xFF34C759);
    if (_notifStatus == 'denied') return Colors.redAccent;
    if (_notifStatus == 'ios_safari_needs_pwa') return const Color(0xFFFF9500);
    return ThemeController.subtextColor;
  }

  Widget _buildNotifTrailing() {
    if (_isLoadingNotif || _notifStatus == 'loading') {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CupertinoActivityIndicator(radius: 9),
      );
    }
    if (_notifStatus == 'granted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF34C759).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF34C759), size: 14),
            SizedBox(width: 4),
            Text(
              'Active',
              style: TextStyle(
                color: Color(0xFF34C759),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (_notifStatus == 'ios_safari_needs_pwa') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Setup',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 2),
            Icon(CupertinoIcons.chevron_right, color: Color(0xFF007AFF), size: 12),
          ],
        ),
      );
    }
    if (_notifStatus == 'denied') {
      return const Icon(CupertinoIcons.exclamationmark_circle, color: Colors.redAccent, size: 20);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Enable',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

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

                const SizedBox(height: 14),


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

                const SizedBox(height: 18),

                // Notifications Group
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'NOTIFICATIONS',
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
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _handleNotificationAction,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _getNotifIconColor().withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getNotifIcon(),
                                  color: _getNotifIconColor(),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Push Notifications',
                                      style: TextStyle(
                                        color: ThemeController.textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getNotifSubtitle(),
                                      style: TextStyle(
                                        color: _getNotifSubtitleColor(),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildNotifTrailing(),
                            ],
                          ),
                        ),
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
