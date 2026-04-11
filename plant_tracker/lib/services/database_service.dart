import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  static final _db = FirebaseDatabase.instance.ref();

  // WORKERS
  static Stream<DatabaseEvent> workersStream() =>
      _db.child('workers').onValue;

  static Future<Map<String, dynamic>?> getWorker(String workerId) async {
    final snap = await _db.child('workers/$workerId').get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  // ATTENDANCE
  static Stream<DatabaseEvent> attendanceStream() =>
      _db.child('attendance').onValue;

  static Future<void> writeAttendance(String id, Map<String, dynamic> data) =>
      _db.child('attendance/$id').set(data);

  static Future<void> updateAttendance(String id, Map<String, dynamic> data) =>
      _db.child('attendance/$id').update(data);

  // INVENTORY
  static Stream<DatabaseEvent> inventoryStream() =>
      _db.child('inventory').onValue;

  static Future<void> addInventoryItem(String id, Map<String, dynamic> data) =>
      _db.child('inventory/$id').set(data);

  // ORDERS
  static Stream<DatabaseEvent> ordersStream() =>
      _db.child('orders').onValue;

  static Future<void> updateOrder(String id, Map<String, dynamic> data) =>
      _db.child('orders/$id').update(data);

  // BUDGET REQUESTS
  static Stream<DatabaseEvent> budgetRequestsStream() =>
      _db.child('budgetRequests').onValue;

  static Future<void> addBudgetRequest(String id, Map<String, dynamic> data) =>
      _db.child('budgetRequests/$id').set(data);

  static Future<void> updateBudgetRequest(String id, Map<String, dynamic> data) =>
      _db.child('budgetRequests/$id').update(data);

  // NOTIFICATIONS
  static Stream<DatabaseEvent> notificationsStream() =>
      _db.child('notifications').onValue;

  static Future<void> addNotification(String id, Map<String, dynamic> data) =>
      _db.child('notifications/$id').set(data);

  static Future<void> markNotificationRead(String id) =>
      _db.child('notifications/$id').update({'read': true});

  // SALARY
  static Stream<DatabaseEvent> salaryStream(String workerId) =>
      _db.child('salary').orderByChild('workerId').equalTo(workerId).onValue;

  // PAYSLIPS
  static Stream<DatabaseEvent> payslipsStream(String workerId) =>
      _db.child('payslips').orderByChild('workerId').equalTo(workerId).onValue;

  // DASHBOARD
  static Future<Map<String, dynamic>?> getDashboard() async {
    final snap = await _db.child('dashboard').get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  // RULES
  static Future<Map<String, dynamic>?> getRules() async {
    final snap = await _db.child('rules').get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }
}
