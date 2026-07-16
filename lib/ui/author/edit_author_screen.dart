import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/ui/author/author_photo_crop_dialog.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditAuthorScreen extends StatefulWidget {
  const EditAuthorScreen({super.key, required this.authorId});

  final int authorId;

  @override
  State<EditAuthorScreen> createState() => _EditAuthorScreenState();
}

class _EditAuthorScreenState extends State<EditAuthorScreen> {
  final _nameController = TextEditingController();
  final List<String> _photos = [];
  final List<_PendingAuthorPhoto> _pendingPhotoUploads = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Author? _author;

  bool get _hasPendingPhotoUploads => _pendingPhotoUploads.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadAuthor();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<TracksStorage>();
    final isPhotoActionDisabled =
        _isLoading || _isSaving || _hasPendingPhotoUploads;
    final isSaveDisabled = _isLoading || _isSaving || _hasPendingPhotoUploads;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit author')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading) const LinearProgressIndicator(),
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
                    controller: _nameController,
                    enabled: !_isLoading && !_isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Current name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final actions = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: isPhotoActionDisabled
                                ? null
                                : _uploadPhotos,
                            icon: const Icon(Icons.crop),
                            label: const Text('Upload and crop'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: isPhotoActionDisabled
                                ? null
                                : _addPhotoUrl,
                            icon: const Icon(Icons.add_link),
                            label: const Text('Add URL'),
                          ),
                        ],
                      );

                      final title = Text(
                        'Photos',
                        style: Theme.of(context).textTheme.titleMedium,
                      );

                      if (constraints.maxWidth < 520) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [title, const SizedBox(height: 8), actions],
                        );
                      }

                      return Row(children: [title, const Spacer(), actions]);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_photos.isEmpty && _pendingPhotoUploads.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('No photos yet.'),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth < 560
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ..._pendingPhotoUploads.map(
                              (photo) => SizedBox(
                                width: cardWidth,
                                child: _AuthorPhotoCard(
                                  title: photo.name,
                                  sourceLabel: 'Pending file',
                                  memoryBytes: photo.bytes,
                                  isPending: true,
                                ),
                              ),
                            ),
                            ..._photos.asMap().entries.map(
                              (entry) => SizedBox(
                                width: cardWidth,
                                child: _AuthorPhotoCard(
                                  title: entry.value,
                                  sourceLabel:
                                      _isUploadedAuthorPhotoReference(
                                        entry.value,
                                      )
                                      ? 'Uploaded file'
                                      : 'URL',
                                  imageUrl: storage.resolveAuthorPhotoUrl(
                                    entry.value,
                                  ),
                                  onRemove: _isSaving || _hasPendingPhotoUploads
                                      ? null
                                      : () => _removePhoto(entry.key),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  if (_hasPendingPhotoUploads) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Uploading photos. Save is available after uploads finish.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_isSaving || _hasPendingPhotoUploads)
                    const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed:
                            _isLoading || _isSaving || _hasPendingPhotoUploads
                            ? null
                            : _deleteAuthor,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete author'),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        onPressed: isSaveDisabled ? null : _saveAuthor,
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

  Future<void> _loadAuthor() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final author = await context.read<TracksStorage>().getAuthor(
        widget.authorId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _author = author;
        _nameController.text = author.currentName;
        _photos
          ..clear()
          ..addAll(author.photos);
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

  Future<void> _uploadPhotos() async {
    final storage = context.read<TracksStorage>();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final pendingPhotos = <_PendingAuthorPhoto>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        continue;
      }

      final croppedBytes = await showAuthorPhotoCropDialog(
        context,
        imageBytes: bytes,
        fileName: file.name,
      );
      if (!mounted) {
        return;
      }
      if (croppedBytes == null) {
        continue;
      }

      pendingPhotos.add(
        _PendingAuthorPhoto(
          name: _croppedAuthorPhotoFileName(file.name),
          bytes: croppedBytes,
        ),
      );
    }

    if (pendingPhotos.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No photos were added.')));
      return;
    }

    setState(() {
      _pendingPhotoUploads.addAll(pendingPhotos);
      _errorMessage = null;
    });

    try {
      for (final pendingPhoto in pendingPhotos) {
        final xFile = XFile.fromData(
          pendingPhoto.bytes,
          name: pendingPhoto.name,
          mimeType: _imageMimeTypeFromName(pendingPhoto.name),
        );
        final photoPath = await storage.uploadAuthorPhoto(
          CrossFile(file: xFile),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _pendingPhotoUploads.remove(pendingPhoto);
          _photos.add(photoPath);
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingPhotoUploads.removeWhere(pendingPhotos.contains);
        _errorMessage = _describeError(error);
      });
    }
  }

  Future<void> _addPhotoUrl() async {
    final controller = TextEditingController();
    final photo = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add photo URL'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Photo URL',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (photo == null || photo.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _photos.add(photo);
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _saveAuthor() async {
    final author = _author;
    if (author == null) {
      return;
    }

    final currentName = _nameController.text.trim();
    if (currentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current name is required.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedAuthor = await context.read<TracksStorage>().updateAuthor(
        Author(
          id: author.id,
          currentName: currentName,
          photos: List.of(_photos),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _author = updatedAuthor;
        _photos
          ..clear()
          ..addAll(updatedAuthor.photos);
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

  Future<void> _deleteAuthor() async {
    final author = _author;
    final authorId = author?.id;
    if (authorId == null || author == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete author?'),
          content: Text(
            'Delete "${author.currentName}" from the database? This action cannot be undone.',
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

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<TracksStorage>().deleteAuthor(authorId);
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

  String? _imageMimeTypeFromName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final extension = dotIndex == -1
        ? ''
        : fileName.substring(dotIndex + 1).toLowerCase();
    return switch (extension) {
      'bmp' => 'image/bmp',
      'gif' => 'image/gif',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  String _croppedAuthorPhotoFileName(String fileName) {
    final trimmedFileName = fileName.trim();
    final dotIndex = trimmedFileName.lastIndexOf('.');
    final baseName = dotIndex == -1
        ? trimmedFileName
        : trimmedFileName.substring(0, dotIndex);
    final normalizedBaseName = baseName.isEmpty ? 'author_photo' : baseName;
    return '${normalizedBaseName}_cropped.png';
  }

  bool _isUploadedAuthorPhotoReference(String photo) {
    final trimmedPhoto = photo.trim();
    if (trimmedPhoto.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(trimmedPhoto);
    if (uri != null && uri.hasScheme) {
      return uri.path.contains('/api/author-photos/');
    }

    return trimmedPhoto.startsWith('/api/author-photos/') ||
        (!trimmedPhoto.startsWith('/') && !trimmedPhoto.contains('/'));
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

class _PendingAuthorPhoto {
  const _PendingAuthorPhoto({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class _AuthorPhotoCard extends StatelessWidget {
  const _AuthorPhotoCard({
    required this.title,
    required this.sourceLabel,
    this.imageUrl,
    this.memoryBytes,
    this.isPending = false,
    this.onRemove,
  });

  final String title;
  final String sourceLabel;
  final String? imageUrl;
  final Uint8List? memoryBytes;
  final bool isPending;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: _buildPreview(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PhotoSourceBadge(
                        label: sourceLabel,
                        isPending: isPending,
                      ),
                      const SizedBox(height: 8),
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final placeholder = _AuthorPhotoPlaceholder(
      icon: isPending ? Icons.upload_file : Icons.image_outlined,
    );

    Widget preview = placeholder;
    final bytes = memoryBytes;
    final url = imageUrl;
    if (bytes != null) {
      preview = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    } else if (url != null && url.isNotEmpty) {
      preview = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              placeholder,
              const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      );
    }

    if (!isPending) {
      return preview;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        preview,
        ColoredBox(
          color: Colors.black.withValues(alpha: 0.24),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _PhotoSourceBadge extends StatelessWidget {
  const _PhotoSourceBadge({required this.label, required this.isPending});

  final String label;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUrl = label == 'URL';
    final icon = isPending
        ? Icons.pending_outlined
        : isUrl
        ? Icons.link
        : Icons.image_outlined;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPending
            ? colorScheme.tertiaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _AuthorPhotoPlaceholder extends StatelessWidget {
  const _AuthorPhotoPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: 36, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
