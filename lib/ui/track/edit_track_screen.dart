import 'package:cross_file/cross_file.dart';
import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/ui/album/album_picker.dart';
import 'package:esketit_music_console/ui/album/albums_support.dart';
import 'package:esketit_music_console/ui/album/edit_album_screen.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditTrackScreen extends StatefulWidget {
  const EditTrackScreen({super.key, required this.trackId});

  final int trackId;

  @override
  State<EditTrackScreen> createState() => _EditTrackScreenState();
}

class _EditTrackScreenState extends State<EditTrackScreen> {
  final _titleController = TextEditingController();
  final List<TextTrackInfo> _additionalInfos = [];
  final List<Author> _selectedAuthors = [];
  List<Author> _availableAuthors = const [];
  List<Album> _availableAlbums = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  int? _selectedAlbumId;
  Track? _track;
  Album? _currentAlbum;
  CrossFile? _replacementFile;

  @override
  void initState() {
    super.initState();
    _loadTrack();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit track')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading || _isSaving) const LinearProgressIndicator(),
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
                  AlbumPickerField(
                    albums: _availableAlbums,
                    selectedAlbum: _selectedAlbum,
                    isLoading: _isLoading,
                    enabled: !_isLoading && !_isSaving && track != null,
                    onSelected: (album) {
                      setState(() {
                        _selectedAlbumId = album.id;
                      });
                    },
                    onCreateNew: _openCreateAlbumScreen,
                  ),
                  const SizedBox(height: 12),
                  _SelectionSummaryCard(
                    title: 'Album position',
                    value: _buildAlbumPositionLabel(),
                  ),
                  const SizedBox(height: 16),
                  _AuthorPickerField(
                    authors: _selectedAuthors,
                    isLoading: _isLoading,
                    onTap: _isLoading || _isSaving ? null : _showAuthorPicker,
                    onRemove: _isLoading || _isSaving ? null : _removeAuthor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Audio file',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _SelectionSummaryCard(
                    title: _replacementFile == null
                        ? 'Current file'
                        : 'Replacement file',
                    value: _buildFileLabel(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _isLoading || _isSaving ? null : _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          _replacementFile == null
                              ? 'Replace file'
                              : 'Pick another file',
                        ),
                      ),
                      if (_replacementFile != null)
                        TextButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _replacementFile = null;
                                  });
                                },
                          child: const Text('Keep current file'),
                        ),
                    ],
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
                        child: _AdditionalInfoCard(
                          info: entry.value,
                          onDelete: _isSaving
                              ? null
                              : () => _removeAdditionalInfo(entry.key),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _isLoading || _isSaving
                        ? null
                        : _showAddTextInfoDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add additional info'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _isLoading || _isSaving || track == null
                            ? null
                            : _deleteTrack,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete track'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _isLoading || _isSaving || track == null
                            ? null
                            : _saveTrack,
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

  Future<void> _loadTrack() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = context.read<TracksStorage>();
      final track = await storage.getTrack(widget.trackId);
      final authorsFuture = storage.getAuthors();
      final albumsFuture = loadAllAlbums(storage);
      final currentAlbumFuture = storage.getAlbum(track.albumId);

      final authors = await authorsFuture;
      final albums = await albumsFuture;
      final currentAlbum = await currentAlbumFuture;

      if (!mounted) {
        return;
      }

      authors.sort(
        (left, right) => left.currentName.toLowerCase().compareTo(
          right.currentName.toLowerCase(),
        ),
      );
      albums.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );

      setState(() {
        _track = track;
        _currentAlbum = currentAlbum;
        _availableAuthors = authors;
        _availableAlbums = albums;
        _selectedAlbumId = track.albumId;
        _titleController.text = track.name;
        _selectedAuthors
          ..clear()
          ..addAll(track.authors);
        _additionalInfos
          ..clear()
          ..addAll(track.additionalInfo.whereType<TextTrackInfo>());
        _replacementFile = null;
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) {
      return;
    }

    final xFile = XFile.fromData(
      file.bytes!,
      name: file.name,
      mimeType: file.extension == null ? null : 'audio/${file.extension}',
    );

    setState(() {
      _replacementFile = CrossFile(file: xFile);
    });
  }

  Future<void> _openCreateAlbumScreen() async {
    final savedAlbum = await Navigator.of(
      context,
    ).push<Album>(MaterialPageRoute(builder: (_) => const EditAlbumScreen()));

    if (savedAlbum?.id == null || !mounted) {
      return;
    }

    await _reloadAlbums();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedAlbumId = savedAlbum!.id;
    });
  }

  Future<void> _reloadAlbums() async {
    final albums = await loadAllAlbums(context.read<TracksStorage>());
    albums.sort(
      (left, right) =>
          left.title.toLowerCase().compareTo(right.title.toLowerCase()),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _availableAlbums = albums;
      if (!_availableAlbums.any((album) => album.id == _selectedAlbumId)) {
        _selectedAlbumId = albums.isEmpty ? null : albums.first.id;
      }
    });
  }

  Future<void> _showAuthorPicker() async {
    final pickedAuthors = await showDialog<List<Author>>(
      context: context,
      builder: (context) => _AuthorPickerDialog(
        availableAuthors: _availableAuthors,
        initiallySelectedAuthors: _selectedAuthors,
      ),
    );

    if (pickedAuthors == null || !mounted) {
      return;
    }

    setState(() {
      _selectedAuthors
        ..clear()
        ..addAll(pickedAuthors);
    });
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

  Future<void> _saveTrack() async {
    final track = _track;
    final selectedAlbum = _selectedAlbum;
    final title = _titleController.text.trim();

    if (track == null) {
      return;
    }
    if (title.isEmpty) {
      _showMessage('Title is required.');
      return;
    }
    if (selectedAlbum?.id == null) {
      _showMessage('Select an album first.');
      return;
    }
    if (_selectedAuthors.isEmpty) {
      _showMessage('Select at least one author.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final storage = context.read<TracksStorage>();
      final albumOrder = await _resolveAlbumOrder(selectedAlbum!);
      final updatedTrack = await storage.updateTrack(
        Track(
          id: track.id,
          name: title,
          authors: List<Author>.from(_selectedAuthors),
          albumId: selectedAlbum.id!,
          albumOrder: albumOrder,
          additionalInfo: List<TextTrackInfo>.from(_additionalInfos),
          file: _replacementFile ?? track.file,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _track = updatedTrack;
        _selectedAlbumId = updatedTrack.albumId;
        _replacementFile = null;
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

  Future<int> _resolveAlbumOrder(Album selectedAlbum) async {
    final track = _track;
    if (track?.id == null) {
      return 0;
    }

    if (selectedAlbum.id == _currentAlbum?.id) {
      final currentTrackIds = _currentAlbum?.trackIds ?? const <int>[];
      final currentIndex = currentTrackIds.indexOf(track!.id!);
      if (currentIndex >= 0) {
        return currentIndex;
      }
    }

    final album = await context.read<TracksStorage>().getAlbum(
      selectedAlbum.id!,
    );
    return album.trackIds.length;
  }

  Future<void> _deleteTrack() async {
    final track = _track;
    if (track?.id == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete track?'),
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
      await context.read<TracksStorage>().deleteTrack(track!.id!);
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

  void _removeAuthor(Author author) {
    setState(() {
      _selectedAuthors.remove(author);
    });
  }

  void _removeAdditionalInfo(int index) {
    setState(() {
      _additionalInfos.removeAt(index);
    });
  }

  Album? get _selectedAlbum {
    for (final album in _availableAlbums) {
      if (album.id == _selectedAlbumId) {
        return album;
      }
    }
    return null;
  }

  String _buildAlbumPositionLabel() {
    final selectedAlbum = _selectedAlbum;
    final track = _track;
    if (selectedAlbum == null || track?.id == null) {
      return 'Select an album';
    }
    if (selectedAlbum.id == _currentAlbum?.id) {
      final currentIndex = _currentAlbum?.trackIds.indexOf(track!.id!);
      if (currentIndex != null && currentIndex >= 0) {
        return 'Current position: ${currentIndex + 1}';
      }
    }
    return 'Track will be moved to position ${selectedAlbum.trackIds.length + 1}';
  }

  String _buildFileLabel() {
    final file = (_replacementFile ?? _track?.file);
    if (file == null) {
      return 'No file selected';
    }
    if (file is CrossFile) {
      return '${file.name} (local file selected)';
    }
    if (file is StorageFile) {
      return '${file.name}\n${file.downloadUrl}';
    }
    return 'Unsupported file type: ${file.runtimeType}';
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SelectionSummaryCard extends StatelessWidget {
  const _SelectionSummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _AuthorPickerField extends StatelessWidget {
  const _AuthorPickerField({
    required this.authors,
    required this.isLoading,
    required this.onTap,
    required this.onRemove,
  });

  final List<Author> authors;
  final bool isLoading;
  final VoidCallback? onTap;
  final ValueChanged<Author>? onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Authors',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Loading authors...'),
              )
            : authors.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Select authors'),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: authors
                    .map(
                      (author) => InputChip(
                        label: Text(author.currentName),
                        onDeleted: onRemove == null
                            ? null
                            : () => onRemove!(author),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}

class _AuthorPickerDialog extends StatefulWidget {
  const _AuthorPickerDialog({
    required this.availableAuthors,
    required this.initiallySelectedAuthors,
  });

  final List<Author> availableAuthors;
  final List<Author> initiallySelectedAuthors;

  @override
  State<_AuthorPickerDialog> createState() => _AuthorPickerDialogState();
}

class _AuthorPickerDialogState extends State<_AuthorPickerDialog> {
  late final Map<String, Author> _selectedAuthorsByKey = {
    for (final author in widget.availableAuthors)
      if (widget.initiallySelectedAuthors.any(
        (selected) =>
            selected.currentName.toLowerCase() ==
            author.currentName.toLowerCase(),
      ))
        author.currentName.toLowerCase(): author,
    for (final author in widget.initiallySelectedAuthors)
      if (!widget.availableAuthors.any(
        (availableAuthor) =>
            availableAuthor.currentName.toLowerCase() ==
            author.currentName.toLowerCase(),
      ))
        author.currentName.toLowerCase(): author,
  };
  final _customAuthorController = TextEditingController();

  @override
  void dispose() {
    _customAuthorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select authors'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_customSelectedAuthors.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selected custom authors',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _customSelectedAuthors
                        .map(
                          (author) => InputChip(
                            label: Text(author.currentName),
                            onDeleted: () {
                              setState(() {
                                _selectedAuthorsByKey.remove(
                                  author.currentName.toLowerCase(),
                                );
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.availableAuthors.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No authors in database yet.'),
                )
              else
                ...widget.availableAuthors.map(
                  (author) => CheckboxListTile(
                    value: _selectedAuthorsByKey.containsKey(
                      author.currentName.toLowerCase(),
                    ),
                    contentPadding: EdgeInsets.zero,
                    title: Text(author.currentName),
                    onChanged: (value) {
                      setState(() {
                        final key = author.currentName.toLowerCase();
                        if (value == true) {
                          _selectedAuthorsByKey[key] = author;
                        } else {
                          _selectedAuthorsByKey.remove(key);
                        }
                      });
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _customAuthorController,
                decoration: const InputDecoration(
                  labelText: 'Add custom author',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addCustomAuthor(),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _addCustomAuthor,
                  icon: const Icon(Icons.add),
                  label: const Text('Add custom author'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final authors = _selectedAuthorsByKey.values.toList();
            authors.sort(
              (left, right) => left.currentName.toLowerCase().compareTo(
                right.currentName.toLowerCase(),
              ),
            );
            Navigator.of(context).pop(authors);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _addCustomAuthor() {
    final authorName = _customAuthorController.text.trim();
    if (authorName.isEmpty) {
      return;
    }
    setState(() {
      _selectedAuthorsByKey[authorName.toLowerCase()] = Author(
        currentName: authorName,
      );
    });
    _customAuthorController.clear();
  }

  List<Author> get _customSelectedAuthors {
    return _selectedAuthorsByKey.values
        .where(
          (selectedAuthor) => !widget.availableAuthors.any(
            (availableAuthor) =>
                availableAuthor.currentName.toLowerCase() ==
                selectedAuthor.currentName.toLowerCase(),
          ),
        )
        .toList()
      ..sort(
        (left, right) => left.currentName.toLowerCase().compareTo(
          right.currentName.toLowerCase(),
        ),
      );
  }
}

class _AdditionalInfoCard extends StatelessWidget {
  const _AdditionalInfoCard({required this.info, required this.onDelete});

  final TextTrackInfo info;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(info.title.isEmpty ? 'Untitled info' : info.title),
        subtitle: info.text.isEmpty ? null : Text(info.text),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove',
        ),
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
