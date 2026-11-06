const _videoExtensions = {
  'mp4',
  'mov',
  'm4v',
  'webm',
  'mkv',
  '3gp',
  'avi',
  'm3u8',
};

/// True when [url] points to a video, judged by its file extension.
/// Query params (signed / CDN URLs) are ignored.
bool isVideoUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final path = Uri.tryParse(url)?.path ?? url;
  final dot = path.lastIndexOf('.');
  if (dot == -1) return false;
  return _videoExtensions.contains(path.substring(dot + 1).toLowerCase());
}

/// Media order from the API is arbitrary — a video can come first. Single
/// thumbnails (cards, cart, checkout, hero) want the first real image, and
/// fall back to the first video only when the product has no image at all.
String? coverMediaUrl(Iterable<String?> urls) {
  String? firstVideo;
  for (final url in urls) {
    if (url == null || url.isEmpty) continue;
    if (!isVideoUrl(url)) return url;
    firstVideo ??= url;
  }
  return firstVideo;
}

/// Swipeable card previews show images only (a native player per grid card
/// is too heavy); videos are kept only when there is no image to show.
List<T> previewMedia<T>(List<T> items, String? Function(T) urlOf) {
  final images = items.where((i) => !isVideoUrl(urlOf(i))).toList();
  return images.isNotEmpty ? images : items;
}
