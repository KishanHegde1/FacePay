import '../data/app_state.dart';

/// Provider account references are opaque. Preview labels are never bank IDs.
class BalanceAccount {
  const BalanceAccount({
    required this.id,
    required this.bankName,
    required this.maskedAccount,
    this.isPreview = false,
  });

  final String id, bankName, maskedAccount;
  final bool isPreview;
}

sealed class BankBalanceResult {
  const BankBalanceResult();
}

class BankBalanceUnavailable extends BankBalanceResult {
  const BankBalanceUnavailable();
}

/// Only a connected provider may return this result, after authorization.
/// Kept in screen memory; never written to AppState.balance or Neon.
class BankBalanceAvailable extends BankBalanceResult {
  const BankBalanceAvailable({
    required this.minorUnits,
    required this.currency,
    required this.fractionDigits,
    required this.fetchedAt,
  });

  final int minorUnits, fractionDigits;
  final String currency;
  final DateTime fetchedAt;
}

abstract interface class BankBalanceService {
  BalanceAccount? selectedAccount(AppState state);
  Future<BankBalanceResult> fetchBalance(BalanceAccount account);
}

class UnconnectedBankBalanceService implements BankBalanceService {
  const UnconnectedBankBalanceService();

  @override
  BalanceAccount? selectedAccount(AppState state) {
    final bank = state.linkedBank;
    if (bank == null) return null;
    return BalanceAccount(
      id: 'preview:${bank.name}:${bank.linkedAt.toIso8601String()}',
      bankName: bank.name,
      maskedAccount: '•••• ${bank.lastFour}',
      isPreview: true,
    );
  }

  @override
  Future<BankBalanceResult> fetchBalance(BalanceAccount account) async =>
      const BankBalanceUnavailable();
}
