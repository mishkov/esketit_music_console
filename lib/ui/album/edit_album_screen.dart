import 'package:cross_file/cross_file.dart';
import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditAlbumScreen extends StatefulWidget {
  const EditAlbumScreen({super.key, this.albumId});

  final int? albumId;

  bool get isCreating => albumId == null;

  @override
  State<EditAlbumScreen> createState() => _EditAlbumScreenState();
}

class _EditAlbumScreenState extends State<EditAlbumScreen> {
  final _titleController = TextEditingController();
  final _coverImagePathController = TextEditingController();
  final List<TextTrackInfo> _additionalInfos = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingCover = false;
  bool _isPublished = false;
  String? _errorMessage;
  DateTime _releaseDate = DateTime.now().toUtc();
  Album? _album;
  List<Track> _tracks = const [];

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _coverImagePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreating ? 'Create album' : 'Edit album'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading || _isSaving || _isUploadingCover)
                    const LinearProgressIndicator(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    enabled: !_isLoading && !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _coverImagePathController,
                    enabled: !_isLoading && !_isSaving && !_isUploadingCover,
                    decoration: const InputDecoration(
                      labelText: 'Cover image path',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _isLoading || _isSaving || _isUploadingCover
                          ? null
                          : _uploadCover,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload cover'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SummaryCard(
                    title: 'Release date',
                    value: _formatDate(_releaseDate),
                    actionLabel: 'Change',
                    onAction: _isLoading || _isSaving ? null : _pickReleaseDate,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: _isPublished,
                    onChanged: _isLoading || _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _isPublished = value;
                            });
                          },
                    title: const Text('Published'),
                    subtitle: Text(
                      _tracks.isEmpty
                          ? 'Albums without tracks stay drafts.'
                          : 'Published albums are visible as released content.',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Derived authors',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_derivedAuthors.isEmpty)
                    const _EmptyStateCard(
                      message:
                          'No authors yet. Authors are derived from album tracks.',
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _derivedAuthors
                          .map(
                            (author) => InputChip(
                              label: Text(author.currentName),
                              onPressed: null,
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Tracks',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This screen can reorder the current album tracks. Moving tracks between albums is not supported here yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (_tracks.isEmpty)
                    const _EmptyStateCard(
                      message: 'No tracks attached to this album yet.',
                    )
                  else
                    ..._tracks.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(entry.value.name),
                            subtitle: Text(
                              entry.value.authors
                                  .map((author) => author.currentName)
                                  .join(', '),
                            ),
                            leading: CircleAvatar(
                              child: Text('${entry.key + 1}'),
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  onPressed: _isSaving || entry.key == 0
                                      ? null
                                      : () => _moveTrack(
                                          entry.key,
                                          entry.key - 1,
                                        ),
                                  icon: const Icon(Icons.arrow_upward),
                                  tooltip: 'Move up',
                                ),
                                IconButton(
                                  onPressed:
                                      _isSaving ||
                                          entry.key == _tracks.length - 1
                                      ? null
                                      : () => _moveTrack(
                                          entry.key,
                                          entry.key + 1,
                                        ),
                                  icon: const Icon(Icons.arrow_downward),
                                  tooltip: 'Move down',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Additional infos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_additionalInfos.isEmpty)
                    const _EmptyStateCard(message: 'No additional infos yet.')
                  else
                    ..._additionalInfos.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(
                              entry.value.title.isEmpty
                                  ? 'Untitled info'
                                  : entry.value.title,
                            ),
                            subtitle: entry.value.text.isEmpty
                                ? null
                                : Text(entry.value.text),
                            trailing: IconButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => _removeAdditionalInfo(entry.key),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove',
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _isSaving ? null : _showAddTextInfoDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add additional info'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (!widget.isCreating)
                        TextButton.icon(
                          onPressed: _isLoading || _isSaving
                              ? null
                              : _deleteAlbum,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete album'),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _isLoading || _isSaving ? null : _saveAlbum,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadAlbum() async {
    if (widget.albumId == null) {
      setState(() {
        _isLoading = false;
        _releaseDate = DateTime.now().toUtc();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = context.read<TracksStorage>();
      final album = await storage.getAlbum(widget.albumId!);
      final tracks = await storage.getAlbumTracks(widget.albumId!);
      if (!mounted) {
        return;
      }
      setState(() {
        _album = album;
        _tracks = tracks;
        _titleController.text = album.title;
        _coverImagePathController.text = album.coverImagePath;
        _releaseDate = album.releaseDate;
        _isPublished = album.isPublished;
        _additionalInfos
          ..clear()
          ..addAll(album.additionalInfo.whereType<TextTrackInfo>());
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

  Future<void> _pickReleaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate.toLocal(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _releaseDate = DateTime.utc(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _uploadCover() async {
    final storage = context.read<TracksStorage>();
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) {
      return;
    }

    final xFile = XFile.fromData(
      file.bytes!,
      name: file.name,
      mimeType: file.extension == null ? null : 'image/${file.extension}',
    );

    setState(() {
      _isUploadingCover = true;
      _errorMessage = null;
    });

    try {
      final coverPath = await storage.uploadAlbumCover(CrossFile(file: xFile));
      if (!mounted) {
        return;
      }
      setState(() {
        _coverImagePathController.text = coverPath;
        _isUploadingCover = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUploadingCover = false;
        _errorMessage = _describeError(error);
      });
    }
  }

  Future<void> _showAddTextInfoDialog() async {
    final titleController = TextEditingController();
    final textController = TextEditingController();

    final info = await showDialog<TextTrackInfo>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add text info'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Info title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Info text',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                final text = textController.text.trim();
                if (title.isEmpty && text.isEmpty) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(
                  context,
                ).pop(TextTrackInfo(title: title, text: text));
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    textController.dispose();

    if (info == null || !mounted) {
      return;
    }

    setState(() {
      _additionalInfos.add(info);
    });
  }

  Future<void> _saveAlbum() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Album title is required.')));
      return;
    }
    if (_isPublished && _tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Albums without tracks cannot be published.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final draft = Album(
      id: _album?.id,
      title: title,
      coverImagePath: _coverImagePathController.text.trim(),
      authors: _derivedAuthors,
      releaseDate: _releaseDate,
      isPublished: _isPublished,
      trackIds: _tracks.map((track) => track.id).whereType<int>().toList(),
      additionalInfo: List<TextTrackInfo>.from(_additionalInfos),
    );

    try {
      final storage = context.read<TracksStorage>();
      final savedAlbum = widget.isCreating
          ? await storage.createAlbum(draft)
          : await storage.updateAlbum(draft);
      if (!mounted) {
        return;
      }
      setState(() {
        _album = savedAlbum;
        _isSaving = false;
      });
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = _describeError(error);
      });
    }
  }

  Future<void> _deleteAlbum() async {
    final albumId = _album?.id;
    if (albumId == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete album?'),
          content: Text(
            'Delete "${_titleController.text.trim()}" from the database? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<TracksStorage>().deleteAlbum(albumId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = _describeError(error);
      });
    }
  }

  void _moveTrack(int fromIndex, int toIndex) {
    setState(() {
      final updatedTracks = List<Track>.from(_tracks);
      final item = updatedTracks.removeAt(fromIndex);
      updatedTracks.insert(toIndex, item);
      _tracks = updatedTracks;
    });
  }

  void _removeAdditionalInfo(int index) {
    setState(() {
      _additionalInfos.removeAt(index);
    });
  }

  List<Author> get _derivedAuthors {
    final authorsById = <int, Author>{};
    final customAuthorsByName = <String, Author>{};

    for (final track in _tracks) {
      for (final author in track.authors) {
        final id = author.id;
        if (id != null) {
          authorsById[id] = author;
        } else {
          customAuthorsByName[author.currentName.toLowerCase()] = author;
        }
      }
    }

    final authors = [...authorsById.values, ...customAuthorsByName.values];
    authors.sort(
      (left, right) => left.currentName.toLowerCase().compareTo(
        right.currentName.toLowerCase(),
      ),
    );
    return authors;
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

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String value;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}
