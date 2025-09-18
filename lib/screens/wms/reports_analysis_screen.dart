// lib/screens/wms/reports_analysis_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import '../../services/warehouse_service.dart';
import '../../utils/colors.dart';

class ReportsAnalysisScreen extends StatefulWidget {
  final String userName;
  const ReportsAnalysisScreen({super.key, required this.userName});

  @override
  State<ReportsAnalysisScreen> createState() => _ReportsAnalysisScreenState();
}

class _ReportsAnalysisScreenState extends State<ReportsAnalysisScreen>
    with TickerProviderStateMixin {
  // Core State Variables
  bool _isLoading = true;
  String? _errorMessage;
  
  // Report Data
  Map<String, dynamic> _dashboardStats = {};
  List<Map<String, dynamic>> _inventoryReports = [];
  List<Map<String, dynamic>> _picklistReports = [];
  List<Map<String, dynamic>> _loadingReports = [];
  List<Map<String, dynamic>> _movementReports = [];
  List<Map<String, dynamic>> _storageReports = [];
  
  // Export States
  bool _isExportingInventory = false;
  bool _isExportingPicklist = false;
  bool _isExportingLoading = false;
  bool _isExportingMovement = false;
  bool _isExportingStorage = false;
  bool _isExportingAnalytics = false;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Tab Controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllReports();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  // ================================
  // DATA LOADING
  // ================================
  Future<void> _loadAllReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final results = await Future.wait([
        _loadDashboardStats(),
        _loadInventoryReports(),
        _loadPicklistReports(),
        _loadLoadingReports(),
        _loadMovementReports(),
        _loadStorageReports(),
      ]);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await WarehouseService.getDashboardStats();
      if (stats['success']) {
        _dashboardStats = stats['data'];
      }
    } catch (e) {
      print('Error loading dashboard stats: $e');
    }
  }

  Future<void> _loadInventoryReports() async {
    try {
      final inventory = await WarehouseService.fetchInventory(limit: 1000);
      _inventoryReports = inventory;
    } catch (e) {
      print('Error loading inventory reports: $e');
    }
  }

  Future<void> _loadPicklistReports() async {
    try {
      final picklist = await WarehouseService.fetchPicklist(limit: 500);
      _picklistReports = picklist;
    } catch (e) {
      print('Error loading picklist reports: $e');
    }
  }

  Future<void> _loadLoadingReports() async {
    try {
      final loading = await WarehouseService.getLoadingReports(limit: 200);
      _loadingReports = loading;
    } catch (e) {
      print('Error loading loading reports: $e');
    }
  }

  Future<void> _loadMovementReports() async {
    try {
      final movements = await WarehouseService.getStoredItems();
      _movementReports = movements;
    } catch (e) {
      print('Error loading movement reports: $e');
    }
  }

  Future<void> _loadStorageReports() async {
    try {
      final storage = await WarehouseService.getStoredItems();
      _storageReports = storage;
    } catch (e) {
      print('Error loading storage reports: $e');
    }
  }

  // ================================
  // UPDATE & DELETE FUNCTIONALITY
  // ================================

  // INVENTORY UPDATE & DELETE
  Future<void> _updateInventoryItem(Map<String, dynamic> item) async {
    final TextEditingController nameController = TextEditingController(text: item['name'] ?? '');
    final TextEditingController quantityController = TextEditingController(text: (item['quantity'] ?? 0).toString());
    final TextEditingController priceController = TextEditingController(text: (item['unit_price'] ?? 0.0).toString());
    final TextEditingController minStockController = TextEditingController(text: (item['min_stock'] ?? 10).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Inventory Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Unit Price'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: minStockController,
                decoration: const InputDecoration(labelText: 'Min Stock'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updates = {
                'name': nameController.text,
                'quantity': int.tryParse(quantityController.text) ?? 0,
                'unit_price': double.tryParse(priceController.text) ?? 0.0,
                'min_stock': int.tryParse(minStockController.text) ?? 10,
              };
              
              final success = await WarehouseService.updateInventory(item['id'], updates);
              
              if (success) {
                _showSuccessMessage('Inventory item updated successfully!');
                _loadInventoryReports();
              } else {
                _showErrorMessage('Failed to update inventory item');
              }
              
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInventoryItem(Map<String, dynamic> item) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Inventory Item'),
        content: Text('Are you sure you want to delete "${item['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await WarehouseService.deleteInventory(item['id']);
              
              if (success) {
                _showSuccessMessage('Inventory item deleted successfully!');
                _loadInventoryReports();
              } else {
                _showErrorMessage('Failed to delete inventory item');
              }
              
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // STORAGE UPDATE & DELETE
  Future<void> _updateStorageItem(Map<String, dynamic> item) async {
    final TextEditingController descriptionController = TextEditingController(text: item['description'] ?? '');
    final TextEditingController quantityController = TextEditingController(text: (item['qty'] ?? 0).toString());
    final TextEditingController locationController = TextEditingController(text: item['location'] ?? '');
    final TextEditingController categoryController = TextEditingController(text: item['category'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Storage Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newQuantity = int.tryParse(quantityController.text) ?? 0;
              final success = await WarehouseService.updateStorageItemQuantity(item['id'], newQuantity);
              
              if (success) {
                _showSuccessMessage('Storage item updated successfully!');
                _loadStorageReports();
              } else {
                _showErrorMessage('Failed to update storage item');
              }
              
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStorageItem(Map<String, dynamic> item) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Storage Item'),
        content: Text('Are you sure you want to delete storage item "${item['description'] ?? item['item_no']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await WarehouseService.removeItemFromStorage(item['id'], widget.userName);
              
              if (success) {
                _showSuccessMessage('Storage item deleted successfully!');
                _loadStorageReports();
              } else {
                _showErrorMessage('Failed to delete storage item');
              }
              
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // PICKLIST UPDATE & DELETE
  Future<void> _updatePicklistItem(Map<String, dynamic> item) async {
    final TextEditingController quantityController = TextEditingController(text: (item['quantity_picked'] ?? 0).toString());
    String selectedStatus = item['status'] ?? 'pending';
    final List<String> statusOptions = ['pending', 'in_progress', 'completed', 'cancelled'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Picklist Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity Picked'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: statusOptions.map((status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.toUpperCase()),
                )).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedStatus = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final quantityPicked = int.tryParse(quantityController.text) ?? 0;
                
                final success = await WarehouseService.updatePickWithVoice(
                  picklistId: item['id'],
                  quantityPicked: quantityPicked,
                  pickerName: widget.userName,
                );
                
                if (success['success']) {
                  await WarehouseService.updatePickStatus(item['id'], selectedStatus);
                  _showSuccessMessage('Picklist item updated successfully!');
                  _loadPicklistReports();
                } else {
                  _showErrorMessage('Failed to update picklist item');
                }
                
                Navigator.of(context).pop();
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePicklistItem(Map<String, dynamic> item) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Picklist Item'),
        content: Text('Are you sure you want to delete picklist item "${item['item_name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await WarehouseService.deletePicklistItem(item['id']);
              
              if (success) {
                _showSuccessMessage('Picklist item deleted successfully!');
                _loadPicklistReports();
              } else {
                _showErrorMessage('Failed to delete picklist item');
              }
              
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // LOADING REPORT UPDATE & DELETE
  Future<void> _updateLoadingReport(Map<String, dynamic> report) async {
    final TextEditingController vehicleController = TextEditingController(text: report['vehicle_number'] ?? '');
    final TextEditingController driverController = TextEditingController(text: report['driver_name'] ?? '');
    final TextEditingController destinationController = TextEditingController(text: report['destination'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Loading Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vehicleController,
                decoration: const InputDecoration(labelText: 'Vehicle Number'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: driverController,
                decoration: const InputDecoration(labelText: 'Driver Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: destinationController,
                decoration: const InputDecoration(labelText: 'Destination'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updates = {
                'vehicle_number': vehicleController.text.toUpperCase(),
                'driver_name': driverController.text,
                'destination': destinationController.text,
              };
              
              final success = await WarehouseService.updateLoadingReport(report['id'], updates);
              
              if (success) {
                _showSuccessMessage('Loading report updated successfully!');
                _loadLoadingReports();
              } else {
                _showErrorMessage('Failed to update loading report');
              }
              
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLoadingReport(Map<String, dynamic> report) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Loading Report'),
        content: Text('Are you sure you want to delete loading report for vehicle "${report['vehicle_number']}"? This action cannot be undone and will delete all related carton scans.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await WarehouseService.deleteLoadingReport(report['id']);
              
              if (success) {
                _showSuccessMessage('Loading report deleted successfully!');
                _loadLoadingReports();
              } else {
                _showErrorMessage('Failed to delete loading report');
              }
              
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================================
  // EXPORT FUNCTIONALITY (Same as before)
  // ================================
  Future<void> _exportInventoryReport() async {
    setState(() => _isExportingInventory = true);
    try {
      List<List<dynamic>> csvData = [
        ['COMPREHENSIVE INVENTORY ANALYSIS REPORT'],
        ['Generated on:', DateTime.now().toString()],
        ['Generated by:', widget.userName],
        ['Total Items:', _inventoryReports.length.toString()],
        [],
        [
          'Item Name', 'SKU', 'Barcode', 'Category', 'Quantity',
          'Min Stock', 'Unit Price', 'Total Value', 'Location', 'Status', 'Last Updated'
        ],
      ];

      for (var item in _inventoryReports) {
        final quantity = item['quantity'] ?? 0;
        final minStock = item['min_stock'] ?? 10;
        final unitPrice = (item['unit_price'] ?? 0.0).toDouble();
        final totalValue = quantity * unitPrice;

        String status = 'In Stock';
        if (quantity == 0) status = 'Out of Stock';
        else if (quantity <= minStock) status = 'Low Stock';

        csvData.add([
          item['name'] ?? '',
          item['sku'] ?? '',
          item['barcode'] ?? '',
          item['category'] ?? 'General',
          quantity.toString(),
          minStock.toString(),
          unitPrice.toStringAsFixed(2),
          totalValue.toStringAsFixed(2),
          item['location'] ?? 'Storage',
          status,
          item['updated_at']?.toString().substring(0, 16) ?? '',
        ]);
      }

      await _saveAndShareCSV(csvData, 'comprehensive_inventory_analysis', 'Inventory Analysis Report');
      _showSuccessMessage('Inventory analysis report exported successfully!');
    } catch (e) {
      _showErrorMessage('Export failed: ${e.toString()}');
    } finally {
      setState(() => _isExportingInventory = false);
    }
  }

  Future<void> _exportStorageReport() async {
    setState(() => _isExportingStorage = true);
    try {
      List<List<dynamic>> csvData = [
        ['STORAGE MANAGEMENT ANALYSIS REPORT'],
        ['Generated on:', DateTime.now().toString()],
        ['Generated by:', widget.userName],
        ['Total Storage Items:', _storageReports.length.toString()],
        [],
        [
          'Item Number', 'Description', 'Category', 'Location',
          'Quantity', 'Unit Price', 'Total Value', 'Date Added', 'Scanned By'
        ],
      ];

      for (var item in _storageReports) {
        final quantity = (item['qty'] ?? 0) as int;
        final unitPrice = (item['unit_price'] ?? 0.0) as double;
        final totalItemValue = quantity * unitPrice;

        csvData.add([
          item['item_no'] ?? '',
          item['description'] ?? '',
          item['category'] ?? 'General',
          item['location'] ?? 'Unknown',
          quantity.toString(),
          unitPrice.toStringAsFixed(2),
          totalItemValue.toStringAsFixed(2),
          item['date_added']?.toString().substring(0, 16) ?? '',
          item['scanned_by'] ?? '',
        ]);
      }

      await _saveAndShareCSV(csvData, 'storage_management_analysis', 'Storage Analysis Report');
      _showSuccessMessage('Storage analysis report exported successfully!');
    } catch (e) {
      _showErrorMessage('Export failed: ${e.toString()}');
    } finally {
      setState(() => _isExportingStorage = false);
    }
  }

  Future<void> _exportPicklistReport() async {
    setState(() => _isExportingPicklist = true);
    try {
      List<List<dynamic>> csvData = [
        ['PICKLIST OPERATIONS ANALYSIS REPORT'],
        ['Generated on:', DateTime.now().toString()],
        ['Generated by:', widget.userName],
        ['Total Operations:', _picklistReports.length.toString()],
        [],
        [
          'Wave Number', 'Item Name', 'SKU', 'Picker', 'Quantity Requested',
          'Quantity Picked', 'Location', 'Priority', 'Status', 'Created At', 'Completed At'
        ],
      ];

      for (var item in _picklistReports) {
        csvData.add([
          item['wave_number'] ?? '',
          item['item_name'] ?? '',
          item['sku'] ?? '',
          item['picker_name'] ?? '',
          (item['quantity_requested'] ?? 0).toString(),
          (item['quantity_picked'] ?? 0).toString(),
          item['location'] ?? '',
          item['priority'] ?? 'normal',
          item['status'] ?? 'pending',
          item['created_at']?.toString().substring(0, 16) ?? '',
          item['completed_at']?.toString().substring(0, 16) ?? '',
        ]);
      }

      await _saveAndShareCSV(csvData, 'picklist_operations_analysis', 'Picklist Analysis Report');
      _showSuccessMessage('Picklist analysis report exported successfully!');
    } catch (e) {
      _showErrorMessage('Export failed: ${e.toString()}');
    } finally {
      setState(() => _isExportingPicklist = false);
    }
  }

  Future<void> _exportLoadingReport() async {
    setState(() => _isExportingLoading = true);
    try {
      List<List<dynamic>> csvData = [
        ['LOADING OPERATIONS ANALYSIS REPORT'],
        ['Generated on:', DateTime.now().toString()],
        ['Generated by:', widget.userName],
        ['Total Sessions:', _loadingReports.length.toString()],
        [],
        [
          'Vehicle Number', 'Driver Name', 'Dock Location', 'Destination',
          'Cartons Loaded', 'Status', 'Check-in Time', 'Completion Time', 'Operator'
        ],
      ];

      for (var session in _loadingReports) {
        csvData.add([
          session['vehicle_number'] ?? '',
          session['driver_name'] ?? '',
          session['dock_location'] ?? '',
          session['destination'] ?? '',
          (session['cartons_loaded'] ?? 0).toString(),
          session['status'] ?? 'active',
          session['check_in_time']?.toString().substring(0, 16) ?? '',
          session['completion_time']?.toString().substring(0, 16) ?? '',
          session['checked_in_by'] ?? '',
        ]);
      }

      await _saveAndShareCSV(csvData, 'loading_operations_analysis', 'Loading Analysis Report');
      _showSuccessMessage('Loading analysis report exported successfully!');
    } catch (e) {
      _showErrorMessage('Export failed: ${e.toString()}');
    } finally {
      setState(() => _isExportingLoading = false);
    }
  }

  Future<void> _exportMovementReport() async {
    setState(() => _isExportingMovement = true);
    try {
      List<List<dynamic>> csvData = [
        ['MOVEMENT TRACKING ANALYSIS REPORT'],
        ['Generated on:', DateTime.now().toString()],
        ['Generated by:', widget.userName],
        ['Total Movements:', _movementReports.length.toString()],
        [],
        [
          'Item Number', 'Description', 'Quantity', 'Location',
          'Category', 'Scanned By', 'Date Added', 'Movement Type'
        ],
      ];

      for (var movement in _movementReports) {
        csvData.add([
          movement['item_no'] ?? '',
          movement['description'] ?? '',
          (movement['qty'] ?? 0).toString(),
          movement['location'] ?? '',
          movement['category'] ?? 'General',
          movement['scanned_by'] ?? '',
          movement['date_added']?.toString().substring(0, 16) ?? '',
          'STORAGE_IN',
        ]);
      }

      await _saveAndShareCSV(csvData, 'movement_tracking_analysis', 'Movement Analysis Report');
      _showSuccessMessage('Movement analysis report exported successfully!');
    } catch (e) {
      _showErrorMessage('Export failed: ${e.toString()}');
    } finally {
      setState(() => _isExportingMovement = false);
    }
  }

  Future<void> _exportComprehensiveAnalytics() async {
    setState(() => _isExportingAnalytics = true);
    try {
      List<List<dynamic>> csvData = [
        ['COMPREHENSIVE WAREHOUSE ANALYTICS REPORT'],
        ['Generated on:', DateTime.now().toString()],
        ['Generated by:', widget.userName],
        ['Report Type:', 'Full Warehouse Analytics'],
        [],
        ['EXECUTIVE SUMMARY:'],
        ['Total Inventory Items:', _inventoryReports.length.toString()],
        ['Total Storage Items:', _storageReports.length.toString()],
        ['Active Picklist Operations:', _picklistReports.where((p) => p['status'] != 'completed').length.toString()],
        ['Loading Sessions:', _loadingReports.length.toString()],
        ['Movement Records:', _movementReports.length.toString()],
      ];

      await _saveAndShareCSV(csvData, 'comprehensive_warehouse_analytics', 'Comprehensive Analytics Report');
      _showSuccessMessage('Comprehensive analytics report exported successfully!');
    } catch (e) {
      _showErrorMessage('Export failed: ${e.toString()}');
    } finally {
      setState(() => _isExportingAnalytics = false);
    }
  }

  Future<void> _saveAndShareCSV(List<List<dynamic>> csvData, String fileName, String reportName) async {
    String csvString = const ListToCsvConverter().convert(csvData);
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toString().replaceAll(':', '-').substring(0, 19);
    final file = File('${directory.path}/${fileName}_$timestamp.csv');
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '$reportName - Generated on ${DateTime.now().toString().substring(0, 16)}',
    );
  }

  // ================================
  // UI BUILDERS
  // ================================
  
  Widget _buildDashboardOverview() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOverviewCard(),
          const SizedBox(height: 16),
          _buildQuickStatsGrid(),
          const SizedBox(height: 16),
          _buildAnalyticsActions(),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.8),
              Colors.blue.withOpacity(0.6),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Warehouse Analytics & Reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Generated on ${DateTime.now().toString().substring(0, 16)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewStat(
                    'Products',
                    (_dashboardStats['totalProducts'] ?? 0).toString(),
                  ),
                ),
                Expanded(
                  child: _buildOverviewStat(
                    'Total Value',
                    '\$${(_dashboardStats['inventoryValue'] ?? 0.0).toStringAsFixed(0)}',
                  ),
                ),
                Expanded(
                  child: _buildOverviewStat(
                    'Efficiency',
                    '${(_dashboardStats['systemEfficiency'] ?? 95.0).toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final crossAxisCount = isSmallScreen ? 2 : 4;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isSmallScreen ? 1.3 : 1.1,
          children: [
            _buildStatCard(
              'Storage Items',
              _storageReports.length.toString(),
              Icons.storage,
              Colors.green,
            ),
            _buildStatCard(
              'Inventory',
              _inventoryReports.length.toString(),
              Icons.inventory_2,
              Colors.blue,
            ),
            _buildStatCard(
              'Picklist Ops',
              _picklistReports.length.toString(),
              Icons.list_alt,
              Colors.orange,
            ),
            _buildStatCard(
              'Loading Sessions',
              _loadingReports.length.toString(),
              Icons.local_shipping,
              Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Export Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isExportingAnalytics ? null : _exportComprehensiveAnalytics,
                    icon: _isExportingAnalytics
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics, size: 16),
                    label: const Text('Full Analytics'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList(
    String title,
    List<Map<String, dynamic>> reports,
    bool isExporting,
    VoidCallback onExport,
    Widget Function(Map<String, dynamic>) itemBuilder,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${reports.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              IconButton(
                onPressed: isExporting ? null : onExport,
                icon: isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download),
                tooltip: 'Export $title',
              ),
            ],
          ),
        ),
        if (reports.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.folder_open,
                  size: 48,
                  color: Colors.grey.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No $title Available',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: reports.length,
              itemBuilder: (context, index) => itemBuilder(reports[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> item) {
    final quantity = item['quantity'] ?? 0;
    final minStock = item['min_stock'] ?? 10;
    final unitPrice = (item['unit_price'] ?? 0.0).toDouble();
    
    Color statusColor = Colors.green;
    String status = 'In Stock';
    if (quantity == 0) {
      statusColor = Colors.red;
      status = 'Out of Stock';
    } else if (quantity <= minStock) {
      statusColor = Colors.orange;
      status = 'Low Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.inventory_2, color: statusColor, size: 20),
        ),
        title: Text(
          item['name'] ?? 'Unknown Item',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SKU: ${item['sku'] ?? 'N/A'} • Qty: $quantity'),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _updateInventoryItem(item);
                } else if (value == 'delete') {
                  _deleteInventoryItem(item);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.storage, color: Colors.green, size: 20),
        ),
        title: Text(
          item['description'] ?? item['item_no'] ?? 'Unknown Item',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Item No: ${item['item_no'] ?? 'N/A'} • Qty: ${item['qty'] ?? 0}'),
            Text('Location: ${item['location'] ?? 'Unknown'} • Category: ${item['category'] ?? 'General'}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item['date_added']?.toString().substring(0, 10) ?? '',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _updateStorageItem(item);
                } else if (value == 'delete') {
                  _deleteStorageItem(item);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicklistItem(Map<String, dynamic> item) {
    Color statusColor = Colors.blue;
    switch (item['status']) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.playlist_add_check, color: statusColor, size: 20),
        ),
        title: Text(
          item['item_name'] ?? 'Unknown Item',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Wave: ${item['wave_number'] ?? 'N/A'} • Picker: ${item['picker_name'] ?? 'N/A'}'),
            Text('Qty: ${item['quantity_picked'] ?? 0}/${item['quantity_requested'] ?? 0}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                (item['status'] ?? 'pending').toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _updatePicklistItem(item);
                } else if (value == 'delete') {
                  _deletePicklistItem(item);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingItem(Map<String, dynamic> item) {
    Color statusColor = item['status'] == 'completed' ? Colors.green : Colors.blue;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.local_shipping, color: statusColor, size: 20),
        ),
        title: Text(
          item['vehicle_number'] ?? 'Unknown Vehicle',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Driver: ${item['driver_name'] ?? 'N/A'}'),
            Text('Dock: ${item['dock_location'] ?? 'N/A'} • Cartons: ${item['cartons_loaded'] ?? 0}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                (item['status'] ?? 'active').toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _updateLoadingReport(item);
                } else if (value == 'delete') {
                  _deleteLoadingReport(item);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.move_to_inbox, color: Colors.purple, size: 20),
        ),
        title: Text(
          item['description'] ?? item['item_no'] ?? 'Unknown Item',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Item No: ${item['item_no'] ?? 'N/A'} • Qty: ${item['qty'] ?? 0}'),
            Text('Location: ${item['location'] ?? 'Unknown'}'),
          ],
        ),
        trailing: Text(
          item['date_added']?.toString().substring(0, 10) ?? '',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Reports & Analytics'),
        backgroundColor: Colors.blue.withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAllReports,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Reports',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Inventory'),
            Tab(text: 'Storage'),
            Tab(text: 'Picklist'),
            Tab(text: 'Loading'),
            Tab(text: 'Movement'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.blue),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading comprehensive analytics...',
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
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Failed to Load Reports',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textLight,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadAllReports,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Overview Tab
                        SingleChildScrollView(
                          child: _buildDashboardOverview(),
                        ),
                        // Inventory Tab
                        _buildReportList(
                          'Inventory Analysis',
                          _inventoryReports,
                          _isExportingInventory,
                          _exportInventoryReport,
                          _buildInventoryItem,
                        ),
                        // Storage Tab
                        _buildReportList(
                          'Storage Management',
                          _storageReports,
                          _isExportingStorage,
                          _exportStorageReport,
                          _buildStorageItem,
                        ),
                        // Picklist Tab
                        _buildReportList(
                          'Picklist Operations',
                          _picklistReports,
                          _isExportingPicklist,
                          _exportPicklistReport,
                          _buildPicklistItem,
                        ),
                        // Loading Tab
                        _buildReportList(
                          'Loading Operations',
                          _loadingReports,
                          _isExportingLoading,
                          _exportLoadingReport,
                          _buildLoadingItem,
                        ),
                        // Movement Tab
                        _buildReportList(
                          'Movement Tracking',
                          _movementReports,
                          _isExportingMovement,
                          _exportMovementReport,
                          _buildMovementItem,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
