import 'dart:convert';
import 'dart:typed_data';

class Mp3Metadata {
  const Mp3Metadata({this.title, this.album, this.authors = const []});

  final String? title;
  final String? album;
  final List<String> authors;

  bool get hasData =>
      (title != null && title!.trim().isNotEmpty) ||
      (album != null && album!.trim().isNotEmpty) ||
      authors.isNotEmpty;
}

Mp3Metadata parseMp3Metadata(Uint8List bytes) {
  final v2 = _parseId3v2(bytes);
  if (v2.hasData) {
    return v2;
  }
  return _parseId3v1(bytes);
}

Mp3Metadata _parseId3v2(Uint8List bytes) {
  if (bytes.length < 10 || _ascii(bytes, 0, 3) != 'ID3') {
    return const Mp3Metadata();
  }

  final majorVersion = bytes[3];
  if (majorVersion < 2 || majorVersion > 4) {
    return const Mp3Metadata();
  }

  final tagSize = _syncSafeInt(bytes, 6);
  final tagEnd = 10 + tagSize;
  var offset = 10;

  if (bytes[5] & 0x40 != 0 && bytes.length >= 14) {
    final extendedHeaderSize = majorVersion == 3
        ? _bigEndianInt(bytes, 10, 4)
        : _syncSafeInt(bytes, 10);
    offset += extendedHeaderSize;
  }

  String? title;
  String? album;
  List<String> authors = const [];

  while (offset < tagEnd && offset < bytes.length) {
    if (majorVersion == 2) {
      if (offset + 6 > bytes.length) {
        break;
      }
      final frameId = _ascii(bytes, offset, 3);
      final frameSize = _bigEndianInt(bytes, offset + 3, 3);
      offset += 6;
      if (frameId.trim().isEmpty ||
          frameSize <= 0 ||
          offset + frameSize > bytes.length) {
        break;
      }
      final frameData = bytes.sublist(offset, offset + frameSize);
      if (frameId == 'TT2') {
        title = _decodeTextFrame(frameData);
      } else if (frameId == 'TAL') {
        album = _decodeTextFrame(frameData);
      } else if (frameId == 'TP1') {
        authors = _splitAuthors(_decodeTextFrame(frameData));
      }
      offset += frameSize;
      continue;
    }

    if (offset + 10 > bytes.length) {
      break;
    }
    final frameId = _ascii(bytes, offset, 4);
    final frameSize = majorVersion == 4
        ? _syncSafeInt(bytes, offset + 4)
        : _bigEndianInt(bytes, offset + 4, 4);
    offset += 10;
    if (frameId.trim().isEmpty ||
        frameSize <= 0 ||
        offset + frameSize > bytes.length) {
      break;
    }
    final frameData = bytes.sublist(offset, offset + frameSize);
    if (frameId == 'TIT2') {
      title = _decodeTextFrame(frameData);
    } else if (frameId == 'TALB') {
      album = _decodeTextFrame(frameData);
    } else if (frameId == 'TPE1') {
      authors = _splitAuthors(_decodeTextFrame(frameData));
    }
    offset += frameSize;
  }

  return Mp3Metadata(
    title: _normalize(title),
    album: _normalize(album),
    authors: authors,
  );
}

Mp3Metadata _parseId3v1(Uint8List bytes) {
  if (bytes.length < 128 || _ascii(bytes, bytes.length - 128, 3) != 'TAG') {
    return const Mp3Metadata();
  }

  final title = _latin1(bytes.sublist(bytes.length - 125, bytes.length - 95));
  final artist = _latin1(bytes.sublist(bytes.length - 95, bytes.length - 65));
  final album = _latin1(bytes.sublist(bytes.length - 65, bytes.length - 35));

  return Mp3Metadata(
    title: _normalize(title),
    album: _normalize(album),
    authors: _splitAuthors(artist),
  );
}

String _ascii(Uint8List bytes, int offset, int length) {
  return ascii.decode(
    bytes.sublist(offset, offset + length),
    allowInvalid: true,
  );
}

int _syncSafeInt(Uint8List bytes, int offset) {
  return (bytes[offset] << 21) |
      (bytes[offset + 1] << 14) |
      (bytes[offset + 2] << 7) |
      bytes[offset + 3];
}

int _bigEndianInt(Uint8List bytes, int offset, int length) {
  var value = 0;
  for (var i = 0; i < length; i++) {
    value = (value << 8) | bytes[offset + i];
  }
  return value;
}

String? _decodeTextFrame(Uint8List frameData) {
  if (frameData.isEmpty) {
    return null;
  }

  final encoding = frameData.first;
  final content = frameData.sublist(1);
  switch (encoding) {
    case 0:
      return _normalize(latin1.decode(content, allowInvalid: true));
    case 1:
      return _normalize(_decodeUtf16(content, bigEndian: false));
    case 2:
      return _normalize(_decodeUtf16(content, bigEndian: true));
    case 3:
      return _normalize(utf8.decode(content, allowMalformed: true));
    default:
      return null;
  }
}

String _decodeUtf16(Uint8List bytes, {required bool bigEndian}) {
  if (bytes.isEmpty) {
    return '';
  }

  var offset = 0;
  Endian endian = bigEndian ? Endian.big : Endian.little;

  if (bytes.length >= 2) {
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      endian = Endian.big;
      offset = 2;
    } else if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      endian = Endian.little;
      offset = 2;
    }
  }

  final codeUnits = <int>[];
  for (var i = offset; i + 1 < bytes.length; i += 2) {
    final value = endian == Endian.big
        ? (bytes[i] << 8) | bytes[i + 1]
        : bytes[i] | (bytes[i + 1] << 8);
    if (value == 0) {
      continue;
    }
    codeUnits.add(value);
  }
  return String.fromCharCodes(codeUnits);
}

String _latin1(Uint8List bytes) {
  return latin1.decode(bytes, allowInvalid: true);
}

String? _normalize(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.replaceAll('\u0000', '').trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _splitAuthors(String? raw) {
  final normalized = _normalize(raw);
  if (normalized == null) {
    return const [];
  }

  return normalized
      .split(
        RegExp(r'\s*(?:,|;|/| feat\. | ft\. | & )\s*', caseSensitive: false),
      )
      .map((author) => author.trim())
      .where((author) => author.isNotEmpty)
      .toList();
}
