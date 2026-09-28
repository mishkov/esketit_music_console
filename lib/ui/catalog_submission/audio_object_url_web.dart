// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:esketit_music_console/ui/catalog_submission/audio_object_url.dart';

class BrowserAudioObjectUrlFactory implements AudioObjectUrlFactory {
  @override
  String create(List<int> bytes, {String? contentType}) {
    final blob = html.Blob([bytes], contentType ?? 'audio/mpeg');
    return html.Url.createObjectUrlFromBlob(blob);
  }

  @override
  void revoke(String url) => html.Url.revokeObjectUrl(url);
}
