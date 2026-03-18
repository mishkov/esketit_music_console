import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
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
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Author? _author;

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
                  Row(
                    children: [
                      Text(
                        'Photos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: _isLoading || _isSaving ? null : _addPhoto,
                        icon: const Icon(Icons.add_link),
                        label: const Text('Add photo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_photos.isEmpty)
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
                    ..._photos.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(entry.value),
                            trailing: IconButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => _removePhoto(entry.key),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove',
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (_isSaving) const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _isLoading || _isSaving
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
                        onPressed: _isLoading || _isSaving ? null : _saveAuthor,
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

  Future<void> _addPhoto() async {
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
