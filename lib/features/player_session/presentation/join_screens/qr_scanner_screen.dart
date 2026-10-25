import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../sync/protocol/models.dart';

class QrScannerScreen extends StatefulWidget {
  final ValueChanged<QrPayload> onPayloadReceived;
  final VoidCallback onManualEntry;

  const QrScannerScreen({
    super.key,
    required this.onPayloadReceived,
    required this.onManualEntry,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasDetected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasDetected) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final raw = barcode.rawValue!;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final payload = QrPayload.fromJson(decoded);

      if (payload.marker != AppConstants.appMarker) {
        _showError('Этот QR-код не является кодом игровой сессии Манчкина.');
        return;
      }

      _hasDetected = true;
      widget.onPayloadReceived(payload);
    } catch (_) {
      _showError('Не удалось прочитать код сессии.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentCrimson,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать QR стола'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 64,
                        color: AppColors.accentCrimson,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Не удалось получить доступ к камере:\n${error.errorDetails?.message ?? error.toString()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: widget.onManualEntry,
                        child: const Text('Ввести IP вручную'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Overlay scanning frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryGold, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkSurface,
                foregroundColor: AppColors.primaryGold,
                side: const BorderSide(color: AppColors.primaryGold),
              ),
              onPressed: widget.onManualEntry,
              icon: const Icon(Icons.keyboard),
              label: const Text('Ввести IP и порт вручную'),
            ),
          ),
        ],
      ),
    );
  }
}
