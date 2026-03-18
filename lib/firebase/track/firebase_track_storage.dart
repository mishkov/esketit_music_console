import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:esketit_music_console/domain/author.dart';
import 'package:esketit_music_console/unassigned_layer/cross_file.dart';
import 'package:esketit_music_console/firebase/track/storage_file.dart';
import 'package:esketit_music_console/domain/track.dart';
import 'package:esketit_music_console/domain/track_info/text_track_info.dart';
import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/use_case/track/storage/storage_tracks_list.dart';
import 'package:esketit_music_console/use_case/track/storage/tracks_storage.dart';

class FirebaseTrackStorage implements TracksStorage {
  static const _tracksCollection = 'tracks';

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirebaseTrackStorage({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<StorageTracksList> getTracks() async {
    final snapshot = await _firestore.collection(_tracksCollection).get();

    final tracks = snapshot.docs.map((doc) {
      final data = doc.data();
      final fileData = (data['file'] as Map<String, dynamic>?) ?? {};

      return Track(
        name: (data['name'] as String?) ?? '',
        authors: _deserializeAuthors(data['authors']),
        addionalInfo: _deserializeTrackInfo(data['additionalInfo']),
        file: StorageFile(
          name: (fileData['name'] as String?) ?? '',
          storagePath: (fileData['storagePath'] as String?) ?? '',
          downloadUrl: (fileData['downloadUrl'] as String?) ?? '',
        ),
      );
    }).toList();

    return StorageTracksList(tracks: tracks);
  }

  @override
  Future<void> putTrack(Track track) async {
    final trackDocRef = _firestore.collection(_tracksCollection).doc();
    final uploadedFile = await _uploadFile(track.file, trackDocRef.id);

    await trackDocRef.set({
      'name': track.name,
      'authors': track.authors.map((author) => author.currentName).toList(),
      'additionalInfo': _serializeTrackInfo(track.addionalInfo),
      'file': {
        'name': uploadedFile.name,
        'storagePath': uploadedFile.storagePath,
        'downloadUrl': uploadedFile.downloadUrl,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<StorageFile> _uploadFile(Object file, String trackId) async {
    if (file is StorageFile) {
      return file;
    }
    if (file is! CrossFile) {
      throw UnsupportedError(
        'Unsupported file type: ${file.runtimeType}. '
        'Use IoFile(XFile) for uploads.',
      );
    }

    final fileName = file.name;
    final safeFileName = fileName.replaceAll('/', '_');
    final storagePath = 'tracks/$trackId/$safeFileName';
    final ref = _storage.ref(storagePath);

    await ref.putData(await file.readAsBytes());
    final downloadUrl = await ref.getDownloadURL();

    return StorageFile(
      name: fileName,
      storagePath: storagePath,
      downloadUrl: downloadUrl,
    );
  }

  List<Author> _deserializeAuthors(Object? rawAuthors) {
    final names = (rawAuthors as List<dynamic>? ?? []).whereType<String>();
    return names.map((name) => Author(currentName: name)).toList();
  }

  List<Map<String, dynamic>> _serializeTrackInfo(List<TrackInfo> info) {
    return info.map((entry) {
      if (entry is TextTrackInfo) {
        return <String, dynamic>{
          'type': 'text',
          'title': entry.title,
          'text': entry.text,
        };
      }

      throw UnsupportedError(
        'Unsupported TrackInfo type: ${entry.runtimeType}.',
      );
    }).toList();
  }

  List<TrackInfo> _deserializeTrackInfo(Object? rawTrackInfo) {
    final entries = (rawTrackInfo as List<dynamic>? ?? []).whereType<Object>();
    return entries.whereType<Map<String, dynamic>>().map((entry) {
      switch (entry['type']) {
        case 'text':
          return TextTrackInfo(
            title: (entry['title'] as String?) ?? '',
            text: (entry['text'] as String?) ?? '',
          );
        default:
          throw UnsupportedError(
            'Unsupported TrackInfo type value: ${entry['type']}.',
          );
      }
    }).toList();
  }
}
