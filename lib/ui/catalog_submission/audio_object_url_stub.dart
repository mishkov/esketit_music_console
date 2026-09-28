import 'dart:convert';

import 'package:esketit_music_console/ui/catalog_submission/audio_object_url.dart';

class BrowserAudioObjectUrlFactory implements AudioObjectUrlFactory {
  @override
  String create(List<int> bytes, {String? contentType}) =>
      'data:${contentType ?? 'audio/mpeg'};base64,${base64Encode(bytes)}';

  @override
  void revoke(String url) {}
}
