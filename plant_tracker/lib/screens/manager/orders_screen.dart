import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String id;
  final String customerName;
  final String orderRef;
  final String status;
  final int totalUnits;
  final Color statusColor;

  OrderItem({required this.id, required this.customerName, required this.orderRef, required this.status, required this.totalUnits, required this.statusColor});

  factory OrderItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final statusStr = data['status'] ?? 'pending';
    
    Color c = Colors.orange;
    if (statusStr == 'approved') c = Colors.blue;
    if (statusStr == 'completed') c = Colors.green;
    
    // Sum qty:
    final items = data['items'] as List<dynamic>? ?? [];
    int qty = 0;
    for (var i in items) {
      qty += (i['quantity'] as num?)?.toInt() ?? 0;
    }

    return OrderItem(
      id: doc.id,
      customerName: data['customerName'] ?? 'Unknown Customer',
      orderRef: data['orderId'] ?? doc.id.substring(0, 8).toUpperCase(),
      status: statusStr,
      totalUnits: qty,
      statusColor: c,
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _formKey = GlobalKey<FormState>();
  final customerController = TextEditingController();
  
  static const List<String> _allowedFlavours = [
    'jeera', 'mango', 'red', 'orange', 'kacchi kiri', 'lima', 
    'blueberry', 'pineapple', 'lassi', 'pineapple lassi', 'strawberry lassi'
  ];
  String? _selectedFlavour;
  
  final qtyController = TextEditingController();

  Future<void> _addSimpleOrder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cust = customerController.text.trim();
    final item = _selectedFlavour;
    final qty = int.tryParse(qtyController.text) ?? 0;

    if (cust.isEmpty || item == null) return;
    if (qty < 100 || qty > 1000) return;

    final orderId = "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    await FirebaseFirestore.instance.collection('orders').add({
      'customerName': cust,
      'orderId': orderId,
      'items': [
        {'name': item, 'quantity': qty, 'price': 0.0}
      ],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    customerController.clear();
    _selectedFlavour = null;
    qtyController.clear();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showAddOrderSheet() {
    _selectedFlavour = null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Create Simple Order", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: customerController, 
                    decoration: const InputDecoration(labelText: "Customer Name", border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedFlavour,
                  decoration: const InputDecoration(labelText: "Product / Flavour", border: OutlineInputBorder()),
                  items: _allowedFlavours.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setModalState(() {
                      _selectedFlavour = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'Please select a flavour' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: qtyController, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: "Quantity", border: OutlineInputBorder()),
                  validator: (value) {
                    final qty = int.tryParse(value ?? '') ?? 0;
                    if (qty < 100) return 'Minimum 100 required';
                    if (qty > 1000) return 'Maximum 1000 allowed';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _addSimpleOrder,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: const Text("Place Order"),
                ),
                const SizedBox(height: 20),
              ],
            ),
           );
          }
        ),
      ),
    );
  }

  Future<void> _updateStatus(String docId, String newStatus, OrderItem order) async {
    try {
      if (newStatus == 'completed' && order.status != 'completed') {
        // Find the documents in inventory to deduct!
        // We will fetch the order items
        final snap = await FirebaseFirestore.instance.collection('orders').doc(docId).get();
        final items = snap.data()?['items'] as List<dynamic>? ?? [];
        
        for (var i in items) {
          final name = i['name'] as String?;
          final qty = (i['quantity'] as num?)?.toInt() ?? 0;
          if (name != null) {
            // Find inventory item with this name
            final invSnap = await FirebaseFirestore.instance.collection('inventory').where('name', isEqualTo: name).limit(1).get();
            if (invSnap.docs.isNotEmpty) {
              final invDoc = invSnap.docs.first;
              final currentQty = (invDoc.data()['quantity'] as num?)?.toInt() ?? 0;
              await invDoc.reference.update({'quantity': currentQty - qty < 0 ? 0 : currentQty - qty});
            }
          }
        }
      }
      
      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to update status $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOrderSheet,
        icon: const Icon(Icons.add),
        label: const Text("New Order"),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Could not load orders."));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No active orders."));
                
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final order = OrderItem.fromDoc(docs[index]);
                    return _figmaOrderCard(order);
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)]),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Order Tracking",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text("Shipments & Deliveries",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _figmaOrderCard(OrderItem order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Text(order.orderRef,
                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (val) => _updateStatus(order.id, val, order),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: order.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(order.status.toUpperCase(),
                          style: TextStyle(color: order.statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: order.statusColor),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'pending', child: Text("Set Pending")),
                  const PopupMenuItem(value: 'approved', child: Text("Set Approved")),
                  const PopupMenuItem(value: 'completed', child: Text("Set Completed (Deducts Stock)")),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text("${order.totalUnits} Units Total", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              InkWell(
                onTap: () {
                  FirebaseFirestore.instance.collection('orders').doc(order.id).delete();
                },
                child: const Text("Delete Order",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          )
        ],
      ),
    );
  }
}