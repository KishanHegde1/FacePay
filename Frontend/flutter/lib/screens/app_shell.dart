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
import '../services/face_scan_purpose.dart';
import '../services/app_settings.dart';
import '../services/profile_photo_service.dart';
import '../services/device_lock_service.dart';
import 'settings_screen.dart';

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
    this.deviceLockService,
  });
  final BankBalanceService balanceService;
  final ProfileData? profile;
  final Future<ProfileData> Function(String name, String email)? onSaveProfile;
  final AppState state;
  final VoidCallback onSignOut;
  final String accessToken;
  final FaceEnrollmentService? faceEnrollmentService;
  final DeviceLockService? deviceLockService;
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
  final ProfilePhotoRepository _photos = ProfilePhotoService();
  AppSettings? _fallbackSettings;

  void _settings() {
    final settings =
        AppSettingsScope.maybeOf(context) ??
        (_fallbackSettings ??= AppSettings());
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: settings,
          deviceLockService: widget.deviceLockService,
        ),
      ),
    );
  }

  Future<void> _loadProfilePhoto() async {
    final id = widget.profile?.id;
    if (id == null) return;
    try {
      final photo = await _photos.read(id);
      if (mounted && widget.profile?.id == id) {
        widget.state.setProfilePhoto(photo);
      }
    } catch (_) {
      // A failed local photo read must not block sign-in or navigation.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFaceEnrollment();
    _loadProfilePhoto();
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
    _fallbackSettings?.dispose();
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
        purpose: FaceScanPurpose.enrollment,
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
    backgroundColor: AppPalette.of(context).surface,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You’re all caught up',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            Text(
              widget.state.notificationsEnabled
                  ? 'Your account is ready for payment setup.'
                  : 'Notifications are paused. You can turn them on in Profile.',
              style: TextStyle(
                color: AppPalette.of(context).muted,
                height: 1.6,
              ),
            ),
            if (widget.state.notificationsEnabled) ...[
              SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppPalette.of(context).mint,
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
          onSettings: _settings,
          photo: widget.state.profilePhoto,
          photoRepository: _photos,
          onPhotoChanged: widget.state.setProfilePhoto,
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
                  constraints: BoxConstraints(
                    minHeight: 78,
                    maxHeight:
                        78 +
                        (MediaQuery.textScalerOf(context).scale(16) - 16).clamp(
                          0,
                          48,
                        ),
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.of(context).surface,
                    border: Border(
                      top: BorderSide(color: AppPalette.of(context).border),
                    ),
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
                            icon: Icon(Icons.north_east_rounded),
                            style: IconButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
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
              color: _selected == index
                  ? AppPalette.of(context).primary
                  : AppPalette.of(context).muted,
              size: 23,
            ),
            SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: _selected == index
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: _selected == index
                    ? AppPalette.of(context).primary
                    : AppPalette.of(context).muted,
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
    decoration: BoxDecoration(
      color: AppPalette.of(context).surface,
      border: Border(bottom: BorderSide(color: AppPalette.of(context).border)),
    ),
    child: Row(
      children: [
        if (wide) ...[
          Text(
            _labels[_selected],
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(width: 12),
          Text(
            '/ Personal account',
            style: TextStyle(fontSize: 12, color: AppPalette.of(context).muted),
          ),
        ] else
          FacePayLogo(
            size: 30,
            showName:
                MediaQuery.sizeOf(context).width >= 360 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3,
          ),
        const Spacer(),
        if (wide && MediaQuery.sizeOf(context).width >= 1200) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppPalette.of(context).primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'PERSONAL ACCOUNT',
              style: TextStyle(
                color: AppPalette.of(context).primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
          ),
          SizedBox(width: 20),
        ],
        IconButton(
          onPressed: _settings,
          tooltip: 'Settings',
          icon: Icon(Icons.settings_outlined),
        ),
        IconButton(
          onPressed: _notifications,
          tooltip: 'Notifications',
          icon: Icon(Icons.notifications_none_rounded),
        ),
        SizedBox(width: 8),
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
                photo: widget.state.profilePhoto,
                color: AppPalette.of(context).mint,
                size: 38,
              ),
            ),
          ),
        ),
        if (wide) ...[
          SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              widget.state.displayName.trim().isEmpty
                  ? 'Profile'
                  : widget.state.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _sidebar() => Container(
    width: 236,
    decoration: BoxDecoration(
      color: AppPalette.of(context).surface,
      border: Border(right: BorderSide(color: AppPalette.of(context).border)),
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
                      SizedBox(height: 48),
                      Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'YOUR SPACE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.of(context).muted,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      SizedBox(height: 18),
                      for (var i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              selected: _selected == i,
                              selectedTileColor: AppPalette.of(
                                context,
                              ).primaryLight,
                              selectedColor: AppPalette.of(context).primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Icon(_icons[i], size: 20),
                              title: Text(
                                _labels[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: () => _select(i),
                            ),
                          ),
                        ),
                      SizedBox(height: 20),
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
                          color: AppPalette.of(
                            context,
                          ).tint(const Color(0xFFF7F6FF)),
                          padding: const EdgeInsets.all(18),
                          radius: 18,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.face_retouching_natural,
                                size: 26,
                                color: AppPalette.of(context).primary,
                              ),
                              SizedBox(height: 13),
                              Text(
                                'A little more you.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Your people. Your moments. Your way to pay.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.7,
                                  color: AppPalette.of(context).muted,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _select(3),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                ),
                                child: Text(
                                  'Explore FacePay →',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Frontend preview · v0.1',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppPalette.of(context).muted,
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
