import 'dart:typed_data';

import 'package:esketit_music_console/domain/track_info/track_info.dart';
import 'package:esketit_music_console/esketit_rest_api/telegram/telegram_import_models.dart';

abstract class TelegramImportRepository {
  Future<TelegramStatus> getStatus();

  Future<void> requestAuthCode({required String phoneNumber});

  Future<TelegramStatus> confirmAuthCode({
    required String phoneNumber,
    required String code,
  });

  Future<TelegramStatus> confirmPassword({required String password});

  Future<TelegramImportSession?> getCurrentSession();

  Future<TelegramImportSession> startSession({
    required String channelUsername,
    int? startMessageId,
    bool replaceExisting = false,
  });

  Future<TelegramImportSession> skipCurrent();

  Future<TelegramImportSession> saveCurrent({
    required String name,
    required List<int> authorIds,
    required int albumId,
    required int albumOrder,
    required List<TrackInfo> additionalInfo,
  });

  Future<void> cancelCurrentSession();

  Future<DownloadedBinaryFile> downloadCurrentAudio();

  Future<DownloadedBinaryFile> downloadSkippedReport();
}

class DownloadedBinaryFile {
  const DownloadedBinaryFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}
