class ChatUser {
  ChatUser({
    required this.image,
    required this.about,
    required this.name,
    required this.createdAt,
    required this.isOnline,
    required this.id,
    required this.lastActive,
    required this.email,
    required this.pushToken,
    Map<String, dynamic>? mutedUsers,
    List<String>? blockedUsers,
    List<String>? statusBlockedUsers,
  })  : mutedUsers = mutedUsers ?? {},
        blockedUsers = blockedUsers ?? [],
        statusBlockedUsers = statusBlockedUsers ?? [];

  late String image;
  late String about;
  late String name;
  late String createdAt;
  late bool isOnline;
  late String id;
  late String lastActive;
  late String email;
  late String pushToken;
  Map<String, dynamic> mutedUsers = {};
  List<String> blockedUsers = [];
  List<String> statusBlockedUsers = [];

  ChatUser.fromJson(Map<String, dynamic> json) {
    image = json['image'] ?? '';
    about = json['about'] ?? '';
    name = json['name'] ?? '';
    createdAt = json['created_at'] ?? '';
    isOnline = json['is_online'] ?? '';
    id = json['id'] ?? '';
    lastActive = json['last_active'] ?? '';
    email = json['email'] ?? '';
    pushToken = json['push_token'] ?? '';
    mutedUsers = Map<String, dynamic>.from(json['muted_users'] ?? {});
    blockedUsers = List<String>.from(json['blocked_users'] ?? []);
    statusBlockedUsers = List<String>.from(json['status_blocked_users'] ?? []);
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['image'] = image;
    data['about'] = about;
    data['name'] = name;
    data['created_at'] = createdAt;
    data['is_online'] = isOnline;
    data['id'] = id;
    data['last_active'] = lastActive;
    data['email'] = email;
    data['push_token'] = pushToken;
    data['muted_users'] = mutedUsers;
    data['blocked_users'] = blockedUsers;
    data['status_blocked_users'] = statusBlockedUsers;
    return data;
  }
}