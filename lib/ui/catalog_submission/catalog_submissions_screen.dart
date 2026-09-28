import 'package:esketit_music_console/domain/auth/app_user.dart';
import 'package:esketit_music_console/domain/catalog_submission.dart';
import 'package:esketit_music_console/ui/catalog_submission/my_submissions_screen.dart';
import 'package:esketit_music_console/ui/catalog_submission/review_queue_screen.dart';
import 'package:esketit_music_console/ui/catalog_submission/submit_music_screen.dart';
import 'package:esketit_music_console/use_case/auth/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CatalogSubmissionsScreen extends StatefulWidget {
  const CatalogSubmissionsScreen({super.key});

  @override
  State<CatalogSubmissionsScreen> createState() =>
      _CatalogSubmissionsScreenState();
}

class _CatalogSubmissionsScreenState extends State<CatalogSubmissionsScreen> {
  String? _selectedKey;
  int _mySubmissionsVersion = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.session?.user);
    if (user == null) return const SizedBox.shrink();
    final pages = _pagesFor(user);
    if (pages.isEmpty) {
      return const Center(
        child: Text('You do not have access to catalog submissions.'),
      );
    }

    final selectedKey = pages.any((page) => page.key == _selectedKey)
        ? _selectedKey!
        : pages.first.key;
    final selected = pages.firstWhere((page) => page.key == selectedKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catalog submissions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: [
                    for (final page in pages)
                      ButtonSegment<String>(
                        value: page.key,
                        icon: Icon(page.icon),
                        label: Text(page.label),
                      ),
                  ],
                  selected: {selectedKey},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedKey = selection.single);
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (selected.key) {
            'mine' => MySubmissionsScreen(
              key: ValueKey('my-submissions-$_mySubmissionsVersion'),
            ),
            'submit' => SubmitMusicScreen(
              onSubmissionCreated: () {
                setState(() {
                  _mySubmissionsVersion += 1;
                  _selectedKey = 'mine';
                });
              },
            ),
            'review' => ReviewQueueScreen(reviewerId: user.id),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  List<_CatalogPage> _pagesFor(AppUser user) {
    final pages = <_CatalogPage>[];
    if (user.hasPermission(catalogSubmissionsReadOwnPermission)) {
      pages.add(
        const _CatalogPage(
          key: 'mine',
          label: 'My submissions',
          icon: Icons.history,
        ),
      );
    }
    if (user.hasPermission(authorsSubmitPermission) ||
        user.hasPermission(albumsSubmitPermission) ||
        user.hasPermission(tracksSubmitPermission)) {
      pages.add(
        const _CatalogPage(
          key: 'submit',
          label: 'Submit music',
          icon: Icons.upload,
        ),
      );
    }
    if (user.hasPermission(catalogSubmissionsReviewPermission)) {
      pages.add(
        const _CatalogPage(
          key: 'review',
          label: 'Review queue',
          icon: Icons.fact_check_outlined,
        ),
      );
    }
    return pages;
  }
}

class _CatalogPage {
  const _CatalogPage({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}
