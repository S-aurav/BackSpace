import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/apis.dart';
import '../helper/cache_manager.dart';
import '../helper/dialogs.dart';
import '../helper/theme_controller.dart';
import '../models/chat_user.dart';
import '../models/group.dart';

// Cupertino / iMessage Sheet to Add New Members to an Existing Group
class AddGroupMembersSheet extends StatefulWidget {
  final GroupChat group;

  const AddGroupMembersSheet({super.key, required this.group});

  @override
  State<AddGroupMembersSheet> createState() => _AddGroupMembersSheetState();
}

class _AddGroupMembersSheetState extends State<AddGroupMembersSheet> {
  final Set<String> _selectedIds = {};
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: ThemeController.bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ThemeController.dividerColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  'Add Members',
                  style: TextStyle(
                    color: ThemeController.textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _selectedIds.isEmpty || _isAdding ? null : _addSelectedMembers,
                  child: Text(
                    _selectedIds.isNotEmpty ? 'Add (${_selectedIds.length})' : 'Add',
                    style: TextStyle(
                      color: _selectedIds.isNotEmpty && !_isAdding
                          ? const Color(0xFF007AFF)
                          : const Color(0xFF007AFF).withValues(alpha: 0.35),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contacts Stream Body
          Expanded(
            child: StreamBuilder(
              stream: APIs.getMyUsersId(),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                  case ConnectionState.none:
                    return const Center(child: CupertinoActivityIndicator(color: Color(0xFF007AFF)));

                  case ConnectionState.active:
                  case ConnectionState.done:
                    final ids = snapshot.data?.docs.map((e) => e.id).toList() ?? [];

                    if (ids.isEmpty) {
                      return const Center(
                        child: Text(
                          'No contacts available',
                          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                        ),
                      );
                    }

                    return StreamBuilder(
                      stream: APIs.getAllUsers(ids),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const Center(child: CupertinoActivityIndicator(color: Color(0xFF007AFF)));
                        }

                        final docs = userSnapshot.data?.docs ?? [];
                        final allUsers = docs.map((e) => ChatUser.fromJson(e.data())).toList();

                        // Filter out users who are already in the group
                        final eligibleUsers = allUsers.where((u) => !widget.group.members.contains(u.id)).toList();

                        if (eligibleUsers.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.checkmark_seal_fill,
                                    size: 48,
                                    color: const Color(0xFF007AFF).withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'All contacts are already in this group!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ThemeController.subtextColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: eligibleUsers.length,
                          separatorBuilder: (_, __) => Divider(
                            color: ThemeController.dividerColor.withValues(alpha: 0.3),
                            height: 1,
                            indent: 68,
                          ),
                          itemBuilder: (context, index) {
                            final user = eligibleUsers[index];
                            final isSelected = _selectedIds.contains(user.id);

                            return ListTile(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(user.id);
                                  } else {
                                    _selectedIds.add(user.id);
                                  }
                                });
                              },
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: CachedNetworkImage(
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  imageUrl: APIs.getOptimizedImageUrl(user.image, width: 80),
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
                              trailing: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF007AFF) : ThemeController.subtextColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white)
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedIds.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      Dialogs.showProgressBar(context);
      final newIds = _selectedIds.toList();
      await APIs.addGroupMembers(widget.group, newIds);
      widget.group.members.addAll(newIds);

      if (mounted) {
        Navigator.pop(context); // close progress bar
        Navigator.pop(context, newIds.length); // close sheet
        Dialogs.showSnackbar(context, 'Added ${newIds.length} member(s) to group!');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isAdding = false);
        Dialogs.showSnackbar(context, 'Failed to add members');
      }
    }
  }
}
