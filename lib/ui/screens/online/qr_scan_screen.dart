import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../l10n/app_strings.dart';
import '../../../online/join_code.dart';
import '../../theme/app_theme.dart';

/// La fotocamera puntata sul QR di una stanza. Torna indietro col codice
/// appena ne legge uno valido.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  static Future<String?> scan(BuildContext context) =>
      Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detected(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue == null ? null : JoinCode.fromScan(barcode.rawValue!);
      if (code != null) {
        _done = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(t.scanTitle)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _detected,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(t.scanDenied, textAlign: TextAlign.center, style: AppText.body),
              ),
            ),
          ),
          // Il mirino: un quadrato dorato in mezzo.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: SafeArea(
              child: Text(t.scanHint, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
