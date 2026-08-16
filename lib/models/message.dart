class Message {
  Message({
    required this.toId,
    required this.msg,
    required this.read,
    required this.type,
    required this.fromId,
    required this.sent,
    this.senderName,
    this.senderImage,
  });

  late final String toId;
  late final String msg;
  late final String read;
  late final String fromId;
  late final String sent;
  late final Type type;
  String? senderName;
  String? senderImage;

  Message.fromJson(Map<String, dynamic> json) {
    toId = json['toId'].toString();
    msg = json['msg'].toString();
    read = json['read'].toString();
    final typeStr = json['type'].toString();
    if (typeStr == Type.image.name || typeStr == 'Type.image') {
      type = Type.image;
    } else if (typeStr == Type.video.name || typeStr == 'Type.video') {
      type = Type.video;
    } else {
      type = Type.text;
    }
    fromId = json['fromId'].toString();
    sent = json['sent'].toString();
    senderName = json['senderName']?.toString();
    senderImage = json['senderImage']?.toString();
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['toId'] = toId;
    data['msg'] = msg;
    data['read'] = read;
    data['type'] = type.name;
    data['fromId'] = fromId;
    data['sent'] = sent;
    if (senderName != null) data['senderName'] = senderName;
    if (senderImage != null) data['senderImage'] = senderImage;
    return data;
  }
}

enum Type { text, image, video }