import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../ui/design.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profile,
    this.onSaveProfile,
    required this.onSignOut,
  });
  final ProfileData? profile;
  final Future<ProfileData> Function(String name, String email)? onSaveProfile;
  final VoidCallback onSignOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  ProfileData? _saved;
  bool _saving = false, _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _saved = widget.profile;
    _name = TextEditingController(text: _saved?.name ?? '');
    _email = TextEditingController(text: _saved?.email ?? '');
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile?.id != oldWidget.profile?.id ||
        (widget.profile != oldWidget.profile && !_hasChanges && !_saving)) {
      _saved = widget.profile;
      _name.text = _saved?.name ?? '';
      _email.text = _saved?.email ?? '';
      _success = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _name.text.trim() != (_saved?.name ?? '') ||
      _email.text.trim() != (_saved?.email ?? '');

  void _changed(String _) => setState(() {
    _error = null;
    _success = false;
  });

  Future<void> _save() async {
    if (_saving ||
        widget.onSaveProfile == null ||
        !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _success = false;
      _error = null;
    });
    try {
      final profile = await widget.onSaveProfile!(
        _name.text.trim(),
        _email.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _saved = profile;
        _name.text = profile.name;
        _email.text = profile.email;
        _success = true;
      });
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your changes could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final profile = _saved;
      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR ACCOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your profile',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A few details. A little more you.',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                if (profile == null)
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 44,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your profile is not available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to load your account details.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: widget.onSignOut,
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SurfaceCard(
                    padding: EdgeInsets.all(compact ? 22 : 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(21),
                                ),
                                child: profile.name.isEmpty
                                    ? const Icon(
                                        Icons.person_outline_rounded,
                                        size: 30,
                                        color: AppColors.primary,
                                      )
                                    : Center(
                                        child: Text(
                                          profile.name
                                              .trim()
                                              .split(RegExp(r'\s+'))
                                              .take(2)
                                              .map(
                                                (part) => part.characters.first
                                                    .toUpperCase(),
                                              )
                                              .join(),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.name.isEmpty
                                          ? 'Make yourself at home'
                                          : profile.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.5,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Your personal details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          const Divider(),
                          const SizedBox(height: 24),
                          _label('Full name'),
                          TextFormField(
                            key: const ValueKey('profile-name'),
                            controller: _name,
                            enabled: !_saving,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            maxLength: 80,
                            onChanged: _changed,
                            decoration: const InputDecoration(
                              hintText: 'Enter your full name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              counterText: '',
                            ),
                            validator: (value) =>
                                (value?.trim().runes.length ?? 0) < 2
                                ? 'Enter your name (at least 2 characters).'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          _label('Mobile number'),
                          TextFormField(
                            key: const ValueKey('profile-mobile'),
                            initialValue: profile.mobileNo,
                            readOnly: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.phone_outlined),
                              suffixIcon: Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF338767),
                                size: 21,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Verified at sign-in. Your mobile number stays linked to this account.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _label('Email address'),
                          TextFormField(
                            key: const ValueKey('profile-email'),
                            controller: _email,
                            enabled: !_saving,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            maxLength: 254,
                            onChanged: _changed,
                            onFieldSubmitted: (_) {
                              if (_hasChanges) _save();
                            },
                            decoration: const InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                              counterText: '',
                              helperText: 'Optional',
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isNotEmpty &&
                                  !RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(email)) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 20),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                          if (_success) ...[
                            const SizedBox(height: 20),
                            Semantics(
                              liveRegion: true,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: Color(0xFF338767),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Profile saved.',
                                    style: TextStyle(
                                      color: Color(0xFF338767),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          PrimaryButton(
                            label: _saving ? 'Saving…' : 'Save changes',
                            loading: _saving,
                            icon: Icons.check_rounded,
                            onPressed:
                                _hasChanges && widget.onSaveProfile != null
                                ? _save
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : widget.onSignOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign out'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}
