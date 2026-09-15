import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/design.dart';

/// A local preview of the payment UI. It records a clearly labelled, in-memory
/// demo activity item and never calls a bank, PSP, backend, or persistence API.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.state,
    this.onComplete,
    this.onLinkBank,
  });

  final AppState state;
  final VoidCallback? onComplete;
  final VoidCallback? onLinkBank;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _maximumDemoAmount = 10000000.0;
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  PaymentTransaction? _recordedPayment;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _leave() {
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

    widget.state.recordDemoPayment(
      recipient: _recipientController.text,
      amount: amount,
    );
    setState(() => _recordedPayment = widget.state.transactions.first);
  }

  void _startAnother() {
    setState(() {
      _recordedPayment = null;
      _recipientController.clear();
      _amountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _recordedPayment == null
                ? _entry()
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
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _entry() {
    final bank = widget.state.linkedBank;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _topBar('Demo payment'),
        const SizedBox(height: 24),
        const _DemoPill(),
        const SizedBox(height: 16),
        const Text(
          'Try the payment flow',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This records local demo activity only. No money moves, no real bank balance changes, and no details are sent to a bank.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.55),
        ),
        const SizedBox(height: 22),
        _BankPanel(bank: bank, onLinkBank: widget.onLinkBank),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: SurfaceCard(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demo details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('demo-payment-recipient'),
                  controller: _recipientController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Recipient name',
                    hintText: 'Enter a name for this demo',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a recipient name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('demo-payment-amount'),
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
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
        const SizedBox(height: 20),
        PrimaryButton(
          label: bank == null ? 'Link demo bank first' : 'Review demo payment',
          icon: bank == null
              ? Icons.account_balance_outlined
              : Icons.arrow_forward_rounded,
          onPressed: bank == null ? widget.onLinkBank : _review,
        ),
      ],
    );
  }

  Widget _success(PaymentTransaction payment) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _topBar('Demo payment'),
        const SizedBox(height: 54),
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF21806C),
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Demo payment recorded',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'No money moved. This local preview is visible only while the app is open.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.55),
        ),
        const SizedBox(height: 26),
        SurfaceCard(
          color: AppColors.surface,
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
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Create another demo',
          icon: Icons.add_rounded,
          onPressed: _startAnother,
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: _leave, child: const Text('Back to home')),
      ],
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
          color: Color(0xFFFFF4DA),
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Text(
          'DEMO MODE · NO MONEY MOVES',
          style: TextStyle(
            color: Color(0xFF9A6500),
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
      color: bank == null ? const Color(0xFFFFF4DA) : AppColors.primaryLight,
      child: Row(
        children: [
          Icon(
            bank == null
                ? Icons.info_outline_rounded
                : Icons.account_balance_outlined,
            color: bank == null ? const Color(0xFF9A6500) : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bank == null
                  ? 'Link a demo bank account to continue. It is a local label only, not a bank connection.'
                  : 'Using local demo bank: ${bank!.name} · •••• ${bank!.lastFour}',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          if (bank == null && onLinkBank != null)
            TextButton(onPressed: onLinkBank, child: const Text('Link')),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DemoPill(),
            const SizedBox(height: 16),
            const Text(
              'Review demo payment',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _ReceiptLine('Recipient', recipient),
            const SizedBox(height: 12),
            _ReceiptLine('Demo amount', formatMoney(amount)),
            const SizedBox(height: 12),
            _ReceiptLine('Demo bank', '${bank.name} · •••• ${bank.lastFour}'),
            const SizedBox(height: 18),
            const Text(
              'This only saves demo activity while the app remains open. No money moves, no balance changes, and no bank receives these details.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Record demo payment',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
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
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
