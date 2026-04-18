import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StockItem {
  final String id;
  final String name;
  final String supplier;
  final int available;
  final int minStock;
  final String unit;
  final double progress;
  final bool isLow;

  StockItem({
    required this.id,
    required this.name,
    required this.supplier,
    required this.available,
    required this.minStock,
    required this.unit,
    required this.progress,
    required this.isLow,
  });

  factory StockItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final avail = (data['quantity'] as num?)?.toInt() ?? 0;
    final min = (data['minStock'] as num?)?.toInt() ?? 0;
    
    // Calculate progress (capped at 1.0)
    double prog = avail / (min * 2 > 0 ? min * 2 : 1);
    if (prog > 1.0) prog = 1.0;
    
    return StockItem(
      id: doc.id,
      name: data['name'] ?? 'Unknown',
      supplier: data['category'] ?? 'General Supplier',
      available: avail,
      minStock: min,
      unit: "units", // Could be dynamic if added to schema
      progress: prog,
      isLow: min > 0 && avail < min,
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool showAll = true;
  String _searchQuery = '';

  static const List<String> _allowedMaterials = [
    'preservatives', 'essence', 'citric acid', 'plastic wrapper', 'sugar'
  ];
  String? _selectedMaterial;
  final _formKey = GlobalKey<FormState>();

  final supplierController = TextEditingController(); // Maps to category
  final availController = TextEditingController();
  final minController = TextEditingController();
  final priceController = TextEditingController();
  final searchController = TextEditingController();

  @override
  void dispose() {
    supplierController.dispose();
    availController.dispose();
    minController.dispose();
    priceController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _saveNewItem() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nameStr = _selectedMaterial;
    if (nameStr == null || nameStr.isEmpty) return;

    final avail = int.tryParse(availController.text) ?? 0;
    if (avail > 1000) return;
    final minVal = int.tryParse(minController.text) ?? 0;
    final priceStr = double.tryParse(priceController.text) ?? 0.0;

    try {
      await FirebaseFirestore.instance.collection('inventory').add({
        'name': nameStr,
        'category': supplierController.text.trim(),
        'quantity': avail,
        'price': priceStr,
        'minStock': minVal,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      _selectedMaterial = null;
      supplierController.clear();
      availController.clear();
      minController.clear();
      priceController.clear();
    }
  }
  
  Future<void> _updateStock(String docId, int oldVal, int change) async {
    try {
      final newVal = oldVal + change;
      if (newVal > 1000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum quantity limit is 1000!'))
          );
        }
        return;
      }
      await FirebaseFirestore.instance.collection('inventory').doc(docId).update({
        'quantity': newVal < 0 ? 0 : newVal,
      });
    } catch (e) {
      debugPrint("Failed to update stock: $e");
    }
  }
  
  Future<void> _deleteItem(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('inventory').doc(docId).delete();
    } catch (e) {
      debugPrint("Failed to delete stock: $e");
    }
  }

  void _showAddItemSheet() {
    _selectedMaterial = null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20, left: 20, right: 20,
        ),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Add New Material", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedMaterial,
                    decoration: const InputDecoration(labelText: "Material Name", border: OutlineInputBorder()),
                    items: _allowedMaterials.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setModalState(() {
                        _selectedMaterial = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'Please select a material' : null,
                  ),
                  const SizedBox(height: 15),
                  TextField(controller: supplierController, decoration: const InputDecoration(labelText: "Supplier / Category", border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: availController, 
                          keyboardType: TextInputType.number, 
                          decoration: const InputDecoration(labelText: "Initial Qty", border: OutlineInputBorder()),
                          validator: (value) {
                            final qty = int.tryParse(value ?? '') ?? 0;
                            if (qty > 1000) return 'Max 1000 allowed';
                            return null;
                          },
                        )
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: minController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Min Alert", border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Cost/Price (Unit)", border: OutlineInputBorder())),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
                      onPressed: _saveNewItem,
                      child: const Text("Save Item"),
                    ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('inventory').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data?.docs ?? [];
          final allItems = docs.map((d) => StockItem.fromDoc(d)).toList();
          
          List<StockItem> filteredItems = allItems;
          if (_searchQuery.trim().isNotEmpty) {
            final query = _searchQuery.trim().toLowerCase();
            filteredItems = filteredItems.where((i) => i.name.toLowerCase().contains(query)).toList();
          }

          final lowItems = filteredItems.where((i) => i.isLow).toList();
          final displayedItems = showAll ? filteredItems : lowItems;

          return Column(
            children: [
              _buildHeader(filteredItems.length, lowItems.length),
              _buildSearchAndFilters(filteredItems.length, lowItems.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: displayedItems.length,
                  itemBuilder: (context, index) {
                    final item = displayedItems[index];
                    return _figmaStockCard(item);
                  },
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildHeader(int total, int lowCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFEF5350)]),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Inventory", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("$total items • $lowCount low", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddItemSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2), foregroundColor: Colors.white, elevation: 0),
              )
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Text("$lowCount items below minimum stock level", style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(int total, int low) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: "Search materials...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _filterBtn("All Items ($total)", showAll, () => setState(() => showAll = true))),
              const SizedBox(width: 10),
              Expanded(child: _filterBtn("⚠️ Low Stock ($low)", !showAll, () => setState(() => showAll = false))),
            ],
          )
        ],
      ),
    );
  }

  Widget _filterBtn(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD32F2F) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [if (!isActive) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _figmaStockCard(StockItem item) {
    final isLow = item.isLow;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isLow ? Border.all(color: Colors.red.shade200, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: isLow ? Colors.red.shade50 : Colors.green.shade50, child: Icon(Icons.inventory_2_outlined, color: isLow ? Colors.red : Colors.green, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), if (isLow) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16)]),
                    Text(item.supplier, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(onPressed: () => _deleteItem(item.id), icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _dataBox(item.available.toString(), "Available"),
              const SizedBox(width: 8),
              _dataBox(item.minStock.toString(), "Min Stock"),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => _updateStock(item.id, item.available, -1)),
                    Text(item.unit, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => _updateStock(item.id, item.available, 1)),
                  ]
                ),
              )
            ]
          ),
          const SizedBox(height: 15),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: item.progress, minHeight: 8, color: isLow ? Colors.red : Colors.green, backgroundColor: Colors.grey.shade100)),
          if (isLow && item.minStock > 0) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text("Stock below minimum! Reorder from ${item.supplier}", style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)))]))
          ]
        ],
      ),
    );
  }

  Widget _dataBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10))])
      ),
    );
  }
}