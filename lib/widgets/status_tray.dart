import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../api/apis.dart';
import '../helper/theme_controller.dart';
import '../models/chat_user.dart';
import '../models/story.dart';
import '../screens/create_story_screen.dart';
import '../screens/story_viewer_screen.dart';

class StatusTrayWidget extends StatelessWidget {
  final List<ChatUser> myContacts;

  const StatusTrayWidget({super.key, required this.myContacts});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 125,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "My Status" Avatar & Add Button
          _buildMyStatusTile(context),

          // Contact Status Avatar List
          for (var contact in myContacts)
            _buildContactStatusTile(context, contact),
        ],
      ),
    );
  }

  Widget _buildMyStatusTile(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: APIs.getUserStoriesStream(APIs.user.uid),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final myStories = docs.map((e) => Story.fromJson(e.data())).toList();
        final hasActiveStory = myStories.isNotEmpty;

        return GestureDetector(
          onTap: () {
            if (hasActiveStory) {
              final group = UserStoriesGroup(
                userId: APIs.user.uid,
                userName: 'My Status',
                userImage: APIs.me.image,
                stories: myStories,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewerScreen(
                    userStoriesGroups: [group],
                    initialGroupIndex: 0,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasActiveStory
                            ? const LinearGradient(
                                colors: [Color(0xFF007AFF), Colors.purpleAccent, Colors.pinkAccent],
                              )
                            : null,
                        border: !hasActiveStory
                            ? Border.all(color: ThemeController.dividerColor, width: 2)
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: ThemeController.cardColor,
                        backgroundImage: APIs.me.image.isNotEmpty
                            ? CachedNetworkImageProvider(APIs.me.image)
                            : null,
                        child: APIs.me.image.isEmpty
                            ? Icon(Icons.person, color: ThemeController.subtextColor, size: 30)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            shape: BoxShape.circle,
                            border: Border.all(color: ThemeController.bgColor, width: 2),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'My Status',
                  style: TextStyle(
                    color: ThemeController.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactStatusTile(BuildContext context, ChatUser contact) {
    return FutureBuilder<bool>(
      future: APIs.isUserBlockedFromStatus(contact.id),
      builder: (context, blockSnapshot) {
        if (blockSnapshot.data == true) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: APIs.getUserStoriesStream(contact.id),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();

        final stories = docs.map((e) => Story.fromJson(e.data())).toList();
        final hasUnseen = stories.any((s) => !s.views.contains(APIs.user.uid));

        return GestureDetector(
          onTap: () {
            final group = UserStoriesGroup(
              userId: contact.id,
              userName: contact.name,
              userImage: contact.image,
              stories: stories,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoryViewerScreen(
                  userStoriesGroups: [group],
                  initialGroupIndex: 0,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasUnseen
                        ? const LinearGradient(
                            colors: [Color(0xFF007AFF), Colors.purpleAccent, Colors.pinkAccent],
                          )
                        : null,
                    border: !hasUnseen
                        ? Border.all(color: ThemeController.dividerColor, width: 2)
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: ThemeController.cardColor,
                    backgroundImage: contact.image.isNotEmpty
                        ? CachedNetworkImageProvider(contact.image)
                        : null,
                    child: contact.image.isEmpty
                        ? Icon(Icons.person, color: ThemeController.subtextColor, size: 30)
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 76,
                  child: Text(
                    contact.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ThemeController.textColor,
                      fontSize: 13,
                      fontWeight: hasUnseen ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
      },
    );
  }
}
