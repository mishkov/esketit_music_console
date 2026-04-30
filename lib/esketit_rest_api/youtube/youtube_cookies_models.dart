class YouTubeCookiesStatus {
  const YouTubeCookiesStatus({
    required this.configured,
    required this.filePresent,
    this.lastModified,
  });

  final bool configured;
  final bool filePresent;
  final DateTime? lastModified;

  factory YouTubeCookiesStatus.fromJson(Map<String, dynamic> json) {
    return YouTubeCookiesStatus(
      configured: json['configured'] as bool? ?? false,
      filePresent: json['filePresent'] as bool? ?? false,
      lastModified: DateTime.tryParse((json['lastModified'] as String?) ?? ''),
    );
  }
}
