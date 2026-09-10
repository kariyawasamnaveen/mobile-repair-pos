import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Opens [CameraScannerSheet] as a full-screen modal route and returns the
/// scanned (or manually typed) code, or null if the user cancelled.
Future<String?> showCameraScannerSheet(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CameraScannerSheet(),
    ),
  );
}

/// A full-screen camera scanner with:
/// - Runtime permission request with graceful denial handling
/// - Live viewfinder overlay with scan region hint
/// - Torch / flashlight toggle
/// - Manual text entry fallback (for damaged barcodes)
/// - Auto-closes with haptic feedback on first successful scan
class CameraScannerSheet extends StatefulWidget {
  const CameraScannerSheet({super.key});

  @override
  State<CameraScannerSheet> createState() => _CameraScannerSheetState();
}

class _CameraScannerSheetState extends State<CameraScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.qrCode,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.dataMatrix,
    ],
  );

  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocusNode = FocusNode();

  _PermissionState _permissionState = _PermissionState.checking;
  bool _torchOn = false;
  bool _scanned = false; // guard against double-pop from rapid detections

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    _manualFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) setState(() => _permissionState = _PermissionState.granted);
      return;
    }

    if (status.isPermanentlyDenied) {
      if (mounted) setState(() => _permissionState = _PermissionState.permanentlyDenied);
      return;
    }

    // Show rationale then request
    final result = await Permission.camera.request();
    if (!mounted) return;
    if (result.isGranted) {
      setState(() => _permissionState = _PermissionState.granted);
    } else if (result.isPermanentlyDenied) {
      setState(() => _permissionState = _PermissionState.permanentlyDenied);
    } else {
      setState(() => _permissionState = _PermissionState.denied);
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _scanned = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(raw);
  }

  void _submitManualEntry() {
    final text = _manualController.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode / IMEI'),
        actions: [
          if (_permissionState == _PermissionState.granted)
            IconButton(
              tooltip: _torchOn ? 'Torch off' : 'Torch on',
              icon: Icon(_torchOn ? Icons.flashlight_off : Icons.flashlight_on),
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: switch (_permissionState) {
        _PermissionState.checking => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        _PermissionState.granted => _ScannerView(
            controller: _scannerController,
            manualController: _manualController,
            manualFocusNode: _manualFocusNode,
            onDetected: _onBarcodeDetected,
            onManualSubmit: _submitManualEntry,
          ),
        _PermissionState.denied => _PermissionDeniedView(
            isPermanent: false,
            onRetry: _checkCameraPermission,
          ),
        _PermissionState.permanentlyDenied => _PermissionDeniedView(
            isPermanent: true,
            onRetry: _checkCameraPermission,
          ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Scanner view — camera preview + viewfinder overlay + manual entry
// ---------------------------------------------------------------------------

class _ScannerView extends StatelessWidget {
  const _ScannerView({
    required this.controller,
    required this.manualController,
    required this.manualFocusNode,
    required this.onDetected,
    required this.onManualSubmit,
  });

  final MobileScannerController controller;
  final TextEditingController manualController;
  final FocusNode manualFocusNode;
  final void Function(BarcodeCapture) onDetected;
  final VoidCallback onManualSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: controller,
                onDetect: onDetected,
              ),
              const _ViewfinderOverlay(),
              Positioned(
                bottom: 16,
                child: Text(
                  'Point camera at barcode or IMEI',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        _ManualEntryBar(
          controller: manualController,
          focusNode: manualFocusNode,
          onSubmit: onManualSubmit,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Viewfinder overlay — a simple cutout rectangle with corner guides
// ---------------------------------------------------------------------------

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        const cutoutWidth = 260.0;
        const cutoutHeight = 160.0;
        final left = (size.width - cutoutWidth) / 2;
        final top = (size.height - cutoutHeight) / 2;

        return CustomPaint(
          size: size,
          painter: _ViewfinderPainter(
            cutout: Rect.fromLTWH(left, top, cutoutWidth, cutoutHeight),
          ),
        );
      },
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.cutout});

  final Rect cutout;

  @override
  void paint(Canvas canvas, Size size) {
    // Dim the area outside the viewfinder
    final dimPaint = Paint()..color = Colors.black54;
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(fullRect),
        Path()..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(8))),
      ),
      dimPaint,
    );

    // Corner guides
    const cornerLen = 20.0;
    const cornerWidth = 3.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(cutout.topLeft, cutout.topLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(cutout.topLeft, cutout.topLeft + const Offset(0, cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(cutout.topRight, cutout.topRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(cutout.topRight, cutout.topRight + const Offset(0, cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(cutout.bottomLeft, cutout.bottomLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(cutout.bottomLeft, cutout.bottomLeft + const Offset(0, -cornerLen), cornerPaint);
    // Bottom-right
    canvas.drawLine(cutout.bottomRight, cutout.bottomRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(cutout.bottomRight, cutout.bottomRight + const Offset(0, -cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) => oldDelegate.cutout != cutout;
}

// ---------------------------------------------------------------------------
// Manual entry bar — pinned at the bottom of the scanner view
// ---------------------------------------------------------------------------

class _ManualEntryBar extends StatelessWidget {
  const _ManualEntryBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter barcode / IMEI manually',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.grey.shade900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Permission denied view
// ---------------------------------------------------------------------------

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.isPermanent,
    required this.onRetry,
  });

  final bool isPermanent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              isPermanent
                  ? 'Camera permission is permanently denied.\nPlease enable it in device Settings to use the scanner.'
                  : 'Camera access is needed to scan barcodes and IMEIs.\nTap below to try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (isPermanent)
              FilledButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open App Settings'),
              )
            else
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Grant Camera Access'),
              ),
            const SizedBox(height: 12),
            Text(
              'You can also use manual entry or the physical barcode scanner.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal permission state enum
// ---------------------------------------------------------------------------

enum _PermissionState { checking, granted, denied, permanentlyDenied }
