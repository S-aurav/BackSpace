import 'dart:developer';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../helper/theme_controller.dart';
import '../models/chat_user.dart';
import '../models/group.dart';
import '../widgets/chat_user_card.dart';
import '../widgets/custom_context_menu_dialog.dart';
import '../widgets/group_user_card.dart';
import '../widgets/status_tray.dart';
import 'create_group_screen.dart';
import 'settings_screen.dart';

// Home Screen -- Authentic iOS iMessage Clone with Groups & Direct Messages
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ChatUser> _list = [];
  final List<ChatUser> _searchList = [];

  List<GroupChat> _groupsList = [];
  final List<GroupChat> _searchGroupsList = [];

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late Stream<QuerySnapshot<Map<String, dynamic>>> _myUsersStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _myGroupsStream;

  @override
  void initState() {
    super.initState();
    APIs.getSelfInfo();
    _myUsersStream = APIs.getMyUsersId();
    _myGroupsStream = APIs.getMyGroups();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAppUpdate());
  }

  void _checkAppUpdate() async {
    try {
      final doc = await APIs.firestore.collection('config').doc('app_version').get();
      log('CheckAppUpdate doc exists: ${doc.exists}, data: ${doc.data()}');

      if (doc.exists && doc.data() != null) {
        final rawData = doc.data()!;
        final Map<String, dynamic> data = {};
        rawData.forEach((key, value) {
          data[key.trim()] = value;
        });

        final latestVersion = (data['latest_version'] ?? data['latestVersion'] ?? '2.0.0').toString().trim();
        final downloadUrl = (data['download_url'] ?? data['downloadUrl'] ?? 'https://github.com/S-aurav/BackSpace/releases').toString();
        final forceUpdate = (data['force_update'] ?? data['forceUpdate'] ?? false) as bool;

        // Current app version (from pubspec.yaml)
        const currentVersion = '2.0.0';
        log('Comparing versions: latest="$latestVersion", current="$currentVersion"');

        if (latestVersion != currentVersion) {
          if (!mounted) return;
          showCupertinoDialog(
            context: context,
            barrierDismissible: !forceUpdate,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('🎉 Update Available!'),
              content: Text(
                'Version $latestVersion is now available with new features & performance fixes.\n\nPlease update to get the latest experience!',
              ),
              actions: [
                if (!forceUpdate)
                  CupertinoDialogAction(
                    child: const Text('Later'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Download Update'),
                  onPressed: () {
                    if (!forceUpdate) Navigator.pop(ctx);
                    APIs.openUrl(downloadUrl);
                  },
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      log('Error checking update: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 60.0;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: ThemeController.bgColor,
            extendBodyBehindAppBar: true,

            // Authentic iOS Acrylic / Frosted Glass Top Bar
            appBar: AppBar(
              toolbarHeight: 60,
              automaticallyImplyLeading: false,
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
              title: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Back',
                      style: TextStyle(
                        color: ThemeController.textColor,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const TextSpan(
                      text: 'Space',
                      style: TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              centerTitle: false,
              titleSpacing: 18,
              actions: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  child: const Icon(
                    CupertinoIcons.ellipsis_circle,
                    color: Color(0xFF007AFF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),

            body: StreamBuilder(
              stream: _myGroupsStream,
              builder: (context, groupsSnapshot) {
                if (groupsSnapshot.hasData) {
                  final groupDocs = groupsSnapshot.data?.docs ?? [];
                  _groupsList = groupDocs.map((e) => GroupChat.fromJson(e.data())).toList();
                }

                return StreamBuilder(
                  stream: _myUsersStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData && _list.isEmpty && _groupsList.isEmpty) {
                      return const Center(child: CupertinoActivityIndicator(color: Color(0xFF007AFF)));
                    }

                    final userDocs = snapshot.data?.docs.toList() ?? [];
                    userDocs.sort((a, b) {
                      final timeA = int.tryParse(a.data()['last_message_time']?.toString() ?? '0') ?? 0;
                      final timeB = int.tryParse(b.data()['last_message_time']?.toString() ?? '0') ?? 0;
                      return timeB.compareTo(timeA);
                    });
                    final userIds = userDocs.map((e) => e.id).toList();

                    return StreamBuilder(
                      stream: APIs.getAllUsers(userIds),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.hasData) {
                          final data = userSnapshot.data?.docs;
                          _list = data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];
                          _list.removeWhere((u) => APIs.me.blockedUsers.contains(u.id));
                          _list.sort((a, b) => userIds.indexOf(a.id).compareTo(userIds.indexOf(b.id)));
                        }

                        // Combine Direct Chats & Groups into a unified list sorted by latest message time
                        final List<dynamic> combinedItems = [];
                        final Map<String, String> userTimeMap = {
                          for (var d in userDocs) d.id: d.data()['last_message_time']?.toString() ?? '0'
                        };

                        if (_isSearching) {
                          combinedItems.addAll(_searchGroupsList);
                          combinedItems.addAll(_searchList);
                        } else {
                          combinedItems.addAll(_groupsList);
                          combinedItems.addAll(_list);

                          combinedItems.sort((a, b) {
                            String timeA = '';
                            String timeB = '';

                            if (a is GroupChat) {
                              timeA = a.lastMessageTime;
                            } else if (a is ChatUser) {
                              timeA = userTimeMap[a.id] ?? '0';
                            }

                            if (b is GroupChat) {
                              timeB = b.lastMessageTime;
                            } else if (b is ChatUser) {
                              timeB = userTimeMap[b.id] ?? '0';
                            }

                            final intA = int.tryParse(timeA) ?? 0;
                            final intB = int.tryParse(timeB) ?? 0;
                            return intB.compareTo(intA);
                          });
                        }

                        return CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: SizedBox(height: topPadding),
                            ),

                            // iOS Search Bar
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: ThemeController.cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: TextStyle(color: ThemeController.textColor, fontSize: 15),
                                    onChanged: (val) {
                                      _searchList.clear();
                                      _searchGroupsList.clear();

                                      final query = val.trim().toLowerCase();
                                      if (query.isNotEmpty) {
                                        _isSearching = true;

                                        for (var i in _list) {
                                          if (i.name.toLowerCase().contains(query) ||
                                              i.email.toLowerCase().contains(query)) {
                                            _searchList.add(i);
                                          }
                                        }

                                        for (var g in _groupsList) {
                                          if (g.name.toLowerCase().contains(query) ||
                                              g.description.toLowerCase().contains(query)) {
                                            _searchGroupsList.add(g);
                                          }
                                        }
                                      } else {
                                        _isSearching = false;
                                      }
                                      setState(() {});
                                    },
                                    decoration: const InputDecoration(
                                      hintText: 'Search',
                                      hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                                      prefixIcon: Icon(
                                        CupertinoIcons.search,
                                        color: Color(0xFF8E8E93),
                                        size: 18,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.only(bottom: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Stories Tray
                            SliverToBoxAdapter(
                              child: StatusTrayWidget(myContacts: _list),
                            ),

                            // Section Header
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: Text(
                                  'MESSAGES',
                                  style: TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),

                            // Contacts & Groups Combined List
                            _isSearching && combinedItems.isEmpty
                                ? SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                CupertinoIcons.person_crop_circle_badge_plus,
                                                color: Color(0xFF007AFF),
                                                size: 48,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No contact found',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: ThemeController.textColor,
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Would you like to add "${_searchController.text.trim()}" to your contacts?',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: ThemeController.subtextColor,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            GestureDetector(
                                              onTap: () => _addChatUserDialog(initialEmail: _searchController.text.trim()),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
                                                    Icon(CupertinoIcons.add, color: Colors.white, size: 18),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Add Contact',
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
                                      ),
                                    ),
                                  )
                                : (combinedItems.isNotEmpty
                                    ? SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final item = combinedItems[index];
                                            if (item is GroupChat) {
                                              return GroupUserCard(group: item);
                                            } else if (item is ChatUser) {
                                              return ChatUserCard(user: item);
                                            }
                                            return const SizedBox.shrink();
                                          },
                                          childCount: combinedItems.length,
                                        ),
                                      )
                                    : const SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: Center(
                                          child: Text(
                                            'No Messages Yet\nTap the 📝 button to start a chat or group',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
                                          ),
                                        ),
                                      )),

                            // Bottom Spacer for Safe Area and Comfortable Scrolling
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: MediaQuery.of(context).padding.bottom + 80.0,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),

            // iMessage Floating Action Button (Bottom Right)
            floatingActionButton: GestureDetector(
              onTapDown: (details) => _showFabOptionsSheet(targetOffset: details.globalPosition),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.square_pencil_fill,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // FAB Action Menu: New Message or New Group
  void _showFabOptionsSheet({Offset? targetOffset}) {
    CustomContextMenuDialog.show(
      context: context,
      title: 'New Conversation',
      targetOffset: targetOffset,
      items: [
        ContextMenuItem(
          title: 'New Direct Message',
          icon: CupertinoIcons.chat_bubble_fill,
          onTap: () {
            _addChatUserDialog();
          },
        ),
        ContextMenuItem(
          title: 'New Group Chat',
          icon: CupertinoIcons.person_3_fill,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateGroupScreen(availableContacts: _list),
              ),
            );
          },
        ),
      ],
    );
  }

  // Dialog to Add New Contact
  void _addChatUserDialog({String? initialEmail}) {
    String email = initialEmail ?? '';
    final controller = TextEditingController(text: email);

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('New Message'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Enter Contact Email',
            placeholderStyle: const TextStyle(color: Color(0xFF8E8E93)),
            style: TextStyle(color: ThemeController.textColor),
            onChanged: (val) => email = val,
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
              final targetEmail = email.trim();
              Navigator.pop(dialogContext);
              if (targetEmail.isNotEmpty) {
                final exists = await APIs.addChatUser(targetEmail);
                if (!exists && mounted) {
                  Dialogs.showSnackbar(context, 'User does not exist!');
                } else if (mounted) {
                  _searchController.clear();
                  _isSearching = false;
                  setState(() {});
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}