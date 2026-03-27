import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/ui/album/edit_album_screen.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AlbumsListScreen extends StatefulWidget {
  const AlbumsListScreen({super.key});

  @override
  State<AlbumsListScreen> createState() => _AlbumsListScreenState();
}

class _AlbumsListScreenState extends State<AlbumsListScreen> {
  List<Album> _albums = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Albums', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                onPressed: _isLoading ? null : _loadAlbums,
                tooltip: 'Reload albums',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading) const LinearProgressIndicator(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: !_isLoading && _albums.isEmpty
                ? const Center(child: Text('No albums found.'))
                : ListView.separated(
                    itemCount: _albums.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final album = _albums[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          title: Text(album.title),
                          subtitle: Text(
                            [
                              album.isPublished ? 'Published' : 'Draft',
                              'Tracks: ${album.trackIds.length}',
                              if (album.authors.isNotEmpty)
                                'Authors: ${album.authors.map((author) => author.currentName).join(', ')}',
                            ].join('\n'),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: album.id == null
                              ? null
                              : () => _openAlbum(album.id!),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final albums = await context.read<TracksStorage>().getAlbums();
      albums.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _albums = albums;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _describeError(error);
      });
    }
  }

  Future<void> _openAlbum(int albumId) async {
    final updatedAlbum = await Navigator.of(context).push<Album>(
      MaterialPageRoute(builder: (_) => EditAlbumScreen(albumId: albumId)),
    );

    if (updatedAlbum != null && mounted) {
      await _loadAlbums();
    }
  }

  String _describeError(Object error) {
    if (error is HttpAppError) {
      final responseBody = error.responseBody;
      if (responseBody is String && responseBody.trim().isNotEmpty) {
        return responseBody.trim();
      }
      return error.message;
    }
    return error.toString();
  }
}
