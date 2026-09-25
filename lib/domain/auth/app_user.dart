import 'package:equatable/equatable.dart';
import 'package:esketit_music_console/domain/access_control.dart';

class AppUser extends Equatable {
  const AppUser({
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

  bool hasPermission(String code) =>
      permissions.any((permission) => permission.code == code);

  @override
  List<Object?> get props => [id, email, createdAt, roles, permissions];
}
