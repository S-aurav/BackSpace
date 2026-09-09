// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/apis.dart';
import '../helper/cache_manager.dart';
import '../helper/dialogs.dart';
import '../helper/theme_controller.dart';
import '../models/chat_user.dart';
import '../widgets/adaptive_blur.dart';
import 'group_chat_screen.dart';

// Create Group Screen -- Step 1: Select Members, Step 2: Set Group Subject & Photo
class CreateGroupScreen extends StatefulWidget {
  final List<ChatUser> availableContacts;

  const CreateGroupScreen({super.key, required this.availableContacts});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final Set<String> _selectedMemberIds = {};
  int _step = 1; // 1: Select Members, 2: Group Info

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _groupImage;
  Uint8List? _groupImageBytes;
  XFile? _groupImageXFile;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        return Scaffold(
          backgroundColor: ThemeController.bgColor,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            toolbarHeight: 56,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: AdaptiveBlur(
              sigma: 30,
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
              onTap: () {
                if (_step == 2) {
                  setState(() => _step = 1);
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Row(
                children: [
                  SizedBox(width: 8),
                  Icon(CupertinoIcons.chevron_left, color: Color(0xFF007AFF), size: 22),
                ],
              ),
            ),
            title: Text(
              _step == 1 ? 'Add Members' : 'New Group',
              style: TextStyle(
                color: ThemeController.textColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: [
              if (_step == 1)
                GestureDetector(
                  onTap: () {
                    if (_selectedMemberIds.isEmpty) {
                      Dialogs.showSnackbar(context, 'Select at least 1 contact');
                      return;
                    }
                    setState(() => _step = 2);
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        'Next',
                        style: TextStyle(
                          color: Color(0xFF007AFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: _step == 1 ? _buildMemberSelectionStep() : _buildGroupInfoStep(isDark),
        );
      },
    );
  }

  // Step 1: Contact selection with top horizontal selected avatar bar
  Widget _buildMemberSelectionStep() {
    final selectedUsers = widget.availableContacts
        .where((u) => _selectedMemberIds.contains(u.id))
        .toList();

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 60),

        // Horizontal Tray for Selected Members
        if (selectedUsers.isNotEmpty) ...[
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedUsers.length,
              itemBuilder: (context, index) {
                final user = selectedUsers[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMemberIds.remove(user.id);
                      });
                    },
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: CachedNetworkImage(
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                imageUrl: APIs.getOptimizedImageUrl(user.image, width: 100),
                                cacheManager: AvatarCacheManager.instance,
                                errorWidget: (context, url, error) => const CircleAvatar(
                                  child: Icon(CupertinoIcons.person_fill),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  CupertinoIcons.xmark,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 48,
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ThemeController.subtextColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(color: ThemeController.dividerColor.withValues(alpha: 0.3), height: 1),
        ],

        // Available Contacts List
        Expanded(
          child: widget.availableContacts.isNotEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.availableContacts.length,
                  itemBuilder: (context, index) {
                    final user = widget.availableContacts[index];
                    final isSelected = _selectedMemberIds.contains(user.id);

                    return ListTile(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedMemberIds.remove(user.id);
                          } else {
                            _selectedMemberIds.add(user.id);
                          }
                        });
                      },
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: CachedNetworkImage(
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          imageUrl: APIs.getOptimizedImageUrl(user.image, width: 100),
                          cacheManager: AvatarCacheManager.instance,
                          errorWidget: (context, url, error) => const CircleAvatar(
                            child: Icon(CupertinoIcons.person_fill),
                          ),
                        ),
                      ),
                      title: Text(
                        user.name,
                        style: TextStyle(
                          color: ThemeController.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        user.about,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ThemeController.subtextColor,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Icon(
                        isSelected
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.circle,
                        color: isSelected
                            ? const Color(0xFF007AFF)
                            : ThemeController.subtextColor.withValues(alpha: 0.5),
                        size: 24,
                      ),
                    );
                  },
                )
              : Center(
                  child: Text(
                    'No contacts available',
                    style: TextStyle(color: ThemeController.subtextColor, fontSize: 16),
                  ),
                ),
        ),
      ],
    );
  }

  // Step 2: Group Name, Description & Image Selection
  Widget _buildGroupInfoStep(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: MediaQuery.of(context).padding.top + 76,
        bottom: 32,
      ),
      child: Column(
        children: [
          // Group Avatar Selection
          Center(
            child: Stack(
              children: [
                _groupImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(55),
                        child: Image.memory(
                          _groupImageBytes!,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      )
                    : (_groupImage != null && !kIsWeb
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(55),
                            child: Image.file(
                              File(_groupImage!),
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.group_solid,
                              color: Color(0xFF007AFF),
                              size: 54,
                            ),
                          )),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickGroupImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        shape: BoxShape.circle,
                        border: Border.all(color: ThemeController.bgColor, width: 3),
                      ),
                      child: const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Group Details Input Card
          AdaptiveBlur(
            borderRadius: BorderRadius.circular(16),
            sigma: 20,
            child: Container(
              decoration: BoxDecoration(
                color: ThemeController.cardColor.withValues(alpha: ThemeController.cardAlpha),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ThemeController.dividerColor.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _nameController,
                        style: TextStyle(color: ThemeController.textColor, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Group Name',
                          labelStyle: TextStyle(color: ThemeController.subtextColor, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Divider(color: ThemeController.dividerColor.withValues(alpha: 0.4), height: 1, indent: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _descController,
                        style: TextStyle(color: ThemeController.textColor, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Group Description (Optional)',
                          labelStyle: TextStyle(color: ThemeController.subtextColor, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 28),

          // Create Group Button
          _isCreating
              ? const CupertinoActivityIndicator(color: Color(0xFF007AFF))
              : Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _submitCreateGroup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Create Group',
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
                ),
        ],
      ),
    );
  }

  // Image Picker for Group Photo
  Future<void> _pickGroupImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _groupImage = image.path;
        _groupImageBytes = bytes;
        _groupImageXFile = image;
      });
    }
  }

  // Create Group in Firestore
  Future<void> _submitCreateGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Dialogs.showSnackbar(context, 'Group Name is required');
      return;
    }

    setState(() => _isCreating = true);

    final group = await APIs.createGroup(
      name: name,
      description: _descController.text.trim(),
      memberIds: _selectedMemberIds.toList(),
      imageFile: _groupImageXFile ?? (_groupImage != null ? File(_groupImage!) : null),
    );

    setState(() => _isCreating = false);

    if (group != null && mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
      );
    } else if (mounted) {
      Dialogs.showSnackbar(context, 'Failed to create group');
    }
  }
}
