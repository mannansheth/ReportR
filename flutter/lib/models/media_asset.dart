class MediaAsset {
  const MediaAsset({
    required this.path,
    required this.base64,
    required this.mimeType,
  });

  final String path;
  final String base64;
  final String mimeType;
}
