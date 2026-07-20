import 'package:flutter/material.dart';

abstract final class AppColors {
  static const accent = Color(0xFF9D86FF);
  static const accentSoft = Color(0x339D86FF);
  static const accentBorder = Color(0x809D86FF);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x70FFFFFF);
  static const surface = Color(0x14FFFFFF);
  static const surfaceSelected = Color(0x26FFFFFF);
  static const border = Color(0x18FFFFFF);
  static const skeletonBase = Color(0x12FFFFFF);
  static const skeletonHighlight = Color(0x2EFFFFFF);
  static const error = Color(0xFFFFA8A8);
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
  static const standard = Duration(milliseconds: 300);
  static const emphasized = Duration(milliseconds: 420);
  static const lyricLine = Duration(milliseconds: 480);
  static const lyricScroll = Duration(milliseconds: 560);
}

abstract final class AppCurves {
  static const standard = Curves.easeOutCubic;
  static const lyricLine = Curves.easeOutQuart;
  static const lyricScroll = Curves.easeInOutCubic;
}

abstract final class AppTextStyles {
  static const caption = TextStyle(
    color: AppColors.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );
  static const metadata = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w800,
  );
}
