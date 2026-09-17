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
    required this.onRegisterFace,
  });

  final AppState state;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  final VoidCallback onScan;
  final VoidCallback onWallet;
  final VoidCallback onBalance;
  final VoidCallback onActivity;
  final VoidCallback onLinkBank;
  final VoidCallback onRegisterFace;

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
                Text(
                  'A LITTLE MORE EVERYDAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: AppPalette.of(context).muted,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Hello, $firstName.',
                  style: TextStyle(
                    fontSize: wide ? 36 : 30,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.3,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your account is ready for the next step.',
                  style: TextStyle(
                    color: AppPalette.of(context).muted,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 28),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: _paymentSetupCard(context)),
                      SizedBox(width: 22),
                      Expanded(flex: 5, child: _faceCard(context)),
                    ],
                  )
                else
                  _paymentSetupCard(context),
                SizedBox(height: 26),
                _quickActions(context),
                SizedBox(height: 26),
                _bankLinkCard(context),
                SizedBox(height: 26),
                if (!wide) ...[
                  _faceCard(context, compact: true),
                  SizedBox(height: 26),
                ],
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: _recentActivity(context)),
                      SizedBox(width: 22),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _contactsSetup(context),
                            SizedBox(height: 22),
                            _activityInsights(context),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _contactsSetup(context),
                  SizedBox(height: 22),
                  _recentActivity(context),
                  SizedBox(height: 22),
                  _activityInsights(context),
                ],
                SizedBox(height: 24),
                Center(
                  child: Text(
                    'Made for the moments that matter.  ·  FacePay',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppPalette.of(context).muted,
                    ),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _paymentSetupCard(BuildContext context) => Container(
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
              Row(
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
              SizedBox(height: 24),
              Text(
                'Ready for setup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'No real balance or payment method is connected. You can try a local demo payment.',
                style: TextStyle(
                  color: Color(0xFFCCC5DF),
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
              SizedBox(height: 26),
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
                      icon: Icon(Icons.tune_rounded, size: 18),
                      label: Text(
                        'Wallet setup',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
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
                      icon: Icon(Icons.receipt_long_outlined, size: 16),
                      label: Text('Activity', style: TextStyle(fontSize: 12)),
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

  Widget _faceCard(BuildContext context, {bool compact = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: AppPalette.of(context).tint(const Color(0xFFEBE7FA)),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FACE VERIFICATION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppPalette.of(context).muted,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'A familiar face.\nA safer flow.',
                style: TextStyle(
                  fontSize: compact ? 24 : 28,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                  letterSpacing: -.9,
                  color: AppPalette.of(context).ink,
                ),
              ),
              SizedBox(height: 12),
              if (!compact)
                Text(
                  state.faceRegistered
                      ? 'Face setup is registered on this device.'
                      : 'Register FacePay on this device with a two-blink check.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AppPalette.of(context).muted,
                  ),
                ),
              SizedBox(height: 8),
              TextButton(
                onPressed: onRegisterFace,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  state.faceRegistered
                      ? 'Face registered  →'
                      : 'Register Face  →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Container(
          width: compact ? 68 : 82,
          height: compact ? 82 : 106,
          decoration: BoxDecoration(
            color: const Color(0xFFB6A2E2),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
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

  Widget _quickActions(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actions = [
        (
          'Send',
          Icons.north_east_rounded,
          AppPalette.of(context).tint(const Color(0xFFF0EDFF)),
          onSend,
        ),
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
                    color: AppPalette.of(context).surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: AppPalette.of(context).border),
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
                                color: AppPalette.of(context).tint(action.$3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                action.$2,
                                size: 22,
                                color: AppPalette.of(context).ink,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              action.$1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
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

  Widget _bankLinkCard(BuildContext context) {
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
            color: linked
                ? AppPalette.of(context).tint(const Color(0xFFDDF6EA))
                : AppPalette.of(context).primaryLight,
            borderRadius: BorderRadius.circular(15),
          ),
          child: linked
              ? Text(
                  bank.monogram,
                  style: TextStyle(
                    color: (AppPalette.of(context).dark
                        ? const Color(0xFF88DAB9)
                        : const Color(0xFF338767)),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : Icon(
                  Icons.account_balance_outlined,
                  color: AppPalette.of(context).primary,
                ),
        ),
        SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                linked ? bank.name : 'Link a bank account',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                linked
                    ? 'Demo account · •••• ${bank.lastFour}'
                    : 'Explore 20 popular banks in a safe demo flow.',
                style: TextStyle(
                  color: AppPalette.of(context).muted,
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
      color: linked
          ? AppPalette.of(context).tint(const Color(0xFFF6FBF8))
          : AppPalette.of(context).surface,
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 430
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  SizedBox(height: 15),
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
                  SizedBox(width: 20),
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

  Widget _contactsSetup(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contacts',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'No contacts are added yet. Contacts will be available once payments are connected.',
          style: TextStyle(
            fontSize: 12,
            color: AppPalette.of(context).muted,
            height: 1.5,
          ),
        ),
        SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppPalette.of(context).background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.people_outline_rounded,
                color: AppPalette.of(context).primary,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your contacts will stay empty until you add them through a connected payment service.',
                  style: TextStyle(
                    color: AppPalette.of(context).muted,
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

  Widget _recentActivity(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
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
              child: Text('View all', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        SizedBox(height: 6),
        if (state.transactions.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: AppPalette.of(context).muted,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No demo activity yet. Verified transactions will appear here after payment services are connected.',
                    style: TextStyle(
                      color: AppPalette.of(context).muted,
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
                            ? AppPalette.of(context).mint
                            : AppPalette.of(context).primaryLight,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        transaction.incoming
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        size: 18,
                        color: transaction.incoming
                            ? const Color(0xFF358467)
                            : AppPalette.of(context).primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            transaction.category,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppPalette.of(context).muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${transaction.incoming ? '+' : '−'}${formatMoney(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: transaction.incoming
                            ? const Color(0xFF358467)
                            : AppPalette.of(context).ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );

  Widget _activityInsights(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity insights',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Spending summaries will appear after verified payment activity is available.',
          style: TextStyle(
            fontSize: 12,
            color: AppPalette.of(context).muted,
            height: 1.5,
          ),
        ),
        SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppPalette.of(context).background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.insights_outlined,
                color: AppPalette.of(context).primary,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'There is no spending data to show.',
                  style: TextStyle(
                    color: AppPalette.of(context).muted,
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
