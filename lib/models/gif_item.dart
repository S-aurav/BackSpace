class GifItem {
  final String id;
  final String provider; // e.g. 'klipy'
  final String title;
  final String previewUrl; // Lightweight rendition for grid view / preview
  final String mediaUrl; // Full rendition for chat display
  final double aspectRatio;

  const GifItem({
    required this.id,
    this.provider = 'klipy',
    this.title = '',
    required this.previewUrl,
    required this.mediaUrl,
    this.aspectRatio = 1.33,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider': provider,
      'title': title,
      'previewUrl': previewUrl,
      'mediaUrl': mediaUrl,
      'aspectRatio': aspectRatio,
    };
  }

  factory GifItem.fromJson(Map<String, dynamic> json) {
    return GifItem(
      id: json['id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'klipy',
      title: json['title']?.toString() ?? '',
      previewUrl: json['previewUrl']?.toString() ?? json['mediaUrl']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 1.33,
    );
  }
}
