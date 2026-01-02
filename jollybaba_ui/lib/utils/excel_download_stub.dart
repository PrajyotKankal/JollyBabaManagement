// lib/utils/excel_download_stub.dart
// Stub for non-web platforms - downloads not supported on mobile yet

import 'dart:typed_data';

/// Downloads Excel bytes as a file.
/// Stub for non-web platforms.
Future<void> downloadExcelBytes(Uint8List bytes, String filename) async {
  // On mobile, we could use path_provider + share or save to downloads
  // For now, this is a no-op since Excel download is web-only feature
  throw UnsupportedError('Excel download is only supported on web');
}
