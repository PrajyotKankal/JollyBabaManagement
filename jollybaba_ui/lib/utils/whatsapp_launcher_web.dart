// lib/utils/whatsapp_launcher_web.dart
// Web-specific WhatsApp launcher - works in browsers AND iOS PWA (home screen shortcut)
import 'dart:html' as html;
import 'dart:js' as js;

Future<bool> openWhatsAppPlatform(String phone, String message) async {
  final encoded = Uri.encodeComponent(message);
  
  // Normalize phone number - remove non-digits, ensure 91 prefix
  String normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (normalizedPhone.length == 10) {
    normalizedPhone = '91$normalizedPhone';
  } else if (!normalizedPhone.startsWith('91') && normalizedPhone.length > 10) {
    normalizedPhone = '91$normalizedPhone';
  }
  
  // iOS PWA detection using JS interop
  bool isIosPwa = false;
  try {
    final standalone = js.context['navigator']['standalone'];
    isIosPwa = standalone == true;
  } catch (_) {
    isIosPwa = false;
  }
  
  // Check if running in iOS Safari (mobile)
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  final isIosSafari = userAgent.contains('iphone') || userAgent.contains('ipad');
  
  // Primary URL - wa.me works best across all platforms including iOS PWA
  final waMe = "https://wa.me/$normalizedPhone?text=$encoded";
  
  // Fallback - api.whatsapp.com
  final apiWhatsApp = "https://api.whatsapp.com/send?phone=$normalizedPhone&text=$encoded";
  
  try {
    if (isIosPwa || isIosSafari) {
      // For iOS PWA or Safari, use window.location.href to navigate directly
      // This forces Safari to open the link which then triggers WhatsApp
      html.window.location.href = waMe;
      return true;
    } else {
      // For regular browsers, open in new tab/window
      final opened = html.window.open(waMe, '_blank');
      if (opened != null) {
        return true;
      }
      
      // Try api.whatsapp.com as fallback
      final fallback = html.window.open(apiWhatsApp, '_blank');
      if (fallback != null) {
        return true;
      }
    }
    
    return false;
  } catch (e) {
    // Last resort - try direct navigation
    try {
      html.window.location.href = waMe;
      return true;
    } catch (_) {
      return false;
    }
  }
}
