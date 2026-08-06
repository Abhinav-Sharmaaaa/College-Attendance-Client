import 'package:flutter/material.dart';

const _seedColor = Color(0xFF6750A4);

final ColorScheme _colorScheme = ColorScheme.fromSeed(
  seedColor: _seedColor,
  brightness: Brightness.light,
);

class _ExpressiveTransitionsBuilder extends PageTransitionsBuilder {
  const _ExpressiveTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    final secondaryFade = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: fade,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.85).animate(secondaryFade),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _colorScheme,
  scaffoldBackgroundColor: _colorScheme.surface,
  splashFactory: InkSparkle.splashFactory,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _ExpressiveTransitionsBuilder(),
      TargetPlatform.iOS: _ExpressiveTransitionsBuilder(),
      TargetPlatform.macOS: _ExpressiveTransitionsBuilder(),
      TargetPlatform.windows: _ExpressiveTransitionsBuilder(),
      TargetPlatform.linux: _ExpressiveTransitionsBuilder(),
    },
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      height: 1.45,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: _colorScheme.surface,
    foregroundColor: _colorScheme.onSurface,
    surfaceTintColor: _colorScheme.surfaceTint,
    elevation: 0,
    scrolledUnderElevation: 3,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: _colorScheme.onSurface,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: _colorScheme.onPrimary,
      backgroundColor: _colorScheme.primary,
      disabledBackgroundColor: _colorScheme.onSurface.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
      animationDuration: const Duration(milliseconds: 350),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      animationDuration: const Duration(milliseconds: 350),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: _colorScheme.surfaceContainerLow,
    surfaceTintColor: _colorScheme.surfaceTint,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _colorScheme.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: _colorScheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: _colorScheme.error, width: 1.5),
    ),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: _colorScheme.primary,
    linearTrackColor: _colorScheme.surfaceContainerHighest,
    circularTrackColor: _colorScheme.surfaceContainerHighest,
  ),
  listTileTheme: ListTileThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: _colorScheme.surfaceContainerHighest,
    labelStyle: TextStyle(color: _colorScheme.onSurfaceVariant),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
);