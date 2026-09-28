export 'audio_object_url_stub.dart'
    if (dart.library.html) 'audio_object_url_web.dart';

abstract class AudioObjectUrlFactory {
  String create(List<int> bytes, {String? contentType});

  void revoke(String url);
}
