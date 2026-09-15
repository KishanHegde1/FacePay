import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../services/scan_detection.dart';
import '../services/face_scan_purpose.dart';
import '../ui/design.dart';
import 'payment_screen.dart';

/// Untrusted QR text is displayed only. It is never opened as a URL, treated
/// as a verified recipient, or used to create an amount or transaction.
class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    required this.state,
    required this.detection,
    this.onFaceVerified,
    this.purpose = FaceScanPurpose.scan,
    this.closeAfterFaceVerified = false,
  });

  final AppState state;
  final ScanDetection detection;
  final Future<void> Function()? onFaceVerified;
  final FaceScanPurpose purpose;
  final bool closeAfterFaceVerified;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  bool _saving = false;
  String? _error;
  bool _saved = false;

  Future<void> _saveFace() async {
    final callback = widget.onFaceVerified;
    if (callback == null || _saving || _saved) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await callback();
      if (mounted) {
        setState(() => _saved = true);
        if (widget.closeAfterFaceVerified) Navigator.of(context).pop(false);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qr = widget.detection.kind == ScanDetectionKind.qr;
    final enrollment = widget.purpose == FaceScanPurpose.enrollment;
    final demoApproval = widget.purpose == FaceScanPurpose.demoPaymentApproval;
    final raw = widget.detection.rawValue ?? '';
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
                      qr
                          ? 'Review scanned code'
                          : _saved
                          ? (demoApproval
                                ? 'Demo payment approved'
                                : 'Face registration complete')
                          : 'Two blinks detected',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (qr) ...[
                      Text(
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
                      Text(
                        _saved
                            ? (demoApproval
                                  ? 'Face approval complete for this demo payment.'
                                  : 'This device is registered.')
                            : demoApproval
                            ? 'Ready to approve this demo payment.'
                            : enrollment
                            ? 'Ready to register FacePay on this device.'
                            : 'Face liveness check complete.',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _saved
                            ? (demoApproval
                                  ? 'The demo payment was recorded locally. No money moved.'
                                  : 'The protected enrollment record was saved in your FacePay account. A different app installation must register again.')
                            : 'The scan found one face, completed two blinks, and did not detect a phone, tablet, or display in the camera view.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        demoApproval
                            ? 'This is a demo approval only. It is not a real transfer or bank authorization.'
                            : 'No face image or ML Kit landmark data is saved. A certified encrypted face-template provider is still required before real face payments.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!qr && widget.onFaceVerified != null && !_saved) ...[
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _saving
                      ? (demoApproval ? 'Approving…' : 'Saving…')
                      : (demoApproval
                            ? 'Approve demo payment'
                            : 'Register Face'),
                  onPressed: _saving ? null : _saveFace,
                  icon: Icons.verified_user_outlined,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
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
                      builder: (_) => PaymentScreen(state: widget.state),
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
