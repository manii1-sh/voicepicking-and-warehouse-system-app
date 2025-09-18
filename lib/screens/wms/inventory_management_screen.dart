// lib/screens/wms/inventory_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'low_stock_screen.dart';
import 'out_of_stock_screen.dart';
import 'reports_analysis_screen.dart';
import 'total_items_screen.dart'; // ✅ NEW IMPORT
import '../../services/warehouse_service.dart';
import '../../utils/colors.dart';
import 'picklist_management_screen.dart';

class InventoryManagementScreen extends StatefulWidget {
  final String userName;
  const InventoryManagementScreen({
    super.key,
    required this.userName,
  });

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen>
    with TickerProviderStateMixin {
  // Core State Variables
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _filteredInventory = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  // ✅ ENHANCED ERROR HANDLING VARIABLES
  Timer? _processingTimer;
  Timer? _debounceTimer;
  bool _isProcessingScan = false;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;
  static const int _maxDataLength = 10000;
  static const int _processingTimeout = 15;
  String? _lastProcessedData;

  // Search and Filter Controllers
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  Set<String> _categories = {'All'};

  // Picklist Controllers (Enhanced with validation)
  final TextEditingController _waveNumberController = TextEditingController();
  final TextEditingController _pickQuantityController = TextEditingController();
  final TextEditingController _locationCheckDigitController = TextEditingController();
  final TextEditingController _barcodeCheckDigitController = TextEditingController();
  final TextEditingController _pickerNameController = TextEditingController();
  final TextEditingController _pickLocationController = TextEditingController();
  final TextEditingController _pickBarcodeController = TextEditingController();
  String _selectedPriority = 'normal';

  // Add/Edit Item Controllers
  final TextEditingController _addNameController = TextEditingController();
  final TextEditingController _addSkuController = TextEditingController();
  final TextEditingController _addBarcodeController = TextEditingController();
  final TextEditingController _addDescriptionController = TextEditingController();
  final TextEditingController _addQuantityController = TextEditingController();
  final TextEditingController _addMinStockController = TextEditingController();
  final TextEditingController _addUnitPriceController = TextEditingController();
  final TextEditingController _addLocationController = TextEditingController();
  String _addSelectedCategory = 'General';

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInventory();
    _setupControllerListeners(); // ✅ ENHANCED LISTENERS
    _pickerNameController.text = widget.userName;
  }

