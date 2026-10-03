class McpSettings {
  const McpSettings({
    required this.actingUserId,
    required this.workflowGuidance,
    required this.uploadGuidance,
    required this.version,
    required this.credentialConfigured,
  });

  factory McpSettings.fromJson(Map<String, dynamic> json) => McpSettings(
    actingUserId: (json['actingUserId'] as num?)?.toInt(),
    workflowGuidance: json['workflowGuidance'] as String,
    uploadGuidance: json['uploadGuidance'] as String,
    version: (json['version'] as num).toInt(),
    credentialConfigured: json['credentialConfigured'] as bool,
  );

  final int? actingUserId;
  final String workflowGuidance;
  final String uploadGuidance;
  final int version;
  final bool credentialConfigured;
}
