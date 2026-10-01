import 'package:flutter/material.dart';
import 'package:esketit_music_console/ui/catalog_submission/full_screen_album_image.dart';

class AlbumCoverPreview extends StatelessWidget {
  const AlbumCoverPreview({super.key, required this.url, required this.size});

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
          builder: (context) => FullScreenAlbumImage(url: url),
        ),
        child: image,
      ),
    );
  }
}
