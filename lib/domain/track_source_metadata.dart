import 'dart:convert';

import 'package:equatable/equatable.dart';

class TrackSourceMetadata extends Equatable {
  const TrackSourceMetadata({
    required this.provider,
    required this.identity,
    this.kind,
    this.url,
  });

  final String provider;
  final Map<String, Object?> identity;
  final String? kind;
  final String? url;

  Map<String, Object?> get normalizedIdentity => normalizeJsonObject(identity);

  String get normalizedIdentityKey => canonicalizeJsonObject(identity);

  String? get normalizedUrl {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @override
  List<Object?> get props => [
    provider.trim(),
    kind?.trim(),
    normalizedUrl,
    normalizedIdentityKey,
  ];
}

Map<String, Object?> jsonObjectFromDynamic(Object? value) {
  if (value is! Map) {
    return const {};
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    result['${entry.key}'] = jsonValueFromDynamic(entry.value);
  }
  return result;
}

Object? jsonValueFromDynamic(Object? value) {
  if (value is Map) {
    return jsonObjectFromDynamic(value);
  }
  if (value is List) {
    return value.map(jsonValueFromDynamic).toList(growable: false);
  }
  if (value is num || value is bool || value == null || value is String) {
    return value;
  }
  return '$value';
}

Map<String, Object?> normalizeJsonObject(Map<String, Object?> value) {
  final sortedKeys = value.keys.toList()..sort();
  return {for (final key in sortedKeys) key: normalizeJsonValue(value[key])};
}

Object? normalizeJsonValue(Object? value) {
  if (value is String) {
    return value.trim();
  }
  if (value is Map<String, Object?>) {
    return normalizeJsonObject(value);
  }
  if (value is Map) {
    return normalizeJsonObject(jsonObjectFromDynamic(value));
  }
  if (value is List) {
    return value.map(normalizeJsonValue).toList(growable: false);
  }
  return value;
}

String canonicalizeJsonObject(Map<String, Object?> value) {
  return jsonEncode(normalizeJsonObject(value));
}

String formatJsonObject(Map<String, Object?> value) {
  return const JsonEncoder.withIndent('  ').convert(normalizeJsonObject(value));
}
