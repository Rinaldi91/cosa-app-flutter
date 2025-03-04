import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerWithOverlay extends StatefulWidget {
  const BarcodeScannerWithOverlay({super.key});

  @override
  _BarcodeScannerWithOverlayState createState() =>
      _BarcodeScannerWithOverlayState();
}

class _BarcodeScannerWithOverlayState extends State<BarcodeScannerWithOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  MobileScannerController? _scannerController;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  void _initializeController() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.all],
      torchEnabled: _isFlashOn,
    );
  }

  void _toggleFlash() async {
    if (_scannerController != null) {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      await _scannerController!.toggleTorch();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Mengatur ukuran dan posisi scanWindow di tengah
    final scanWindow = Rect.fromCenter(
      center: Offset(
          size.width / 2,
          size.height / 2 -
              (size.height * 0.1) // Naikkan posisi 10% dari tinggi layar
          ),
      width: size.width * 0.7,
      height: size.width * 0.7,
    );

    return WillPopScope(
      onWillPop: () async {
        _scannerController?.dispose();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan Barcode'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              _scannerController?.dispose();
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: _isFlashOn ? Colors.yellow : Colors.grey,
              ),
              onPressed: _toggleFlash,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                _scannerController?.dispose();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _scannerController!,
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String code = barcodes.first.rawValue ?? '';
                  _scannerController?.dispose();
                  if (mounted) {
                    Navigator.pop(context, code);
                  }
                }
              },
              errorBuilder: (context, error, child) {
                return Center(
                  child: Text(
                    'Error: ${error.message}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              },
            ),
            CustomPaint(
              painter: ScannerOverlay(scanWindow),
            ),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Positioned(
                  top: scanWindow.top + (scanWindow.height * _animation.value),
                  left: scanWindow.left,
                  child: Container(
                    height: 3,
                    width: scanWindow.width,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0),
                          Colors.blue.withOpacity(0.8),
                          Colors.blue.withOpacity(0),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                );
              },
            ),
            ...buildCornerMarkers(scanWindow, size),
          ],
        ),
      ),
    );
  }

  List<Widget> buildCornerMarkers(Rect scanWindow, Size size) {
    const markerLength = 20.0;
    const markerWidth = 4.0;
    final cornerColor = Colors.blue.withOpacity(0.8);

    return [
      // Top Left Corner
      Positioned(
        top: scanWindow.top,
        left: scanWindow.left,
        child: Container(
          width: markerLength,
          height: markerWidth,
          color: cornerColor,
        ),
      ),
      Positioned(
        top: scanWindow.top,
        left: scanWindow.left,
        child: Container(
          width: markerWidth,
          height: markerLength,
          color: cornerColor,
        ),
      ),
      // Top Right Corner
      Positioned(
        top: scanWindow.top,
        right: size.width - scanWindow.right,
        child: Container(
          width: markerLength,
          height: markerWidth,
          color: cornerColor,
        ),
      ),
      Positioned(
        top: scanWindow.top,
        right: size.width - scanWindow.right,
        child: Container(
          width: markerWidth,
          height: markerLength,
          color: cornerColor,
        ),
      ),
      // Bottom Left Corner - Fixed Position
      Positioned(
        top: scanWindow.bottom -
            markerWidth, // Changed from bottom to top positioning
        left: scanWindow.left,
        child: Container(
          width: markerLength,
          height: markerWidth,
          color: cornerColor,
        ),
      ),
      Positioned(
        top: scanWindow.bottom -
            markerLength, // Changed from bottom to top positioning
        left: scanWindow.left,
        child: Container(
          width: markerWidth,
          height: markerLength,
          color: cornerColor,
        ),
      ),
      // Bottom Right Corner - Fixed Position
      Positioned(
        top: scanWindow.bottom -
            markerWidth, // Changed from bottom to top positioning
        right: size.width - scanWindow.right,
        child: Container(
          width: markerLength,
          height: markerWidth,
          color: cornerColor,
        ),
      ),
      Positioned(
        top: scanWindow.bottom -
            markerLength, // Changed from bottom to top positioning
        right: size.width - scanWindow.right,
        child: Container(
          width: markerWidth,
          height: markerLength,
          color: cornerColor,
        ),
      ),
    ];
  }
}

extension on MobileScannerException {
  get message => null;
}

class ScannerOverlay extends CustomPainter {
  ScannerOverlay(this.scanWindow);

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)));

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final borderPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      backgroundPaint,
    );

    canvas.drawRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)),
        borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
