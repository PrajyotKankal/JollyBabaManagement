// Stub implementation for non-web platforms (Android/iOS)
// This file is used when compiling for mobile to avoid dart:html errors

class WebBarcodeScanner {
  static Future<void> showScanner({
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    // This should never be called on mobile since we check kIsWeb first
    onError('Web scanner not available on this platform');
  }
}
