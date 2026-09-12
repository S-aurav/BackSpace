// ignore_for_file: use_build_context_synchronously

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/apis.dart';
import '../helper/cache_manager.dart';
import '../helper/dialogs.dart';
import '../helper/theme_controller.dart';
import '../models/chat_user.dart';
import 'chat_screen.dart';

/// WhatsApp-style Profile QR & Scanner screen with two tabs:
/// Tab 1: "My Code" (shows your personal QR code)
/// Tab 2: "Scan Code" (camera scanner to scan other contacts)
class ProfileQrScreen extends StatefulWidget {
  const ProfileQrScreen({super.key});

  @override
  State<ProfileQrScreen> createState() => _ProfileQrScreenState();
}

class _ProfileQrScreenState extends State<ProfileQrScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0 = My Code, 1 = Scan Code
  late final MobileScannerController _scannerController;
  late final AnimationController _animController;
  bool _isProcessingScan = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
    });

    if (index == 1) {
      _scannerController.start();
    } else {
      _scannerController.stop();
    }
  }

  // Generate the standard BackSpace contact QR payload
  String _getQrPayload() {
    final uid = APIs.user.uid;
    final name = Uri.encodeComponent(APIs.me.name);
    final email = Uri.encodeComponent(APIs.me.email);
    return 'backspace://contact?id=$uid&name=$name&email=$email';
  }

  // Parse scanned QR data
  void _onBarcodeDetect(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _handleScannedData(rawValue);
  }

  // Handle scanned string from camera or gallery image
  Future<void> _handleScannedData(String rawData) async {
    if (_isProcessingScan) return;
    setState(() => _isProcessingScan = true);

    String? targetId;
    String? targetEmail;
    String? targetName;

    try {
      final uri = Uri.parse(rawData.trim());
      if (uri.scheme == 'backspace' && uri.host == 'contact') {
        targetId = uri.queryParameters['id'];
        targetEmail = uri.queryParameters['email'];
        targetName = uri.queryParameters['name'];
      } else if (rawData.contains('@')) {
        targetEmail = rawData.trim();
      }
    } catch (_) {
      // Fallback
    }

    // Check if it's user's own QR code
    if (targetId == APIs.user.uid || (targetEmail != null && targetEmail == APIs.user.email)) {
      HapticFeedback.lightImpact();
      Dialogs.showSnackbar(context, "That's your own QR code! 😊");
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessingScan = false);
      return;
    }

    if (targetId == null && (targetEmail == null || targetEmail.isEmpty)) {
      HapticFeedback.lightImpact();
      Dialogs.showSnackbar(context, 'Not a valid BackSpace contact QR code');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessingScan = false);
      return;
    }

    HapticFeedback.heavyImpact();

    // Establish contact relationship in my_users
    if (targetId != null) {
      await APIs.addChatUserById(targetId);
    }
    if (targetEmail != null && targetEmail.isNotEmpty) {
      await APIs.addChatUser(targetEmail);
    }

    // Retrieve fresh user info
    ChatUser? targetUser;
    if (targetId != null) {
      targetUser = await APIs.getUserById(targetId);
    }

    targetUser ??= ChatUser(
      id: targetId ?? '',
      name: targetName != null ? Uri.decodeComponent(targetName) : (targetEmail ?? 'New Contact'),
      email: targetEmail ?? '',
      about: 'Hey there! I am using BackSpace.',
      image: '',
      createdAt: '',
      isOnline: false,
      lastActive: '',
      pushToken: '',
    );

    if (!mounted) return;

    _showContactAddedModal(targetUser);
  }

  // Modal Sheet displayed when a contact is successfully scanned
  void _showContactAddedModal(ChatUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = ThemeController.isDark;
        return Container(
          decoration: BoxDecoration(
            color: ThemeController.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Success Icon & Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFF34C759), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Contact Added',
                      style: TextStyle(
                        color: Color(0xFF34C759),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // User Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(45),
                child: user.image.isNotEmpty
                    ? CachedNetworkImage(
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        imageUrl: APIs.getOptimizedImageUrl(user.image, width: 180),
                        cacheManager: AvatarCacheManager.instance,
                        errorWidget: (_, __, ___) => CircleAvatar(
                          radius: 45,
                          backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                          child: const Icon(CupertinoIcons.person_fill, size: 45, color: Color(0xFF007AFF)),
                        ),
                      )
                    : CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.15),
                        child: const Icon(CupertinoIcons.person_fill, size: 45, color: Color(0xFF007AFF)),
                      ),
              ),
              const SizedBox(height: 14),

              Text(
                user.name,
                style: TextStyle(
                  color: ThemeController.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user.about.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  user.about,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ThemeController.subtextColor, fontSize: 14),
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: ThemeController.textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(user: user)),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.chat_bubble_fill, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Message',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() => _isProcessingScan = false);
      }
    });
  }

  // Pick QR from photo album
  Future<void> _pickQrFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final capture = await _scannerController.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final rawValue = capture.barcodes.first.rawValue;
        if (rawValue != null && rawValue.isNotEmpty) {
          _handleScannedData(rawValue);
          return;
        }
      }
      Dialogs.showSnackbar(context, 'No QR code found in selected image');
    } catch (e) {
      Dialogs.showSnackbar(context, 'Error reading image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark;

    return Scaffold(
      backgroundColor: ThemeController.bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: ThemeController.headerColor.withValues(alpha: 0.55),
                border: Border(
                  bottom: BorderSide(
                    color: ThemeController.dividerColor.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Row(
            children: [
              SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_left, color: Color(0xFF007AFF), size: 22),
            ],
          ),
        ),
        title: Text(
          'QR Code',
          style: TextStyle(
            color: ThemeController.textColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Content for active tab
          IndexedStack(
            index: _selectedTab,
            children: [
              _buildMyCodeTab(isDark),
              _buildScanCodeTab(),
            ],
          ),

          // Top Cupertino Segmented Switcher (Floating below AppBar)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56 + 12,
            left: 24,
            right: 24,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tabButton(0, 'My Code', CupertinoIcons.qrcode),
                    _tabButton(1, 'Scan Code', CupertinoIcons.camera_viewfinder),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : ThemeController.subtextColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : ThemeController.subtextColor,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: My Code View
  Widget _buildMyCodeTab(bool isDark) {
    final mq = MediaQuery.of(context);
    final topOffset = mq.padding.top + 130;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: topOffset, left: 24, right: 24, bottom: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // White WhatsApp-style Card holding QR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                // User Avatar Header
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF007AFF),
                        shape: BoxShape.circle,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: CachedNetworkImage(
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          imageUrl: APIs.getOptimizedImageUrl(APIs.me.image, width: 144),
                          cacheManager: AvatarCacheManager.instance,
                          errorWidget: (_, __, ___) => const CircleAvatar(
                            radius: 36,
                            child: Icon(CupertinoIcons.person_fill, size: 36),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // User Name
                Text(
                  APIs.me.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'BackSpace Contact',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: QrImageView(
                    data: _getQrPayload(),
                    version: QrVersions.auto,
                    size: 210.0,
                    gapless: true,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF007AFF),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Subtitle Note
                const Text(
                  'Your QR code is private. If you share it with someone, they can scan it with their BackSpace camera to add you as a contact.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Copy Email Button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            color: const Color(0xFF007AFF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: APIs.me.email));
              Dialogs.showSnackbar(context, 'Email copied to clipboard!');
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.doc_on_clipboard, color: Color(0xFF007AFF), size: 18),
                SizedBox(width: 8),
                Text(
                  'Copy Email',
                  style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Scan Code View
  Widget _buildScanCodeTab() {
    return Stack(
      children: [
        // Camera Viewfinder
        Positioned.fill(
          child: MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetect,
          ),
        ),

        // Darkened Targeting Mask Overlay
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return CustomPaint(
                painter: _ScannerOverlayPainter(
                  scanProgress: _animController.value,
                ),
              );
            },
          ),
        ),

        // Hint Text
        Positioned(
          bottom: 120,
          left: 32,
          right: 32,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Align QR code within the frame to scan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // Bottom Controls: Torch & Gallery
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flashlight toggle
              GestureDetector(
                onTap: () async {
                  await _scannerController.toggleTorch();
                  setState(() {
                    _isTorchOn = !_isTorchOn;
                  });
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _isTorchOn
                        ? const Color(0xFF007AFF)
                        : Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Icon(
                    _isTorchOn ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash_fill,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 32),

              // Gallery Image Picker
              GestureDetector(
                onTap: _pickQrFromGallery,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Icon(
                    CupertinoIcons.photo_fill_on_rectangle_fill,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter to render the WhatsApp-style cutout overlay and animated scanning beam
class _ScannerOverlayPainter extends CustomPainter {
  final double scanProgress;

  _ScannerOverlayPainter({required this.scanProgress});

  @override
  void paint(Canvas canvas, Size size) {
    const cutoutSize = 250.0;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2 - 20;
    final cutoutRect = Rect.fromLTWH(left, top, cutoutSize, cutoutSize);
    final rrect = RRect.fromRectAndRadius(cutoutRect, const Radius.circular(24));

    // Dark semi-transparent mask with cutout
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()..addRRect(rrect);
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.drawPath(overlayPath, maskPaint);

    // Corner targeting guides
    final cornerPaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    const radius = 24.0;

    // Top-Left
    canvas.drawLine(Offset(left, top + radius), Offset(left, top + radius + cornerLength), cornerPaint);
    canvas.drawLine(Offset(left + radius, top), Offset(left + radius + cornerLength, top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(left + cutoutSize, top + radius), Offset(left + cutoutSize, top + radius + cornerLength), cornerPaint);
    canvas.drawLine(Offset(left + cutoutSize - radius, top), Offset(left + cutoutSize - radius - cornerLength, top), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(left, top + cutoutSize - radius), Offset(left, top + cutoutSize - radius - cornerLength), cornerPaint);
    canvas.drawLine(Offset(left + radius, top + cutoutSize), Offset(left + radius + cornerLength, top + cutoutSize), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(left + cutoutSize, top + cutoutSize - radius), Offset(left + cutoutSize, top + cutoutSize - radius - cornerLength), cornerPaint);
    canvas.drawLine(Offset(left + cutoutSize - radius, top + cutoutSize), Offset(left + cutoutSize - radius - cornerLength, top + cutoutSize), cornerPaint);

    // Animated cyan/blue scanning line
    final scanLineY = top + 10 + ((cutoutSize - 20) * scanProgress);
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF007AFF).withValues(alpha: 0.0),
          const Color(0xFF007AFF),
          const Color(0xFF007AFF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(left + 10, scanLineY, cutoutSize - 20, 2))
      ..strokeWidth = 2.5;

    canvas.drawLine(Offset(left + 12, scanLineY), Offset(left + cutoutSize - 12, scanLineY), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanProgress != scanProgress;
  }
}
