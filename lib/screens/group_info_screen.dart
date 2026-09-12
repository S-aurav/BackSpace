// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/apis.dart';
import '../helper/cache_manager.dart';
import '../helper/dialogs.dart';
import '../helper/my_date_util.dart';
import '../helper/theme_controller.dart';
import '../models/chat_user.dart';
import '../models/group.dart';
import '../widgets/adaptive_blur.dart';
import '../widgets/add_group_members_sheet.dart';
import '../widgets/custom_context_menu_dialog.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/linkify_text.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'view_profile_screen.dart';

// Group Info Screen -- Details, Members List, Admin Management & Leave Group
class GroupInfoScreen extends StatefulWidget {
  final GroupChat group;

  const GroupInfoScreen({super.key, required this.group});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late GroupChat _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  @override
  Widget build(BuildContext context) {
    final isMember = _group.members.contains(APIs.user.uid);
    final isMuted = APIs.isChatMuted(_group.id);

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
              onTap: () => Navigator.pop(context),
              child: const Row(
                children: [
                  SizedBox(width: 8),
                  Icon(CupertinoIcons.chevron_left, color: Color(0xFF007AFF), size: 22),
                ],
              ),
            ),
            title: Text(
              'Group Info',
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
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: MediaQuery.of(context).padding.top + 76,
              bottom: 32,
            ),
            child: Column(
              children: [
                // Group Avatar & Title
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_group.image.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImageViewer(
                                      imageUrl: _group.image,
                                      heroTag: 'group_info_avatar_${_group.id}',
                                      title: _group.name,
                                      subtitle: '${_group.members.length} members',
                                    ),
                                  ),
                                );
                              } else if (isMember) {
                                _editGroupImage();
                              }
                            },
                            child: Hero(
                              tag: 'group_info_avatar_${_group.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(55),
                                child: _group.image.isNotEmpty
                                    ? CachedNetworkImage(
                                        width: 110,
                                        height: 110,
                                        fit: BoxFit.cover,
                                        imageUrl: APIs.getOptimizedImageUrl(_group.image, width: 200),
                                        cacheManager: AvatarCacheManager.instance,
                                        errorWidget: (context, url, error) => const CircleAvatar(
                                          radius: 55,
                                          child: Icon(CupertinoIcons.group_solid, size: 48),
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
                                      ),
                              ),
                            ),
                          ),
                          if (isMember)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _editGroupImage,
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
                      const SizedBox(height: 14),
                      Text(
                        _group.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ThemeController.textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_group.members.length} Members',
                        style: TextStyle(
                          color: ThemeController.subtextColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Group Description Card (Editable by all Members)
                GestureDetector(
                  onTap: isMember ? _showEditDescriptionDialog : null,
                  child: AdaptiveBlur(
                    borderRadius: BorderRadius.circular(16),
                    sigma: 20,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThemeController.cardColor.withValues(alpha: ThemeController.cardAlpha),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ThemeController.dividerColor.withValues(alpha: 0.35),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'DESCRIPTION',
                                  style: TextStyle(
                                    color: ThemeController.subtextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isMember)
                                  const Icon(
                                    CupertinoIcons.pencil,
                                    color: Color(0xFF007AFF),
                                    size: 16,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _group.description.isNotEmpty
                                ? LinkifyText(
                                    text: _group.description,
                                    style: TextStyle(
                                      color: ThemeController.textColor,
                                      fontSize: 15,
                                      height: 1.3,
                                    ),
                                  )
                                : Text(
                                    isMember ? 'Tap to add group description...' : 'No description set.',
                                    style: TextStyle(
                                      color: ThemeController.subtextColor,
                                      fontSize: 15,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Mute Notifications Settings Tile
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
                      child: ListTile(
                        leading: Icon(
                          isMuted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell_fill,
                          color: isMuted ? const Color(0xFFFF9500) : const Color(0xFF007AFF),
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
                          isMuted ? 'Notifications muted' : 'Receive group notifications',
                          style: TextStyle(
                            color: ThemeController.subtextColor,
                            fontSize: 13,
                          ),
                        ),
                        trailing: CupertinoSwitch(
                          value: isMuted,
                          activeColor: const Color(0xFFFF9500),
                          onChanged: (val) async {
                            if (val) {
                              _showMuteDurationPicker();
                            } else {
                              await APIs.unmuteChat(_group.id);
                              if (mounted) setState(() {});
                              Dialogs.showSnackbar(context, 'Unmuted notifications');
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Members Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MEMBERS (${_group.members.length})',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isMember)
                      GestureDetector(
                        onTap: _showAddMembersModal,
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.person_add_solid, color: Color(0xFF007AFF), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Add Members',
                              style: TextStyle(
                                color: Color(0xFF007AFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Members List Container
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
                      child: StreamBuilder(
                        stream: APIs.getAllUsers(_group.members),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(child: CupertinoActivityIndicator(color: Color(0xFF007AFF))),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];
                          final membersList = docs.map((e) => ChatUser.fromJson(e.data())).toList();

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Add Members top tile for any group member
                              if (isMember) ...[
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                  onTap: _showAddMembersModal,
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF007AFF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(CupertinoIcons.person_add_solid, color: Colors.white, size: 20),
                                  ),
                                  title: const Text(
                                    'Add Members',
                                    style: TextStyle(
                                      color: Color(0xFF007AFF),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Divider(
                                  color: ThemeController.dividerColor.withValues(alpha: 0.3),
                                  height: 1,
                                  indent: 68,
                                ),
                              ],

                              ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: membersList.length,
                                separatorBuilder: (_, __) => Divider(
                                  color: ThemeController.dividerColor.withValues(alpha: 0.3),
                                  height: 1,
                                  indent: 68,
                                ),
                                itemBuilder: (context, index) {
                              final member = membersList[index];
                              final isMemberAdmin = _group.admins.contains(member.id);
                              final isCurrentUser = member.id == APIs.user.uid;
                              final isOnline = MyDateUtil.isUserOnline(isOnline: member.isOnline, lastActive: member.lastActive);

                               Offset? tapPos;
                               return GestureDetector(
                                 onTapDown: (details) => tapPos = details.globalPosition,
                                 onLongPressDown: (details) => tapPos = details.globalPosition,
                                 child: ListTile(
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                   onTap: () {
                                     if (isCurrentUser) {
                                       Navigator.push(
                                         context,
                                         MaterialPageRoute(builder: (_) => ProfileScreen(user: APIs.me)),
                                       );
                                     } else {
                                       _showMemberOptionsSheet(member, isMemberAdmin, targetOffset: tapPos);
                                     }
                                   },
                                   onLongPress: () {
                                     if (!isCurrentUser) {
                                       _showMemberOptionsSheet(member, isMemberAdmin, targetOffset: tapPos);
                                     }
                                   },
                                leading: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: CachedNetworkImage(
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        imageUrl: APIs.getOptimizedImageUrl(member.image, width: 80),
                                        cacheManager: AvatarCacheManager.instance,
                                        errorWidget: (context, url, error) => const CircleAvatar(
                                          child: Icon(CupertinoIcons.person_fill),
                                        ),
                                      ),
                                    ),
                                    if (isOnline)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 11,
                                          height: 11,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF34C759),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: ThemeController.bgColor, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  isCurrentUser ? '${member.name} (You)' : member.name,
                                  style: TextStyle(
                                    color: ThemeController.textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  member.about,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ThemeController.subtextColor,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isMemberAdmin) ...[
                                      const Icon(CupertinoIcons.shield_fill, color: Color(0xFF007AFF), size: 18),
                                      const SizedBox(width: 8),
                                    ],
                                    if (isOnline)
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF34C759),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

                const SizedBox(height: 28),

                // Exit Group Button
                GestureDetector(
                  onTap: _confirmLeaveGroup,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Exit Group',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

  // Open Add Group Members Modal Sheet
  void _showAddMembersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddGroupMembersSheet(group: _group),
    ).then((addedCount) {
      if (addedCount != null && addedCount is int && addedCount > 0) {
        setState(() {});
      }
    });
  }

  void _showMuteDurationPicker({Offset? targetOffset}) {
    CustomContextMenuDialog.show(
      context: context,
      title: 'Mute "${_group.name}"',
      targetOffset: targetOffset,
      items: [
        ContextMenuItem(
          title: '1 Hour',
          icon: CupertinoIcons.clock,
          onTap: () async {
            await APIs.muteChat(_group.id, MuteDuration.oneHour);
            if (mounted) setState(() {});
            Dialogs.showSnackbar(context, 'Muted notifications for 1 hour');
          },
        ),
        ContextMenuItem(
          title: '1 Week',
          icon: CupertinoIcons.calendar,
          onTap: () async {
            await APIs.muteChat(_group.id, MuteDuration.oneWeek);
            if (mounted) setState(() {});
            Dialogs.showSnackbar(context, 'Muted notifications for 1 week');
          },
        ),
        ContextMenuItem(
          title: 'Always',
          icon: CupertinoIcons.bell_slash_fill,
          isDestructive: true,
          onTap: () async {
            await APIs.muteChat(_group.id, MuteDuration.always);
            if (mounted) setState(() {});
            Dialogs.showSnackbar(context, 'Muted notifications');
          },
        ),
      ],
    );
  }

  // Edit Group Photo
  Future<void> _editGroupImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      Dialogs.showProgressBar(context);
      await APIs.updateGroupInfo(_group, _group.name, _group.description, image);
      Navigator.pop(context);
      Dialogs.showSnackbar(context, 'Group photo updated');
      setState(() {});
    }
  }

  // Cupertino Dialog for Editing Group Description (Identical to Edit Profile)
  void _showEditDescriptionDialog() {
    String newDesc = _group.description;
    final textController = TextEditingController(text: newDesc);

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Edit Group Description'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: textController,
            placeholder: 'Enter group description',
            placeholderStyle: const TextStyle(color: Color(0xFF8E8E93)),
            style: TextStyle(color: ThemeController.textColor),
            maxLines: 3,
            onChanged: (val) => newDesc = val,
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
              final trimmedDesc = newDesc.trim();
              Navigator.pop(dialogContext);
              setState(() {
                _group.description = trimmedDesc;
              });
              await APIs.updateGroupInfo(_group, _group.name, trimmedDesc, null);
              if (mounted) {
                Dialogs.showSnackbar(context, 'Group description updated successfully!');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Show Member Options Context Menu (Tap or Long Press)
  void _showMemberOptionsSheet(ChatUser member, bool isMemberAdmin, {Offset? targetOffset}) {
    final bool isAdmin = _group.admins.contains(APIs.user.uid);
    final bool isOwner = _group.createdBy == APIs.user.uid;

    CustomContextMenuDialog.show(
      context: context,
      title: member.name,
      targetOffset: targetOffset,
      items: [
        // 1. WhatsApp style "Message <Name>" option
        ContextMenuItem(
          title: 'Message ${member.name}',
          icon: CupertinoIcons.chat_bubble_fill,
          onTap: () async {
            // Establish contact relationship in my_users
            await APIs.addChatUser(member.email);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(user: member)),
              );
            }
          },
        ),

        // 2. View Profile
        ContextMenuItem(
          title: 'View Profile',
          icon: CupertinoIcons.person_crop_circle,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ViewProfileScreen(user: member)),
            );
          },
        ),

        // 3. Admin-only management options
        if (isAdmin && !isMemberAdmin)
          ContextMenuItem(
            title: 'Make Group Admin',
            icon: CupertinoIcons.shield_fill,
            onTap: () async {
              await APIs.makeGroupAdmin(_group, member.id);
              setState(() {
                if (!_group.admins.contains(member.id)) {
                  _group.admins.add(member.id);
                }
              });
              if (mounted) Dialogs.showSnackbar(context, '${member.name} is now a Group Admin!');
            },
          ),
        if (isAdmin && isOwner && isMemberAdmin && member.id != _group.createdBy)
          ContextMenuItem(
            title: 'Dismiss as Admin',
            icon: CupertinoIcons.shield_slash_fill,
            onTap: () async {
              await APIs.removeGroupAdmin(_group, member.id);
              setState(() {
                _group.admins.remove(member.id);
              });
              if (mounted) Dialogs.showSnackbar(context, '${member.name} is no longer an Admin');
            },
          ),
        if (isAdmin)
          ContextMenuItem(
            title: 'Remove from Group',
            icon: CupertinoIcons.person_badge_minus,
            isDestructive: true,
            onTap: () {
              _removeMember(member);
            },
          ),
      ],
    );
  }

  // Admin removes member
  Future<void> _removeMember(ChatUser member) async {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${member.name} from the group?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await APIs.removeGroupMember(_group, member.id);
              if (mounted) {
                setState(() {
                  _group.members.remove(member.id);
                });
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // Leave Group
  void _confirmLeaveGroup() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Exit Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await APIs.leaveGroup(_group);
              Navigator.pop(context); // pop GroupInfo
              Navigator.pop(context); // pop GroupChat
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
