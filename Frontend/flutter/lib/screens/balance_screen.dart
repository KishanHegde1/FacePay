import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../services/bank_balance_service.dart';
import '../ui/design.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({
    super.key,
    required this.state,
    this.service = const UnconnectedBankBalanceService(),
    this.onManageAccount,
  });

  final AppState state;
  final BankBalanceService service;
  final VoidCallback? onManageAccount;

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  BalanceAccount? _account;
  BankBalanceResult? _result;
  String? _error;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _account = widget.service.selectedAccount(widget.state);
    widget.state.addListener(_accountChanged);
  }

  @override
  void didUpdateWidget(covariant BalanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_accountChanged);
      widget.state.addListener(_accountChanged);
    }
    _accountChanged(force: oldWidget.service != widget.service);
  }

  void _accountChanged({bool force = false}) {
    final account = widget.service.selectedAccount(widget.state);
    if (!force && account?.id == _account?.id) return;
    setState(() {
      _request++;
      _account = account;
      _result = null;
      _error = null;
      _loading = false;
    });
  }

  Future<void> _fetch() async {
    final account = _account;
    if (account == null || _loading) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.service
          .fetchBalance(account)
          .timeout(const Duration(seconds: 30));
      if (!mounted || request != _request) return;
      setState(() => _result = result);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(
        () => _error = 'Could not fetch your bank balance. Please try again.',
      );
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _request++;
    widget.state.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Account balance')),
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
                    const Icon(
                      Icons.account_balance_outlined,
                      color: AppColors.primary,
                      size: 34,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      account == null
                          ? 'No bank account selected'
                          : 'Selected bank account',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (account != null) ...[
                      Text(
                        account.bankName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(account.maskedAccount),
                      if (account.isPreview) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Local bank preview only. This is not a connected bank account.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ] else
                      const Text(
                        'Select a bank from your wallet. Real account linking requires a payment provider.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    if (widget.onManageAccount != null) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: widget.onManageAccount,
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(
                          account == null
                              ? 'Choose bank'
                              : 'Manage selected bank',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SurfaceCard(
                color: AppColors.primaryLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result is BankBalanceAvailable
                          ? 'Available bank balance'
                          : 'Bank balance unavailable',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (result is BankBalanceAvailable) ...[
                      Text(
                        '${result.currency} ${(result.minorUnits / math.pow(10, result.fractionDigits)).toStringAsFixed(result.fractionDigits)}',
                        key: const ValueKey('provider-balance'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text('Updated: ${result.fetchedAt.toLocal()}'),
                    ] else
                      const Text(
                        'Real bank balance fetching becomes available only after the payment provider is connected.',
                      ),
                    if (result is BankBalanceUnavailable) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'No balance was fetched. The payment provider is not connected yet.',
                        key: ValueKey('balance-unavailable-result'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _loading
                    ? 'Fetching balance…'
                    : result == null
                    ? 'Fetch Balance'
                    : 'Refresh Balance',
                icon: Icons.refresh_rounded,
                loading: _loading,
                onPressed: account == null ? null : _fetch,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
