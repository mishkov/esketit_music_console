import 'package:equatable/equatable.dart';

enum AppUserRole { admin, listener }

class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final int id;
  final String email;
  final AppUserRole role;
  final DateTime createdAt;

  bool get isAdmin => role == AppUserRole.admin;

  @override
  List<Object?> get props => [id, email, role, createdAt];
}
