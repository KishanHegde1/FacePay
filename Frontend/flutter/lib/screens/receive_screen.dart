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
      backgroundColor: AppPalette.of(context).background,
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
                        backgroundColor: AppPalette.of(context).surface,
                        foregroundColor: AppPalette.of(context).ink,
                      ),
                      icon: Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Receive money',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
                SizedBox(height: 48),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppPalette.of(context).mint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.qr_code_rounded,
                      size: 42,
                      color: (AppPalette.of(context).dark
                          ? const Color(0xFF88DAB9)
                          : const Color(0xFF278566)),
                    ),
                  ),
                ),
                SizedBox(height: 26),
                Text(
                  'Receiving is being set up',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 29,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppPalette.of(context).ink,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'A payment provider is required before FacePay can create a payment ID, QR code, request, or amount. Nothing is shared from this screen today.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppPalette.of(context).muted,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 28),
                SurfaceCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: AppPalette.of(context).primary,
                      ),
                      SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          bank == null
                              ? 'No payment account is connected, so there is nothing to receive into yet.'
                              : '${bank.name} remains a local bank-directory preview and cannot receive payments.',
                          style: TextStyle(
                            color: AppPalette.of(context).muted,
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
