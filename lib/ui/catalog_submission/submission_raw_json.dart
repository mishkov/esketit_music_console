import 'dart:convert';

import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:flutter/material.dart';

class SubmissionRawJson extends StatelessWidget {
  const SubmissionRawJson({super.key, required this.submission});

  final CatalogSubmission submission;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: ValueKey('raw-json-${submission.id}'),
      title: Text('Raw JSON', style: Theme.of(context).textTheme.titleSmall),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        SizedBox(
          width: double.infinity,
          child: SelectableText(
            const JsonEncoder.withIndent(
              ' ',
            ).convert(submission.retainedEntity),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
