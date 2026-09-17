import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:face_payment/services/app_settings.dart';
import 'package:face_payment/services/profile_photo_service.dart';
import 'package:face_payment/screens/settings_screen.dart';
import 'package:face_payment/screens/profile_screen.dart';
import 'package:face_payment/ui/design.dart';
import 'frontend_test.dart' as helpers;

class FakePhotos implements ProfilePhotoRepository {
  Uint8List? data;
  ImageSource? lastSource;
  String? lastOwner;
  ProfilePhotoFailure? failure;
  bool cancelled = false;
  int removals = 0;
  @override
  Future<Uint8List?> read(String id) async => data;
  @override
  Future<Uint8List?> choose(String id, ImageSource source) async {
    lastOwner = id;
    lastSource = source;
    if (failure != null) throw failure!;
    if (cancelled) return null;
    data = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    return data;
  }

  @override
  Future<void> remove(String id) async {
    lastOwner = id;
    removals++;
    data = null;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('appearance saves and restores, corrupt values use system', () async {
    final settings = AppSettings();
    await settings.setThemeMode(ThemeMode.dark);
    final restored = AppSettings();
    await restored.load();
    expect(restored.themeMode, ThemeMode.dark);
    SharedPreferences.setMockInitialValues({AppSettings.themeKey: 'unknown'});
    await restored.load();
    expect(restored.themeMode, ThemeMode.system);
    settings.dispose();
    restored.dispose();
  });
  test('loading appearance after disposal is safe', () async {
    final settings = AppSettings();
    final pending = settings.load();
    settings.dispose();
    await pending;
  });
  testWidgets('settings changes live appearance and system follows device', (
    tester,
  ) async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpWidget(
      AnimatedBuilder(
        animation: settings,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          home: SettingsScreen(settings: settings),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.light,
    );
    await tester.tap(find.byKey(const ValueKey('theme-system')));
    await tester.pumpAndSettle();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });
  for (final source in ImageSource.values) {
    testWidgets('profile selects $source, updates avatar, then removes photo', (
      tester,
    ) async {
      final photos = FakePhotos();
      Uint8List? changed;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ProfileScreen(
              profile: helpers.testProfile,
              photoRepository: photos,
              onPhotoChanged: (value) => changed = value,
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('profile-photo')));
      await tester.tap(find.byKey(const ValueKey('profile-photo')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey(
            source == ImageSource.gallery ? 'photo-gallery' : 'photo-camera',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(photos.lastSource, source);
      expect(photos.lastOwner, helpers.testProfile.id);
      expect(changed, isNotNull);
      expect(find.text('Change photo'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photo-remove')));
      await tester.pumpAndSettle();
      expect(photos.removals, 1);
      expect(changed, isNull);
      expect(find.text('Add photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final cancelled in [false, true]) {
    testWidgets(
      'photo ${cancelled ? 'cancel' : 'permission error'} retains avatar and allows retry',
      (tester) async {
        final photos = FakePhotos()..cancelled = cancelled;
        if (!cancelled) {
          photos.failure = const ProfilePhotoFailure(
            'Allow camera access and try again.',
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileScreen(
                profile: helpers.testProfile,
                photoRepository: photos,
                onSignOut: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('profile-photo')));
        await tester.tap(find.byKey(const ValueKey('profile-photo')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('photo-camera')));
        await tester.pumpAndSettle();
        expect(find.text('Add photo'), findsOneWidget);
        if (!cancelled) {
          expect(
            find.text('Allow camera access and try again.'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
