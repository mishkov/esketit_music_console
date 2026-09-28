import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/domain/catalog_publication_status.dart';
import 'package:esketit_music_console/errors/http_app_error.dart';
import 'package:esketit_music_console/ui/author/edit_author_screen.dart';
import 'package:esketit_music_console/ui/catalog_submission/publication_status_badge.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthorsListScreen extends StatefulWidget {
  const AuthorsListScreen({super.key});

  @override
  State<AuthorsListScreen> createState() => _AuthorsListScreenState();
}

class _AuthorsListScreenState extends State<AuthorsListScreen> {
  List<Author> _authors = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAuthors();
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
              Text('Authors', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                onPressed: _isLoading ? null : _loadAuthors,
                tooltip: 'Reload authors',
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
            child: !_isLoading && _authors.isEmpty
                ? const Center(child: Text('No authors found.'))
                : ListView.separated(
                    itemCount: _authors.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final author = _authors[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          title: Text(author.currentName),
                          subtitle: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('Photos: ${author.photos.length}'),
                              PublicationStatusBadge(
                                status: author.publicationStatus,
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap:
                              author.id == null ||
                                  author.publicationStatus !=
                                      CatalogPublicationStatus.published
                              ? null
                              : () => _openAuthor(author.id!),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAuthors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authors = await context.read<TracksStorage>().getAuthors();
      authors.sort(
        (left, right) => left.currentName.toLowerCase().compareTo(
          right.currentName.toLowerCase(),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _authors = authors;
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

  Future<void> _openAuthor(int authorId) async {
    final didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditAuthorScreen(authorId: authorId)),
    );

    if (didUpdate == true && mounted) {
      await _loadAuthors();
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
