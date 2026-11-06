import 'package:url_launcher/url_launcher.dart';

/// Opens a remotely supplied link (FCM payload, banner/popup `redirect_url`,
/// notification `link_url`, ...) in the browser.
///
/// Only http(s) is launched — these URLs come straight from admin/server data,
/// so other schemes (intent:, file:, market: ...) aren't opened blindly.
/// Fire-and-forget: there's nothing to show the user if the browser refuses.
void openExternalUrl(String? url) {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  final scheme = uri?.scheme.toLowerCase();
  if (uri == null || (scheme != 'http' && scheme != 'https')) return;
  launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
}
