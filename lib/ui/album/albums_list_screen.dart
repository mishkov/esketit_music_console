import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/domain/author.dart';
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
  static const _pageSize = 20;

  final _queryController = TextEditingController();
  List<Album> _albums = const [];
  List<Author> _authors = const [];
  bool _isLoading = true;
  bool _isLoadingFilters = true;
  String? _errorMessage;
  int _page = 1;
  int _totalPages = 0;
  int _totalItems = 0;
  int? _selectedAuthorId;
  bool? _publishedFilter;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
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
          _FiltersSection(
            queryController: _queryController,
            authors: _authors,
            selectedAuthorId: _selectedAuthorId,
            publishedFilter: _publishedFilter,
            isLoading: _isLoadingFilters || _isLoading,
            onApply: _applyFilters,
            onAuthorChanged: (value) {
              setState(() {
                _selectedAuthorId = value;
              });
              _applyFilters();
            },
            onPublishedChanged: (value) {
              setState(() {
                _publishedFilter = value;
              });
              _applyFilters();
            },
            onClear: _clearFilters,
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
                      return _AlbumCard(
                        album: album,
                        coverImageUrl: context
                            .read<TracksStorage>()
                            .resolveAlbumCoverUrl(album.coverImagePath),
                        releaseDateLabel: _formatDate(album.releaseDate),
                        onTap: album.id == null
                            ? null
                            : () => _openAlbum(album.id!),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          _PaginationSection(
            page: _page,
            totalPages: _totalPages,
            totalItems: _totalItems,
            isLoading: _isLoading,
            onPageSelected: _goToPage,
            onPrevious: _page > 1 ? () => _goToPage(_page - 1) : null,
            onNext: _page < _totalPages ? () => _goToPage(_page + 1) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _loadInitialState() async {
    await Future.wait([_loadAuthors(), _loadAlbums()]);
  }

  Future<void> _loadAuthors() async {
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
        _isLoadingFilters = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingFilters = false;
        _errorMessage = _describeError(error);
      });
    }
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final albumsPage = await context.read<TracksStorage>().getAlbumsList(
        page: _page,
        pageSize: _pageSize,
        query: _queryController.text.trim(),
        authorId: _selectedAuthorId,
        isPublished: _publishedFilter,
      );
      final albums = List<Album>.from(albumsPage.albums)
        ..sort(
          (left, right) =>
              left.title.toLowerCase().compareTo(right.title.toLowerCase()),
        );
      if (!mounted) {
        return;
      }
      setState(() {
        _albums = albums;
        _page = albumsPage.page;
        _totalPages = albumsPage.totalPages;
        _totalItems = albumsPage.totalItems;
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

  Future<void> _applyFilters() async {
    setState(() {
      _page = 1;
    });
    await _loadAlbums();
  }

  Future<void> _clearFilters() async {
    _queryController.clear();
    setState(() {
      _selectedAuthorId = null;
      _publishedFilter = null;
      _page = 1;
    });
    await _loadAlbums();
  }

  Future<void> _goToPage(int page) async {
    setState(() {
      _page = page;
    });
    await _loadAlbums();
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

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '${localDate.year}-$month-$day';
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.coverImageUrl,
    required this.releaseDateLabel,
    this.onTap,
  });

  final Album album;
  final String coverImageUrl;
  final String releaseDateLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final authorNames = album.authors
        .map((author) => author.currentName.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AlbumCover(imageUrl: coverImageUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          album.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        _AlbumTag(
                          label: album.isPublished ? 'Published' : 'Draft',
                        ),
                        _AlbumTag(label: '${album.trackIds.length} tracks'),
                        _AlbumTag(label: releaseDateLabel),
                      ],
                    ),
                    if (authorNames.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            const TextSpan(text: 'Author: '),
                            TextSpan(
                              text: authorNames,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumTag extends StatelessWidget {
  const _AlbumTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 70.4,
        height: 70.4,
        child: imageUrl.isEmpty
            ? placeholder
            : Image.network(
                imageUrl,
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
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _FiltersSection extends StatelessWidget {
  const _FiltersSection({
    required this.queryController,
    required this.authors,
    required this.selectedAuthorId,
    required this.publishedFilter,
    required this.isLoading,
    required this.onApply,
    required this.onAuthorChanged,
    required this.onPublishedChanged,
    required this.onClear,
  });

  final TextEditingController queryController;
  final List<Author> authors;
  final int? selectedAuthorId;
  final bool? publishedFilter;
  final bool isLoading;
  final Future<void> Function() onApply;
  final ValueChanged<int?> onAuthorChanged;
  final ValueChanged<bool?> onPublishedChanged;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: queryController,
            enabled: !isLoading,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search albums',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: queryController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              queryController.clear();
                              onApply();
                            },
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onSubmitted: (_) => onApply(),
          ),
        ),
        SizedBox(
          width: 240,
          child: _AuthorFilterField(
            authors: authors,
            selectedAuthorId: selectedAuthorId,
            enabled: !isLoading,
            onChanged: onAuthorChanged,
          ),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<bool?>(
            initialValue: publishedFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('All statuses')),
              DropdownMenuItem<bool?>(value: true, child: Text('Published')),
              DropdownMenuItem<bool?>(value: false, child: Text('Draft')),
            ],
            onChanged: isLoading ? null : onPublishedChanged,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: isLoading ? null : onApply,
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('Apply'),
        ),
        TextButton(
          onPressed: isLoading ? null : onClear,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

class _AuthorFilterField extends StatelessWidget {
  const _AuthorFilterField({
    required this.authors,
    required this.selectedAuthorId,
    required this.enabled,
    required this.onChanged,
  });

  final List<Author> authors;
  final int? selectedAuthorId;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    Author? selectedAuthor;
    for (final author in authors) {
      if (author.id == selectedAuthorId) {
        selectedAuthor = author;
        break;
      }
    }

    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final result = await showDialog<_AuthorFilterSelection>(
                context: context,
                builder: (context) => _AuthorFilterDialog(
                  authors: authors,
                  selectedAuthorId: selectedAuthorId,
                ),
              );
              if (result == null) {
                return;
              }
              onChanged(result.authorId);
            },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Author',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedAuthor?.currentName ?? 'All authors',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _AuthorFilterSelection {
  const _AuthorFilterSelection(this.authorId);

  final int? authorId;
}

class _AuthorFilterDialog extends StatefulWidget {
  const _AuthorFilterDialog({
    required this.authors,
    required this.selectedAuthorId,
  });

  final List<Author> authors;
  final int? selectedAuthorId;

  @override
  State<_AuthorFilterDialog> createState() => _AuthorFilterDialogState();
}

class _AuthorFilterDialogState extends State<_AuthorFilterDialog> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAuthors = widget.authors.where((author) {
      return author.currentName.toLowerCase().contains(_query);
    }).toList();

    return AlertDialog(
      title: const Text('Filter by author'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                labelText: 'Search authors',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.people_outline),
                    title: const Text('All authors'),
                    trailing: widget.selectedAuthorId == null
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const _AuthorFilterSelection(null)),
                  ),
                  const Divider(height: 1),
                  if (filteredAuthors.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No authors match the search.'),
                      ),
                    )
                  else
                    ...filteredAuthors.map(
                      (author) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          author.currentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: author.id == widget.selectedAuthorId
                            ? const Icon(Icons.check_circle)
                            : null,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(_AuthorFilterSelection(author.id)),
                      ),
                    ),
                ],
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
      ],
    );
  }
}

class _PaginationSection extends StatelessWidget {
  const _PaginationSection({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.isLoading,
    required this.onPageSelected,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int totalItems;
  final bool isLoading;
  final ValueChanged<int> onPageSelected;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final currentPage = totalPages == 0
        ? 1
        : page < 1
        ? 1
        : page > totalPages
        ? totalPages
        : page;

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(totalPages == 0 ? '0 results' : '$totalItems results'),
        if (totalPages > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Page: '),
              DropdownButton<int>(
                key: const ValueKey('albums-page-selector'),
                value: currentPage,
                items: List.generate(
                  totalPages,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text('${index + 1}'),
                  ),
                ),
                onChanged: isLoading || totalPages <= 1
                    ? null
                    : (value) {
                        if (value == null || value == currentPage) {
                          return;
                        }
                        onPageSelected(value);
                      },
              ),
              Text(' of $totalPages'),
            ],
          ),
        OutlinedButton.icon(
          key: const ValueKey('albums-page-previous'),
          onPressed: isLoading ? null : onPrevious,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('albums-page-next'),
          onPressed: isLoading ? null : onNext,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
      ],
    );
  }
}
