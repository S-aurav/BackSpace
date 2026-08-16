// ignore_for_file: use_build_context_synchronously

import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../helper/theme_controller.dart';
import '../main.dart';
import '../models/chat_user.dart';

// Profile screen -- Adapts dynamically to Light/Dark Mode with frosted glass iOS cards & iMessage edit dialogs
class ProfileScreen extends StatefulWidget {
  final ChatUser user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _image;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        final isDark = ThemeController.isDark;

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
                'Edit Profile',
                style: TextStyle(
                  color: ThemeController.textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),

            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: MediaQuery.of(context).padding.top + 76,
                  bottom: 32,
                ),
                child: Column(
                  children: [
                    // Avatar Header Section with Camera Badge
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              _image != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(mq.height * .1),
                                      child: Image.file(
                                        File(_image!),
                                        width: mq.height * .13,
                                        height: mq.height * .13,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(mq.height * .1),
                                      child: CachedNetworkImage(
                                        width: mq.height * .13,
                                        height: mq.height * .13,
                                        fit: BoxFit.cover,
                                        imageUrl: widget.user.image,
                                        errorWidget: (context, url, error) => const CircleAvatar(
                                          child: Icon(CupertinoIcons.person_fill),
                                        ),
                                      ),
                                    ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _showCupertinoPhotoSheet,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007AFF),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: ThemeController.bgColor, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            APIs.me.name.isNotEmpty ? APIs.me.name : widget.user.name,
                            style: TextStyle(
                              color: ThemeController.textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.user.email,
                            style: TextStyle(
                              color: ThemeController.subtextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Frosted Glass Grouped Input Container (iMessage Style)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: ThemeController.cardColor.withValues(alpha: isDark ? 0.75 : 0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ThemeController.dividerColor.withValues(alpha: 0.35),
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Name Row
                              ListTile(
                                onTap: _showEditNameDialog,
                                title: Text(
                                  'Name',
                                  style: TextStyle(
                                    color: ThemeController.subtextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  APIs.me.name.isNotEmpty ? APIs.me.name : widget.user.name,
                                  style: TextStyle(
                                    color: ThemeController.textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: const Icon(
                                  CupertinoIcons.pencil,
                                  color: Color(0xFF007AFF),
                                  size: 20,
                                ),
                              ),
                              Divider(
                                color: ThemeController.dividerColor.withValues(alpha: 0.3),
                                height: 1,
                                indent: 16,
                              ),
                              // Status Row
                              ListTile(
                                onTap: _showEditAboutDialog,
                                title: Text(
                                  'Status / About',
                                  style: TextStyle(
                                    color: ThemeController.subtextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  APIs.me.about.isNotEmpty ? APIs.me.about : widget.user.about,
                                  style: TextStyle(
                                    color: ThemeController.textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: const Icon(
                                  CupertinoIcons.pencil,
                                  color: Color(0xFF007AFF),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Cupertino Dialog for Editing Name
  void _showEditNameDialog() {
    String newName = APIs.me.name;
    final textController = TextEditingController(text: newName);

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Edit Name'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: textController,
            placeholder: 'Enter your name',
            placeholderStyle: const TextStyle(color: Color(0xFF8E8E93)),
            style: TextStyle(color: ThemeController.textColor),
            onChanged: (val) => newName = val,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              if (newName.trim().isNotEmpty) {
                APIs.me.name = newName.trim();
                await APIs.updateUserInfo();
                if (mounted) {
                  Navigator.pop(dialogContext);
                  setState(() {});
                  Dialogs.showSnackbar(context, 'Name updated successfully!');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Cupertino Dialog for Editing Status
  void _showEditAboutDialog() {
    String newAbout = APIs.me.about;
    final textController = TextEditingController(text: newAbout);

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Edit Status / About'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: textController,
            placeholder: 'Enter your status',
            placeholderStyle: const TextStyle(color: Color(0xFF8E8E93)),
            style: TextStyle(color: ThemeController.textColor),
            onChanged: (val) => newAbout = val,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              if (newAbout.trim().isNotEmpty) {
                APIs.me.about = newAbout.trim();
                await APIs.updateUserInfo();
                if (mounted) {
                  Navigator.pop(dialogContext);
                  setState(() {});
                  Dialogs.showSnackbar(context, 'Status updated successfully!');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Cupertino Action Sheet for Photo Selection
  void _showCupertinoPhotoSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Profile Picture', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        message: const Text('Select a new profile image'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, color: Color(0xFF007AFF)),
                SizedBox(width: 8),
                Text('Choose from Gallery', style: TextStyle(color: Color(0xFF007AFF))),
              ],
            ),
            onPressed: () async {
              Navigator.pop(context);
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (image != null) {
                log('Image Path: ${image.path}');
                setState(() => _image = image.path);
                APIs.updateProfilePicture(File(_image!));
              }
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, color: Color(0xFF007AFF)),
                SizedBox(width: 8),
                Text('Take Photo', style: TextStyle(color: Color(0xFF007AFF))),
              ],
            ),
            onPressed: () async {
              Navigator.pop(context);
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
              if (image != null) {
                log('Image Path: ${image.path}');
                setState(() => _image = image.path);
                APIs.updateProfilePicture(File(_image!));
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF007AFF))),
        ),
      ),
    );
  }
}