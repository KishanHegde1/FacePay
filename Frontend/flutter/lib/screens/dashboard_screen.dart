import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/design.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.state,
    required this.onSend,
    required this.onReceive,
    required this.onScan,
    required this.onWallet,
    required this.onBalance,
    required this.onActivity,
    required this.onLinkBank,
  });

  final AppState state;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onScan;
  final VoidCallback onWallet;
  final VoidCallback onBalance;
  final VoidCallback onActivity;
  final VoidCallback onLinkBank;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 860;
      final name = state.displayName.trim();
      final firstName = name.isEmpty
          ? 'there'
          : name.split(RegExp(r'\s+')).first;
      return SingleChildScrollView(
        padding: EdgeInsets.all(constraints.maxWidth < 600 ? 20 : 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A LITTLE MORE EVERYDAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Hello, $firstName.',
                  style: TextStyle(
                    fontSize: wide ? 36 : 30,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account is ready for the next step.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 28),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: _paymentSetupCard()),
                      const SizedBox(width: 22),
                      Expanded(flex: 5, child: _faceCard()),
                    ],
                  )
                else
                  _paymentSetupCard(),
                const SizedBox(height: 26),
                _quickActions(),
                const SizedBox(height: 26),
                _bankLinkCard(),
                const SizedBox(height: 26),
                if (!wide) ...[
                  _faceCard(compact: true),
                  const SizedBox(height: 26),
                ],
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: _recentActivity()),
                      const SizedBox(width: 22),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _contactsSetup(),
                            const SizedBox(height: 22),
                            _activityInsights(),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _contactsSetup(),
                  const SizedBox(height: 22),
                  _recentActivity(),
                  const SizedBox(height: 22),
                  _activityInsights(),
                ],
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Made for the moments that matter.  ·  FacePay',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _paymentSetupCard() => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF272244), Color(0xFF433770)],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned(
          right: -55,
          top: -65,
          child: ExcludeSemantics(
            child: Container(
              width: 235,
              height: 235,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .07),
                  width: 35,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payment services',
                      style: TextStyle(color: Color(0xFFCCC5DF), fontSize: 12),
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFFD0C6F3),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Ready for setup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'No real balance or payment method is connected. You can try a local demo payment.',
                style: TextStyle(
                  color: Color(0xFFCCC5DF),
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onWallet,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE4DCF9),
                        foregroundColor: const Color(0xFF352754),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text(
                        'Wallet setup',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onActivity,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 16,
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text(
                        'Activity',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _faceCard({bool compact = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: const Color(0xFFEBE7FA),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FACE VERIFICATION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF756295),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'A familiar face.\nA safer flow.',
                style: TextStyle(
                  fontSize: compact ? 24 : 28,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                  letterSpacing: -.9,
                  color: const Color(0xFF392953),
                ),
              ),
              const SizedBox(height: 12),
              if (!compact)
                const Text(
                  'Face verification will be connected when payment services are ready.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Color(0xFF75658E),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSend,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  foregroundColor: const Color(0xFF5840A6),
                ),
                child: const Text(
                  'View payment setup  →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: compact ? 68 : 82,
          height: compact ? 82 : 106,
          decoration: BoxDecoration(
            color: const Color(0xFFB6A2E2),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x227B59BF),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: CustomPaint(painter: FaceMarkPainter()),
        ),
      ],
    ),
  );

  Widget _quickActions() => LayoutBuilder(
    builder: (context, constraints) {
      final actions = [
        ('Send', Icons.north_east_rounded, const Color(0xFFF0EDFF), onSend),
        (
          'Receive',
          Icons.south_west_rounded,
          const Color(0xFFE5F5EC),
          onReceive,
        ),
        (
          'Scan',
          Icons.qr_code_scanner_rounded,
          const Color(0xFFFFEEE3),
          onScan,
        ),
        (
          'Wallet',
          Icons.account_balance_wallet_outlined,
          const Color(0xFFE6EEFC),
          onWallet,
        ),
        (
          'Balance',
          Icons.account_balance_outlined,
          const Color(0xFFFFF5D9),
          onBalance,
        ),
      ];
      final actionWidth = ((constraints.maxWidth - 48) / 5).clamp(
        82.0,
        double.infinity,
      );
      return SingleChildScrollView(
        key: const ValueKey('home-actions'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final action in actions)
              Padding(
                padding: EdgeInsets.only(
                  right: action == actions.last ? 0 : 12,
                ),
                child: SizedBox(
                  width: actionWidth,
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: action.$4,
                      key: ValueKey('action-${action.$1.toLowerCase()}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 19,
                          horizontal: 4,
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: action.$3,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                action.$2,
                                size: 22,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              action.$1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _bankLinkCard() {
    final bank = state.linkedBank;
    final linked = bank != null;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: linked ? const Color(0xFFDDF6EA) : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(15),
          ),
          child: linked
              ? Text(
                  bank.monogram,
                  style: const TextStyle(
                    color: Color(0xFF338767),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : const Icon(
                  Icons.account_balance_outlined,
                  color: AppColors.primary,
                ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                linked ? bank.name : 'Link a bank account',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                linked
                    ? 'Demo account · •••• ${bank.lastFour}'
                    : 'Explore 20 popular banks in a safe demo flow.',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return SurfaceCard(
      key: const ValueKey('bank-dashboard-card'),
      color: linked ? const Color(0xFFF6FBF8) : AppColors.surface,
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 430
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    key: const ValueKey('bank-link-cta'),
                    onPressed: onLinkBank,
                    icon: Icon(
                      linked ? Icons.tune_rounded : Icons.add_link_rounded,
                      size: 18,
                    ),
                    label: Text(linked ? 'Manage demo bank' : 'Link demo bank'),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 20),
                  OutlinedButton.icon(
                    key: const ValueKey('bank-link-cta'),
                    onPressed: onLinkBank,
                    icon: Icon(
                      linked ? Icons.tune_rounded : Icons.add_link_rounded,
                      size: 18,
                    ),
                    label: Text(linked ? 'Manage' : 'Link bank'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _contactsSetup() => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contacts',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'No contacts are added yet. Contacts will be available once payments are connected.',
          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.people_outline_rounded, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your contacts will stay empty until you add them through a connected payment service.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _recentActivity() => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent activity',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
            ),
            TextButton(
              onPressed: onActivity,
              child: const Text('View all', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (state.transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: AppColors.muted),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No demo activity yet. Verified transactions will appear here after payment services are connected.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final transaction in state.transactions.take(4))
            InkWell(
              onTap: onActivity,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: transaction.incoming
                            ? AppColors.mint
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        transaction.incoming
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        size: 18,
                        color: transaction.incoming
                            ? const Color(0xFF358467)
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            transaction.category,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${transaction.incoming ? '+' : '−'}${formatMoney(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: transaction.incoming
                            ? const Color(0xFF358467)
                            : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );

  Widget _activityInsights() => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity insights',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Spending summaries will appear after verified payment activity is available.',
          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.insights_outlined, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'There is no spending data to show.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
