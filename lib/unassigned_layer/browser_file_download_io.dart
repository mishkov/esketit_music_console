import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> saveBytesAsFile({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) async {
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save file',
    fileName: fileName,
    bytes: bytes,
  );
  if (savePath == null || savePath.isEmpty) {
    return;
  }

  final outputFile = File(savePath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(bytes, flush: true);
}
