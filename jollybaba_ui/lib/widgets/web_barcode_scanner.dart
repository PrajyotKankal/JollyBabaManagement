// Main export file for web barcode scanner
// Uses conditional export to select platform-specific implementation
export 'web_barcode_scanner_stub.dart'
    if (dart.library.html) 'web_barcode_scanner_web.dart';