  @override
  void dispose() {
    _processingTimer?.cancel();
    _debounceTimer?.cancel();
    _fadeController.dispose();
    _searchController.dispose();
    _waveNumberController.dispose();
    _pickQuantityController.dispose();
    _locationCheckDigitController.dispose();
    _barcodeCheckDigitController.dispose();
    _pickerNameController.dispose();
    _pickLocationController.dispose();
    _pickBarcodeController.dispose();
    _addNameController.dispose();
    _addSkuController.dispose();
    _addBarcodeController.dispose();
    _addDescriptionController.dispose();
    _addQuantityController.dispose();
    _addMinStockController.dispose();
    _addUnitPriceController.dispose();
    _addLocationController.dispose();
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

  // ✅ ENHANCED CONTROLLER LISTENERS WITH DEBOUNCING
  void _setupControllerListeners() {
    _searchController.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _filterInventory();
      });
    });
  }

  // ✅ ENHANCED VALIDATION HELPERS
  bool _isValidInput(String input, {int maxLength = 255}) {
    if (input.trim().isEmpty) return false;
    if (input.length > maxLength) return false;
    return true;
  }

  bool _isValidBarcodeFormat(String barcode) {
    try {
      if (barcode.length > _maxDataLength) return false;
      if (barcode.trim().isEmpty) return false;
      final uniqueChars = barcode.split('').toSet();
      if (uniqueChars.length < 3 && barcode.length > 10) return false;
      return true;
    } catch (e) {
      debugPrint('❌ Barcode format validation error: $e');
      return false;
    }
  }

  // ✅ CENTRALIZED ERROR HANDLING
  void _handleError(String title, dynamic error, {bool isRecoverable = false}) {
    _consecutiveErrors++;
    String errorMessage = error.toString();
    if (errorMessage.length > 200) {
      errorMessage = '${errorMessage.substring(0, 200)}...';
    }

    debugPrint('❌ Error ($title): $errorMessage');
    setState(() => _isLoading = false);
    
    _showErrorMessage('$title: $errorMessage');

    if (isRecoverable) {
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _showErrorRecoveryDialog();
      } else {
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _resetProcessingState();
          }
        });
      }
    }
    _resetProcessingState();
  }

  void _resetProcessingState() {
    _isProcessingScan = false;
    _processingTimer?.cancel();
    _lastProcessedData = null;
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ✅ ERROR RECOVERY DIALOG
  void _showErrorRecoveryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Multiple Errors Detected'),
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
              child: const Column(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Multiple operation errors detected. This may be due to:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Invalid data format\n'
                    '• Network connectivity issues\n'
                    '• Database problems\n'
                    '• Corrupted input data',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _consecutiveErrors = 0;
              _resetProcessingState();
            },
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _consecutiveErrors = 0;
              _loadInventory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  // ================================
  // HELPER METHODS FOR CHECK DIGITS
  // ================================
  String _generateLocationCheckDigit(String locationCode) {
    try {
      String numericPart = locationCode.replaceAll(RegExp(r'[^0-9]'), '');
      if (numericPart.length >= 2) {
        return numericPart.substring(numericPart.length - 2);
      }
      int sum = 0;
      for (int i = 0; i < locationCode.length; i++) {
        sum += locationCode.codeUnitAt(i);
      }
      return (sum % 100).toString().padLeft(2, '0');
    } catch (e) {
      return '00';
    }
  }

  String _generateBarcodeCheckDigit(String barcode) {
    try {
      String numericPart = barcode.replaceAll(RegExp(r'[^0-9]'), '');
      if (numericPart.length >= 3) {
        return numericPart.substring(numericPart.length - 3);
      }
      int sum = 0;
      for (int i = 0; i < barcode.length; i++) {
        sum += barcode.codeUnitAt(i);
      }
      return (sum % 1000).toString().padLeft(3, '0');
    } catch (e) {
      return '000';
    }
  }

  // ================================
  // DATA LOADING & FILTERING
  // ================================
  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final data = await WarehouseService.fetchInventory(limit: 1000);
      final categorySet = <String>{'All'};
      
      for (var item in data) {
        if (item['category'] != null) {
          categorySet.add(item['category']);
        }
      }

      if (mounted) {
        setState(() {
          _inventory = data;
          _filteredInventory = data;
          _categories = categorySet;
          _isLoading = false;
          _consecutiveErrors = 0; // Reset error count on success
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        _handleError('Failed to load inventory', e, isRecoverable: true);
      }
    }
  }

  void _filterInventory() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredInventory = _inventory.where((item) {
        final matchesSearch = searchTerm.isEmpty ||
            (item['name']?.toString().toLowerCase().contains(searchTerm) ?? false) ||
            (item['sku']?.toString().toLowerCase().contains(searchTerm) ?? false) ||
            (item['barcode']?.toString().toLowerCase().contains(searchTerm) ?? false);
        final matchesCategory = _selectedCategory == 'All' ||
            item['category'] == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  // ================================
  // ✅ NAVIGATION TO TOTAL ITEMS SCREEN
  // ================================
  void _navigateToTotalItemsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TotalItemsScreen(
          userName: widget.userName,
          inventoryItems: _inventory,
        ),
      ),
    ).then((_) => _loadInventory()); // Refresh when returning
  }

  // ================================
  // ADD NEW ITEM WITH ENHANCED VALIDATION
  // ================================
  void _showAddItemDialog() {
    _clearAddForm();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.add_box, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Add New Item')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_addNameController, 'Item Name *', Icons.inventory_2),
                const SizedBox(height: 16),
                _buildTextField(_addSkuController, 'SKU *', Icons.qr_code),
                const SizedBox(height: 16),
                _buildTextField(_addBarcodeController, 'Barcode *', Icons.qr_code_scanner),
                const SizedBox(height: 16),
                _buildTextField(_addDescriptionController, 'Description', Icons.description, maxLines: 2),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildNumberField(_addQuantityController, 'Quantity *', Icons.numbers)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNumberField(_addMinStockController, 'Min Stock *', Icons.warning)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildPriceField(_addUnitPriceController, 'Unit Price *', Icons.attach_money)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(_addLocationController, 'Location', Icons.place)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _handleAddItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  // ✅ ENHANCED ADD ITEM WITH PROCESSING TIMEOUT
  Future<void> _handleAddItem() async {
    if (_isProcessingScan) return;
    
    try {
      // Input validation
      if (!_isValidInput(_addNameController.text) ||
          !_isValidInput(_addSkuController.text) ||
          !_isValidInput(_addBarcodeController.text) ||
          !_isValidInput(_addQuantityController.text) ||
          !_isValidInput(_addMinStockController.text) ||
          !_isValidInput(_addUnitPriceController.text)) {
        _showErrorMessage('Please fill in all required fields with valid data');
        return;
      }

      final quantity = int.tryParse(_addQuantityController.text.trim());
      final minStock = int.tryParse(_addMinStockController.text.trim());
      final unitPrice = double.tryParse(_addUnitPriceController.text.trim());

      if (quantity == null || quantity < 0) {
        _showErrorMessage('Please enter a valid quantity');
        return;
      }
      if (minStock == null || minStock < 0) {
        _showErrorMessage('Please enter a valid minimum stock');
        return;
      }
      if (unitPrice == null || unitPrice < 0) {
        _showErrorMessage('Please enter a valid unit price');
        return;
      }

      Navigator.pop(context);

      // Set processing state with timeout
      _isProcessingScan = true;
      setState(() => _isLoading = true);

      _processingTimer = Timer(Duration(seconds: _processingTimeout), () {
        if (_isProcessingScan) {
          _handleError('Add item timeout', 'Operation took too long', isRecoverable: true);
          _resetProcessingState();
        }
      });

      final itemData = {
        'name': _addNameController.text.trim(),
        'sku': _addSkuController.text.trim(),
        'barcode': _addBarcodeController.text.trim(),
        'description': _addDescriptionController.text.trim(),
        'category': _addSelectedCategory,
        'quantity': quantity,
        'min_stock': minStock,
        'unit_price': unitPrice,
        'location': _addLocationController.text.trim().isEmpty ? 'Storage' : _addLocationController.text.trim(),
        'created_by': widget.userName,
      };

      final success = await WarehouseService.insertInventory(itemData);

      _processingTimer?.cancel();
      
      if (success) {
        _showSuccessMessage('Item added successfully!');
        await _loadInventory();
        _consecutiveErrors = 0;
      } else {
        _handleError('Failed to add item', 'Database operation failed', isRecoverable: true);
      }
    } catch (e) {
      _processingTimer?.cancel();
      _handleError('Add item error', e, isRecoverable: true);
    } finally {
      _resetProcessingState();
    }
  }

  void _clearAddForm() {
    _addNameController.clear();
    _addSkuController.clear();
    _addBarcodeController.clear();
    _addDescriptionController.clear();
    _addQuantityController.text = '1';
    _addMinStockController.text = '10';
    _addUnitPriceController.text = '0.00';
    _addLocationController.text = 'Storage';
    _addSelectedCategory = 'General';
  }

  // ================================
  // ✅ ENHANCED ADD TO PICKLIST WITH COMPREHENSIVE VALIDATION
  // ================================
  void _showAddToPicklistDialog(Map<String, dynamic> item) {
    if (_isProcessingScan) return;

    try {
      // ✅ PRE-FILL ALL FIELDS FROM ITEM DATA (EDITABLE) WITH VALIDATION
      _waveNumberController.clear();
      _pickQuantityController.text = (item['quantity'] ?? 1).toString();
      _pickLocationController.text = item['location'] ?? 'Storage';
      _pickBarcodeController.text = item['barcode'] ?? '';
      _locationCheckDigitController.text = item['location_check_digit']?.toString() ??
          _generateLocationCheckDigit(item['location'] ?? '');
      _barcodeCheckDigitController.text = item['barcode_digits']?.toString() ??
          _generateBarcodeCheckDigit(item['barcode'] ?? '');
      _pickerNameController.text = widget.userName;
      _selectedPriority = 'normal';

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.playlist_add, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Expanded(child: Text('Add to Voice Picklist')),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.mic, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Voice Picking Ready',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Item: ${item['name']}\nAvailable: ${item['quantity']} units\nLocation: ${item['location'] ?? 'Storage'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_waveNumberController, 'Wave Number *', Icons.waves,
                        hint: 'e.g., WAVE-001'),
                    const SizedBox(height: 16),
                    _buildNumberField(_pickQuantityController, 'Quantity to Pick *', Icons.numbers,
                        hint: 'Max: ${item['quantity']}'),
                    const SizedBox(height: 16),
                    _buildTextField(_pickLocationController, 'Pick Location *', Icons.place),
                    const SizedBox(height: 16),
                    _buildTextField(_pickBarcodeController, 'Barcode', Icons.qr_code),
                    const SizedBox(height: 16),
                    _buildTextField(_locationCheckDigitController, 'Location Check Digit', Icons.pin,
                        maxLength: 3, hint: 'e.g., 123'),
                    const SizedBox(height: 16),
                    _buildTextField(_barcodeCheckDigitController, 'Barcode Check Digit', Icons.verified,
                        maxLength: 4, hint: 'e.g., 1234'),
                    const SizedBox(height: 16),
                    _buildTextField(_pickerNameController, 'Picker Name *', Icons.person),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: const Icon(Icons.priority_high),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                        DropdownMenuItem(value: 'normal', child: Text('Normal Priority')),
                        DropdownMenuItem(value: 'high', child: Text('High Priority')),
                        DropdownMenuItem(value: 'urgent', child: Text('Urgent Priority')),
                      ],
                      onChanged: (value) => setDialogState(() => _selectedPriority = value ?? 'normal'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _handleAddToPicklist(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add to Picklist'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _handleError('Error opening picklist dialog', e, isRecoverable: true);
    }
  }

  // ✅ ENHANCED ADD TO PICKLIST WITH TIMEOUT AND VALIDATION
  Future<void> _handleAddToPicklist(Map<String, dynamic> item) async {
    if (_isProcessingScan) return;

    // Prevent duplicate processing
    final operationId = '${item['id']}_${_waveNumberController.text.trim()}';
    if (_lastProcessedData == operationId) {
      debugPrint('⚠️ Duplicate picklist operation detected, ignoring');
      return;
    }

    try {
      // Enhanced validation
      if (!_isValidInput(_waveNumberController.text) ||
          !_isValidInput(_pickQuantityController.text) ||
          !_isValidInput(_pickLocationController.text) ||
          !_isValidInput(_pickerNameController.text)) {
        _showErrorMessage('Please fill in all required fields with valid data');
        return;
      }

      final quantity = int.tryParse(_pickQuantityController.text.trim());
      if (quantity == null || quantity <= 0) {
        _showErrorMessage('Please enter a valid quantity');
        return;
      }

      final availableQuantity = (item['quantity'] ?? 0) as int;
      if (quantity > availableQuantity) {
        _showErrorMessage('Quantity exceeds available stock ($availableQuantity)');
        return;
      }

      Navigator.pop(context);

      _lastProcessedData = operationId;
      _isProcessingScan = true;
      setState(() => _isLoading = true);

      _processingTimer = Timer(Duration(seconds: _processingTimeout), () {
        if (_isProcessingScan) {
          _handleError('Picklist operation timeout', 'Operation took too long', isRecoverable: true);
          _resetProcessingState();
        }
      });

      final success = await WarehouseService.addInventoryToPicklist(
        inventoryId: item['id'],
        waveNumber: _waveNumberController.text.trim(),
        pickerName: _pickerNameController.text.trim(),
        quantityRequested: quantity,
        location: _pickLocationController.text.trim(),
        priority: _selectedPriority,
        locationCheckDigit: _locationCheckDigitController.text.trim().isEmpty
            ? null : _locationCheckDigitController.text.trim(),
        barcodeCheckDigit: _barcodeCheckDigitController.text.trim().isEmpty
            ? null : _barcodeCheckDigitController.text.trim(),
        barcodeNumber: _pickBarcodeController.text.trim().isEmpty
            ? item['barcode'] : _pickBarcodeController.text.trim(),
      );

      _processingTimer?.cancel();

      if (success) {
        _showSuccessMessage('Item added to voice picklist successfully!');
        _consecutiveErrors = 0;
      } else {
        _handleError('Failed to add item to picklist', 'Database operation failed', isRecoverable: true);
      }
    } catch (e) {
      _processingTimer?.cancel();
      _handleError('Picklist error', e, isRecoverable: true);
    } finally {
      _resetProcessingState();
    }
  }

  // ================================
  // ✅ ENHANCED INVENTORY CARD WITH DETAILED INFO
  // ================================
  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final name = item['name'] ?? "Unnamed";
    final sku = item['sku'] ?? "N/A";
    final quantity = (item['quantity'] ?? 0) as int;
    final minStock = (item['min_stock'] ?? 10) as int;
    final category = item['category'] ?? "General";
    final barcode = item['barcode'] ?? "N/A";
    final unitPrice = (item['unit_price'] ?? 0.0).toDouble();
    final totalValue = quantity * unitPrice;
    final description = item['description'] ?? "";
    final location = item['location'] ?? "Storage";

    Color statusColor = Colors.green;
    String status = 'In Stock';
    IconData statusIcon = Icons.check_circle;

    if (quantity == 0) {
      statusColor = Colors.red;
      status = 'Out of Stock';
      statusIcon = Icons.error;
    } else if (quantity <= minStock) {
      statusColor = Colors.orange;
      status = 'Low Stock';
      statusIcon = Icons.warning;
    }

    return Container(
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
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "SKU: $sku • Qty: $quantity",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleItemAction(value, item),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit_quantity',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Quantity'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'update_item',
                  child: Row(
                    children: [
                      Icon(Icons.update, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('Update Item'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_to_picklist',
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('Add to Picklist'),
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
                    // Basic Info
                    if (description.isNotEmpty) _buildDetailRow('Description', description),
                    _buildDetailRow('SKU', sku),
                    _buildDetailRow('Barcode', barcode),
                    _buildDetailRow('Location', location),
                    _buildDetailRow('Category', category),
                    
                    // Quantity & Stock Info
                    _buildDetailRow('Current Quantity', quantity.toString()),
                    _buildDetailRow('Minimum Stock', minStock.toString()),
                    _buildDetailRow('Unit Price', '\$${unitPrice.toStringAsFixed(2)}'),
                    _buildDetailRow('Total Value', '\$${totalValue.toStringAsFixed(2)}'),
                    
                    // ✅ ENHANCED: Voice Picking Check Digits
                    const SizedBox(height: 8),
                    const Divider(),
                    const Text(
                      'Voice Picking Check Digits:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Location Check Digit
                    _buildDetailRow(
                      'Location Check Digit',
                      item['location_check_digit']?.toString() ??
                          _generateLocationCheckDigit(location)
                    ),
                    
                    // Barcode Check Digits
                    _buildDetailRow(
                      'Barcode Check Digits',
                      item['barcode_digits']?.toString() ??
                          _generateBarcodeCheckDigit(barcode)
                    ),
                    
                    // Additional metadata
                    const SizedBox(height: 8),
                    const Divider(),
                    _buildDetailRow('Created By', item['created_by']?.toString() ?? 'System'),
                    _buildDetailRow('Last Updated', _formatDate(item['updated_at']?.toString() ?? '')),
                    
                    // Status and flags
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: item['is_active'] == true ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: item['is_active'] == true ? Colors.green : Colors.red,
                            ),
                          ),
                          child: Text(
                            item['is_active'] == true ? 'ACTIVE' : 'INACTIVE',
                            style: TextStyle(
                              color: item['is_active'] == true ? Colors.green : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessingScan ? null : () => _showEditQuantityDialog(item),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Qty'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessingScan ? null : () => _showAddToPicklistDialog(item),
                            icon: const Icon(Icons.mic, size: 18),
                            label: const Text('Voice Pick'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(barcode),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy Barcode'),
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

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return "—";
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr.length > 19 ? dateStr.substring(0, 19) : dateStr;
    }
  }

  void _copyToClipboard(String text) {
    try {
      Clipboard.setData(ClipboardData(text: text));
      _showSuccessMessage('Barcode copied to clipboard');
    } catch (e) {
      _showErrorMessage('Failed to copy barcode');
    }
  }

  // ================================
  // ITEM ACTIONS HANDLER WITH ENHANCED ERROR HANDLING
  // ================================
  void _handleItemAction(String action, Map<String, dynamic> item) {
    if (_isProcessingScan) return;
    
    try {
      switch (action) {
        case 'edit_quantity':
          _showEditQuantityDialog(item);
          break;
        case 'update_item':
          _showUpdateItemDialog(item);
          break;
        case 'add_to_picklist':
          _showAddToPicklistDialog(item);
          break;
        case 'delete':
          _showDeleteConfirmation(item);
          break;
      }
    } catch (e) {
      _handleError('Error handling action', e, isRecoverable: true);
    }
  }

  // ================================
  // ✅ ENHANCED EDIT QUANTITY DIALOG WITH PROCESSING TIMEOUT
  // ================================
  void _showEditQuantityDialog(Map<String, dynamic> item) {
    final quantityController = TextEditingController(
      text: (item['quantity'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Edit Quantity')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Item: ${item['name'] ?? 'Unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'New Quantity',
                prefixIcon: const Icon(Icons.numbers),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                helperText: 'Current: ${item['quantity'] ?? 0}',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isProcessingScan ? null : () => _handleUpdateQuantity(item, quantityController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: _isProcessingScan 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Update'),
          ),
        ],
      ),
    );
  }

  // ✅ ENHANCED UPDATE QUANTITY WITH TIMEOUT
  Future<void> _handleUpdateQuantity(Map<String, dynamic> item, String quantityText) async {
    if (_isProcessingScan) return;

    try {
      if (!_isValidInput(quantityText)) {
        _showErrorMessage('Please enter a valid quantity');
        return;
      }

      final newQuantity = int.tryParse(quantityText);
      if (newQuantity == null || newQuantity < 0) {
        _showErrorMessage('Please enter a valid quantity (0 or greater)');
        return;
      }

      _isProcessingScan = true;
      setState(() => _isLoading = true);

      _processingTimer = Timer(Duration(seconds: _processingTimeout), () {
        if (_isProcessingScan) {
          _handleError('Update quantity timeout', 'Operation took too long', isRecoverable: true);
          _resetProcessingState();
        }
      });

      final success = await WarehouseService.updateInventory(
        item['id'],
        {'quantity': newQuantity},
      );

      _processingTimer?.cancel();

      if (success) {
        Navigator.of(context).pop();
        _showSuccessMessage('Quantity updated successfully');
        await _loadInventory();
        _consecutiveErrors = 0;
      } else {
        _handleError('Failed to update quantity', 'Database operation failed', isRecoverable: true);
      }
    } catch (e) {
      _processingTimer?.cancel();
      _handleError('Update quantity error', e, isRecoverable: true);
    } finally {
      _resetProcessingState();
    }
  }

  // ================================
  // ✅ ENHANCED UPDATE ITEM DIALOG WITH VALIDATION
  // ================================
  void _showUpdateItemDialog(Map<String, dynamic> item) {
    // Pre-fill controllers with existing data
    _addNameController.text = item['name'] ?? '';
    _addSkuController.text = item['sku'] ?? '';
    _addBarcodeController.text = item['barcode'] ?? '';
    _addDescriptionController.text = item['description'] ?? '';
    _addQuantityController.text = (item['quantity'] ?? 0).toString();
    _addMinStockController.text = (item['min_stock'] ?? 10).toString();
    _addUnitPriceController.text = (item['unit_price'] ?? 0.0).toString();
    _addLocationController.text = item['location'] ?? 'Storage';
    _addSelectedCategory = item['category'] ?? 'General';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Update Item')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_addNameController, 'Item Name *', Icons.inventory_2),
                const SizedBox(height: 16),
                _buildTextField(_addSkuController, 'SKU *', Icons.qr_code, enabled: false), // SKU not editable
                const SizedBox(height: 16),
                _buildTextField(_addBarcodeController, 'Barcode *', Icons.qr_code_scanner),
                const SizedBox(height: 16),
                _buildTextField(_addDescriptionController, 'Description', Icons.description, maxLines: 2),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildNumberField(_addQuantityController, 'Quantity *', Icons.numbers)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNumberField(_addMinStockController, 'Min Stock *', Icons.warning)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildPriceField(_addUnitPriceController, 'Unit Price *', Icons.attach_money)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(_addLocationController, 'Location', Icons.place)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isProcessingScan ? null : () => _handleUpdateItem(item['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: _isProcessingScan 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Update'),
          ),
        ],
      ),
    );
  }

  // ✅ ENHANCED UPDATE ITEM WITH TIMEOUT
  Future<void> _handleUpdateItem(String itemId) async {
    if (_isProcessingScan) return;

    try {
      // Enhanced validation
      if (!_isValidInput(_addNameController.text) ||
          !_isValidInput(_addBarcodeController.text) ||
          !_isValidInput(_addQuantityController.text) ||
          !_isValidInput(_addMinStockController.text) ||
          !_isValidInput(_addUnitPriceController.text)) {
        _showErrorMessage('Please fill in all required fields with valid data');
        return;
      }

      final quantity = int.tryParse(_addQuantityController.text.trim());
      final minStock = int.tryParse(_addMinStockController.text.trim());
      final unitPrice = double.tryParse(_addUnitPriceController.text.trim());

      if (quantity == null || quantity < 0) {
        _showErrorMessage('Please enter a valid quantity');
        return;
      }
      if (minStock == null || minStock < 0) {
        _showErrorMessage('Please enter a valid minimum stock');
        return;
      }
      if (unitPrice == null || unitPrice < 0) {
        _showErrorMessage('Please enter a valid unit price');
        return;
      }

      Navigator.pop(context);

      _isProcessingScan = true;
      setState(() => _isLoading = true);

      _processingTimer = Timer(Duration(seconds: _processingTimeout), () {
        if (_isProcessingScan) {
          _handleError('Update item timeout', 'Operation took too long', isRecoverable: true);
          _resetProcessingState();
        }
      });

      final updates = {
        'name': _addNameController.text.trim(),
        'barcode': _addBarcodeController.text.trim(),
        'description': _addDescriptionController.text.trim(),
        'category': _addSelectedCategory,
        'quantity': quantity,
        'min_stock': minStock,
        'unit_price': unitPrice,
        'location': _addLocationController.text.trim(),
      };

      final success = await WarehouseService.updateInventory(itemId, updates);

      _processingTimer?.cancel();

      if (success) {
        _showSuccessMessage('Item updated successfully!');
        await _loadInventory();
        _consecutiveErrors = 0;
      } else {
        _handleError('Failed to update item', 'Database operation failed', isRecoverable: true);
      }
    } catch (e) {
      _processingTimer?.cancel();
      _handleError('Update item error', e, isRecoverable: true);
    } finally {
      _resetProcessingState();
    }
  }

  // ================================
  // DELETE ITEM DIALOG WITH ENHANCED CONFIRMATION
  // ================================
  void _showDeleteConfirmation(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Delete Item')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Are you sure you want to delete "${item['name'] ?? 'this item'}"?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This action cannot be undone.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isProcessingScan ? null : () => _handleDeleteItem(item['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: _isProcessingScan 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ✅ ENHANCED DELETE ITEM WITH TIMEOUT
  Future<void> _handleDeleteItem(String itemId) async {
    if (_isProcessingScan) return;

    try {
      _isProcessingScan = true;
      setState(() => _isLoading = true);

      _processingTimer = Timer(Duration(seconds: _processingTimeout), () {
        if (_isProcessingScan) {
          _handleError('Delete item timeout', 'Operation took too long', isRecoverable: true);
          _resetProcessingState();
        }
      });

      final success = await WarehouseService.deleteInventory(itemId);

      _processingTimer?.cancel();

      if (success) {
        Navigator.of(context).pop();
        _showSuccessMessage('Item deleted successfully');
        await _loadInventory();
        _consecutiveErrors = 0;
      } else {
        _handleError('Failed to delete item', 'Database operation failed', isRecoverable: true);
      }
    } catch (e) {
      _processingTimer?.cancel();
      _handleError('Delete item error', e, isRecoverable: true);
    } finally {
      _resetProcessingState();
    }
  }

  // ================================
  // ✅ ENHANCED EXPORT FUNCTIONALITY WITH TIMEOUT
  // ================================
  Future<void> _exportInventoryReport() async {
    if (_isExporting || _isProcessingScan) return;
    
    setState(() => _isExporting = true);
    
    try {
      _processingTimer = Timer(Duration(seconds: _processingTimeout * 2), () {
        if (_isExporting) {
          _handleError('Export timeout', 'Export operation took too long', isRecoverable: true);
          setState(() => _isExporting = false);
        }
      });

      final reportData = await WarehouseService.generateInventoryReport();
      
      if (reportData['error'] != null) {
        _processingTimer?.cancel();
        _showErrorMessage('Export failed: ${reportData['error']}');
        return;
      }

      List<List<dynamic>> csvData = [];

      // Report Header
      csvData.addAll([
        ['COMPREHENSIVE INVENTORY REPORT'],
        ['Generated on:', DateTime.now().toString()],
        ['Generated by:', widget.userName],
        ['Total Items:', reportData['total_items'].toString()],
        ['Low Stock Items:', reportData['low_stock_items'].toString()],
        ['Out of Stock Items:', reportData['out_of_stock_items'].toString()],
        ['Total Inventory Value:', '\$${reportData['total_inventory_value'].toStringAsFixed(2)}'],
        [],
      ]);

      // Category breakdown
      csvData.add(['CATEGORY BREAKDOWN:']);
      final categoryBreakdown = reportData['category_breakdown'] as Map<String, dynamic>;
      categoryBreakdown.forEach((category, count) {
        csvData.add([category, count.toString()]);
      });
      csvData.add([]);

      // Inventory Data Header
      csvData.add([
        'Item Name', 'SKU', 'Barcode', 'Description', 'Category',
        'Current Quantity', 'Minimum Stock', 'Unit Price', 'Total Value',
        'Stock Status', 'Location', 'Last Updated'
      ]);

      // Inventory items data
      final inventoryData = reportData['inventory_data'] as List<Map<String, dynamic>>;
      for (var item in inventoryData) {
        final quantity = item['quantity'] ?? 0;
        final minStock = item['min_stock'] ?? 10;
        final unitPrice = (item['unit_price'] ?? 0.0).toDouble();
        final totalValue = quantity * unitPrice;

        String stockStatus = 'In Stock';
        if (quantity == 0) {
          stockStatus = 'Out of Stock';
        } else if (quantity <= minStock) {
          stockStatus = 'Low Stock';
        }

        csvData.add([
          item['name'] ?? '',
          item['sku'] ?? '',
          item['barcode'] ?? '',
          item['description'] ?? '',
          item['category'] ?? 'General',
          quantity.toString(),
          minStock.toString(),
          unitPrice.toStringAsFixed(2),
          totalValue.toStringAsFixed(2),
          stockStatus,
          item['location'] ?? 'Storage',
          item['updated_at']?.toString().substring(0, 16) ?? '',
        ]);
      }

      String csvString = const ListToCsvConverter().convert(csvData);

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toString().replaceAll(':', '-').substring(0, 19);
      final file = File('${directory.path}/comprehensive_inventory_report_$timestamp.csv');
      await file.writeAsString(csvString);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Comprehensive Inventory Report - ${inventoryData.length} items, Total Value: \$${reportData['total_inventory_value'].toStringAsFixed(2)}',
      );

      _processingTimer?.cancel();
      _showSuccessMessage('Inventory report exported successfully!');
      _consecutiveErrors = 0;
    } catch (e) {
      _processingTimer?.cancel();
      _handleError('Export failed', e, isRecoverable: false);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // ================================
  // UTILITY WIDGETS WITH ENHANCED VALIDATION
  // ================================
  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {int? maxLines, bool enabled = true, String? hint, int? maxLength}) {
    return TextField(
      controller: controller,
      maxLines: maxLines ?? 1,
      maxLength: maxLength,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        counterText: maxLength != null ? '' : null,
      ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label, IconData icon, {String? hint}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildPriceField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _addSelectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: ['General', 'Electronics', 'Clothing', 'Food', 'Books', 'Tools', 'Other']
          .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
          .toList(),
      onChanged: (value) => setState(() => _addSelectedCategory = value ?? 'General'),
    );
  }

  // ✅ ENHANCED STAT CARD WITH NAVIGATION
  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getLowStockCount() {
    return _filteredInventory.where((item) {
      final qty = item['quantity'] ?? 0;
      final minStock = item['min_stock'] ?? 10;
      return qty > 0 && qty <= minStock;
    }).length;
  }

  int _getOutOfStockCount() {
    return _filteredInventory.where((item) => (item['quantity'] ?? 0) == 0).length;
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 14)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white70,
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    }
  }

  // ================================
  // ✅ ENHANCED BUILD METHOD WITH TOTAL ITEMS NAVIGATION
  // ================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📦 Enhanced Inventory Management"),
        backgroundColor: Colors.blue.withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadInventory,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Inventory',
          ),
          IconButton(
            onPressed: _isExporting || _isLoading ? null : _exportInventoryReport,
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
            tooltip: 'Export Comprehensive Report',
          ),
          IconButton(
            onPressed: _isProcessingScan ? null : _showAddItemDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add New Item',
          ),
        ],
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
          child: Column(
            children: [
              // Search and Filter Section
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, SKU, or barcode...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterInventory();
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category Filter',
                              prefixIcon: const Icon(Icons.category),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value ?? 'All';
                              });
                              _filterInventory();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ✅ ENHANCED Statistics Header with Navigation
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // ✅ TOTAL ITEMS WITH NAVIGATION
                    _buildStatCard(
                      'Total Items',
                      _filteredInventory.length.toString(),
                      Icons.inventory_2,
                      Colors.blue,
                      onTap: _navigateToTotalItemsScreen, // ✅ NAVIGATE TO TOTAL ITEMS
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Low Stock',
                      _getLowStockCount().toString(),
                      Icons.warning,
                      Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LowStockScreen(userName: widget.userName),
                          ),
                        ).then((_) => _loadInventory());
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Out of Stock',
                      _getOutOfStockCount().toString(),
                      Icons.error,
                      Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OutOfStockScreen(userName: widget.userName),
                          ),
                        ).then((_) => _loadInventory());
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Enhanced Error Display
              if (_consecutiveErrors > 0)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Errors detected: $_consecutiveErrors/$_maxConsecutiveErrors',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Inventory List
              Expanded(
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
                              "Loading inventory...",
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Error loading inventory",
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
                                  onPressed: _loadInventory,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredInventory.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "No inventory items found",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Add items using Storage Scanner or the + button",
                                      style: TextStyle(
                                        color: AppColors.textLight,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: _isProcessingScan ? null : _showAddItemDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add First Item'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadInventory,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredInventory.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredInventory[index];
                                    return _buildInventoryCard(item);
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
