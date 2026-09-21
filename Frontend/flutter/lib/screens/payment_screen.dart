import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../services/face_scan_purpose.dart';
import '../services/payment_feedback_service.dart';
import '../services/scanner_session.dart';
import '../ui/design.dart';
import 'scan_screen.dart';

/// A local preview of the payment UI. It records a clearly labelled, in-memory
/// demo activity item and never calls a bank, PSP, backend, or persistence API.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.state,
    this.onComplete,
    this.onLinkBank,
    this.scannerSessionFactory,
    this.feedbackService,
  });

  final AppState state;
  final VoidCallback? onComplete;
  final VoidCallback? onLinkBank;

  /// Creates a fresh scanner for each approval attempt in device-free tests.
  final ScannerSession Function()? scannerSessionFactory;
  final PaymentFeedbackService? feedbackService;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _maximumDemoAmount = 10000000.0;
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  PaymentTransaction? _recordedPayment;
  late final PaymentFeedbackService _feedbackService;
  Timer? _confirmationTimer;
  bool _showingConfirmation = false;
  bool _paymentCommitted = false;

  @override
  void initState() {
    super.initState();
    _feedbackService = widget.feedbackService ?? DevicePaymentFeedbackService();
  }

  @override
  void dispose() {
    _confirmationTimer?.cancel();
    unawaited(_feedbackService.stop());
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _leave() {
    _confirmationTimer?.cancel();
    unawaited(_feedbackService.stop());
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  double? _amount() {
    return double.tryParse(_amountController.text.trim().replaceAll(',', ''));
  }

  Future<void> _review() async {
    if (widget.state.linkedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link a demo bank account first.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!widget.state.faceRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Register FacePay on this device before approving a demo payment.',
          ),
        ),
      );
      return;
    }

    final amount = _amount()!;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DemoPaymentReviewSheet(
        recipient: _recipientController.text.trim(),
        amount: amount,
        bank: widget.state.linkedBank!,
      ),
    );
    if (confirmed != true || !mounted) return;
    final scannerSession = widget.scannerSessionFactory?.call();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          state: widget.state,
          session: scannerSession,
          purpose: FaceScanPurpose.demoPaymentApproval,
          closeAfterFaceVerified: true,
          onFaceVerified: () async {
            if (_paymentCommitted) return;
            _paymentCommitted = true;
            widget.state.recordDemoPayment(
              recipient: _recipientController.text,
              amount: amount,
            );
            if (mounted) {
              setState(() {
                _recordedPayment = widget.state.transactions.first;
                _showingConfirmation = true;
              });
            }
          },
        ),
      ),
    );
    // Start only after both camera/result routes have closed, so the user gets
    // the complete 4.5 seconds of visible confirmation.
    if (mounted &&
        _recordedPayment != null &&
        _showingConfirmation &&
        _confirmationTimer == null) {
      unawaited(_feedbackService.speakThanks());
      _confirmationTimer = Timer(const Duration(milliseconds: 4500), () {
        if (mounted) setState(() => _showingConfirmation = false);
      });
    }
  }

  void _startAnother() {
    _confirmationTimer?.cancel();
    unawaited(_feedbackService.stop());
    setState(() {
      _recordedPayment = null;
      _showingConfirmation = false;
      _paymentCommitted = false;
      _recipientController.clear();
      _amountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.of(context).background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _recordedPayment == null
                ? _entry()
                : _showingConfirmation
                ? _completionConfirmation()
                : _success(_recordedPayment!),
          ),
        ),
      ),
    );
  }

  Widget _topBar(String title) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Back',
          onPressed: _leave,
          style: IconButton.styleFrom(
            backgroundColor: AppPalette.of(context).surface,
            foregroundColor: AppPalette.of(context).ink,
          ),
          icon: Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(width: 48),
      ],
    );
  }

  Widget _entry() {
    final bank = widget.state.linkedBank;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _topBar('Demo payment'),
        SizedBox(height: 24),
        const _DemoPill(),
        SizedBox(height: 16),
        Text(
          'Try the payment flow',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: AppPalette.of(context).ink,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'This records local demo activity only. No money moves, no real bank balance changes, and no details are sent to a bank.',
          style: TextStyle(
            color: AppPalette.of(context).muted,
            fontSize: 13,
            height: 1.55,
          ),
        ),
        SizedBox(height: 22),
        _BankPanel(bank: bank, onLinkBank: widget.onLinkBank),
        SizedBox(height: 18),
        Form(
          key: _formKey,
          child: SurfaceCard(
            color: AppPalette.of(context).surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('demo-payment-recipient'),
                  controller: _recipientController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Recipient name',
                    hintText: 'Enter a name for this demo',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a recipient name.'
                      : null,
                ),
                SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('demo-payment-amount'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Demo amount',
                    hintText: '0.00',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').trim().replaceAll(',', ''),
                    );
                    if (amount == null || !amount.isFinite || amount <= 0) {
                      return 'Enter an amount greater than zero.';
                    }
                    if (amount > _maximumDemoAmount) {
                      return 'For the demo, enter ₹1,00,00,000 or less.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        PrimaryButton(
          label: bank == null
              ? 'Link demo bank first'
              : !widget.state.faceRegistered
              ? 'Register FacePay first'
              : 'Review & approve',
          icon: bank == null
              ? Icons.account_balance_outlined
              : Icons.arrow_forward_rounded,
          onPressed: bank == null
              ? widget.onLinkBank
              : widget.state.faceRegistered
              ? _review
              : () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Open Home and choose Register Face first.'),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _success(PaymentTransaction payment) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _topBar('Demo payment'),
        SizedBox(height: 54),
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppPalette.of(context).mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: (AppPalette.of(context).dark
                  ? const Color(0xFF88DAB9)
                  : const Color(0xFF21806C)),
              size: 44,
            ),
          ),
        ),
        SizedBox(height: 22),
        Text(
          'Demo payment recorded',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'No money moved. This local preview is visible only while the app is open.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppPalette.of(context).muted,
            fontSize: 13,
            height: 1.55,
          ),
        ),
        SizedBox(height: 26),
        SurfaceCard(
          color: AppPalette.of(context).surface,
          child: Column(
            children: [
              _ReceiptLine('Recipient', payment.title),
              const Divider(height: 24),
              _ReceiptLine('Demo amount', formatMoney(payment.amount)),
              const Divider(height: 24),
              _ReceiptLine('Reference', payment.id),
            ],
          ),
        ),
        SizedBox(height: 20),
        PrimaryButton(
          label: 'Create another demo',
          icon: Icons.add_rounded,
          onPressed: _startAnother,
        ),
        SizedBox(height: 12),
        TextButton(onPressed: _leave, child: Text('Back to home')),
      ],
    );
  }

  Widget _completionConfirmation() {
    return Semantics(
      liveRegion: true,
      label: 'Demo payment completed. No money moved.',
      child: Padding(
        key: const ValueKey('demo-payment-completion'),
        padding: const EdgeInsets.fromLTRB(28, 72, 28, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: AppPalette.of(context).mint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 58,
                color: AppPalette.of(context).dark
                    ? const Color(0xFF88DAB9)
                    : const Color(0xFF21806C),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Demo payment completed',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.of(context).ink,
                fontSize: 29,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thanks, bro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.of(context).primary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No money moved. Your local demo receipt will appear shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.of(context).muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoPill extends StatelessWidget {
  const _DemoPill();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.of(context).tint(const Color(0xFFFFF4DA)),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          'DEMO MODE · NO MONEY MOVES',
          style: TextStyle(
            color: (AppPalette.of(context).dark
                ? const Color(0xFFFFD58A)
                : const Color(0xFF9A6500)),
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: .45,
          ),
        ),
      ),
    );
  }
}

