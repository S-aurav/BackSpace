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
    this.replyToMsg,
    this.replyToSenderName,
    this.replyToType,
    this.replyToMediaUrl,
    this.gifId,
    this.gifProvider,
    this.gifPreviewUrl,
  });

  late final String toId;
  late final String msg;
  late final String read;
  late final String fromId;
  late final String sent;
  late final Type type;
  String? senderName;
  String? senderImage;

  // Quoted reply fields (for 1:1, group, or status/story replies)
  String? replyToMsg;
  String? replyToSenderName;
  String? replyToType; // 'text', 'image', 'video', 'story', 'gif'
  String? replyToMediaUrl;

  // KLIPY GIF Metadata fields (zero Cloudinary storage)
  String? gifId;
  String? gifProvider; // e.g. 'klipy'
  String? gifPreviewUrl;

  Message.fromJson(Map<String, dynamic> json) {
    toId = json['toId'].toString();
    msg = json['msg'].toString();
    read = json['read'].toString();
    final typeStr = json['type'].toString();
    if (typeStr == Type.image.name || typeStr == 'Type.image') {
      type = Type.image;
    } else if (typeStr == Type.video.name || typeStr == 'Type.video') {
      type = Type.video;
    } else if (typeStr == Type.gif.name || typeStr == 'Type.gif') {
      type = Type.gif;
    } else {
      type = Type.text;
    }
    fromId = json['fromId'].toString();
    sent = json['sent'].toString();
    senderName = json['senderName']?.toString();
    senderImage = json['senderImage']?.toString();
    replyToMsg = json['replyToMsg']?.toString();
    replyToSenderName = json['replyToSenderName']?.toString();
    replyToType = json['replyToType']?.toString();
    replyToMediaUrl = json['replyToMediaUrl']?.toString();
    gifId = json['gifId']?.toString();
    gifProvider = json['gifProvider']?.toString();
    gifPreviewUrl = json['gifPreviewUrl']?.toString();
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
    if (replyToMsg != null) data['replyToMsg'] = replyToMsg;
    if (replyToSenderName != null) data['replyToSenderName'] = replyToSenderName;
    if (replyToType != null) data['replyToType'] = replyToType;
    if (replyToMediaUrl != null) data['replyToMediaUrl'] = replyToMediaUrl;
    if (gifId != null) data['gifId'] = gifId;
    if (gifProvider != null) data['gifProvider'] = gifProvider;
    if (gifPreviewUrl != null) data['gifPreviewUrl'] = gifPreviewUrl;
    return data;
  }
}

enum Type { text, image, video, gif }