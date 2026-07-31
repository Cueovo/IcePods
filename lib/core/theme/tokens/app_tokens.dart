import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFF090A0F);
  static const interaction = Color(0xFF9D86FF);
  static const interactionSoft = Color(0x339D86FF);
  static const interactionBorder = Color(0x809D86FF);
  static const brandQq = Color(0xFF31C27C);
  static const vip = Color(0xFFF2C14E);
  static const danger = Color(0xFFFFA8A8);
  static const textPrimary = Color(0xF2FFFFFF);
  static const textSecondary = Color(0xB3FFFFFF);
  static const textTertiary = Color(0x80FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
  static const glassLow = Color(0x14FFFFFF);
  static const glassMid = Color(0x26FFFFFF);
  static const border = Color(0x24FFFFFF);

  // Compatibility aliases for surfaces that have not migrated to semantic roles.
  static const accent = interaction;
  static const accentSoft = interactionSoft;
  static const accentBorder = interactionBorder;
  static const surface = glassLow;
  static const surfaceSelected = glassMid;
  static const skeletonBase = Color(0x12FFFFFF);
  static const skeletonHighlight = Color(0x2EFFFFFF);
  static const error = danger;
  static const success = Color(0xFFC8B6FF);
}

abstract final class AppRadii {
  static const badge = 4.0;
  static const artwork = 12.0;
  static const tile = 14.0;
  static const card = 18.0;
  static const pill = 999.0;
}

abstract final class AppDurations {
  static const quick = Duration(milliseconds: 180);
  static const press = Duration(milliseconds: 120);
  static const splashExit = Duration(milliseconds: 260);
  static const menuPage = Duration(milliseconds: 240);
  static const scene = Duration(milliseconds: 280);
  static const reducedMotion = Duration(milliseconds: 200);
  static const standard = Duration(milliseconds: 300);
  static const emphasized = Duration(milliseconds: 420);
  static const lyricLine = Duration(milliseconds: 480);
  static const lyricScroll = Duration(milliseconds: 560);
}

abstract final class AppCurves {
  static const standard = Curves.easeOutCubic;
  static const strongEaseOut = Cubic(0.23, 1, 0.32, 1);
  static const sceneEase = strongEaseOut;
  static const movementEase = Cubic(0.77, 0, 0.175, 1);
  static const menuPage = Cubic(0.32, 0.72, 0, 1);
  static const lyricLine = Curves.easeOutQuart;
  static const lyricScroll = Curves.easeInOutCubic;
}

abstract final class AppTextStyles {
  static const FontWeight regular = FontWeight.w500;
  static const FontWeight strong = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;

  static const micro = TextStyle(
    color: AppColors.textMuted,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: regular,
  );
  static const caption = micro;
  static const metadata = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: regular,
  );
  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    height: 19 / 14,
    fontWeight: regular,
  );
  static const label = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    height: 18 / 15,
    fontWeight: strong,
  );
  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    height: 24 / 20,
    fontWeight: strong,
  );
  static const display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: heavy,
  );
}
