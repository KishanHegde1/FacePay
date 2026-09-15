import 'package:flutter/material.dart';
import '../data/app_state.dart';
import '../services/auth_api.dart';
import '../ui/design.dart';
import 'dashboard_screen.dart';
import 'wallet_screen.dart';
import 'activity_screen.dart';
import 'profile_screen.dart';
import 'payment_screen.dart';
import 'receive_screen.dart';
import 'scan_screen.dart';
import 'bank_link_screen.dart';
import 'balance_screen.dart';
import '../services/bank_balance_service.dart';
import '../services/face_enrollment_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.state,
    required this.onSignOut,
    this.profile,
    this.onSaveProfile,
    this.balanceService = const UnconnectedBankBalanceService(),
    this.accessToken = '',
    this.faceEnrollmentService,
  });
  final BankBalanceService balanceService;
  final ProfileData? profile;
  final Future<ProfileData> Function(String name, String email)? onSaveProfile;
  final AppState state;
  final VoidCallback onSignOut;
  final String accessToken;
  final FaceEnrollmentService? faceEnrollmentService;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;
  static const _labels = ['Overview', 'My wallet', 'Activity', 'Profile'];
  static const _icons = [
    Icons.grid_view_rounded,
    Icons.account_balance_wallet_outlined,
    Icons.swap_horiz_rounded,
    Icons.person_outline_rounded,
  ];
  late final FaceEnrollmentService _faceEnrollment =
      widget.faceEnrollmentService ?? FaceEnrollmentService();

  @override
  void initState() {
    super.initState();
    _loadFaceEnrollment();
  }

  Future<void> _loadFaceEnrollment() async {
    if (widget.accessToken.isEmpty) return;
    try {
      final enrolled = await _faceEnrollment.enrolled(widget.accessToken);
      if (mounted) widget.state.setFaceRegistered(enrolled);
    } catch (_) {
      // A temporary availability problem must not erase the saved enrollment UI.
    }
  }

  Future<void> _registerFace() async {
    await _faceEnrollment.register(widget.accessToken);
    if (mounted) widget.state.setFaceRegistered(true);
  }

  @override
  void dispose() {
    if (widget.faceEnrollmentService == null) _faceEnrollment.dispose();
    super.dispose();
  }
  void _select(int index) => setState(() => _selected = index);
  void _payment() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PaymentScreen(
        state: widget.state,
        onLinkBank: _linkBank,
        onComplete: () {
          _select(0);
          Navigator.of(context).pop();
        },
      ),
    ),
  );
  void _receive() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ReceiveScreen(state: widget.state)),
  );
  void _scan() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ScanScreen(state: widget.state)),
  );
  void _registerFaceScan() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ScanScreen(
        state: widget.state,
        onFaceVerified: _registerFace,
      ),
    ),
  );
  void _balance() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BalanceScreen(
        state: widget.state,
        service: widget.balanceService,
        onManageAccount: _linkBank,
      ),
    ),
  );
  void _linkBank() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BankLinkScreen(state: widget.state),
    ),
  );

  void _notifications() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You’re all caught up',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              widget.state.notificationsEnabled
                  ? 'Your account is ready for payment setup.'
                  : 'Notifications are paused. You can turn them on in Profile.',
              style: const TextStyle(color: AppColors.muted, height: 1.6),
            ),
            if (widget.state.notificationsEnabled) ...[
              const SizedBox(height: 20),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.mint,
                  child: Icon(Icons.check_rounded, color: Color(0xFF2C8868)),
                ),
                title: Text('Welcome to FacePay'),
                subtitle: Text('Your preview is ready'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= 1000;
      final page = switch (_selected) {
        1 => WalletScreen(state: widget.state, onLinkBank: _linkBank),
        2 => ActivityScreen(state: widget.state),
        3 => ProfileScreen(
          profile: widget.profile,
          onSaveProfile: widget.onSaveProfile,
          onSignOut: widget.onSignOut,
        ),
        _ => DashboardScreen(
          state: widget.state,
          onSend: _payment,
          onReceive: _receive,
          onScan: _scan,
          onWallet: () => _select(1),
          onBalance: _balance,
          onActivity: () => _select(2),
          onLinkBank: _linkBank,
          onRegisterFace: _registerFaceScan,
        ),
      };
      return Scaffold(
        body: Row(
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: SafeArea(
                child: Column(
                  children: [
                    _topbar(wide),
                    Expanded(child: page),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  height: 78,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      _bottomItem(0, 'Home'),
                      _bottomItem(1, 'Wallet'),
                      Expanded(
                        child: Center(
                          child: IconButton.filled(
                            tooltip: 'Send a payment',
                            onPressed: _payment,
                            icon: const Icon(Icons.north_east_rounded),
                            style: IconButton.styleFrom(
                              fixedSize: const Size(50, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _bottomItem(2, 'Activity'),
                      _bottomItem(3, 'Profile'),
                    ],
                  ),
                ),
              ),
      );
    },
  );

  Widget _bottomItem(int index, String label) => Expanded(
    child: Semantics(
      selected: _selected == index,
      button: true,
      child: InkWell(
        onTap: () => _select(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _icons[index],
              color: _selected == index ? AppColors.primary : AppColors.muted,
              size: 23,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: _selected == index
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: _selected == index ? AppColors.primary : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _topbar(bool wide) => Container(
    height: wide ? 88 : 76,
    padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        if (wide) ...[
          Text(
            _labels[_selected],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          const Text(
            '/ Personal account',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ] else
          const FacePayLogo(size: 30),
        const Spacer(),
        if (wide && MediaQuery.sizeOf(context).width >= 1200) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'PERSONAL ACCOUNT',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
        IconButton(
          onPressed: _notifications,
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'Open profile',
          button: true,
          child: InkWell(
            onTap: () => _select(3),
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: PersonAvatar(
                name: widget.state.displayName,
                color: AppColors.mint,
                size: 38,
              ),
            ),
          ),
        ),
        if (wide) ...[
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              widget.state.displayName.trim().isEmpty
                  ? 'Profile'
                  : widget.state.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _sidebar() => Container(
    width: 236,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FacePayLogo(size: 38),
                      const SizedBox(height: 48),
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'YOUR SPACE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.muted,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              selected: _selected == i,
                              selectedTileColor: AppColors.primaryLight,
                              selectedColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Icon(_icons[i], size: 20),
                              title: Text(
                                _labels[i],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: () => _select(i),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Payment setup',
                        onPressed: _payment,
                        icon: Icons.north_east_rounded,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SurfaceCard(
                          color: const Color(0xFFF7F6FF),
                          padding: const EdgeInsets.all(18),
                          radius: 18,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.face_retouching_natural,
                                size: 26,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 13),
                              const Text(
                                'A little more you.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Your people. Your moments. Your way to pay.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.7,
                                  color: AppColors.muted,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _select(3),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                ),
                                child: const Text(
                                  'Explore FacePay →',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Frontend preview · v0.1',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
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
      ),
    ),
  );
}
