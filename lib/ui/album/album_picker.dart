import 'package:esketit_music_console/domain/album.dart';
import 'package:flutter/material.dart';

typedef AlbumPickerCreateNew = Future<void> Function();

class AlbumPickerField extends StatelessWidget {
  const AlbumPickerField({
    super.key,
    required this.albums,
    required this.selectedAlbum,
    required this.isLoading,
    required this.enabled,
    required this.onSelected,
    required this.onCreateNew,
    this.labelText = 'Album',
  });

  final List<Album> albums;
  final Album? selectedAlbum;
  final bool isLoading;
  final bool enabled;
  final ValueChanged<Album> onSelected;
  final AlbumPickerCreateNew onCreateNew;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: !enabled || isLoading
          ? null
          : () =>
                showAlbumPickerDialog(
                  context,
                  availableAlbums: albums,
                  selectedAlbumId: selectedAlbum?.id,
                  onCreateNew: onCreateNew,
                ).then((result) {
                  if (result case AlbumPickerDialogSelection(
                    album: final album,
                  )) {
                    onSelected(album);
                  }
                }),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          suffixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Loading albums...'),
              )
            : selectedAlbum == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Select an album'),
              )
            : _AlbumSummary(album: selectedAlbum!),
      ),
    );
  }
}

Future<AlbumPickerDialogResult?> showAlbumPickerDialog(
  BuildContext context, {
  required List<Album> availableAlbums,
  required AlbumPickerCreateNew onCreateNew,
  int? selectedAlbumId,
  String? metadataAlbumTitle,
}) {
  return showDialog<AlbumPickerDialogResult>(
    context: context,
    builder: (context) => _AlbumPickerDialog(
      availableAlbums: availableAlbums,
      onCreateNew: onCreateNew,
      selectedAlbumId: selectedAlbumId,
      metadataAlbumTitle: metadataAlbumTitle,
    ),
  );
}

sealed class AlbumPickerDialogResult {
  const AlbumPickerDialogResult();
}

class AlbumPickerDialogSelection extends AlbumPickerDialogResult {
  const AlbumPickerDialogSelection(this.album);

  final Album album;
}

class AlbumPickerDialogCreateNew extends AlbumPickerDialogResult {
  const AlbumPickerDialogCreateNew();
}

class _AlbumPickerDialog extends StatefulWidget {
  const _AlbumPickerDialog({
    required this.availableAlbums,
    required this.onCreateNew,
    this.selectedAlbumId,
    this.metadataAlbumTitle,
  });

  final List<Album> availableAlbums;
  final AlbumPickerCreateNew onCreateNew;
  final int? selectedAlbumId;
  final String? metadataAlbumTitle;

  @override
  State<_AlbumPickerDialog> createState() => _AlbumPickerDialogState();
}

class _AlbumPickerDialogState extends State<_AlbumPickerDialog> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.metadataAlbumTitle ?? '',
  );
  final FocusNode _searchFocusNode = FocusNode();
  late String _searchQuery = _searchController.text.trim().toLowerCase();

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
    final filteredAlbums = _filteredAlbums;

    return AlertDialog(
      title: Text(
        widget.metadataAlbumTitle == null ? 'Select album' : 'Album not found',
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.metadataAlbumTitle != null) ...[
              Text(
                'Parsed album "${widget.metadataAlbumTitle}" was not matched automatically. Search below or create it as a new album.',
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.tonalIcon(
              onPressed: () async {
                Navigator.of(context).pop(const AlbumPickerDialogCreateNew());
                await widget.onCreateNew();
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create new album'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                labelText: 'Search albums',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${filteredAlbums.length} album${filteredAlbums.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: filteredAlbums.isEmpty
                  ? const Center(child: Text('No albums match the search.'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredAlbums.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final album = filteredAlbums[index];
                        final isSelected = album.id == widget.selectedAlbumId;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          selected: isSelected,
                          leading: CircleAvatar(
                            child: Text(
                              album.title.isEmpty
                                  ? '?'
                                  : album.title.characters.first.toUpperCase(),
                            ),
                          ),
                          title: Text(album.title),
                          subtitle: Text(_buildSubtitle(album)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          onTap: album.id == null
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pop(AlbumPickerDialogSelection(album)),
                        );
                      },
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

  List<Album> get _filteredAlbums {
    if (_searchQuery.isEmpty) {
      return widget.availableAlbums;
    }

    return widget.availableAlbums.where((album) {
      final title = album.title.toLowerCase();
      final authors = album.authors
          .map((author) => author.currentName.toLowerCase())
          .join(' ');
      final id = album.id?.toString() ?? '';
      return title.contains(_searchQuery) ||
          authors.contains(_searchQuery) ||
          id.contains(_searchQuery);
    }).toList();
  }

  String _buildSubtitle(Album album) {
    final parts = <String>[
      if (album.id != null) '#${album.id}',
      album.isPublished ? 'Published' : 'Draft',
      '${album.trackIds.length} tracks',
      if (album.authors.isNotEmpty)
        album.authors.map((author) => author.currentName).join(', '),
    ];
    return parts.join('  •  ');
  }
}

class _AlbumSummary extends StatelessWidget {
  const _AlbumSummary({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (album.id != null) '#${album.id}',
      album.isPublished ? 'Published' : 'Draft',
      '${album.trackIds.length} tracks',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(album.title, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 2),
        Text(
          subtitleParts.join('  •  '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (album.authors.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            album.authors.map((author) => author.currentName).join(', '),
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
