import 'dart:typed_data';

void saveBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) {
  throw UnsupportedError('Browser downloads are only supported on web.');
}
