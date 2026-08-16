class Story {
  late String id;
  late String userId;
  late String userName;
  late String userImage;
  late String mediaUrl;
  late String caption;
  late String createdAt;
  late String expiresAt;
  late List<String> views;
  late bool isText;
  late bool isVideo;
  late String bgColor;

  Story({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.mediaUrl,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.views,
    required this.isText,
    this.isVideo = false,
    required this.bgColor,
  });

  Story.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString() ?? '';
    userId = json['user_id']?.toString() ?? '';
    userName = json['user_name']?.toString() ?? '';
    userImage = json['user_image']?.toString() ?? '';
    mediaUrl = json['media_url']?.toString() ?? '';
    caption = json['caption']?.toString() ?? '';
    createdAt = json['created_at']?.toString() ?? '';
    expiresAt = json['expires_at']?.toString() ?? '';
    views = List<String>.from(json['views'] ?? []);
    isText = json['is_text'] ?? false;
    isVideo = json['is_video'] ?? false;
    if (!isVideo && !isText && mediaUrl.isNotEmpty) {
      final ext = mediaUrl.split('?').first.split('.').last.toLowerCase();
      if (['mp4', 'mov', 'mkv', 'webm', '3gp', 'avi'].contains(ext) || mediaUrl.contains('/video/upload/')) {
        isVideo = true;
      }
    }
    bgColor = json['bg_color']?.toString() ?? '0xFF4A00E0';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_image': userImage,
      'media_url': mediaUrl,
      'caption': caption,
      'created_at': createdAt,
      'expires_at': expiresAt,
      'views': views,
      'is_text': isText,
      'is_video': isVideo,
      'bg_color': bgColor,
    };
  }
}

class UserStoriesGroup {
  final String userId;
  final String userName;
  final String userImage;
  final List<Story> stories;

  UserStoriesGroup({
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.stories,
  });
}
