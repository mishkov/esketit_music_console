import 'package:esketit_music_console/errors/app_error.dart';

class AlbumCoverSuggestionsUnavailableError extends AppError {
  const AlbumCoverSuggestionsUnavailableError([
    super.message =
        'Album cover suggestions are not available yet. Add the backend endpoint first.',
  ]);
}
