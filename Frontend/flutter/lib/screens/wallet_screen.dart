import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../ui/design.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.state, this.onLinkBank});

  final AppState state;
  final VoidCallback? onLinkBank;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final overview = _WalletOverview(state: state);
          final status = const _PaymentStatusCard();
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 20 : 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Eyebrow('YOUR PAYMENT SPACE'),
                    SizedBox(height: 9),
                    Text(
                      'Your wallet',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.1,
                        color: AppPalette.of(context).ink,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your payment setup will appear here when services are connected.',
                      style: TextStyle(
                        color: AppPalette.of(context).muted,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 28),
                    if (compact) ...[
                      overview,
                      SizedBox(height: 18),
                      status,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: overview),
                          SizedBox(width: 24),
                          Expanded(flex: 5, child: _PaymentStatusCard()),
                        ],
                      ),
                    SizedBox(height: 30),
                    Text(
                      'Bank connection preview',
                      style: TextStyle(
                        fontSize: 21,
                        color: AppPalette.of(context).ink,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Explore supported bank names without connecting an account or sharing financial details.',
                      style: TextStyle(
                        color: AppPalette.of(context).muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 15),
                    SurfaceCard(
                      padding: const EdgeInsets.all(22),
                      child: _BankMethodRow(
                        bank: state.linkedBank,
                        onTap: onLinkBank,
                      ),
                    ),
                    SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 17,
                          color: AppPalette.of(context).muted,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'No card, balance, or real bank connection is stored in this wallet. Demo payment activity stays only while the app is open.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppPalette.of(context).muted,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WalletOverview extends StatelessWidget {
  const _WalletOverview({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final bank = state.linkedBank;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 270),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8975FA), Color(0xFF6550D8), Color(0xFF4832AA)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.of(context).primary.withValues(alpha: .18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -75,
            top: -95,
            child: Container(
              width: 265,
              height: 265,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .1),
                  width: 38,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      FacePayLogo(
                        size: 29,
                        light: true,
                        showName: constraints.maxWidth >= 330,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          'PAYMENT SETUP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28),
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(height: 16),
                Text(
                  'Your wallet is ready for setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'No card, available balance, or payment history has been created.',
                  style: TextStyle(
                    color: Color(0xFFE3DEFA),
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  bank == null
                      ? 'Select a bank from the local directory when you are ready.'
                      : '${bank.name} is selected in the local bank preview.',
                  style: TextStyle(
                    color: Color(0xFFEDE9FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard();

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('PAYMENT STATUS'),
        SizedBox(height: 14),
        Text(
          'Payments are not active yet',
          style: TextStyle(
            fontSize: 23,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'You can try local demo payments. A verified payment provider is still needed to show a balance, add a payment method, or move money.',
          style: TextStyle(color: AppPalette.of(context).muted, height: 1.6),
        ),
        SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.of(context).primaryLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: AppPalette.of(context).primary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No financial information is collected by this screen.',
                  style: TextStyle(
                    color: AppPalette.of(context).primary,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
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

class _BankMethodRow extends StatelessWidget {
  const _BankMethodRow({required this.bank, required this.onTap});

  final DemoLinkedBank? bank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final linked = bank != null;
    final mark = Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: linked
            ? AppPalette.of(context).tint(const Color(0xFFDDF6EA))
            : AppPalette.of(context).primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: linked
          ? Text(
              bank!.monogram,
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
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          linked ? bank!.name : 'Browse bank directory',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        SizedBox(height: 5),
        Text(
          linked
              ? 'Demo account · •••• ${bank!.lastFour}'
              : 'Link a demo bank to preview this experience.',
          style: TextStyle(
            color: AppPalette.of(context).muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('wallet-bank-link'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: constraints.maxWidth < 340
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          mark,
                          SizedBox(width: 16),
                          Expanded(child: details),
                        ],
                      ),
                      if (onTap != null)
                        Padding(
                          padding: EdgeInsets.only(top: 10, left: 62),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: AppPalette.of(context).muted,
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      mark,
                      SizedBox(width: 16),
                      Expanded(child: details),
                      if (onTap != null) ...[
                        SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppPalette.of(context).muted,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: AppPalette.of(context).muted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
    ),
  );
}
