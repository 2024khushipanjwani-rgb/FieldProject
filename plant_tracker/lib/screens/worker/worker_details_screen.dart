import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plant_tracker/core/app_roles.dart';

class WorkerDetailsScreen extends StatefulWidget {
  const WorkerDetailsScreen({
    super.key,
    required this.workerId,
  });

  final String workerId;

  @override
  State<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _hourlyWageController = TextEditingController();
  final _defaultDailyHoursController = TextEditingController();
  final _deductionsController = TextEditingController();
  bool _isSaving = false;
  bool _isInitialized = false;

  DocumentReference<Map<String, dynamic>> get _workerRef =>
      FirebaseFirestore.instance.collection('users').doc(widget.workerId);

  Future<bool> _canEditAsStaff() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    return isStaffRole(doc.data()?['role'] as String?);
  }

  String? _requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Mobile number is required';
    final phoneRegex = RegExp(r'^[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(v)) return 'Enter 10 to 15 digits';
    return null;
  }

  String? _amountValidator(String? value, String label) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return '$label cannot be negative';
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _hourlyWageController.dispose();
    _defaultDailyHoursController.dispose();
    _deductionsController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final hourlyWage = double.tryParse(_hourlyWageController.text.trim()) ?? 0.0;
    final defaultDailyHours =
        int.tryParse(_defaultDailyHoursController.text.trim()) ?? 8;
    final deductions = double.tryParse(_deductionsController.text.trim()) ?? 0.0;

    try {
      await _workerRef.set({
        'username': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
        'hourlyWage': hourlyWage,
        'defaultDailyHours': defaultDailyHours,
        'deductions': deductions,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker details updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update details.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Details'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<bool>(
        future: _canEditAsStaff(),
        builder: (context, roleSnapshot) {
          final canEdit = roleSnapshot.data ?? false;
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _workerRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Could not load worker details.'));
              }

              final data = snapshot.data!.data()!;
              if (!_isInitialized) {
                _nameController.text = (data['username'] as String?) ?? '';
                _phoneController.text = (data['phone'] as String?) ?? '';
                _departmentController.text = (data['department'] as String?) ?? '';
                final savedHourlyWage =
                    (data['hourlyWage'] as num?)?.toDouble();
                final legacyDailyWage =
                    (data['dailyWage'] as num?)?.toDouble();
                final hourly = savedHourlyWage ??
                    (legacyDailyWage != null ? legacyDailyWage / 8 : 0);
                _hourlyWageController.text = hourly.toStringAsFixed(0);
                _defaultDailyHoursController.text =
                    ((data['defaultDailyHours'] as num?)?.toInt() ?? 8)
                        .toString();
                _deductionsController.text =
                    ((data['deductions'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
                _isInitialized = true;
              }

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle('Account'),
                    _readOnlyTile('Email', (data['email'] as String?) ?? '-'),
                    _readOnlyTile('Worker ID', widget.workerId),
                    _readOnlyTile(
                        'Editable by', canEdit ? 'Manager / owner' : 'Not permitted'),
                    const SizedBox(height: 16),
                    _sectionTitle('Profile'),
                    _editableField(
                      _nameController,
                      'Name',
                      Icons.person,
                      enabled: canEdit,
                      validator: (v) => _requiredText(v, 'Name'),
                    ),
                    const SizedBox(height: 12),
                    _editableField(
                      _phoneController,
                      'Mobile Number',
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                      enabled: canEdit,
                      validator: _phoneValidator,
                    ),
                    const SizedBox(height: 12),
                    _editableField(
                      _departmentController,
                      'Department',
                      Icons.apartment,
                      enabled: canEdit,
                      validator: (v) => _requiredText(v, 'Department'),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Compensation'),
                    _editableField(
                      _hourlyWageController,
                      'Hourly Wage',
                      Icons.currency_rupee,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      enabled: canEdit,
                      validator: (v) => _amountValidator(v, 'Hourly wage'),
                    ),
                    const SizedBox(height: 12),
                    _editableField(
                      _defaultDailyHoursController,
                      'Default Daily Hours',
                      Icons.schedule,
                      keyboardType: TextInputType.number,
                      enabled: canEdit,
                      validator: (v) => _amountValidator(v, 'Daily hours'),
                    ),
                    const SizedBox(height: 12),
                    _editableField(
                      _deductionsController,
                      'Deductions',
                      Icons.remove_circle_outline,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      enabled: canEdit,
                      validator: (v) => _amountValidator(v, 'Deductions'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: (!canEdit || _isSaving) ? null : _saveChanges,
                        icon: const Icon(Icons.save_outlined),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                        ),
                        label: _isSaving
                            ? const Text('Saving...')
                            : const Text('Save Changes'),
                      ),
                    ),
                    if (!canEdit) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Only manager or owner can modify worker profile.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _readOnlyTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _editableField(
    TextEditingController controller,
    String label,
    IconData icon,
    {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
