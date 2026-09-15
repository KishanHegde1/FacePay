import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/design.dart';

/// Receiving requests are unavailable until they can be backed by a real
/// payment provider. No payment address, QR code, or request is generated.
class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final bank = state.linkedBank;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.ink,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Receive money',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 48),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_rounded,
                      size: 42,
                      color: Color(0xFF278566),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Receiving is being set up',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 29,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A payment provider is required before FacePay can create a payment ID, QR code, request, or amount. Nothing is shared from this screen today.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                SurfaceCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          bank == null
                              ? 'No payment account is connected, so there is nothing to receive into yet.'
                              : '${bank.name} remains a local bank-directory preview and cannot receive payments.',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
