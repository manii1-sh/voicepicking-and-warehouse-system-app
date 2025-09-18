// lib/screens/wms/picklist_management_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../../utils/colors.dart';
import '../../services/warehouse_service.dart';

class PicklistManagementScreen extends StatefulWidget {
  final String userName;
  const PicklistManagementScreen({super.key, required this.userName});

  @override
  State<PicklistManagementScreen> createState() => _PicklistManagementScreenState();
}

class _PicklistManagementScreenState extends State<PicklistManagementScreen> {
  List<Map<String, dynamic>> _picklist = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  
  // Controllers for adding new picklist
  final _addWaveNumberController = TextEditingController();
  final _addPickerNameController = TextEditingController();
  final _addQuantityController = TextEditingController();
  final _addLocationController = TextEditingController();
  final _locationCheckDigitController = TextEditingController();
  final _barcodeCheckDigitController = TextEditingController();
  final _barcodeNumberController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _skuController = TextEditingController();
  final _searchController = TextEditingController();
  String _selectedPriority = 'normal';

  @override
  void initState() {
    super.initState();
    _loadPicklist();
    _addPickerNameController.text = widget.userName;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _addWaveNumberController.dispose();
    _addPickerNameController.dispose();
    _addQuantityController.dispose();
    _addLocationController.dispose();
    _locationCheckDigitController.dispose();
    _barcodeCheckDigitController.dispose();
    _barcodeNumberController.dispose();
    _itemNameController.dispose();
    _skuController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadPicklist() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final items = await WarehouseService.fetchPicklist(limit: 100);
      if (mounted) {
        setState(() {
          // Filter out cancelled/deleted items
          _picklist = items.where((item) =>
            item['status'] != 'cancelled' &&
            item['status'] != 'deleted'
          ).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPicklist {
    var filtered = _picklist.where((item) {
      // Apply status filter
      bool matchesStatus = true;
      switch (_selectedFilter) {
        case 'pending':
          matchesStatus = item['status'] == 'pending';
          break;
        case 'in_progress':
          matchesStatus = item['status'] == 'in_progress';
          break;
        case 'completed':
          matchesStatus = item['status'] == 'completed';
          break;
        case 'all':
        default:
          matchesStatus = true;
          break;
      }

      // Apply search filter
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        matchesSearch = (item['item_name']?.toString().toLowerCase().contains(_searchQuery) ?? false) ||
            (item['sku']?.toString().toLowerCase().contains(_searchQuery) ?? false) ||
            (item['wave_number']?.toString().toLowerCase().contains(_searchQuery) ?? false) ||
            (item['picker_name']?.toString().toLowerCase().contains(_searchQuery) ?? false);
      }

      return matchesStatus && matchesSearch;
    }).toList();
    
    // Sort by priority and creation date
    filtered.sort((a, b) {
      final priorityOrder = {'urgent': 4, 'high': 3, 'normal': 2, 'low': 1};
      int priorityComparison = (priorityOrder[b['priority']] ?? 2) - (priorityOrder[a['priority']] ?? 2);
      if (priorityComparison != 0) return priorityComparison;
      return (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? '');
    });
    
    return filtered;
  }

  Future<void> _deletePicklistItem(String itemId) async {
    try {
      setState(() => _isLoading = true);
      final success = await WarehouseService.deletePicklistItem(itemId);
      if (success) {
        _showSuccessMessage('Item deleted successfully');
        // Remove from local list immediately
        setState(() {
          _picklist.removeWhere((item) => item['id'] == itemId);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showErrorMessage('Failed to delete item');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('Error deleting item: ${e.toString()}');
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Delete Picklist Item')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.delete_forever, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Delete "${item['item_name'] ?? 'Unknown Item'}"?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wave: ${item['wave_number'] ?? 'N/A'}\nQuantity: ${item['quantity_requested'] ?? 0}',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will permanently remove the item from the picklist. This action cannot be undone.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePicklistItem(item['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPicklistReport() async {
    setState(() => _isExporting = true);
    try {
      // Create comprehensive CSV data
      List<List<dynamic>> csvData = [];
      // Header Section
      csvData.addAll([
        ['PICKLIST MANAGEMENT REPORT'],
        ['Generated on:', DateTime.now().toString()],
        ['Generated by:', widget.userName],
        ['Total Items:', _filteredPicklist.length.toString()],
        [],
      ]);

      // Statistics
      final pendingCount = _filteredPicklist.where((i) => i['status'] == 'pending').length;
      final inProgressCount = _filteredPicklist.where((i) => i['status'] == 'in_progress').length;
      final completedCount = _filteredPicklist.where((i) => i['status'] == 'completed').length;

      csvData.addAll([
        ['SUMMARY STATISTICS:'],
        ['Pending Items:', pendingCount.toString()],
        ['In Progress Items:', inProgressCount.toString()],
        ['Completed Items:', completedCount.toString()],
        [],
      ]);

      // Data Headers
      csvData.add([
        'ID', 'Wave Number', 'Item Name', 'SKU', 'Picker Name',
        'Quantity Requested', 'Quantity Picked', 'Location', 'Priority',
        'Status', 'Created Date', 'Completed Date'
      ]);

      // Data Rows
      for (var item in _filteredPicklist) {
        csvData.add([
          item['id']?.toString() ?? '',
          item['wave_number']?.toString() ?? '',
          item['item_name']?.toString() ?? '',
          item['sku']?.toString() ?? '',
          item['picker_name']?.toString() ?? '',
          item['quantity_requested']?.toString() ?? '0',
          item['quantity_picked']?.toString() ?? '0',
          item['location']?.toString() ?? '',
          item['priority']?.toString() ?? '',
          item['status']?.toString() ?? '',
          item['created_at']?.toString().substring(0, 19) ?? '',
          item['completed_at']?.toString().substring(0, 19) ?? '',
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toString().replaceAll(':', '-').substring(0, 19);
      final file = File('${directory.path}/picklist_report_$timestamp.csv');
      await file.writeAsString(csvString);

      // Share file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Picklist Report - ${_filteredPicklist.length} items',
      );

      _showSuccessMessage('Picklist report exported successfully!');
    } catch (e) {
      _showErrorMessage('Export failed: ${e.toString()}');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // FIXED: Add function with proper error handling and layout
  void _showAddPicklistDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_task, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add New Picklist Item',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildInputField(
                          controller: _addWaveNumberController,
                          label: 'Wave Number *',
                          icon: Icons.waves,
                          hint: 'e.g., WAVE-001',
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _addPickerNameController,
                          label: 'Picker Name *',
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _itemNameController,
                          label: 'Item Name *',
                          icon: Icons.inventory_2,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _skuController,
                          label: 'SKU *',
                          icon: Icons.qr_code,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _addQuantityController,
                          label: 'Quantity Requested *',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _addLocationController,
                          label: 'Location *',
                          icon: Icons.place,
                          hint: 'e.g., A-01-01',
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _locationCheckDigitController,
                          label: 'Location Check Digit',
                          icon: Icons.pin,
                          hint: 'Max 3 digits',
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _barcodeNumberController,
                          label: 'Barcode Number',
                          icon: Icons.qr_code,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _barcodeCheckDigitController,
                          label: 'Barcode Check Digit',
                          icon: Icons.verified,
                          hint: 'Max 4 digits',
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedPriority,
                          decoration: InputDecoration(
                            labelText: 'Priority',
                            prefixIcon: const Icon(Icons.priority_high, color: Colors.green),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.green, width: 2),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                            DropdownMenuItem(value: 'normal', child: Text('Normal Priority')),
                            DropdownMenuItem(value: 'high', child: Text('High Priority')),
                            DropdownMenuItem(value: 'urgent', child: Text('Urgent Priority')),
                          ],
                          onChanged: (value) => setState(() => _selectedPriority = value ?? 'normal'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleAddPicklistItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Add Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
        counterText: maxLength != null ? null : '',
      ),
    );
  }

  Future<void> _handleAddPicklistItem() async {
    if (_addWaveNumberController.text.trim().isEmpty ||
        _addPickerNameController.text.trim().isEmpty ||
        _itemNameController.text.trim().isEmpty ||
        _skuController.text.trim().isEmpty ||
        _addQuantityController.text.trim().isEmpty ||
        _addLocationController.text.trim().isEmpty) {
      _showErrorMessage('Please fill in all required fields');
      return;
    }

    final quantity = int.tryParse(_addQuantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      _showErrorMessage('Please enter a valid quantity');
      return;
    }

    Navigator.pop(context);
    setState(() => _isLoading = true);
    
    try {
      final success = await WarehouseService.addPicklistItem(
        waveNumber: _addWaveNumberController.text.trim(),
        pickerName: _addPickerNameController.text.trim(),
        quantityRequested: quantity,
        location: _addLocationController.text.trim(),
        priority: _selectedPriority,
        locationCheckDigit: _locationCheckDigitController.text.trim().isEmpty
            ? null : _locationCheckDigitController.text.trim(),
        barcodeCheckDigit: _barcodeCheckDigitController.text.trim().isEmpty
            ? null : _barcodeCheckDigitController.text.trim(),
        barcodeNumber: _barcodeNumberController.text.trim().isEmpty
            ? null : _barcodeNumberController.text.trim(),
        itemName: _itemNameController.text.trim(),
        sku: _skuController.text.trim(),
      );
      
      if (success) {
        _showSuccessMessage('Picklist item added successfully! Item will be available for voice picking.');
        _clearAddForm();
        await _loadPicklist();
      } else {
        _showErrorMessage('Failed to add picklist item');
      }
    } catch (e) {
      _showErrorMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearAddForm() {
    _addWaveNumberController.clear();
    _addPickerNameController.text = widget.userName;
    _itemNameController.clear();
    _skuController.clear();
    _addQuantityController.clear();
    _addLocationController.clear();
    _locationCheckDigitController.clear();
    _barcodeCheckDigitController.clear();
    _barcodeNumberController.clear();
    _selectedPriority = 'normal';
  }

  // FIXED: Update status function with proper overflow handling
  void _editPickStatus(Map<String, dynamic> item) {
    String newStatus = item['status'] ?? 'pending';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.green),
            SizedBox(width: 12),
            Expanded(child: Text('Update Pick Status')),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item: ${item['item_name'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wave: ${item['wave_number'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Location: ${item['location'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: newStatus,
                decoration: InputDecoration(
                  labelText: 'New Status',
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: 'pending',
                    child: Row(
                      children: [
                        Icon(Icons.pending_actions, size: 20, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Flexible(child: Text('PENDING')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Row(
                      children: [
                        Icon(Icons.play_circle, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Flexible(child: Text('IN PROGRESS')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        const Flexible(child: Text('COMPLETED')),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) => newStatus = value ?? 'pending',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await WarehouseService.updatePickStatus(item['id'], newStatus);
              if (success) {
                await _loadPicklist();
                _showSuccessMessage('Pick status updated to ${newStatus.toUpperCase().replaceAll('_', ' ')}');
              } else {
                _showErrorMessage('Failed to update pick status');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showItemDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.assignment, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pick ID: ${item['id'] ?? ""}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogDetailRow('Wave Number', item['wave_number'] ?? "N/A"),
                _buildDialogDetailRow('Item Name', item['item_name'] ?? "N/A"),
                _buildDialogDetailRow('SKU', item['sku'] ?? "N/A"),
                _buildDialogDetailRow('Picker Name', item['picker_name'] ?? "Unassigned"),
                _buildDialogDetailRow('Status', item['status'] ?? "pending"),
                _buildDialogDetailRow('Location', item['location'] ?? "Unknown"),
                _buildDialogDetailRow('Barcode', item['barcode'] ?? "N/A"),
                _buildDialogDetailRow('Priority', item['priority'] ?? "Normal"),
                _buildDialogDetailRow('Quantity Requested', item['quantity_requested']?.toString() ?? "0"),
                _buildDialogDetailRow('Quantity Picked', item['quantity_picked']?.toString() ?? "0"),
                _buildDialogDetailRow('Created', _formatDate(item['created_at']?.toString() ?? "")),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editPickStatus(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Update Status"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicklistCard(Map<String, dynamic> item, int index) {
    final waveNumber = item['wave_number'] ?? 'N/A';
    final pickerName = item['picker_name'] ?? 'Unassigned';
    final status = item['status'] ?? 'pending';
    final quantityRequested = item['quantity_requested'] ?? 0;
    final quantityPicked = item['quantity_picked'] ?? 0;
    final location = item['location'] ?? 'Unknown';
    final priority = item['priority'] ?? 'Normal';

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.pending_actions;
    
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusIcon = Icons.play_circle;
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
        break;
    }

    return Dismissible(
      key: Key(item['id'].toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text('Are you sure you want to delete this item?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _deletePicklistItem(item['id']);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 30,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Wave: $waveNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(priority).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            priority.toUpperCase(),
                            style: TextStyle(
                              color: _getPriorityColor(priority),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Item: ${item['item_name'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Picker: $pickerName',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Qty: $quantityPicked/$quantityRequested',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => _handlePickAction(value, item),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit_status',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Update Status'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'view_details',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 18),
                        SizedBox(width: 8),
                        Text('View Details'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDetailRow('Location', location),
                      _buildDetailRow('Priority', priority),
                      _buildDetailRow('SKU', item['sku'] ?? 'N/A'),
                      _buildDetailRow('Barcode', item['barcode'] ?? 'N/A'),
                      _buildDetailRow('Quantity Requested', quantityRequested.toString()),
                      _buildDetailRow('Quantity Picked', quantityPicked.toString()),
                      _buildDetailRow('Created', _formatDate(item['created_at']?.toString() ?? '')),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _editPickStatus(item),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Update Status'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showDeleteConfirmation(item),
                              icon: const Icon(Icons.delete, size: 18),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePickAction(String action, Map<String, dynamic> item) {
    switch (action) {
      case 'edit_status':
        _editPickStatus(item);
        break;
      case 'view_details':
        _showItemDetails(item);
        break;
      case 'delete':
        _showDeleteConfirmation(item);
        break;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "—";
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr.length > 19 ? dateStr.substring(0, 19) : dateStr;
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );
    }
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All', 'icon': Icons.list},
      {'key': 'pending', 'label': 'Pending', 'icon': Icons.pending_actions},
      {'key': 'in_progress', 'label': 'In Progress', 'icon': Icons.play_circle},
      {'key': 'completed', 'label': 'Completed', 'icon': Icons.check_circle},
    ];

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                filter['icon'] as IconData,
                size: 18,
                color: isSelected ? Colors.white : Colors.green,
              ),
              label: Text(filter['label'] as String),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter['key'] as String;
                  });
                }
              },
              backgroundColor: Colors.green.withOpacity(0.1),
              selectedColor: Colors.green,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Picklist Management'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // REMOVED: Completed Operations button as requested
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPicklist,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.file_download),
            onPressed: _isExporting ? null : _exportPicklistReport,
            tooltip: 'Export Report',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddPicklistDialog,
            tooltip: 'Add Picklist Item',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.withOpacity(0.08),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by item, SKU, wave number, or picker...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            // Filter Chips
            _buildFilterChips(),
            // Statistics
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total', _filteredPicklist.length, Colors.blue),
                  _buildStatItem('Pending', _filteredPicklist.where((i) => i['status'] == 'pending').length, Colors.orange),
                  _buildStatItem('In Progress', _filteredPicklist.where((i) => i['status'] == 'in_progress').length, Colors.blue),
                  _buildStatItem('Completed', _filteredPicklist.where((i) => i['status'] == 'completed').length, Colors.green),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.green),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Loading picklist...",
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red.withOpacity(0.7),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Error loading picklist",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _loadPicklist,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _filteredPicklist.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    size: 64,
                                    color: Colors.grey.withOpacity(0.6),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "No picklist items found",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? "No items match your search"
                                        : "Items added from Inventory will appear here",
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: _showAddPicklistDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Picklist Item'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadPicklist,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _filteredPicklist.length,
                                itemBuilder: (context, index) {
                                  final item = _filteredPicklist[index];
                                  return _buildPicklistCard(item, index);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
