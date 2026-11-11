import 'package:flutter/foundation.dart';

/// Represents deep-link actions routed through `https://whofedsnoop.com`
/// or `https://who-fed-snoop.web.app`.
enum DeepLinkKind {
  /// `https://whofedsnoop.com/join/{joinCode}` — 1-tap partner invite link.
  joinHousehold,

  /// `https://whofedsnoop.com/tap/{householdId}` — Encoded on the physical NFC
  /// food-bin sticker (or Android Home Screen Widget button) so tapping logs the meal automatically.
  nfcTapToFeed,

  /// `https://whofedsnoop.com/s/{sitterToken}` — Temporary web pass for a dog sitter.
  sitterGuestPass,
}

@immutable
class WhofedsnoopDeepLink {
  const WhofedsnoopDeepLink({required this.kind, required this.targetId});

  static const String canonicalHost = 'whofedsnoop.com';
  static const Set<String> supportedHosts = <String>{
    'whofedsnoop.com',
    'www.whofedsnoop.com',
    'who-fed-snoop.web.app',
    'who-fed-snoop.firebaseapp.com',
    'localhost',
  };

  final DeepLinkKind kind;

  /// Either the 6-char `joinCode`, `householdId`, or `sitterToken`.
  final String targetId;

  /// Generates a shareable invite URL on `whofedsnoop.com`.
  static Uri buildJoinUri(String joinCode) =>
      Uri.https(canonicalHost, '/join/${joinCode.trim().toUpperCase()}');

  /// Generates the NFC tag payload URL to write onto an NTAG213 food-bin sticker.
  static Uri buildNfcTapUri(String householdId) =>
      Uri.https(canonicalHost, '/tap/${householdId.trim()}');

  /// Generates a temporary web URL for a dog sitter.
  static Uri buildSitterPassUri(String sitterToken) =>
      Uri.https(canonicalHost, '/s/${sitterToken.trim()}');

  /// Parses an incoming Android App Link / Universal Link / NFC / Web URI.
  static WhofedsnoopDeepLink? tryParse(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.isNotEmpty && !supportedHosts.contains(host)) {
      return null;
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) {
      return null;
    }

    final prefix = segments[0].toLowerCase();
    final value = segments[1].trim();
    if (value.isEmpty) {
      return null;
    }

    switch (prefix) {
      case 'join':
        return WhofedsnoopDeepLink(
          kind: DeepLinkKind.joinHousehold,
          targetId: value.toUpperCase(),
        );
      case 'tap':
        return WhofedsnoopDeepLink(
          kind: DeepLinkKind.nfcTapToFeed,
          targetId: value,
        );
      case 's':
        return WhofedsnoopDeepLink(
          kind: DeepLinkKind.sitterGuestPass,
          targetId: value,
        );
      default:
        return null;
    }
  }
}
