import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const ink = Color(0xFF1C1B30);
  static const muted = Color(0xFF888799);
  static const primary = Color(0xFF7661EF);
  static const primaryLight = Color(0xFFF0EDFF);
  static const mint = Color(0xFFDDF6EA);
  static const border = Color(0xFFEBECF2);
  static const danger = Color(0xFFD9586A);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.danger,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        color: AppColors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: AppColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.6, color: AppColors.ink),
      bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: AppColors.ink),
      bodySmall: TextStyle(fontSize: 11, height: 1.5, color: AppColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class FacePayLogo extends StatelessWidget {
  const FacePayLogo({
    super.key,
    this.size = 40,
    this.showName = true,
    this.light = false,
  });
  final double size;
  final bool showName;
  final bool light;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(size * .26),
        child: Image.asset(
          'assets/brand/facepay-icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
      ),
      if (showName) ...[
        SizedBox(width: size * .26),
        Text(
          'facepay',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: size * .62,
            letterSpacing: -1.3,
            fontWeight: FontWeight.w800,
            color: light ? Colors.white : AppColors.ink,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '•',
          style: TextStyle(
            fontSize: size * .65,
            color: light ? const Color(0xFFBFB4FF) : AppColors.primary,
          ),
        ),
      ],
    ],
  );
}

class FaceMarkPainter extends CustomPainter {
  FaceMarkPainter({this.color = Colors.white});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final corner in [0, 1, 2, 3]) {
      canvas.save();
      canvas.translate(24, 24);
      canvas.rotate(corner * 1.57079632679);
      canvas.translate(-24, -24);
      canvas.drawPath(
        Path()
          ..moveTo(11, 18)
          ..lineTo(11, 14)
          ..quadraticBezierTo(11, 11, 14, 11)
          ..lineTo(18, 11),
        p,
      );
      canvas.restore();
    }
    canvas.drawLine(const Offset(19, 20), const Offset(19, 23), p);
    canvas.drawLine(const Offset(29, 20), const Offset(29, 23), p);
    canvas.drawPath(
      Path()
        ..moveTo(19, 29)
        ..quadraticBezierTo(24, 34, 29, 29),
      p,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FaceMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.radius = 24,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      onPressed: loading ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon, size: 18),
          if (loading || icon != null) const SizedBox(width: 10),
          Flexible(child: Text(label)),
        ],
      ),
    ),
  );
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.color = AppColors.primaryLight,
    this.size = 44,
  });
  final String name;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0])
        .join()
        .toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * .36),
      ),
      child: initials.isEmpty
          ? Icon(
              Icons.person_outline_rounded,
              size: size * .48,
              color: AppColors.ink,
            )
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * .3,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
    );
  }
}
