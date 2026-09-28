import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/album_cover_suggestion.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditAlbumScreen extends StatefulWidget {
  const EditAlbumScreen({
    super.key,
    this.albumId,
    this.initialTitle,
    this.initialReleaseDate,
  });

  final int? albumId;
  final String? initialTitle;
  final DateTime? initialReleaseDate;

  bool get isCreating => albumId == null;

  @override
  State<EditAlbumScreen> createState() => _EditAlbumScreenState();
}

class _EditAlbumScreenState extends State<EditAlbumScreen> {
  final _titleController = TextEditingController();
  final _coverImagePathController = TextEditingController();
  final _releaseDateController = TextEditingController();
  final _releaseDateFocusNode = FocusNode();
  final List<TextTrackInfo> _additionalInfos = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingCover = false;
  bool _isLoadingCoverSuggestions = false;
  bool _isImportingSuggestedCover = false;
  bool _isPublished = true;
  String? _errorMessage;
  String? _coverSuggestionsErrorMessage;
  DateTime _releaseDate = DateTime.now().toUtc();
  Album? _album;
  List<Track> _tracks = const [];
  List<AlbumCoverSuggestion> _coverSuggestions = const [];
  String _coverSuggestionsQuery = '';
  int _coverSuggestionsRequestId = 0;
  String? _selectedSuggestionImageUrl;

