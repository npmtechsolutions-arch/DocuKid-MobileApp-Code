import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Material 3 theme with iOS-adaptive touches (ADR-011, DESIGN_SYSTEM §1–8).
abstract final class AppTheme {
  static ThemeData light() => _build(
        Brightness.light,
        ColorScheme.fromSeed(seedColor: Palette.seed).copyWith(
          primary: Palette.primaryL,
          onPrimary: Palette.onPrimaryL,
          primaryContainer: Palette.primaryContainerL,
          surface: Palette.surfaceL,
          surfaceContainer: Palette.surfaceContainerL,
          surfaceContainerHigh: Palette.surfaceContainerHighL,
          surfaceContainerLow: const Color(0xFFF5F6FA),
          surfaceContainerHighest: const Color(0xFFE1E2EB),
          onSurface: Palette.onSurfaceL,
          onSurfaceVariant: Palette.onSurfaceVariantL,
          outlineVariant: Palette.outlineVariantL,
          error: Palette.errorL,
          errorContainer: Palette.errorContainerL,
        ),
        DocuColors.light,
      );

  static ThemeData dark() => _build(
        Brightness.dark,
        ColorScheme.fromSeed(seedColor: Palette.seed, brightness: Brightness.dark).copyWith(
          primary: Palette.primaryD,
          onPrimary: Palette.onPrimaryD,
          primaryContainer: Palette.primaryContainerD,
          surface: Palette.surfaceD,
          surfaceContainer: Palette.surfaceContainerD,
          surfaceContainerHigh: Palette.surfaceContainerHighD,
          surfaceContainerLow: const Color(0xFF17181E),
          surfaceContainerHighest: const Color(0xFF2C2E37),
          onSurface: Palette.onSurfaceD,
          onSurfaceVariant: Palette.onSurfaceVariantD,
          outlineVariant: Palette.outlineVariantD,
          error: Palette.errorD,
          errorContainer: Palette.errorContainerD,
        ),
        DocuColors.dark,
      );

  static ThemeData _build(Brightness b, ColorScheme scheme, DocuColors docu) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
    final t = base.textTheme;
    final text = t.copyWith(
      displaySmall: t.displaySmall?.copyWith(
        fontSize: 36,
        height: 44 / 36,
        fontWeight: FontWeight.w700,
        fontFamily: headingFont,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineSmall: t.headlineSmall?.copyWith(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w700, fontFamily: headingFont),
      titleLarge: t.titleLarge?.copyWith(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700, fontFamily: headingFont),
      titleMedium: t.titleMedium?.copyWith(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, fontFamily: headingFont),
      // Section headers (UI_REFRESH §1: sentence case, Jakarta 600).
      titleSmall: t.titleSmall?.copyWith(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w600, fontFamily: headingFont),
      labelLarge: t.labelLarge?.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
      labelMedium: t.labelMedium?.copyWith(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 24 / 16),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 20 / 14),
      bodySmall: t.bodySmall?.copyWith(fontSize: 12, height: 16 / 12),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    const shapeMd = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.md)));
    const stadium = StadiumBorder();

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [docu],
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shapeMd,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: stadium,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: stadium,
          textStyle: text.labelLarge,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48), textStyle: text.labelLarge),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48), textStyle: text.labelLarge),
      ),
      chipTheme: base.chipTheme.copyWith(shape: stadium, side: BorderSide(color: scheme.outlineVariant)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: Space.x3,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      sliderTheme: base.sliderTheme.copyWith(showValueIndicator: ShowValueIndicator.onDrag),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }
}
