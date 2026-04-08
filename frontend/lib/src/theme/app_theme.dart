import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  // Corporate Light Theme — Clean, professional, with subtle color accents
  static ThemeData light = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: Color(0xFF1565C0),       // Deep corporate blue
      primaryContainer: Color(0xFFD4E4F7),
      secondary: Color(0xFF0D47A1),     // Navy accent
      secondaryContainer: Color(0xFFCBDEF5),
      tertiary: Color(0xFF2E7D32),      // Success green accent
      tertiaryContainer: Color(0xFFC8E6C9),
      error: Color(0xFFC62828),
      errorContainer: Color(0xFFFFCDD2),
    ),
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 4,
    appBarStyle: FlexAppBarStyle.surface,
    appBarElevation: 0.5,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 6,
      blendOnColors: false,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorRadius: 10.0,
      chipRadius: 8.0,
      cardRadius: 14.0,
      dialogRadius: 18.0,
      elevatedButtonRadius: 10.0,
      filledButtonRadius: 10.0,
      outlinedButtonRadius: 10.0,
      textButtonRadius: 10.0,
      fabRadius: 14.0,
      navigationBarIndicatorRadius: 12.0,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
  );

  // Corporate Dark Theme — Subtle, easy on the eyes
  static ThemeData dark = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: Color(0xFF64B5F6),       // Lighter blue for dark mode
      primaryContainer: Color(0xFF1A3A5C),
      secondary: Color(0xFF90CAF9),
      secondaryContainer: Color(0xFF1A3050),
      tertiary: Color(0xFF81C784),
      tertiaryContainer: Color(0xFF1B3A1D),
      error: Color(0xFFEF9A9A),
      errorContainer: Color(0xFF5C1A1A),
    ),
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 8,
    appBarStyle: FlexAppBarStyle.surface,
    appBarElevation: 0.5,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 14,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      alignedDropdown: true,
      useInputDecoratorThemeInDialogs: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorRadius: 10.0,
      chipRadius: 8.0,
      cardRadius: 14.0,
      dialogRadius: 18.0,
      elevatedButtonRadius: 10.0,
      filledButtonRadius: 10.0,
      outlinedButtonRadius: 10.0,
      textButtonRadius: 10.0,
      fabRadius: 14.0,
      navigationBarIndicatorRadius: 12.0,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
  );
}
