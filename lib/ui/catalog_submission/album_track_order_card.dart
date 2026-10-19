import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:flutter/material.dart';

class AlbumTrackOrderCard extends StatelessWidget {
  const AlbumTrackOrderCard({required this.submission, super.key});
  final CatalogSubmission submission;
  @override
  Widget build(BuildContext context) {
    final data = submission.retainedEntity;
    final names = <int, String>{
      for (final item
          in (data['trackDetails'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
        (item['id'] as num).toInt(): item['name'].toString(),
    };
    final base = (data['baseTracks'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final proposed = (data['tracks'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final current = (data['currentTracks'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final ids = <int>{
      for (final item in [...base, ...proposed, ...current])
        (item['trackId'] as num).toInt(),
    };
    String number(List<Map<String, dynamic>> assignments, int id) =>
        assignments
            .where((item) => item['trackId'] == id)
            .firstOrNull?['trackNumber']
            ?.toString() ??
        '—';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Album #${data['albumId']} · Track-number proposal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (data['expectedOrderRevision'] != data['currentOrderRevision'] &&
                data['currentOrderRevision'] != null)
              const Text(
                'The album has changed. Refresh this proposal before approval.',
              ),
            if ((data['reason']?.toString() ?? '').isNotEmpty)
              Text(data['reason'].toString()),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Track')),
                  DataColumn(label: Text('Before')),
                  DataColumn(label: Text('Proposed')),
                  DataColumn(label: Text('Current')),
                ],
                rows: ids
                    .map(
                      (id) => DataRow(
                        cells: [
                          DataCell(Text('${names[id] ?? 'Track'} (#$id)')),
                          DataCell(Text(number(base, id))),
                          DataCell(Text(number(proposed, id))),
                          DataCell(Text(number(current, id))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
