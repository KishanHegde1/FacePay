import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../services/profile_photo_service.dart';
import '../services/auth_api.dart';
import '../ui/design.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profile,
    this.onSaveProfile,
    required this.onSignOut,
    this.onSettings,
    this.photo,
    this.onPhotoChanged,
    this.photoRepository,
  });
  final ProfileData? profile;
  final Future<ProfileData> Function(String name, String email)? onSaveProfile;
  final VoidCallback onSignOut;
  final VoidCallback? onSettings;
  final Uint8List? photo;
  final ValueChanged<Uint8List?>? onPhotoChanged;
  final ProfilePhotoRepository? photoRepository;

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
  Uint8List? _photo;
  bool _photoBusy = false;
  late final ProfilePhotoRepository _photos =
      widget.photoRepository ?? ProfilePhotoService();

  @override
  void initState() {
    super.initState();
    _saved = widget.profile;
    _name = TextEditingController(text: _saved?.name ?? '');
    _email = TextEditingController(text: _saved?.email ?? '');
    _photo = widget.photo;
    if (widget.onPhotoChanged == null) unawaited(_loadPhoto());
  }

  Future<void> _loadPhoto() async {
    final id = widget.profile?.id;
    if (id == null) return;
    try {
      final photo = await _photos.read(id);
      if (mounted && widget.profile?.id == id) setState(() => _photo = photo);
    } on ProfilePhotoFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your photo could not be loaded. Please try again.',
        );
      }
    }
  }

  Future<void> _editPhoto() async {
    if (_photoBusy || widget.profile == null) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Your profile photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              key: const ValueKey('photo-gallery'),
              leading: Icon(Icons.photo_library_outlined),
              title: Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              key: const ValueKey('photo-camera'),
              leading: Icon(Icons.camera_alt_outlined),
              title: Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (_photo != null)
              ListTile(
                key: const ValueKey('photo-remove'),
                leading: Icon(Icons.delete_outline_rounded),
                title: Text('Remove photo'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final id = widget.profile!.id;
    setState(() {
      _photoBusy = true;
      _error = null;
    });
    try {
      Uint8List? photo;
      if (choice == 'remove') {
        await _photos.remove(id);
      } else {
        photo = await _photos.choose(
          id,
          choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        );
        if (photo == null) return;
      }
      if (!mounted || widget.profile?.id != id) return;
      setState(() => _photo = photo);
      widget.onPhotoChanged?.call(photo);
    } on ProfilePhotoFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Your photo could not be updated. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo != oldWidget.photo) _photo = widget.photo;
    if (widget.profile?.id != oldWidget.profile?.id) {
      _photo = widget.photo;
      if (widget.onPhotoChanged == null) unawaited(_loadPhoto());
    }
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
                Text(
                  'YOUR ACCOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: AppPalette.of(context).muted,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Your profile',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'A few details. A little more you.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppPalette.of(context).muted,
                  ),
                ),
                SizedBox(height: 28),
                if (widget.onSettings != null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: widget.onSettings,
                      icon: Icon(Icons.settings_outlined),
                      label: Text('Settings'),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                if (profile == null)
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 44,
                          color: AppPalette.of(context).primary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Your profile is not available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Sign in to load your account details.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppPalette.of(context).muted),
                        ),
                        SizedBox(height: 20),
                        TextButton(
                          onPressed: widget.onSignOut,
                          child: Text('Sign out'),
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
                              PersonAvatar(
                                name: profile.name,
                                photo: _photo,
                                size: 64,
                              ),
                              SizedBox(width: 18),
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
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -.5,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Your personal details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppPalette.of(context).muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 28),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey('profile-photo'),
                                onPressed: _photoBusy ? null : _editPhoto,
                                icon: Icon(Icons.add_a_photo_outlined),
                                label: Text(
                                  _photoBusy
                                      ? 'Updating…'
                                      : _photo == null
                                      ? 'Add photo'
                                      : 'Change photo',
                                ),
                              ),
                              Text(
                                'Saved securely on this device.',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          const Divider(),
                          SizedBox(height: 24),
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
                            decoration: InputDecoration(
                              hintText: 'Enter your full name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              counterText: '',
                            ),
                            validator: (value) =>
                                (value?.trim().runes.length ?? 0) < 2
                                ? 'Enter your name (at least 2 characters).'
                                : null,
                          ),
                          SizedBox(height: 22),
                          _label('Mobile number'),
                          TextFormField(
                            key: const ValueKey('profile-mobile'),
                            initialValue: profile.mobileNo,
                            readOnly: true,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.phone_outlined),
                              suffixIcon: Icon(
                                Icons.verified_rounded,
                                color: (AppPalette.of(context).dark
                                    ? const Color(0xFF88DAB9)
                                    : const Color(0xFF338767)),
                                size: 21,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Verified at sign-in. Your mobile number stays linked to this account.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppPalette.of(context).muted,
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: 22),
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
                            decoration: InputDecoration(
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
                            SizedBox(height: 20),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: AppPalette.of(context).danger,
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                          if (_success) ...[
                            SizedBox(height: 20),
                            Semantics(
                              liveRegion: true,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: (AppPalette.of(context).dark
                                        ? const Color(0xFF88DAB9)
                                        : const Color(0xFF338767)),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Profile saved.',
                                    style: TextStyle(
                                      color: (AppPalette.of(context).dark
                                          ? const Color(0xFF88DAB9)
                                          : const Color(0xFF338767)),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(height: 28),
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
                  SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : widget.onSignOut,
                      icon: Icon(Icons.logout_rounded, size: 18),
                      label: Text('Sign out'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppPalette.of(context).danger,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 20),
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
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}
