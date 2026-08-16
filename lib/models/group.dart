class GroupChat {
  GroupChat({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.admins,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSenderName,
  });

  late String id;
  late String name;
  late String image;
  late String description;
  late String createdBy;
  late String createdAt;
  late List<String> members;
  late List<String> admins;
  late String lastMessage;
  late String lastMessageTime;
  late String lastMessageSenderName;

  GroupChat.fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? '';
    name = json['name'] ?? '';
    image = json['image'] ?? '';
    description = json['description'] ?? '';
    createdBy = json['createdBy'] ?? '';
    createdAt = json['createdAt'] ?? '';
    members = List<String>.from(json['members'] ?? []);
    admins = List<String>.from(json['admins'] ?? []);
    lastMessage = json['lastMessage'] ?? '';
    lastMessageTime = json['lastMessageTime'] ?? '';
    lastMessageSenderName = json['lastMessageSenderName'] ?? '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'members': members,
      'admins': admins,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastMessageSenderName': lastMessageSenderName,
    };
  }
}
