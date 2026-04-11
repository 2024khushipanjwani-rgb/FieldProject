class RBAC {
  static const Map<String, List<String>> _permissions = {
    'admin': ['all'],
    'manager': [
      'mark_attendance', 'view_any_report',
      'send_budget_request', 'manage_inventory',
      'update_order_progress', 'generate_reports',
    ],
    'worker': [
      'view_own_profile', 'view_own_salary',
      'view_own_attendance', 'view_own_report', 'view_payslip',
    ],
  };

  static bool can(String role, String action) {
    final perms = _permissions[role] ?? [];
    return perms.contains('all') || perms.contains(action);
  }

  static bool isOwner(String role) => role == 'admin';
  static bool isManager(String role) => role == 'manager';
  static bool isWorker(String role) => role == 'worker';
}
