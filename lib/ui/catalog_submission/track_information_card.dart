import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/ui/catalog_submission/submission_status_badge.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A readable summary of the fields available in a track review submission.
class TrackInformationCard extends StatefulWidget {
  const TrackInformationCard({
    super.key,
    required this.submission,
    required this.relatedSubmissions,
    required this.requesterEmail,
  });

  final CatalogSubmission submission;
  final List<CatalogSubmission> relatedSubmissions;
  final String requesterEmail;

  @override
  State<TrackInformationCard> createState() => _TrackInformationCardState();
}

class _TrackInformationCardState extends State<TrackInformationCard> {
  final Map<int, Author> _authors = {};
  Album? _album;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void didUpdateWidget(covariant TrackInformationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final referencesChanged =
        _albumId(oldWidget.submission) != _albumId(widget.submission) ||
        !_sameIds(
          _authorIds(oldWidget.submission),
          _authorIds(widget.submission),
        );
    if (referencesChanged) {
      _authors.clear();
      _album = null;
    }
    if (referencesChanged ||
        oldWidget.relatedSubmissions != widget.relatedSubmissions) {
      _loadCatalog();
    }
  }

  void _loadCatalog() {
    final version = ++_loadVersion;
    final albumId = _albumId(widget.submission);
    final loadAlbum =
        albumId != null &&
        _relatedSubmission(CatalogSubmissionEntityType.album, albumId) == null;
    final authorIds = _authorIds(widget.submission).where(
      (id) =>
          _relatedSubmission(CatalogSubmissionEntityType.author, id) == null,
    );
    if (!loadAlbum && authorIds.isEmpty) return;
    final storage = context.read<TracksStorage>();
    if (loadAlbum) {
      storage
          .getAlbum(albumId)
          .then((album) {
            if (mounted && version == _loadVersion) {
              setState(() => _album = album);
            }
          })
          .catchError((Object _) {});
    }
    for (final id in authorIds) {
      storage
          .getAuthor(id)
          .then((author) {
            if (mounted && version == _loadVersion) {
              setState(() => _authors[id] = author);
            }
          })
          .catchError((Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final albumId = _albumId(widget.submission);
    final album = _relatedSubmission(
      CatalogSubmissionEntityType.album,
      albumId,
    );
    final albumData = album?.retainedEntity;
    final coverPath = album == null
        ? _nonEmpty(_album?.coverImagePath)
        : _nonEmpty(albumData?['coverImagePath']);
    final coverUrl = coverPath == null
        ? ''
        : context.read<TracksStorage>().resolveAlbumCoverUrl(coverPath);
    final authors = _authorIds(widget.submission).map((id) {
      final author = _relatedSubmission(CatalogSubmissionEntityType.author, id);
      final photos = author?.retainedEntity['photos'];
      final photoPath = photos is List
          ? photos.map(_nonEmpty).whereType<String>().firstOrNull
          : null;
      return _ArtistSummary(
        (author == null
                ? _nonEmpty(_authors[id]?.currentName)
                : _nonEmpty(author.retainedEntity['currentName'])) ??
            'Author #$id',
        author == null
            ? _authors[id]?.photos
                  .map(_nonEmpty)
                  .whereType<String>()
                  .firstOrNull
            : photoPath,
      );
    }).toList();
    final albumName = albumId == null
        ? null
        : (album == null
                  ? _nonEmpty(_album?.title)
                  : _nonEmpty(albumData?['title'])) ??
              'Album #$albumId';
    final releaseDate = DateTime.tryParse(
      _nonEmpty(albumData?['releaseDate']) ?? '',
    );
    final details = <_TrackDetail>[
      if (authors.isNotEmpty)
        _TrackDetail(
          Icons.person_outline,
          'Artist',
          authors.map((author) => author.name).join(', '),
          artists: authors,
        ),
      if (albumName != null)
        _TrackDetail(Icons.album_outlined, 'Album', albumName),
      if (releaseDate != null)
        _TrackDetail(
          Icons.calendar_today_outlined,
          'Release date',
          _formatDate(releaseDate),
        ),
      if (widget.requesterEmail.trim().isNotEmpty)
        _TrackDetail(
          Icons.person_outline,
          'Submitted by',
          widget.requesterEmail,
        ),
      _TrackDetail(
        Icons.schedule_outlined,
        'Submitted at',
        _formatDateTime(widget.submission.submittedAt),
      ),
    ];

    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('track-information-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.music_note, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Track information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.submission.entityName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Track'),
                      SubmissionStatusBadge(status: widget.submission.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, infoConstraints) {
                      final columns = (infoConstraints.maxWidth / 190)
                          .floor()
                          .clamp(1, 4);
                      final itemWidth =
                          (infoConstraints.maxWidth - (columns - 1) * 12) /
                          columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 14,
                        children: [
                          for (final detail in details)
                            SizedBox(
                              width: itemWidth,
                              child: _DetailView(detail: detail),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );

              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CoverArt(url: coverUrl, size: 112),
                    const SizedBox(height: 16),
                    info,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CoverArt(url: coverUrl, size: 136),
                  const SizedBox(width: 20),
                  Expanded(child: info),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  CatalogSubmission? _relatedSubmission(
    CatalogSubmissionEntityType type,
    int? entityId,
  ) {
    if (entityId == null) return null;
    for (final candidate in widget.relatedSubmissions) {
      if (candidate.entityType == type && candidate.entityId == entityId) {
        return candidate;
      }
    }
    return null;
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.album_outlined,
          size: 40,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
    if (url.isEmpty) return image;
    return Tooltip(
      message: 'View album image full screen',
      child: InkWell(
        key: const ValueKey('open-album-image'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => _FullScreenCoverArt(url: url),
        ),
        child: image,
      ),
    );
  }
}

class _FullScreenCoverArt extends StatelessWidget {
  const _FullScreenCoverArt({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      key: const ValueKey('full-screen-album-image'),
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                key: const ValueKey('close-album-image'),
                tooltip: 'Close album image',
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackDetail {
  const _TrackDetail(
    this.icon,
    this.label,
    this.value, {
    this.artists = const [],
  });

  final IconData icon;
  final String label;
  final String value;
  final List<_ArtistSummary> artists;
}

class _ArtistSummary {
  const _ArtistSummary(this.name, this.photoPath);

  final String name;
  final String? photoPath;
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.detail});

  final _TrackDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(detail.icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (detail.artists.isEmpty)
                Text(detail.value, style: theme.textTheme.bodyMedium)
              else
                for (final artist in detail.artists)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        if (artist.photoPath != null) ...[
                          ClipOval(
                            child: Image.network(
                              context
                                  .read<TracksStorage>()
                                  .resolveAuthorPhotoUrl(artist.photoPath!),
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person_outline, size: 24),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            artist.name,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

int? _albumId(CatalogSubmission submission) {
  final value = submission.retainedEntity['albumId'];
  return value is num ? value.toInt() : null;
}

List<int> _authorIds(CatalogSubmission submission) {
  final value = submission.retainedEntity['authorIds'];
  return value is List
      ? value.whereType<num>().map((id) => id.toInt()).toList()
      : const [];
}

bool _sameIds(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String? _nonEmpty(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatDateTime(DateTime date) {
  final local = date.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${_formatDate(local)} ${two(local.hour)}:${two(local.minute)}';
}
