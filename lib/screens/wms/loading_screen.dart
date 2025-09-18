// lib/screens/wms/loading_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../../utils/colors.dart';
import '../../services/warehouse_service.dart';

class LoadingScreen extends StatefulWidget {
  final String userName;
  const LoadingScreen({super.key, required this.userName});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  // Tab Controller for three sections
  late TabController _tabController;
  
  // Core State
  bool _isLoading = false;
  bool _hasTruckScanned = false;
  
  // Session Data
  String _truckNumber = '';
  String? _sessionId;
  List<Map<String, dynamic>> _scannedCartons = [];
  List<Map<String, dynamic>> _loadingReports = [];
  
  // Controllers
  final TextEditingController _truckController = TextEditingController();
  final TextEditingController _cartonController = TextEditingController();
  
  // Focus Nodes for hands-free scanning
  final FocusNode _cartonFocusNode = FocusNode();
  final FocusNode _truckFocusNode = FocusNode();
  
  // TTS
  FlutterTts? _flutterTts;
  
  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _initializeTTS();
    _setupHandsFreeScanning();
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _truckController.dispose();
    _cartonController.dispose();
    _cartonFocusNode.dispose();
    _truckFocusNode.dispose();
    _flutterTts?.stop();
    super.dispose();
  }

  void _initializeControllers() {
    _tabController = TabController(length: 3, vsync: this);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  Future<void> _initializeTTS() async {
    try {
      _flutterTts = FlutterTts();
      await _flutterTts?.setLanguage('en-US');
      await _flutterTts?.setSpeechRate(0.8);
      await _flutterTts?.setVolume(1.0);
    } catch (e) {
      debugPrint('TTS initialization failed: $e');
    }
  }

  Future<void> _speakMessage(String message) async {
    try {
      await _flutterTts?.stop();
      await _flutterTts?.speak(message);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  // HANDS-FREE BARCODE SCANNING SETUP
  void _setupHandsFreeScanning() {
    // Auto-focus carton field when truck is scanned
    _cartonFocusNode.addListener(() {
      if (_cartonFocusNode.hasFocus && _hasTruckScanned) {
        debugPrint('🎯 Carton field focused - ready for scanning');
      }
    });

    // Auto-focus truck field initially
    _truckFocusNode.addListener(() {
      if (_truckFocusNode.hasFocus && !_hasTruckScanned) {
        debugPrint('🎯 Truck field focused - ready for scanning');
      }
    });

    // Listen for truck barcode input
    _truckController.addListener(() {
      final truckCode = _truckController.text.trim();
      if (truckCode.length >= 6 && !_hasTruckScanned && !_isLoading) {
        // Auto-process truck scan after short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (truckCode == _truckController.text.trim()) {
            _handleTruckScan();
          }
        });
      }
    });

    // Listen for carton barcode input
    _cartonController.addListener(() {
      final cartonCode = _cartonController.text.trim();
      if (cartonCode.length >= 8 && _hasTruckScanned && !_isLoading) {
        // Auto-process carton scan after short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (cartonCode == _cartonController.text.trim()) {
            _handleCartonScan(cartonCode);
          }
        });
      }
    });
  }

  // Auto-focus management
  void _autoFocusFields() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasTruckScanned && _truckFocusNode.canRequestFocus) {
        _truckFocusNode.requestFocus();
      } else if (_hasTruckScanned && _cartonFocusNode.canRequestFocus) {
        _cartonFocusNode.requestFocus();
      }
    });
  }

  // LOAD REPORTS FROM DATABASE
  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await WarehouseService.getLoadingReports();
      setState(() {
        _loadingReports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Failed to load reports: ${e.toString()}', isError: true);
    }
  }

  // TRUCK SCANNING - HANDS-FREE
  Future<void> _handleTruckScan() async {
    final truckNumber = _truckController.text.trim().toUpperCase();
    if (truckNumber.isEmpty || truckNumber.length < 6) {
      _showMessage('Please scan valid truck license plate', isError: true);
      _truckController.clear();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await WarehouseService.startTruckCheckIn(
        vehicleNumber: truckNumber,
        driverName: 'Driver Name',
        userName: widget.userName,
      );

      if (result['success']) {
        setState(() {
          _truckNumber = truckNumber;
          _sessionId = result['session']['id'];
          _hasTruckScanned = true;
          _isLoading = false;
        });
        
        _showMessage('Truck $truckNumber ready for loading', isSuccess: true);
        await _speakMessage('Truck confirmed. Ready to scan cartons');
        
        // Auto-focus carton field for hands-free scanning
        _autoFocusFields();
        
      } else {
        setState(() => _isLoading = false);
        _truckController.clear();
        _showMessage(result['message'], isError: true);
        await _speakMessage(result['voice_message'] ?? 'Truck scan failed');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _truckController.clear();
      _showMessage('Truck scan failed: ${e.toString()}', isError: true);
      await _speakMessage('Truck scan failed');
    }
  }

  // CARTON SCANNING - HANDS-FREE
  Future<void> _handleCartonScan(String cartonBarcode) async {
    if (_sessionId == null) {
      _showMessage('No active session found', isError: true);
      _cartonController.clear();
      return;
    }

    // Check for duplicate in current session
    if (_scannedCartons.any((carton) => carton['carton_barcode'] == cartonBarcode)) {
      _cartonController.clear();
      _showMessage('Carton already scanned', isError: true);
      await _speakMessage('Duplicate carton');
      // Keep focus for next scan
      _cartonFocusNode.requestFocus();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await WarehouseService.scanCarton(
        sessionId: _sessionId!,
        cartonBarcode: cartonBarcode,
        scannedBy: widget.userName,
      );

      setState(() => _isLoading = false);
      _cartonController.clear();

      if (result['success']) {
        await _refreshCartonScans();
        final count = _scannedCartons.length;
        _showMessage('Carton $count loaded successfully', isSuccess: true);
        await _speakMessage('Carton $count confirmed');
      } else {
        _showMessage(result['message'], isError: true);
        await _speakMessage(result['voice_message'] ?? 'Carton rejected');
      }
      
      // Keep focus for continuous scanning
      _cartonFocusNode.requestFocus();
      
    } catch (e) {
      setState(() => _isLoading = false);
      _cartonController.clear();
      _showMessage('Carton scan failed: ${e.toString()}', isError: true);
      await _speakMessage('Carton scan failed');
      // Keep focus for next attempt
      _cartonFocusNode.requestFocus();
    }
  }

  // REFRESH CARTON SCANS FROM DATABASE
  Future<void> _refreshCartonScans() async {
    if (_sessionId == null) return;
    try {
      final sessionDetails = await WarehouseService.getLoadingSessionDetails(_sessionId!);
      if (sessionDetails != null) {
        setState(() {
          _scannedCartons = List<Map<String, dynamic>>.from(
            sessionDetails['carton_scans'] ?? []
          );
        });
      }
    } catch (e) {
      debugPrint('Failed to refresh carton scans: $e');
    }
  }

  // COMPLETE LOADING
  Future<void> _handleCompleteLoading() async {
    if (_scannedCartons.isEmpty) {
      _showMessage('No cartons scanned yet', isError: true);
      return;
    }

    if (_sessionId == null) {
      _showMessage('No active session found', isError: true);
      return;
    }

    final shouldComplete = await _showCompleteDialog();
    if (!shouldComplete) return;

    setState(() => _isLoading = true);
    try {
      final result = await WarehouseService.completeLoading(
        sessionId: _sessionId!,
        completedBy: widget.userName,
      );

      if (result['success']) {
        await _createReport();
        await _loadReports();
        setState(() => _isLoading = false);
        _showMessage('Loading completed! Report generated', isSuccess: true);
        await _speakMessage('Loading completed successfully. Report generated');
        _tabController.animateTo(2);
      } else {
        setState(() => _isLoading = false);
        _showMessage('Completion failed: ${result['message']}', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Completion failed: ${e.toString()}', isError: true);
    }
  }

  Future<bool> _showCompleteDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Complete Loading?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Truck: $_truckNumber'),
            Text('Cartons Scanned: ${_scannedCartons.length}'),
            const SizedBox(height: 16),
            const Text('This will create a loading report and complete the session.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete & Create Report'),
          ),
        ],
      ),
    ) ?? false;
  }

  // CREATE AND EXPORT REPORT
  Future<void> _createReport() async {
    try {
      final result = await WarehouseService.createLoadingReport(
        truckNumber: _truckNumber,
        cartonsLoaded: _scannedCartons.length,
        totalCartons: _scannedCartons.length,
        operator: widget.userName,
        destination: 'Main Distribution Center',
        cartonDetails: _scannedCartons,
      );

      if (result['success']) {
        await _exportReport(result['report']);
      } else {
        _showMessage('Failed to create report: ${result['message']}', isError: true);
      }
    } catch (e) {
      _showMessage('Failed to create report: ${e.toString()}', isError: true);
    }
  }

  Future<void> _exportReport(Map<String, dynamic> report) async {
    try {
      final timestamp = DateTime.now().toString().replaceAll(':', '-').substring(0, 19);
      List<List<dynamic>> csvData = [
        ['LOADING DOCK REPORT'],
        ['Report ID:', report['id']?.toString() ?? 'N/A'],
        ['Generated:', DateTime.now().toString()],
        ['Truck Number:', report['truck_number'] ?? _truckNumber],
        ['Total Cartons:', report['total_cartons']?.toString() ?? _scannedCartons.length.toString()],
        ['Loaded Cartons:', report['cartons_loaded']?.toString() ?? _scannedCartons.length.toString()],
        ['Completion Rate:', '${report['completion_rate'] ?? 100}%'],
        ['Operator:', report['operator'] ?? widget.userName],
        ['Destination:', report['destination'] ?? 'Main Distribution Center'],
        ['Status:', report['status'] ?? 'Completed'],
        [],
        ['CARTON DETAILS:'],
        ['#', 'Barcode', 'Timestamp', 'Status', 'Scanned By'],
      ];

      for (int i = 0; i < _scannedCartons.length; i++) {
        final carton = _scannedCartons[i];
        csvData.add([
          (i + 1).toString(),
          carton['carton_barcode'] ?? '',
          carton['scan_timestamp']?.toString().substring(0, 19) ?? '',
          carton['status'] ?? 'loaded',
          carton['scanned_by'] ?? widget.userName,
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/loading_report_${_truckNumber}_$timestamp.csv');
      await file.writeAsString(csvString);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      _showMessage('Export failed: ${e.toString()}', isError: true);
    }
  }

  // REPORT MANAGEMENT METHODS
  Future<void> _updateReport(String reportId, Map<String, dynamic> updates) async {
    setState(() => _isLoading = true);
    try {
      final success = await WarehouseService.updateLoadingReport(reportId, updates);
      if (success) {
        await _loadReports();
        _showMessage('Report updated successfully', isSuccess: true);
      } else {
        _showMessage('Update failed', isError: true);
      }
    } catch (e) {
      _showMessage('Update failed: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReport(String reportId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Report'),
          ],
        ),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldDelete) return;

    setState(() => _isLoading = true);
    try {
      final success = await WarehouseService.deleteLoadingReport(reportId);
      if (success) {
        await _loadReports();
        _showMessage('Report deleted successfully', isSuccess: true);
      } else {
        _showMessage('Delete failed', isError: true);
      }
    } catch (e) {
      _showMessage('Delete failed: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshReports() async {
    await _loadReports();
    _showMessage('Reports refreshed', isSuccess: true);
  }

  Future<void> _exportExistingReport(Map<String, dynamic> report) async {
    try {
      final result = await WarehouseService.exportLoadingReportCSV(report['id']);
      if (result['success']) {
        await _exportReport(result['report']);
        _showMessage('Report exported successfully', isSuccess: true);
      } else {
        _showMessage('Export failed: ${result['message']}', isError: true);
      }
    } catch (e) {
      _showMessage('Export failed: ${e.toString()}', isError: true);
    }
  }

  // RESET SESSION
  void _resetSession() {
    setState(() {
      _hasTruckScanned = false;
      _truckNumber = '';
      _sessionId = null;
      _scannedCartons.clear();
    });
    _truckController.clear();
    _cartonController.clear();
    _tabController.animateTo(0);
    // Auto-focus truck field for new session
    _autoFocusFields();
  }

  // UI BUILDERS
  Widget _buildScanningTab() {
    // Auto-focus when tab is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoFocusFields());
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Truck Section
          _buildTruckSection(),
          if (_hasTruckScanned) ...[
            const SizedBox(height: 20),
            // Carton Section
            _buildCartonSection(),
            const SizedBox(height: 20),
            // Complete Button
            _buildCompleteButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildTruckSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _hasTruckScanned ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _hasTruckScanned ? Icons.check_circle : Icons.local_shipping,
            size: 48,
            color: _hasTruckScanned ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            _hasTruckScanned ? '✅ Truck Confirmed' : '🚛 Scan Truck',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _hasTruckScanned ? Colors.green : Colors.orange,
            ),
          ),
          if (_hasTruckScanned) ...[
            const SizedBox(height: 8),
            Text(
              _truckNumber,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            // HANDS-FREE TRUCK SCANNING FIELD
            TextField(
              controller: _truckController,
              focusNode: _truckFocusNode,
              decoration: InputDecoration(
                labelText: 'Truck License Plate',
                hintText: 'Scan truck barcode here',
                prefixIcon: const Icon(Icons.local_shipping),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.qr_code_scanner, color: Colors.orange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabled: !_isLoading,
              ),
              textCapitalization: TextCapitalization.characters,
              autofocus: true, // Auto-focus for hands-free scanning
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleTruckScan(),
            ),
            const SizedBox(height: 8),
            Text(
              '📱 Scan truck barcode to auto-fill',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartonSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.inventory, size: 32, color: Colors.green),
              const SizedBox(width: 12),
              Text(
                '📦 Scan Cartons (${_scannedCartons.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // HANDS-FREE CARTON SCANNING FIELD
          TextField(
            controller: _cartonController,
            focusNode: _cartonFocusNode,
            decoration: InputDecoration(
              labelText: 'Carton Barcode',
              hintText: 'Scan carton barcode here',
              prefixIcon: const Icon(Icons.qr_code),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.qr_code_scanner, color: Colors.green),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabled: !_isLoading,
            ),
            autofocus: _hasTruckScanned, // Auto-focus when truck is scanned
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 8),
          Text(
            '📱 Scan carton barcodes to auto-process',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_scannedCartons.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Scans:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    '${_scannedCartons.length} cartons',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompleteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_scannedCartons.isEmpty || _isLoading)
            ? null
            : _handleCompleteLoading,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check_circle),
        label: Text(_isLoading ? 'Completing...' : 'Complete Loading & Create Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.analytics, size: 40, color: Colors.blue),
                const SizedBox(height: 12),
                const Text(
                  'Current Session',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Truck', _hasTruckScanned ? _truckNumber : 'Not Scanned', Colors.orange),
                    _buildStatCard('Cartons', _scannedCartons.length.toString(), Colors.green),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Carton List
          if (_scannedCartons.isEmpty)
            _buildEmptyState()
          else
            _buildCartonList(),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        // Header with refresh button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.assessment, size: 28, color: Colors.blue),
              const SizedBox(width: 12),
              const Text(
                'Loading Reports',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _isLoading ? null : _refreshReports,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Refresh Reports',
              ),
            ],
          ),
        ),
        // Reports List
        Expanded(
          child: _isLoading && _loadingReports.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _loadingReports.isEmpty
                  ? _buildNoReportsState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _loadingReports.length,
                      itemBuilder: (context, index) {
                        return _buildReportCard(_loadingReports[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: report['status'] == 'active' ? Colors.green : Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  report['created_at']?.toString().substring(0, 16) ?? 'No date',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Truck Info
            Row(
              children: [
                const Icon(Icons.local_shipping, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  report['vehicle_number'] ?? 'Unknown Truck',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${report['completion_rate'] ?? 0}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: (report['completion_rate'] ?? 0) >= 90 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Details
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cartons: ${report['cartons_loaded'] ?? 0}',
                  style: const TextStyle(color: AppColors.textLight),
                ),
                Text(
                  'Operator: ${report['checked_in_by'] ?? 'Unknown'}',
                  style: const TextStyle(color: AppColors.textLight),
                ),
                Text(
                  'Destination: ${report['destination'] ?? 'Not specified'}',
                  style: const TextStyle(color: AppColors.textLight),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportExistingReport(report),
                    icon: const Icon(Icons.file_download, size: 16),
                    label: const Text('Export'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditReportDialog(report),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteReport(report['id']),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
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

  void _showEditReportDialog(Map<String, dynamic> report) {
    final destinationController = TextEditingController(text: report['destination'] ?? '');
    final statusController = TextEditingController(text: report['status'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: statusController.text.isNotEmpty ? statusController.text : 'active',
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: ['active', 'completed', 'cancelled']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) => statusController.text = value ?? 'active',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateReport(report['id'], {
                'destination': destinationController.text,
                'status': statusController.text,
              });
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No cartons scanned yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start scanning carton barcodes',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoReportsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No reports available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete loading sessions to generate reports',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartonList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Scanned Cartons',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_scannedCartons.length} items',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _scannedCartons.length,
            itemBuilder: (context, index) {
              final carton = _scannedCartons[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                title: Text(
                  carton['carton_barcode'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  carton['scan_timestamp']?.toString().substring(11, 19) ?? 'No timestamp',
                  style: const TextStyle(color: AppColors.textLight),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    carton['status']?.toString().toUpperCase() ?? 'LOADED',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚛 Loading Dock'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasTruckScanned || _scannedCartons.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetSession,
              tooltip: 'New Session',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.qr_code_scanner),
              text: 'Scanning',
            ),
            Tab(
              icon: Icon(Icons.list_alt),
              text: 'Details',
            ),
            Tab(
              icon: Icon(Icons.assessment),
              text: 'Reports',
            ),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildScanningTab(),
            _buildDetailsTab(),
            _buildReportsTab(),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    
    Color backgroundColor = Colors.blue;
    if (isError) backgroundColor = Colors.red;
    if (isSuccess) backgroundColor = Colors.green;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }
}
