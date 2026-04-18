import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CalendarEventsScreen extends StatefulWidget {
  const CalendarEventsScreen({Key? key}) : super(key: key);

  @override
  State<CalendarEventsScreen> createState() => _CalendarEventsScreenState();
}

class _CalendarEventsScreenState extends State<CalendarEventsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Map of normalised UTC dates → list of events
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalizeDate(DateTime.now());
    _fetchCalendarEvents();
  }

  // ── 1. Normalise to midnight UTC so map lookups always match ──────────────
  DateTime _normalizeDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  // ── 2. Fetch from Firestore ───────────────────────────────────────────────
  Future<void> _fetchCalendarEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final Map<DateTime, List<Map<String, dynamic>>> newEvents = {};

    try {
      // --- Orders ---
      final ordersSnap =
          await FirebaseFirestore.instance.collection('orders').get();

      for (final doc in ordersSnap.docs) {
        final data = doc.data();
        final ts = data['createdAt'];
        if (ts == null) continue;

        final date = _normalizeDate((ts as Timestamp).toDate());

        // Build a summary string from the items list
        final items = (data['items'] as List<dynamic>? ?? []);
        final itemSummary = items.map((i) {
          final name = i['name'] ?? 'item';
          final qty = i['quantity'] ?? 0;
          return '$name ×$qty';
        }).join(', ');

        newEvents.putIfAbsent(date, () => []).add({
          'type': 'order',
          'customerName': data['customerName'] ?? 'Unknown Customer',
          'orderId': data['orderId'] ?? doc.id.substring(0, 8).toUpperCase(),
          'status': data['status'] ?? 'pending',
          'itemSummary': itemSummary.isNotEmpty ? itemSummary : '—',
          'createdAt': ts,
        });
      }

      // --- Funding Requests ---
      final fundingSnap = await FirebaseFirestore.instance
          .collection('funding_requests')
          .get();

      for (final doc in fundingSnap.docs) {
        final data = doc.data();
        final ts = data['createdAt'];
        if (ts == null) continue;

        final date = _normalizeDate((ts as Timestamp).toDate());
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final status = (data['status'] as String?) ?? 'pending';

        newEvents.putIfAbsent(date, () => []).add({
          'type': 'funding',
          'managerName': data['managerName'] ?? 'Manager',
          'amount': amount,
          'reason': data['reason'] ?? 'No reason provided',
          'status': status,
          'createdAt': ts,
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load data: $e');
      return;
    }

    if (mounted) {
      setState(() {
        _events
          ..clear()
          ..addAll(newEvents);
        _isLoading = false;
      });
    }
  }

  // ── 3. Event loader for table_calendar ───────────────────────────────────
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) =>
      _events[_normalizeDate(day)] ?? [];

  // ── 4. UI ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Operations Calendar'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchCalendarEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchCalendarEvents,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ── Calendar ──────────────────────────────────────────
                    Container(
                      color: Colors.white,
                      child: TableCalendar<Map<String, dynamic>>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.now(), // Fixed to dynamically block future selection
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        eventLoader: _getEventsForDay,
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        calendarFormat: CalendarFormat.month,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          // Event marker dots
                          markerDecoration: const BoxDecoration(
                            color: Color(0xFF1B5E20),
                            shape: BoxShape.circle,
                          ),
                          markersMaxCount: 3,
                          // Selected day
                          selectedDecoration: const BoxDecoration(
                            color: Color(0xFF1B5E20),
                            shape: BoxShape.circle,
                          ),
                          // Today (when not selected)
                          todayDecoration: BoxDecoration(
                            color: const Color(0xFF1B5E20).withOpacity(0.35),
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // ── Legend ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _legendDot(const Color(0xFF388E3C), 'Order created'),
                          const SizedBox(width: 16),
                          _legendDot(Colors.orange, 'Money request'),
                        ],
                      ),
                    ),

                    // ── Selected-date divider ─────────────────────────────
                    if (_selectedDay != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        color: const Color(0xFFE8F5E9),
                        child: Text(
                          DateFormat('EEEE, d MMMM yyyy').format(_selectedDay!),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),

                    // ── Event list for selected day ────────────────────────
                    Expanded(child: _buildEventList()),
                  ],
                ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);

    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No orders or requests on this date.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return event['type'] == 'order'
            ? _orderCard(event)
            : _fundingCard(event);
      },
    );
  }

  // ── Order card ────────────────────────────────────────────────────────────
  Widget _orderCard(Map<String, dynamic> e) {
    final ts = e['createdAt'] as Timestamp?;
    final timeStr =
        ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : '';
    final status = e['status'] as String;

    Color statusColor = Colors.orange;
    if (status == 'approved') statusColor = Colors.blue;
    if (status == 'completed') statusColor = Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF388E3C).withOpacity(0.12),
          child: const Icon(Icons.shopping_cart_outlined,
              color: Color(0xFF388E3C)),
        ),
        title: Text(
          e['customerName'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${e['orderId']}  •  ${e['itemSummary']}\n$timeStr',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11),
          ),
        ),
      ),
    );
  }

  // ── Funding-request card ──────────────────────────────────────────────────
  Widget _fundingCard(Map<String, dynamic> e) {
    final ts = e['createdAt'] as Timestamp?;
    final timeStr =
        ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : '';
    final amount = e['amount'] as double;
    final status = e['status'] as String;

    Color statusColor = Colors.orange;
    if (status == 'approved') statusColor = Colors.green;
    if (status == 'denied') statusColor = Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.12),
          child:
              const Icon(Icons.request_quote_outlined, color: Colors.orange),
        ),
        title: Text(
          '₹${amount.toStringAsFixed(0)}  —  ${e['managerName']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${e['reason']}\n$timeStr',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11),
          ),
        ),
      ),
    );
  }
}
