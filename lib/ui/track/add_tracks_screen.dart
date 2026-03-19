import 'package:cross_file/cross_file.dart';
import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/unassigned_layer/mp3_metadata.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddTracksScreen extends StatefulWidget {
  const AddTracksScreen({super.key});

  @override
  State<AddTracksScreen> createState() => _AddTracksScreenState();
}

class _AddTracksScreenState extends State<AddTracksScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Tracks'),
          bottom: const TabBar(tabs: [Tab(text: 'Upload single file')]),
        ),
        body: const TabBarView(children: [_UploadSingleFileTab()]),
      ),
    );
  }
}

class _UploadSingleFileTab extends StatefulWidget {
  const _UploadSingleFileTab();

  @override
  State<_UploadSingleFileTab> createState() => _UploadSingleFileTabState();
}

class _UploadSingleFileTabState extends State<_UploadSingleFileTab> {
  final _titleController = TextEditingController();
  final List<TextTrackInfo> _additionalInfos = [];
  final List<Author> _selectedAuthors = [];
  List<Author> _availableAuthors = const [];
  List<Album> _availableAlbums = const [];
  CrossFile? _pickedFile;
  bool _isSaving = false;
  bool _isLoadingAuthors = true;
  bool _isLoadingAlbums = true;
  int? _selectedAlbumId;

  @override
  void initState() {
    super.initState();
    _loadAuthors();
    _loadAlbums();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingAuthors || _isLoadingAlbums)
                  const LinearProgressIndicator(),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _pickedFile == null ? 'Pick file' : 'Replace file',
                  ),
                ),
                const SizedBox(height: 12),
                _SelectionSummaryCard(
                  title: 'Selected file',
                  value: _pickedFile?.name ?? 'No file selected',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey(
                    'album-${_selectedAlbumId ?? 'none'}-${_availableAlbums.length}',
                  ),
                  initialValue: _selectedAlbumId,
                  items: _availableAlbums
                      .map(
                        (album) => DropdownMenuItem<int>(
                          value: album.id,
                          child: Text(album.title),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving || _isLoadingAlbums
                      ? null
                      : (value) {
                          setState(() {
                            _selectedAlbumId = value;
                          });
                        },
                  decoration: const InputDecoration(
                    labelText: 'Album',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SelectionSummaryCard(
                  title: 'Album position',
                  value: _selectedAlbum == null
                      ? 'Select an album'
                      : 'Track will be added as item ${_selectedAlbum!.trackIds.length + 1}',
                ),
                const SizedBox(height: 16),
                _AuthorPickerField(
                  authors: _selectedAuthors,
                  isLoading: _isLoadingAuthors,
                  onTap: _isSaving ? null : _showAuthorPicker,
                  onRemove: _isSaving ? null : _removeAuthor,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Additional infos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (_additionalInfos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No additional infos yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
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
                MenuAnchor(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: _showAddTextInfoDialog,
                      child: const Text('Text info'),
                    ),
                  ],
                  builder: (context, controller, child) {
                    return FilledButton.tonalIcon(
                      onPressed: _isSaving
                          ? null
                          : () => controller.isOpen
                                ? controller.close()
                                : controller.open(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add additional info'),
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (_isSaving) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: _isSaving ? null : _saveTrack,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadAuthors() async {
    try {
      final authors = await context.read<TracksStorage>().getAuthors();
      if (!mounted) {
        return;
      }
      authors.sort(
        (left, right) => left.currentName.toLowerCase().compareTo(
          right.currentName.toLowerCase(),
        ),
      );
      setState(() {
        _availableAuthors = authors;
        _isLoadingAuthors = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAuthors = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load authors: $error')));
    }
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await context.read<TracksStorage>().getAlbums();
      if (!mounted) {
        return;
      }
      albums.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );
      setState(() {
        _availableAlbums = albums;
        _selectedAlbumId = albums.isEmpty ? null : albums.first.id;
        _isLoadingAlbums = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingAlbums = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load albums: $error')));
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
    final metadata = parseMp3Metadata(file.bytes!);

    setState(() {
      _pickedFile = CrossFile(file: xFile);
      if ((metadata.title?.isNotEmpty ?? false)) {
        _titleController.text = metadata.title!;
      }
    });

    await _applyMetadataAuthors(metadata.authors);
  }

  Future<void> _applyMetadataAuthors(List<String> metadataAuthors) async {
    if (metadataAuthors.isEmpty) {
      return;
    }

    final knownAuthors = <Author>[];
    final newAuthors = <String>[];

    for (final authorName in metadataAuthors) {
      final existingAuthor = _findAvailableAuthor(authorName);
      if (existingAuthor != null) {
        knownAuthors.add(existingAuthor);
      } else {
        newAuthors.add(authorName);
      }
    }

    if (knownAuthors.isNotEmpty) {
      setState(() {
        for (final author in knownAuthors) {
          _addSelectedAuthor(author);
        }
      });
    }

    if (newAuthors.isEmpty || !mounted) {
      return;
    }

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add new authors to database?'),
          content: Text(
            'The MP3 metadata contains authors that are not in the database yet:\n\n${newAuthors.join(', ')}\n\nDo you want to add them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldAdd != true || !mounted) {
      return;
    }

    setState(() {
      for (final authorName in newAuthors) {
        _addSelectedAuthor(Author(currentName: authorName));
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
    if (_pickedFile == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File and title are required.')),
      );
      return;
    }
    final selectedAlbum = _selectedAlbum;
    if (selectedAlbum?.id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an album first.')));
      return;
    }
    if (_selectedAuthors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one author.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await context.read<TracksStorage>().putTrack(
        Track(
          name: _titleController.text.trim(),
          authors: List<Author>.from(_selectedAuthors),
          albumId: selectedAlbum!.id!,
          albumOrder: selectedAlbum.trackIds.length,
          additionalInfo: List<TextTrackInfo>.from(_additionalInfos),
          file: _pickedFile!,
        ),
      );
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
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save track: $error')));
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

  void _addSelectedAuthor(Author author) {
    final exists = _selectedAuthors.any(
      (selected) =>
          selected.currentName.toLowerCase() ==
          author.currentName.toLowerCase(),
    );
    if (!exists) {
      _selectedAuthors.add(author);
    }
  }

  Author? _findAvailableAuthor(String authorName) {
    for (final author in _availableAuthors) {
      if (author.currentName.toLowerCase() == authorName.toLowerCase()) {
        return author;
      }
    }
    return null;
  }

  Album? get _selectedAlbum {
    for (final album in _availableAlbums) {
      if (album.id == _selectedAlbumId) {
        return album;
      }
    }
    return null;
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