class _BankPanel extends StatelessWidget {
  const _BankPanel({required this.bank, this.onLinkBank});

  final DemoLinkedBank? bank;
  final VoidCallback? onLinkBank;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: bank == null
          ? AppPalette.of(context).tint(const Color(0xFFFFF4DA))
          : AppPalette.of(context).primaryLight,
      child: Row(
        children: [
          Icon(
            bank == null
                ? Icons.info_outline_rounded
                : Icons.account_balance_outlined,
            color: bank == null
                ? (AppPalette.of(context).dark
                      ? const Color(0xFFFFD58A)
                      : const Color(0xFF9A6500))
                : AppPalette.of(context).primary,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              bank == null
                  ? 'Link a demo bank account to continue. It is a local label only, not a bank connection.'
                  : 'Using local demo bank: ${bank!.name} · •••• ${bank!.lastFour}',
              style: TextStyle(
                color: AppPalette.of(context).ink,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          if (bank == null && onLinkBank != null)
            TextButton(onPressed: onLinkBank, child: Text('Link')),
        ],
      ),
    );
  }
}

class _DemoPaymentReviewSheet extends StatelessWidget {
  const _DemoPaymentReviewSheet({
    required this.recipient,
    required this.amount,
    required this.bank,
  });

  final String recipient;
  final double amount;
  final DemoLinkedBank bank;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        decoration: BoxDecoration(
          color: AppPalette.of(context).surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DemoPill(),
            SizedBox(height: 16),
            Text(
              'Review demo payment',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 16),
            _ReceiptLine('Recipient', recipient),
            SizedBox(height: 12),
            _ReceiptLine('Demo amount', formatMoney(amount)),
            SizedBox(height: 12),
            _ReceiptLine('Demo bank', '${bank.name} · •••• ${bank.lastFour}'),
            SizedBox(height: 18),
            Text(
              'This only saves demo activity while the app remains open. No money moves, no balance changes, and no bank receives these details.',
              style: TextStyle(
                color: AppPalette.of(context).muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
            PrimaryButton(
              label: 'Continue to face check',
              icon: Icons.face_retouching_natural,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppPalette.of(context).muted, fontSize: 12),
          ),
        ),
        SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
