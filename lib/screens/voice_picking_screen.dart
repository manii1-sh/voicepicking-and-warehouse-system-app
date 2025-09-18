// lib/screens/voice_picking_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../controllers/voice_picking_controller.dart';
import '../utils/colors.dart';
import 'login_screen.dart';
import 'wms/wms_main_screen.dart';
import 'profile_screen.dart';
import 'voice_settings_screen.dart';

class VoicePickingScreen extends StatefulWidget {
  final String userName;

  const VoicePickingScreen({
    super.key,
    this.userName = 'manishpardhi3023',
  });

  @override
  State<VoicePickingScreen> createState() => _VoicePickingScreenState();
}

class _VoicePickingScreenState extends State<VoicePickingScreen>
    with TickerProviderStateMixin {
  // ================================
  // CONTROLLER AND UI STATE
  // ================================
  late VoicePickingController _controller;
  int _selectedNavIndex = 0;
  bool _isRefreshing = false;

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _statusController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Color?> _statusColorAnimation;

  // EDA51 Scanner Components
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  // ================================
  // INITIALIZATION
  // ================================
  @override
  void initState() {
    super.initState();
    _controller = VoicePickingController(userName: widget.userName);
    _initializeAnimations();
    _setupEDA51Scanner();
    _controller.addListener(_onControllerUpdate);
  }

  void _initializeAnimations() {
    try {
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this,
      );
      _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _statusController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );

      _pulseAnimation = Tween<double>(
        begin: 1.0,
        end: 1.15,
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));

      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ));

      _statusColorAnimation = ColorTween(
        begin: AppColors.success,
        end: AppColors.primaryPink,
      ).animate(CurvedAnimation(
        parent: _statusController,
        curve: Curves.easeInOut,
      ));

      _fadeController.forward();
      _statusController.repeat(reverse: true);

      debugPrint('✅ Animations initialized successfully');
    } catch (e) {
      debugPrint('❌ Animation initialization error: $e');
    }
  }

  void _setupEDA51Scanner() {
    try {
      debugPrint('🔧 Setting up EDA51 scanner text field integration...');
      _barcodeController.addListener(() {
        String text = _barcodeController.text;
        debugPrint('📱 EDA51 Text field changed: $text');
      });
      debugPrint('✅ EDA51 scanner text field integration ready');
    } catch (e) {
      debugPrint('❌ EDA51 scanner setup error: $e');
      _showWarningMessage('EDA51 scanner setup failed');
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {
        if (_controller.isListening) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }

        if (_controller.isWaitingForScan) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _controller.isWaitingForScan) {
              _barcodeFocusNode.requestFocus();
            }
          });
        } else {
          _barcodeFocusNode.unfocus();
        }
      });
    }
  }

  // ================================
  // ENHANCED REFRESH FUNCTIONALITY
  // ================================
  Future<void> _refreshData() async {
    try {
      setState(() => _isRefreshing = true);
      debugPrint('🔄 Refreshing voice picking data...');

      await _controller.refreshPicklistData();

      final itemCount = _controller.pickingItems.length;
      if (itemCount > 0) {
        _showSuccessMessage('Data refreshed! $itemCount items assigned and ready for voice picking.');
      } else {
        _showWarningMessage('No picking tasks assigned. Add items via Inventory Management.');
      }

      debugPrint('✅ Voice picking data refreshed - $itemCount items');
    } catch (e) {
      debugPrint('❌ Refresh error: $e');
      _showErrorMessage('Failed to refresh data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ================================
  // EDA51 SCANNER METHODS
  // ================================
  void _handleBarcodeInput(String scannedBarcode) {
    try {
      if (!_controller.isWaitingForScan || scannedBarcode.trim().isEmpty) return;
      _barcodeController.clear();
      _controller.handleBarcodeInput(scannedBarcode);
    } catch (e) {
      debugPrint('❌ Handle barcode input error: $e');
      _showErrorMessage('Failed to process scanned barcode: ${e.toString()}');
    }
  }

  // ================================
  // ✅ UPDATED: HANDS-FREE START/STOP FUNCTIONALITY
  // ================================
  void _handleStartStop() {
    try {
      if (_controller.currentState.name == 'idle') {
        // ✅ Start hands-free session
        debugPrint('🎯 Starting hands-free picking session');
        _controller.startPickingSession();
        _showSuccessMessage('Hands-free mode activated! Say "READY" to begin.');
      } else {
        debugPrint('⏹️ Stopping picking session');
        _controller.resetSession();
      }
    } catch (e) {
      debugPrint('❌ Start/Stop error: $e');
      _showErrorMessage('Failed to start/stop session: ${e.toString()}');
    }
  }

  // ================================
  // ✅ UPDATED: HANDS-FREE MICROPHONE BUTTON
  // ================================
  void _handleMicrophoneButtonTap() {
    try {
      HapticFeedback.lightImpact();

      if (!_controller.speechEnabled) {
        debugPrint('⚠️ Speech not enabled - attempting reinitialization');
        // Note: _controller.initializeVoiceServices() is private, so we handle this differently
        _showErrorMessage('Voice services unavailable. Please restart the app.');
        return;
      }

      if (_controller.currentState.name == 'idle') {
        // ✅ Start hands-free session with one tap
        debugPrint('🎤 Starting hands-free picking session...');
        _controller.startPickingSession();
        _showSuccessMessage('Hands-free mode activated! Say "READY" to begin.');
      } else if (_controller.isHandsFreeModeActive) {
        // Show status message - no need to tap again
        _showSuccessMessage('Hands-free mode is active. Just speak your commands.');
      } else {
        // Fallback for manual mode (shouldn't happen in hands-free implementation)
        _showWarningMessage('Session is active. Use voice commands or reset to restart.');
      }
    } catch (e) {
      debugPrint('❌ Microphone button error: $e');
      _showErrorMessage('Microphone error: ${e.toString()}');
    }
  }

  // ================================
  // UI BUILD METHODS
  // ================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildSystemStatus(),
                        const SizedBox(height: 8),
                        _buildEDA51ScannerField(),
                        const SizedBox(height: 8),
                        _buildCurrentItemDisplay(),
                        const SizedBox(height: 8),
                        _buildVoiceControlCenter(),
                        const SizedBox(height: 8),
                        _buildQuickActions(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                _buildBottomNavigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================================
  // ENHANCED HEADER WITH REAL-TIME STATS
  // ================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.headset_mic_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Voice Picking',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    // ✅ Hands-free mode indicator in header
                    if (_controller.isHandsFreeModeActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HANDS-FREE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Welcome, ${widget.userName} • ${_controller.pickingItems.length} items assigned',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _isRefreshing ? null : _refreshData,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.primaryPink.withOpacity(0.3),
                    ),
                  ),
                  child: _isRefreshing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryPink,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.primaryPink,
                          size: 14,
                        ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _handleLogout,
              icon: const Icon(
                Icons.logout,
                color: AppColors.error,
                size: 16,
              ),
              tooltip: 'Logout',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.error.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(28, 28),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _getSystemStatusColor(),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              _getSystemStatusIcon(),
              color: Colors.white,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _statusColorAnimation,
                builder: (context, child) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _statusColorAnimation.value ?? _getStatusColor(),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              const Text(
                'System Status',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
              const Spacer(),
              Text(
                _getStatusText(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.lightPink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Last: ${_controller.lastInstruction}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.primaryPink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEDA51ScannerField() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _controller.isWaitingForScan
            ? AppColors.primaryPink.withOpacity(0.1)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _controller.isWaitingForScan
              ? AppColors.primaryPink
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code_scanner,
                color: _controller.isWaitingForScan
                    ? AppColors.primaryPink
                    : Colors.grey.shade600,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _controller.isWaitingForScan
                      ? 'Press EDA51 side button to scan'
                      : 'EDA51 Scanner Ready',
                  style: TextStyle(
                    color: _controller.isWaitingForScan
                        ? AppColors.primaryPink
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _barcodeController,
            focusNode: _barcodeFocusNode,
            enabled: true,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              labelText: 'EDA51 Barcode Scanner',
              labelStyle: const TextStyle(fontSize: 11),
              hintText: _controller.isWaitingForScan
                  ? 'Press EDA51 side button...'
                  : 'Scan will appear here',
              hintStyle: const TextStyle(fontSize: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              prefixIcon: const Icon(Icons.qr_code, size: 16),
              suffixIcon: _barcodeController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => _barcodeController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
            ),
            onChanged: (value) {
              debugPrint('📱 EDA51 Input changed: $value');
              if (value.contains('\n') || value.contains('\r')) {
                String cleanBarcode = value.trim();
                if (cleanBarcode.isNotEmpty && _controller.isWaitingForScan) {
                  _handleBarcodeInput(cleanBarcode);
                }
              }
            },
            onSubmitted: (value) {
              debugPrint('📱 EDA51 Input submitted: $value');
              if (value.isNotEmpty && _controller.isWaitingForScan) {
                _handleBarcodeInput(value);
              }
            },
          ),
          const SizedBox(height: 4),
          Text(
            _controller.isWaitingForScan
                ? '1. Press EDA51 side scan button\n2. Barcode will appear above automatically'
                : 'Scanner ready for next item',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentItemDisplay() {
    if (_controller.currentItemDetails == null || _controller.currentState.name == 'idle') {
      return const SizedBox.shrink();
    }

    final currentItem = _controller.currentItemDetails!;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.inventory_2,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item ${_controller.currentItemIndex + 1} of ${_controller.pickingItems.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textLight,
                      ),
                    ),
                    Text(
                      currentItem['item_name'] ?? 'Unknown Item',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildItemInfoCard(
                'Location',
                currentItem['location'] ?? 'N/A',
                Icons.place_outlined,
                AppColors.primaryPink,
              ),
              const SizedBox(width: 6),
              _buildItemInfoCard(
                'Assigned',
                '${currentItem['quantity_requested'] ?? 0}',
                Icons.assignment_outlined,
                Colors.blue,
              ),
              const SizedBox(width: 6),
              _buildItemInfoCard(
                'SKU',
                currentItem['sku'] ?? 'N/A',
                Icons.qr_code_outlined,
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemInfoCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 12,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: color.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ================================
  // ✅ ENHANCED: HANDS-FREE VOICE CONTROL CENTER
  // ================================
  Widget _buildVoiceControlCenter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Voice Control Center',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              // ✅ Hands-free indicator
              if (_controller.isHandsFreeModeActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'HANDS-FREE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _handleMicrophoneButtonTap,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _controller.isListening ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: _controller.isListening || _controller.currentState.name != 'idle'
                          ? AppColors.primaryGradient
                          : LinearGradient(
                              colors: [
                                AppColors.primaryPink.withOpacity(0.3),
                                AppColors.primaryPink.withOpacity(0.5),
                              ],
                            ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPink.withOpacity(_controller.isListening ? 0.4 : 0.2),
                          blurRadius: _controller.isListening ? 15 : 6,
                          spreadRadius: _controller.isListening ? 3 : 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          _getMicrophoneIcon(),
                          size: 32,
                          color: Colors.white,
                        ),
                        // ✅ Hands-free mode indicator
                        if (_controller.isHandsFreeModeActive)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getMicrophoneButtonText(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textLight,
            ),
          ),
          if (_controller.isListening) ...[
            const SizedBox(height: 8),
            Column(
              children: [
                Text(
                  'Listening... ${(_controller.soundLevel * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryPink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _controller.soundLevel.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_controller.userInput.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'You said: "${_controller.userInput}"',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  if (_controller.originalVoiceInput.isNotEmpty &&
                      _controller.originalVoiceInput != _controller.userInput) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Original: "${_controller.originalVoiceInput}"',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================================
  // COMPACT QUICK ACTIONS
  // ================================
  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildSmallQuickActionButton(
                icon: _controller.currentState.name == 'idle'
                    ? Icons.play_arrow_rounded
                    : Icons.stop_rounded,
                label: _controller.currentState.name == 'idle' ? 'Start' : 'Stop',
                onTap: _handleStartStop,
                color: _controller.currentState.name == 'idle'
                    ? AppColors.success
                    : AppColors.error,
              ),
              const SizedBox(width: 4),
              _buildSmallQuickActionButton(
                icon: Icons.refresh_rounded,
                label: 'Reset',
                onTap: _controller.currentState.name != 'idle'
                    ? _controller.resetSession
                    : null,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
              _buildSmallQuickActionButton(
                icon: Icons.settings_rounded,
                label: 'Settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoiceSettingsScreen(
                        userName: widget.userName,
                        onSettingsChanged: () {
                          _controller.updateVoiceSettings();
                        },
                      ),
                    ),
                  );
                },
                color: AppColors.primaryPink,
              ),
              const SizedBox(width: 4),
              _buildSmallQuickActionButton(
                icon: Icons.person_rounded,
                label: 'Profile',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userName: widget.userName,
                      ),
                    ),
                  );
                },
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            decoration: BoxDecoration(
              color: onTap != null
                  ? color.withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: onTap != null
                    ? color.withOpacity(0.3)
                    : Colors.grey.shade300,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: onTap != null ? color : Colors.grey.shade400,
                  size: 14,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: onTap != null ? color : Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
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

  // ================================
  // ENHANCED BOTTOM NAVIGATION WITH AUTO-REFRESH
  // ================================
  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              isActive: _selectedNavIndex == 0,
              onTap: () => _handleNavigation(0),
            ),
            _buildNavItem(
              icon: Icons.warehouse_rounded,
              label: 'WMS',
              isActive: _selectedNavIndex == 1,
              onTap: () => _handleNavigation(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryPink : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.grey.shade600,
                  size: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? AppColors.primaryPink : Colors.grey.shade600,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================
  // HELPER METHODS
  // ================================
  Color _getSystemStatusColor() {
    if (!_controller.isSystemReady || !_controller.speechEnabled) return AppColors.error;
    switch (_controller.voiceStatus.name) {
      case 'listening':
        return AppColors.success;
      case 'processing':
      case 'retrying':
        return AppColors.warning;
      case 'error':
        return AppColors.error;
      default:
        return AppColors.primaryPink;
    }
  }

  IconData _getSystemStatusIcon() {
    if (!_controller.isSystemReady) return Icons.hourglass_empty;
    if (!_controller.speechEnabled) return Icons.error;
    switch (_controller.voiceStatus.name) {
      case 'listening':
        return Icons.mic;
      case 'processing':
        return Icons.psychology;
      case 'retrying':
        return Icons.refresh;
      case 'error':
        return Icons.error;
      default:
        return Icons.check;
    }
  }

  Color _getStatusColor() {
    switch (_controller.voiceStatus.name) {
      case 'listening':
        return AppColors.success;
      case 'processing':
      case 'retrying':
        return AppColors.warning;
      case 'error':
        return AppColors.error;
      default:
        return _controller.speechEnabled ? AppColors.primaryPink : AppColors.error;
    }
  }

  String _getStatusText() {
    if (!_controller.isDataLoaded) return 'LOADING';
    if (!_controller.speechEnabled) return 'ERROR';
    
    // ✅ Show hands-free status
    if (_controller.isHandsFreeModeActive) {
      switch (_controller.voiceStatus.name) {
        case 'listening':
          return 'HANDS-FREE LISTENING';
        case 'processing':
          return 'HANDS-FREE PROCESSING';
        default:
          return 'HANDS-FREE ACTIVE';
      }
    }
    
    switch (_controller.voiceStatus.name) {
      case 'initializing':
        return 'STARTING';
      case 'listening':
        return 'LISTENING';
      case 'processing':
        return 'PROCESSING';
      case 'retrying':
        return 'RETRYING';
      case 'error':
        return 'ERROR';
      default:
        switch (_controller.currentState.name) {
          case 'idle':
            return 'READY';
          case 'ready':
          case 'readyWait':
            return 'WAITING';
          case 'locationCheck':
            return 'LOCATION';
          case 'itemCheck':
            return 'ITEM CHECK';
          case 'barcodeScanning':
            return _controller.isWaitingForScan ? 'SCANNING' : 'SCANNED';
          case 'completed':
            return 'COMPLETED';
          default:
            return 'IDLE';
        }
    }
  }

  IconData _getMicrophoneIcon() {
    if (_controller.isListening) return Icons.mic;
    if (_controller.isProcessing) return Icons.psychology;
    return Icons.mic_none_rounded;
  }

  // ✅ UPDATED: Enhanced microphone button text with hands-free status
  String _getMicrophoneButtonText() {
    if (!_controller.isSystemReady) return 'System Initializing...';
    if (!_controller.speechEnabled) return 'Voice Not Available';
    if (_controller.isWaitingForScan) return 'Waiting for EDA51 Scanner...';
    
    switch (_controller.voiceStatus.name) {
      case 'initializing':
        return 'Initializing Voice Services...';
      case 'listening':
        return _controller.isHandsFreeModeActive 
          ? 'Hands-Free Mode Active...' 
          : 'Listening for Your Command...';
      case 'processing':
        return 'Processing Your Command...';
      case 'retrying':
        return 'Retrying Voice Recognition...';
      case 'error':
        return 'Voice Error - Tap to Retry';
      default:
        if (_controller.currentState.name == 'idle') {
          return 'Tap Once to Start Hands-Free Mode';
        } else if (_controller.isHandsFreeModeActive) {
          return 'Hands-Free Mode Active';
        } else {
          return 'Tap for Voice Input';
        }
    }
  }

  // ================================
  // MESSAGE DISPLAY METHODS
  // ================================
  void _showSuccessMessage(String message) {
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showWarningMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 14),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white70,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  // ================================
  // ENHANCED NAVIGATION METHODS WITH AUTO-REFRESH
  // ================================
  void _handleNavigation(int index) async {
    setState(() {
      _selectedNavIndex = index;
    });

    switch (index) {
      case 0: // Profile
        debugPrint('👤 Navigating to Profile...');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userName: widget.userName),
          ),
        );
        break;

      case 1: // WMS with auto-refresh
        debugPrint('🏭 Navigating to WMS Main Screen...');
        HapticFeedback.lightImpact();
        try {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WMSMainScreen(userName: widget.userName),
            ),
          );

          if (mounted) {
            debugPrint('🔄 Returned from WMS, refreshing voice picking data...');
            _refreshData();
          }
        } catch (navigationError) {
          debugPrint('❌ WMS navigation error: $navigationError');
          _showErrorMessage('Failed to navigate to WMS: ${navigationError.toString()}');
        }
        break;
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.warning, size: 20),
            SizedBox(width: 8),
            Text('Logout', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to logout?', style: TextStyle(fontSize: 14)),
            if (_controller.currentState.name != 'idle' && _controller.currentState.name != 'completed') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _controller.isHandsFreeModeActive 
                    ? 'Warning: Active hands-free picking session will be lost!'
                    : 'Warning: Active picking session will be lost!',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _performLogout() {
    try {
      debugPrint('🚪 Performing logout...');
      _barcodeController.clear();
      _barcodeFocusNode.unfocus();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      debugPrint('✅ Logout completed successfully');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      _showErrorMessage('Logout failed: ${e.toString()}');
    }
  }

  // ================================
  // DISPOSE
  // ================================
  @override
  void dispose() {
    try {
      debugPrint('🧹 Disposing voice picking screen...');
      _pulseController.dispose();
      _fadeController.dispose();
      _statusController.dispose();
      _barcodeController.dispose();
      _barcodeFocusNode.dispose();
      _controller.dispose();
      debugPrint('✅ Voice picking screen disposed successfully');
    } catch (e) {
      debugPrint('❌ Dispose error: $e');
    }
    super.dispose();
  }
}
