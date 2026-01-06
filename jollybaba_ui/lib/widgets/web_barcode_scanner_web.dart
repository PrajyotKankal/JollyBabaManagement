// Web implementation of barcode scanner using html5-qrcode JavaScript library
// This file can only be compiled for web platform
import 'dart:html' as html;
import 'dart:js_util' as js_util;

class WebBarcodeScanner {
  static Future<void> showScanner({
    required Function(String) onSuccess,
    required Function(String) onError,
    Function()? onCancel,
  }) async {
    try {
      final scannerId = 'qr-scanner-${DateTime.now().millisecondsSinceEpoch}';
      
      // Create container div
      final container = html.DivElement()
        ..id = scannerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.maxWidth = '500px'
        ..style.maxHeight = '500px'
        ..style.margin = 'auto';
      
      // Create modal overlay
      final overlay = html.DivElement()
        ..style.position = 'fixed'
        ..style.top = '0'
        ..style.left = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'rgba(0,0,0,0.9)'
        ..style.zIndex = '9999'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.flexDirection = 'column';
      
      // Create close button
      final closeButton = html.ButtonElement()
        ..text = '✕'
        ..style.position = 'absolute'
        ..style.top = '20px'
        ..style.right = '20px'
        ..style.fontSize = '32px'
        ..style.color = 'white'
        ..style.background = 'transparent'
        ..style.border = 'none'
        ..style.cursor = 'pointer'
        ..style.zIndex = '10000';
      
      // Create instruction text
      final instruction = html.DivElement()
        ..text = 'Align the IMEI barcode within the frame'
        ..style.color = 'rgba(255,255,255,0.7)'
        ..style.fontSize = '14px'
        ..style.marginTop = '20px'
        ..style.textAlign = 'center';
      
      overlay.append(container);
      overlay.append(closeButton);
      overlay.append(instruction);
      html.document.body?.append(overlay);
      
      // Initialize scanner
      final scanner = js_util.callConstructor(
        js_util.getProperty(html.window, 'Html5Qrcode'),
        [scannerId],
      );
      
      // Cleanup function
      void cleanup() async {
        try {
          await js_util.promiseToFuture(
            js_util.callMethod(scanner, 'stop', []),
          );
        } catch (e) {
          // Ignore stop errors
        }
        overlay.remove();
      }
      
      // Close button handler
      closeButton.onClick.listen((_) {
        cleanup();
        onCancel?.call();
      });
      
      // Scan success handler
      final onScanSuccess = js_util.allowInterop((String decodedText, dynamic result) {
        final normalized = decodedText.replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.length >= 14 && normalized.length <= 16) {
          cleanup();
          onSuccess(normalized);
        }
      });
      
      // Scan failure handler (ignore - happens constantly)
      final onScanFailure = js_util.allowInterop((dynamic error) {
        // Ignore
      });
      
      // Configuration
      final config = js_util.jsify({
        'fps': 10,
        'qrbox': {'width': 250, 'height': 250},
        'aspectRatio': 1.0,
      });
      
      // Start scanner with rear camera
      final cameraConfig = js_util.jsify({'facingMode': 'environment'});
      
      await js_util.promiseToFuture(
        js_util.callMethod(
          scanner,
          'start',
          [cameraConfig, config, onScanSuccess, onScanFailure],
        ),
      );
    } catch (e) {
      onError('Failed to start camera: ${e.toString()}');
    }
  }
}
