import 'package:esketit_music_console/domain/track_info/track_info.dart';

class ExternalLinkTrackInfo extends TrackInfo {
  const ExternalLinkTrackInfo({
    this.id,
    required this.provider,
    this.title,
    required this.url,
  });

  final String? id;
  final String provider;
  final String? title;
  final String url;

  @override
  List<Object?> get props => [id, provider, title, url];
}