  @override
  void initState() {
    super.initState();
    _loadAlbum();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _coverImagePathController.dispose();
    _releaseDateController.dispose();
    _releaseDateFocusNode.dispose();
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
                  if (_isLoading ||
                      _isSaving ||
                      _isUploadingCover ||
                      _isLoadingCoverSuggestions ||
                      _isImportingSuggestedCover)
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
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) =>
                        _triggerImmediateCoverSuggestionsSearch(),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _coverImagePathController,
                    enabled:
                        !_isLoading &&
                        !_isSaving &&
                        !_isUploadingCover &&
                        !_isImportingSuggestedCover,
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
                  if (widget.isCreating) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Image suggester',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When you type an album title, the app searches for "$_coverSearchPreview". Pick any result to import it to your backend.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (_coverSuggestionsErrorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _coverSuggestionsErrorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_coverSuggestionsQuery.isEmpty &&
                        !_isLoadingCoverSuggestions)
                      const _EmptyStateCard(
                        message:
                            'Enter an album title to load cover suggestions.',
                      )
                    else if (_coverSuggestions.isEmpty &&
                        !_isLoadingCoverSuggestions)
                      _EmptyStateCard(
                        message:
                            'No image suggestions found for "$_coverSuggestionsQuery".',
                      )
                    else
                      _CoverSuggestionGrid(
                        suggestions: _coverSuggestions,
                        selectedImageUrl: _selectedSuggestionImageUrl,
                        isDisabled:
                            _isLoading ||
                            _isSaving ||
                            _isUploadingCover ||
                            _isImportingSuggestedCover,
                        onSelect: _importSuggestedCover,
                      ),
                  ],
                  const SizedBox(height: 16),
                  _EditableDateCard(
                    title: 'Release date',
                    controller: _releaseDateController,
                    focusNode: _releaseDateFocusNode,
                    actionLabel: 'Change',
                    onAction: _isLoading || _isSaving
                        ? null
                        : _focusReleaseDateInput,
                    onTap: _isLoading || _isSaving
                        ? null
                        : _prepareReleaseDateInput,
                    enabled: !_isLoading && !_isSaving,
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
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tracks.length,
                      onReorderItem: _isSaving ? (_, _) {} : _reorderTracks,
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        return Padding(
                          key: ValueKey(track.id ?? '${track.name}-$index'),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              title: Text(track.name),
                              subtitle: Text(
                                track.authors
                                    .map((author) => author.currentName)
                                    .join(', '),
                              ),
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              trailing: ReorderableDragStartListener(
                                index: index,
                                enabled: !_isSaving,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
        _titleController.text = widget.initialTitle?.trim() ?? '';
        _releaseDate = widget.initialReleaseDate ?? DateTime.now().toUtc();
        _syncReleaseDateController();
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
        _syncReleaseDateController();
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

  void _focusReleaseDateInput() {
    _prepareReleaseDateInput();
    _releaseDateFocusNode.requestFocus();
  }

  void _prepareReleaseDateInput() {
    if (_releaseDateController.text == _formatDateInputValue(_releaseDate)) {
      _releaseDateController.clear();
    }
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

  void _triggerImmediateCoverSuggestionsSearch() {
    if (!widget.isCreating) {
      return;
    }

    _refreshCoverSuggestions();
  }

  Future<void> _refreshCoverSuggestions() async {
    final title = _titleController.text.trim();
    final query = title;
    final requestId = ++_coverSuggestionsRequestId;

    if (query.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _coverSuggestionsQuery = '';
        _coverSuggestions = const [];
        _coverSuggestionsErrorMessage = null;
        _isLoadingCoverSuggestions = false;
      });
      return;
    }

    setState(() {
      _coverSuggestionsQuery = query;
      _coverSuggestionsErrorMessage = null;
      _isLoadingCoverSuggestions = true;
    });

    try {
      final suggestions = await context
          .read<TracksStorage>()
          .searchAlbumCoverSuggestions(query);
      if (!mounted || requestId != _coverSuggestionsRequestId) {
        return;
      }
      setState(() {
        _coverSuggestions = suggestions.take(20).toList();
        _isLoadingCoverSuggestions = false;
      });
    } catch (error) {
      if (!mounted || requestId != _coverSuggestionsRequestId) {
        return;
      }
      setState(() {
        _coverSuggestions = const [];
        _isLoadingCoverSuggestions = false;
        _coverSuggestionsErrorMessage = _describeError(error);
      });
    }
  }

  Future<void> _importSuggestedCover(AlbumCoverSuggestion suggestion) async {
    setState(() {
      _isImportingSuggestedCover = true;
      _errorMessage = null;
      _selectedSuggestionImageUrl = suggestion.imageUrl;
    });

    try {
      final coverPath = await context
          .read<TracksStorage>()
          .importAlbumCoverFromUrl(
            imageUrl: suggestion.imageUrl,
            suggestedFileName: _buildSuggestedCoverFileName(
              suggestion.imageUrl,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _coverImagePathController.text = coverPath;
        _isImportingSuggestedCover = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isImportingSuggestedCover = false;
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

    final parsedReleaseDate = _parseReleaseDateInput(
      _releaseDateController.text,
    );
    if (parsedReleaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Release date must be entered as DDMMYYYY.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _releaseDate = parsedReleaseDate;
    });

    final draft = Album(
      id: _album?.id,
      title: title,
      coverImagePath: _coverImagePathController.text.trim(),
      authors: _derivedAuthors,
      releaseDate: parsedReleaseDate,
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
      Navigator.of(context).pop(savedAlbum);
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
      Navigator.of(context).pop(_album);
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

  void _reorderTracks(int oldIndex, int newIndex) {
    setState(() {
      final updatedTracks = List<Track>.from(_tracks);
      final item = updatedTracks.removeAt(oldIndex);
      updatedTracks.insert(newIndex, item);
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

  DateTime? _parseReleaseDateInput(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) {
      return null;
    }

    final day = int.tryParse(digits.substring(0, 2));
    final month = int.tryParse(digits.substring(2, 4));
    final year = int.tryParse(digits.substring(4, 8));
    if (day == null || month == null || year == null) {
      return null;
    }

    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }

    return parsed;
  }

  void _syncReleaseDateController() {
    _releaseDateController.text = _formatDateInputValue(_releaseDate);
  }

  String _formatDateInputValue(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day$month${local.year}';
  }

  String get _coverSearchPreview {
    final title = _titleController.text.trim();
    return title.isEmpty ? r'$ALBUM_NAME cover image' : '$title cover image';
  }

  String _buildSuggestedCoverFileName(String imageUrl) {
    final title = _titleController.text.trim();
    final normalizedTitle = title.isEmpty
        ? 'album-cover'
        : title
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');
    final imageUri = Uri.tryParse(imageUrl);
    final lastSegment = imageUri?.pathSegments.isNotEmpty == true
        ? imageUri!.pathSegments.last
        : '';
    final extensionMatch = RegExp(
      r'\.(jpg|jpeg|png|webp|gif)$',
      caseSensitive: false,
    ).firstMatch(lastSegment);
    final extension = extensionMatch?.group(0)?.toLowerCase() ?? '.jpg';
    return '$normalizedTitle$extension';
  }
}

class _EditableDateCard extends StatelessWidget {
  const _EditableDateCard({
    required this.title,
    required this.controller,
    required this.focusNode,
    required this.actionLabel,
    required this.onAction,
    required this.onTap,
    required this.enabled,
  });

  final String title;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final bool enabled;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              onTap: onTap,
              decoration: InputDecoration(
                labelText: title,
                hintText: 'DDMMYYYY',
                helperText: 'Example: 03042014',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
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

class _CoverSuggestionGrid extends StatelessWidget {
  const _CoverSuggestionGrid({
    required this.suggestions,
    required this.selectedImageUrl,
    required this.isDisabled,
    required this.onSelect,
  });

  final List<AlbumCoverSuggestion> suggestions;
  final String? selectedImageUrl;
  final bool isDisabled;
  final ValueChanged<AlbumCoverSuggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    final columnCount = suggestions.length <= 5 ? suggestions.length : 5;
    if (columnCount == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final totalSpacing = spacing * (columnCount - 1);
        final tileWidth = (constraints.maxWidth - totalSpacing) / columnCount;
        final rowCount = (suggestions.length / columnCount).ceil();
        final gridHeight = (tileWidth * rowCount) + (spacing * (rowCount - 1));

        return SizedBox(
          height: gridHeight,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: suggestions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              final isSelected = suggestion.imageUrl == selectedImageUrl;
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: isDisabled ? null : () => onSelect(suggestion),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        suggestion.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.network(
                            suggestion.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return ColoredBox(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              );
                            },
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              '${suggestion.width}x${suggestion.height}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
