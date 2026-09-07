import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre URLs externas de forma segura (https preferido).
Future<bool> openExternalUrl(String rawUrl) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return false;

  String normalized = trimmed;
  if (normalized.startsWith('//')) {
    normalized = 'https:$normalized';
  } else if (!normalized.startsWith('http://') &&
      !normalized.startsWith('https://')) {
    normalized = 'https://$normalized';
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null) return false;

  if (!kIsWeb && uri.scheme != 'http' && uri.scheme != 'https') {
    return false;
  }

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

IconData socialIconForType(String type) {
  final normalized = type.trim().toLowerCase();
  if (normalized.contains('instagram') || normalized.contains('ig')) {
    return Icons.camera_alt_outlined;
  }
  if (normalized.contains('facebook') || normalized.contains('fb')) {
    return Icons.facebook_outlined;
  }
  if (normalized.contains('whatsapp') || normalized.contains('wa')) {
    return Icons.chat_outlined;
  }
  if (normalized.contains('youtube') || normalized.contains('yt')) {
    return Icons.play_circle_outline;
  }
  if (normalized.contains('twitter') || normalized.contains('x.com')) {
    return Icons.alternate_email;
  }
  if (normalized.contains('web') || normalized.contains('site')) {
    return Icons.language_outlined;
  }
  return Icons.link;
}

String socialLabelForType(String type) {
  final normalized = type.trim().toLowerCase();
  if (normalized.contains('instagram') || normalized.contains('ig')) {
    return 'Instagram';
  }
  if (normalized.contains('facebook') || normalized.contains('fb')) {
    return 'Facebook';
  }
  if (normalized.contains('whatsapp') || normalized.contains('wa')) {
    return 'WhatsApp';
  }
  if (normalized.contains('youtube') || normalized.contains('yt')) {
    return 'YouTube';
  }
  if (normalized.contains('twitter') || normalized.contains('x.com')) {
    return 'X (Twitter)';
  }
  if (normalized.contains('web') || normalized.contains('site')) {
    return 'Sitio web';
  }
  if (normalized.isNotEmpty) {
    return 'Enlace social';
  }
  return 'Enlace externo';
}
