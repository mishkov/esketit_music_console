import 'package:esketit_music_console/domain/access_control.dart';

abstract class AccessControlRepository {
  Future<List<AccessControlUser>> getUsers();

  Future<List<AccessRole>> getRoles();

  Future<List<AccessPermission>> getPermissions();

  Future<List<AccessControlAuditEvent>> getAuditEvents({int limit = 100});

  Future<UserAccessProfile> replaceUserRoles(int userId, List<int> roleIds);

  Future<AccessRole> createRole({
    required String name,
    required String description,
  });

  Future<AccessRole> updateRole(
    int roleId, {
    required String name,
    required String description,
  });

  Future<void> deleteRole(int roleId);

  Future<AccessRole> replaceRolePermissions(
    int roleId,
    List<int> permissionIds,
  );
}
