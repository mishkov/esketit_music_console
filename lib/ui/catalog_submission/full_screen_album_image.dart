import 'package:flutter/material.dart';

class FullScreenAlbumImage extends StatelessWidget {
  const FullScreenAlbumImage({super.key, required this.url});

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
