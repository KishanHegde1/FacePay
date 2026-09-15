import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../services/scan_detection.dart';
import '../ui/design.dart';
import 'payment_screen.dart';

/// Untrusted QR text is displayed only. It is never opened as a URL, treated
/// as a verified recipient, or used to create an amount or transaction.
class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({
    super.key,
    required this.state,
    required this.detection,
  });

  final AppState state;
  final ScanDetection detection;

  @override
  Widget build(BuildContext context) {
    final qr = detection.kind == ScanDetectionKind.qr;
    final raw = detection.rawValue ?? '';
    final preview = raw.length > 2048 ? '${raw.substring(0, 2048)}…' : raw;
    return Scaffold(
      appBar: AppBar(title: Text(qr ? 'QR detected' : 'Blink check complete')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      qr
                          ? Icons.qr_code_rounded
                          : Icons.face_retouching_natural,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      qr ? 'Review scanned code' : 'Two blinks detected',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (qr) ...[
                      const Text(
                        'Scanned content · unverified',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(preview),
                      const SizedBox(height: 20),
                      const Text(
                        'Recipient verification and QR payments become available after the payment provider is connected. No payment has been created.',
                      ),
                    ] else ...[
                      const Text(
                        'Next: face recognition',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Face recognition is not connected yet. This blink check has not identified a person or authorized a payment.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Two blinks are an interaction check only. Secure liveness verification is still required before face payments.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Scan again',
                onPressed: () => Navigator.of(context).pop(true),
                icon: Icons.qr_code_scanner_rounded,
              ),
              if (qr) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(state: state),
                    ),
                  ),
                  child: const Text('View payment setup'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
