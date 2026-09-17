import 'package:flutter/foundation.dart';

String formatMoney(double amount, {bool decimals = true}) {
  final parts = amount.abs().toStringAsFixed(decimals ? 2 : 0).split('.');
  var whole = parts[0];
  if (whole.length > 3) {
    final tail = whole.substring(whole.length - 3);
    var head = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    groups.insert(0, head);
    whole = '${groups.join(',')},$tail';
  }
  return '${amount < 0 ? '-' : ''}₹$whole${decimals ? '.${parts[1]}' : ''}';
}

class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.incoming,
    required this.date,
    required this.category,
    this.isDemo = false,
  });
  final String id, title, subtitle, category;
  final double amount;
  final bool incoming;
  final DateTime date;

  /// True only for a local preview record. It never represents money movement.
  final bool isDemo;
}

/// A label used exclusively by the local bank-linking preview. It never holds
/// a bank account number, login credential, OTP, or connection token.
class DemoLinkedBank {
  const DemoLinkedBank({
    required this.name,
    required this.monogram,
    required this.lastFour,
    required this.linkedAt,
  });

  final String name;
  final String monogram;
  final String lastFour;
  final DateTime linkedAt;
}

/// In-memory presentation state. Payment data starts empty until a real payment
/// provider is connected.
class AppState extends ChangeNotifier {
  Uint8List? profilePhoto;

  void setProfilePhoto(Uint8List? value) {
    profilePhoto = value;
    notifyListeners();
  }

  String displayName = '';
  String email = '';
  double balance = 0;
  bool faceEnabled = true;
  bool faceRegistered = false;
  bool notificationsEnabled = true;
  DemoLinkedBank? linkedBank;
  final List<PaymentTransaction> transactions = [];
  int _demoPaymentSequence = 0;

  void setFaceEnabled(bool value) {
    faceEnabled = value;
    notifyListeners();
  }

  /// This reflects the server-side enrollment record, never a raw face image
  /// or a locally invented biometric match.
  void setFaceRegistered(bool value) {
    faceRegistered = value;
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
    notifyListeners();
  }

  void linkDemoBank({required String name, required String monogram}) {
    linkedBank = DemoLinkedBank(
      name: name,
      monogram: monogram,
      lastFour: '4821',
      linkedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void unlinkDemoBank() {
    if (linkedBank == null) return;
    linkedBank = null;
    notifyListeners();
  }

  /// Records a local-only preview activity item. This deliberately does not
  /// change [balance] or contact any bank, PSP, backend, or persistence layer.
  void recordDemoPayment({required String recipient, required double amount}) {
    final bank = linkedBank;
    final cleanRecipient = recipient.trim();
    if (bank == null) {
      throw StateError('Choose a demo bank before recording a demo payment.');
    }
    if (cleanRecipient.isEmpty || !amount.isFinite || amount <= 0) {
      throw ArgumentError('A recipient and a positive amount are required.');
    }

    _demoPaymentSequence += 1;
    final now = DateTime.now();
    transactions.insert(
      0,
      PaymentTransaction(
        id: 'DEMO-${now.millisecondsSinceEpoch}-$_demoPaymentSequence',
        title: cleanRecipient,
        subtitle: 'Demo from ${bank.name} · •••• ${bank.lastFour}',
        amount: amount,
        incoming: false,
        date: now,
        category: 'Demo payment',
        isDemo: true,
      ),
    );
    notifyListeners();
  }

  void updateProfile({required String name, required String email}) {
    displayName = name.trim();
    this.email = email.trim();
    notifyListeners();
  }
}
