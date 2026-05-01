import 'package:esketit_music_console/domain/album.dart';
import 'package:esketit_music_console/ui/album/album_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const recentAlbumIdsStorageKey = 'recent_album_picker_ids_v1';

  final albums = [
    _buildAlbum(id: 1, title: 'Alpha'),
    _buildAlbum(id: 2, title: 'Beta'),
    _buildAlbum(id: 3, title: 'Gamma'),
    _buildAlbum(id: 4, title: 'Delta'),
    _buildAlbum(id: 5, title: 'Epsilon'),
    _buildAlbum(id: 6, title: 'Zeta'),
  ];

  testWidgets('shows recent albums in stored most-recent-first order', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      recentAlbumIdsStorageKey: ['2', '1'],
    });

    await _pumpAlbumPickerLauncher(tester, albums: albums);

    await tester.tap(find.text('Open album picker'));
    await tester.pumpAndSettle();

    expect(find.text('Last selected albums'), findsOneWidget);

    final betaTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('album-picker-recent-2')),
    );
    final alphaTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('album-picker-recent-1')),
    );

    expect(betaTopLeft.dy, lessThan(alphaTopLeft.dy));
  });

  testWidgets('stores the last selected album first and keeps only five', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      recentAlbumIdsStorageKey: ['5', '4', '3', '2', '1'],
    });

    await _pumpAlbumPickerLauncher(tester, albums: albums);

    await tester.tap(find.text('Open album picker'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Zeta');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('album-picker-all-6')));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();

    expect(preferences.getStringList(recentAlbumIdsStorageKey), [
      '6',
      '5',
      '4',
      '3',
      '2',
    ]);
  });
}

Album _buildAlbum({required int id, required String title}) {
  return Album(
    id: id,
    title: title,
    coverImagePath: '',
    authors: const [],
    releaseDate: DateTime.utc(2024, 1, 1),
    isPublished: true,
    trackIds: const [],
    additionalInfo: const [],
  );
}

Future<void> _pumpAlbumPickerLauncher(
  WidgetTester tester, {
  required List<Album> albums,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showAlbumPickerDialog(
                context,
                availableAlbums: albums,
                onCreateNew: () async {},
              );
            },
            child: const Text('Open album picker'),
          ),
        ),
      ),
    ),
  );
}
