class AppUpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final bool forceUpdate;
  final String title;
  final List<String> releaseNotes;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.forceUpdate = false,
    this.title = "What's New in BackSpace 🎉",
    this.releaseNotes = const [],
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['release_notes'] ?? json['releaseNotes'] ?? json['features'] ?? [];
    List<String> notes = [];
    if (rawNotes is List) {
      notes = rawNotes.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawNotes is String && rawNotes.isNotEmpty) {
      notes = rawNotes.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return AppUpdateInfo(
      latestVersion: (json['latest_version'] ?? json['latestVersion'] ?? '2.0.0').toString().trim(),
      downloadUrl: (json['download_url'] ?? json['downloadUrl'] ?? 'https://github.com/S-aurav/BackSpace/releases').toString().trim(),
      forceUpdate: (json['force_update'] ?? json['forceUpdate'] ?? false) == true,
      title: (json['title'] ?? "What's New in BackSpace 🎉").toString().trim(),
      releaseNotes: notes,
    );
  }
}

class AppAnnouncement {
  final String id;
  final bool isActive;
  final String title;
  final String message;
  final String buttonText;
  final String? actionUrl;
  final String? imageUrl;

  const AppAnnouncement({
    required this.id,
    required this.isActive,
    required this.title,
    required this.message,
    this.buttonText = 'Got It!',
    this.actionUrl,
    this.imageUrl,
  });

  factory AppAnnouncement.fromJson(Map<String, dynamic> json) {
    return AppAnnouncement(
      id: (json['id'] ?? '').toString().trim(),
      isActive: (json['is_active'] ?? json['isActive'] ?? true) == true,
      title: (json['title'] ?? 'Announcement 📢').toString().trim(),
      message: (json['message'] ?? json['body'] ?? '').toString().trim(),
      buttonText: (json['button_text'] ?? json['buttonText'] ?? 'Got It!').toString().trim(),
      actionUrl: json['action_url']?.toString().trim() ?? json['actionUrl']?.toString().trim(),
      imageUrl: json['image_url']?.toString().trim() ?? json['imageUrl']?.toString().trim(),
    );
  }
}
