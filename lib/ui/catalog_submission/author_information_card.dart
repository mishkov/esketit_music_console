import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The author fields supplied by a catalog submission.
class AuthorInformationCard extends StatefulWidget {
  const AuthorInformationCard({super.key, required this.submission});

  final CatalogSubmission submission;

  @override
  State<AuthorInformationCard> createState() => _AuthorInformationCardState();
}

class _AuthorInformationCardState extends State<AuthorInformationCard> {
  int _photoIndex = 0;

  @override
  void didUpdateWidget(covariant AuthorInformationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.submission.id != widget.submission.id ||
        oldWidget.submission.retainedEntity['photos'] !=
            widget.submission.retainedEntity['photos']) {
      _photoIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rawPhotos = widget.submission.retainedEntity['photos'];
    final photoPaths = rawPhotos is List
        ? rawPhotos
              .whereType<String>()
              .map((path) => path.trim())
              .where((path) => path.isNotEmpty)
              .toList()
        : <String>[];
    final photoUrls = photoPaths
        .map(context.read<TracksStorage>().resolveAuthorPhotoUrl)
        .toList();
    final photoIndex = photoUrls.isEmpty
        ? 0
        : _photoIndex.clamp(0, photoUrls.length - 1);
    final name = widget.submission.retainedEntity['currentName'];

    return Container(
      key: const ValueKey('author-information-card'),
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
              Icon(Icons.person_outline, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Author information',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            name is String && name.trim().isNotEmpty
                ? name
                : widget.submission.entityName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text('Photos', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (photoUrls.isEmpty)
            const Text('No photos attached.')
          else ...[
            Row(
              children: [
                IconButton(
                  key: const ValueKey('previous-author-photo'),
                  tooltip: 'Previous author photo',
                  onPressed: photoIndex > 0
                      ? () => setState(() => _photoIndex = photoIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: InkWell(
                    key: const ValueKey('open-author-photo'),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => _FullScreenAuthorPhotos(
                        urls: photoUrls,
                        initialIndex: photoIndex,
                      ),
                    ),
                    child: SizedBox(
                      height: 260,
                      child: _AuthorPhoto(url: photoUrls[photoIndex]),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('next-author-photo'),
                  tooltip: 'Next author photo',
                  onPressed: photoIndex < photoUrls.length - 1
                      ? () => setState(() => _photoIndex = photoIndex + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Center(child: Text('${photoIndex + 1} of ${photoUrls.length}')),
          ],
        ],
      ),
    );
  }
}

class _AuthorPhoto extends StatelessWidget {
  const _AuthorPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    key: const ValueKey('author-photo-image'),
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) =>
        const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
  );
}

class _FullScreenAuthorPhotos extends StatefulWidget {
  const _FullScreenAuthorPhotos({
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<_FullScreenAuthorPhotos> createState() =>
      _FullScreenAuthorPhotosState();
}

class _FullScreenAuthorPhotosState extends State<_FullScreenAuthorPhotos> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    key: const ValueKey('full-screen-author-photo'),
    backgroundColor: Colors.black,
    child: SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const ValueKey('close-author-photo'),
              tooltip: 'Close author photo',
              color: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('previous-full-screen-author-photo'),
                  tooltip: 'Previous author photo',
                  color: Colors.white,
                  onPressed: _index > 0 ? () => setState(() => _index--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(child: _AuthorPhoto(url: widget.urls[_index])),
                IconButton(
                  key: const ValueKey('next-full-screen-author-photo'),
                  tooltip: 'Next author photo',
                  color: Colors.white,
                  onPressed: _index < widget.urls.length - 1
                      ? () => setState(() => _index++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_index + 1} of ${widget.urls.length}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
