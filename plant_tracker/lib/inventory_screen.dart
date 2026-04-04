import 'package:flutter/material.dart';

// 1. Data model to hold your stock info
class StockItem {
  String name;
  String supplier;
  int available;
  int minStock;
  String unit;
  double progress;
  bool isLow;

  StockItem({
    required this.name,
    required this.supplier,
    required this.available,
    required this.minStock,
    required this.unit,
    required this.progress,
    required this.isLow,
  });
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool showAll = true;

  // 2. The dynamic list that starts with your Figma data
  List<StockItem> inventory = [
    StockItem(name: "Preservatives", supplier: "ChemTech Solutions", available: 250, minStock: 150, unit: "kg", progress: 0.8, isLow: false),
    StockItem(name: "Plastic Wrapper", supplier: "Pack Industries Ltd", available: 3500, minStock: 2000, unit: "rolls", progress: 0.7, isLow: false),
    StockItem(name: "Essence", supplier: "Flavor House Co.", available: 85, minStock: 120, unit: "liters", progress: 0.3, isLow: true),
    StockItem(name: "Sugar", supplier: "Sweet Supply Co.", available: 450, minStock: 800, unit: "kg", progress: 0.4, isLow: true),
  ];

  // 3. Controllers to read your "Add Item" form
  final nameController = TextEditingController();
  final supplierController = TextEditingController();
  final availController = TextEditingController();
  final minController = TextEditingController();

  void _saveNewItem() {
    setState(() {
      int avail = int.tryParse(availController.text) ?? 0;
      int min = int.tryParse(minController.text) ?? 0;

      inventory.add(StockItem(
        name: nameController.text,
        supplier: supplierController.text,
        available: avail,
        minStock: min,
        unit: "units", // Default for new items
        progress: avail / (min * 2 > 0 ? min * 2 : 1), // Simple calculation
        isLow: avail < min,
      ));
    });

    // Clear and Close
    nameController.clear();
    supplierController.clear();
    availController.clear();
    minController.clear();
    Navigator.pop(context);
  }

  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20, left: 20, right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add New Material", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Material Name", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: supplierController, decoration: const InputDecoration(labelText: "Supplier", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextField(controller: availController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Available", border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: minController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Min Stock", border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white),
                onPressed: _saveNewItem, // Calls the actual save logic
                child: const Text("Save Item"),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter logic
    final displayedItems = showAll ? inventory : inventory.where((item) => item.isLow).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(inventory.length, inventory.where((i) => i.isLow).length),
          _buildSearchAndFilters(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: displayedItems.length,
              itemBuilder: (context, index) {
                final item = displayedItems[index];
                return _figmaStockCard(item.name, item.supplier, item.available, item.minStock, item.unit, item.progress, item.isLow);
              },
            ),
          ),
        ],
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
                label: const Text("Add Item"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white, elevation: 0),
              )
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
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

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          TextField(
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
              Expanded(child: _filterBtn("All Items (${inventory.length})", showAll, () => setState(() => showAll = true))),
              const SizedBox(width: 10),
              Expanded(child: _filterBtn("⚠️ Low Stock (${inventory.where((i) => i.isLow).length})", !showAll, () => setState(() => showAll = false))),
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
          boxShadow: [if (!isActive) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _figmaStockCard(String name, String supplier, int available, int min, String unit, double progress, bool isLow) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isLow ? Border.all(color: Colors.red.shade200, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: isLow ? Colors.red.shade50 : Colors.green.shade50, child: Icon(Icons.inventory_2_outlined, color: isLow ? Colors.red : Colors.green, size: 20)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), if (isLow) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16)]),
                  Text(supplier, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const Spacer(),
              TextButton.icon(onPressed: () {}, icon: const Icon(Icons.refresh, size: 14), label: const Text("Update", style: TextStyle(fontSize: 12)), style: TextButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue))
            ],
          ),
          const SizedBox(height: 15),
          Row(children: [_dataBox(available.toString(), "Available"), const SizedBox(width: 8), _dataBox(min.toString(), "Min Stock"), const SizedBox(width: 8), _dataBox(unit, "Unit")]),
          const SizedBox(height: 15),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 8, color: isLow ? Colors.red : Colors.green, backgroundColor: Colors.grey.shade100)),
          if (isLow) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text("Stock below minimum! Reorder from $supplier", style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)))]))
          ]
        ],
      ),
    );
  }

  Widget _dataBox(String value, String label) {
    return Expanded(
      child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10))])),
    );
  }
}