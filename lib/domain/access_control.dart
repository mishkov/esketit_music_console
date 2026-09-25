import 'package:equatable/equatable.dart';

class AccessPermission extends Equatable {
  const AccessPermission({
    required this.id,
    required this.code,
    required this.description,
    required this.createdAt,
  });

  final int id;
  final String code;
  final String description;
  final DateTime createdAt;

  factory AccessPermission.fromJson(Map<String, dynamic> json) {
    return AccessPermission(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, code, description, createdAt];
}

class AccessRole extends Equatable {
  const AccessRole({
    required this.id,
    required this.name,
    required this.description,
    required this.system,
    required this.createdAt,
    required this.permissions,
  });

  final int id;
  final String name;
  final String description;
  final bool system;
  final DateTime createdAt;
  final List<AccessPermission> permissions;

  factory AccessRole.fromJson(Map<String, dynamic> json) {
    return AccessRole(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      system: json['system'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      permissions: _jsonList(
        json['permissions'],
      ).map(AccessPermission.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'system': system,
    'createdAt': createdAt.toIso8601String(),
    'permissions': permissions
        .map((permission) => permission.toJson())
        .toList(),
  };

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    system,
    createdAt,
    permissions,
  ];
}

class AccessControlUser extends Equatable {
  const AccessControlUser({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.roles,
    required this.permissions,
  });

  final int id;
  final String email;
  final DateTime createdAt;
  final List<AccessRole> roles;
  final List<AccessPermission> permissions;

  factory AccessControlUser.fromJson(Map<String, dynamic> json) {
    return AccessControlUser(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      roles: _jsonList(
        json['roles'],
      ).map(AccessRole.fromJson).toList(growable: false),
      permissions: _jsonList(
        json['permissions'],
      ).map(AccessPermission.fromJson).toList(growable: false),
    );
  }

  @override
  List<Object?> get props => [id, email, createdAt, roles, permissions];
}

class UserAccessProfile extends Equatable {
  const UserAccessProfile({required this.roles, required this.permissions});

  final List<AccessRole> roles;
  final List<AccessPermission> permissions;

  factory UserAccessProfile.fromJson(Map<String, dynamic> json) {
    return UserAccessProfile(
      roles: _jsonList(
        json['roles'],
      ).map(AccessRole.fromJson).toList(growable: false),
      permissions: _jsonList(
        json['permissions'],
      ).map(AccessPermission.fromJson).toList(growable: false),
    );
  }

  @override
  List<Object?> get props => [roles, permissions];
}

class AccessControlAuditEvent extends Equatable {
  const AccessControlAuditEvent({
    required this.id,
    required this.action,
    required this.details,
    required this.createdAt,
    this.actorUserId,
    this.targetUserId,
    this.targetRoleId,
    this.targetPermissionId,
  });

  final int id;
  final int? actorUserId;
  final String action;
  final int? targetUserId;
  final int? targetRoleId;
  final int? targetPermissionId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  factory AccessControlAuditEvent.fromJson(Map<String, dynamic> json) {
    return AccessControlAuditEvent(
      id: (json['id'] as num).toInt(),
      actorUserId: (json['actorUserId'] as num?)?.toInt(),
      action: json['action'] as String,
      targetUserId: (json['targetUserId'] as num?)?.toInt(),
      targetRoleId: (json['targetRoleId'] as num?)?.toInt(),
      targetPermissionId: (json['targetPermissionId'] as num?)?.toInt(),
      details: Map<String, dynamic>.from(
        json['details'] as Map? ?? const <String, dynamic>{},
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    actorUserId,
    action,
    targetUserId,
    targetRoleId,
    targetPermissionId,
    details,
    createdAt,
  ];
}

List<Map<String, dynamic>> _jsonList(Object? value) {
  if (value is! List) {
    throw const FormatException('Expected a JSON array');
  }
  return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
}
