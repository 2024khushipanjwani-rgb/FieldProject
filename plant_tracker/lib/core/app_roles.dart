/// Firestore `users.role` values used by the app.
abstract final class AppRoles {
  static const worker = 'worker';
  static const manager = 'manager';
  static const owner = 'owner';
  /// Legacy accounts created before manager/owner split.
  static const legacyAdmin = 'admin';
}

bool isWorkerRole(String? r) => r == AppRoles.worker;

bool isManagerRole(String? r) => r == AppRoles.manager;

bool isOwnerRole(String? r) =>
    r == AppRoles.owner || r == AppRoles.legacyAdmin;

bool isStaffRole(String? r) => isManagerRole(r) || isOwnerRole(r);
