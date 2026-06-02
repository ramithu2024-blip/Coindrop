import 'package:flutter/material.dart';

/// 8pt spacing system
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// Reusable text styles
class AppTextStyles {
  static TextStyle balanceLarge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
      fontSize: 36,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    );
  }

  static TextStyle balanceSmall(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    );
  }

  static TextStyle sectionTitle(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle cardLabel(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
      fontSize: 10,
    );
  }

  static TextStyle cardValue(BuildContext context, {Color? color}) {
    return TextStyle(
      color: color ?? Theme.of(context).colorScheme.primary,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );
  }

  static TextStyle envelopeName(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle bodySmall(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
      fontSize: 11,
    );
  }

  static TextStyle emptyTitle(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
      fontSize: 18,
    );
  }

  static TextStyle emptyBody(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
      fontSize: 14,
    );
  }
}

/// Surface/card color helpers
class AppColors {
  static Color surface(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color card(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withAlpha(150);
  }

  static Color textMuted(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withAlpha(100);
  }
}
