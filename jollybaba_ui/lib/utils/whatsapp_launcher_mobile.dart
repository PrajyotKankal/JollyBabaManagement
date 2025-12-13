// lib/utils/whatsapp_launcher_mobile.dart
// Mobile-specific WhatsApp launcher
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openWhatsAppPlatform(String phone, String message) async {
  final encoded = Uri.encodeComponent(message);

  // Android intent URIs (works on many Android devices)
  final intentBusiness =
      Uri.parse("intent://send?phone=91$phone&text=$encoded#Intent;package=com.whatsapp.w4b;scheme=whatsapp;end");
  final intentWhatsApp =
      Uri.parse("intent://send?phone=91$phone&text=$encoded#Intent;package=com.whatsapp;scheme=whatsapp;end");

  // generic URL scheme
  final scheme = Uri.parse("whatsapp://send?phone=91$phone&text=$encoded");

  // browser fallback
  final waMe = Uri.parse("https://wa.me/91$phone?text=$encoded");

  try {
    // 1) Intent -> WhatsApp Business (Android only)
    if (Platform.isAndroid && await canLaunchUrl(intentBusiness)) {
      await launchUrl(intentBusiness, mode: LaunchMode.externalApplication);
      return true;
    }

    // 2) Intent -> WhatsApp (Android only)
    if (Platform.isAndroid && await canLaunchUrl(intentWhatsApp)) {
      await launchUrl(intentWhatsApp, mode: LaunchMode.externalApplication);
      return true;
    }

    // 3) generic whatsapp scheme (iOS/Android)
    if (await canLaunchUrl(scheme)) {
      await launchUrl(scheme, mode: LaunchMode.externalApplication);
      return true;
    }

    // 4) browser fallback (wa.me)
    if (await canLaunchUrl(waMe)) {
      await launchUrl(waMe, mode: LaunchMode.externalApplication);
      return true;
    }

    return false;
  } catch (_) {
    return false;
  }
}
