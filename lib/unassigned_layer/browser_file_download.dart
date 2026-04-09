import 'dart:typed_data';

import 'browser_file_download_stub.dart'
    if (dart.library.io) 'browser_file_download_io.dart'
    if (dart.library.html) 'browser_file_download_web.dart'
    as implementation;

Future<void> saveBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) {
  return implementation.saveBytesAsFile(
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
  );
}
