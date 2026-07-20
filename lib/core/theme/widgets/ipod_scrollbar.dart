import 'package:flutter/material.dart';

/// Thin, low-contrast scrollbar used across the iPod shell lists.
class IpodScrollbar extends StatelessWidget {
  const IpodScrollbar({
    required this.controller,
    required this.child,
    this.thickness = 2,
    this.crossAxisMargin = 0,
    this.mainAxisMargin = 6,
    super.key,
  });

  final ScrollController controller;
  final Widget child;
  final double thickness;
  final double crossAxisMargin;
  final double mainAxisMargin;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: RawScrollbar(
        controller: controller,
        thickness: thickness,
        radius: const Radius.circular(99),
        thumbColor: const Color(0x2EFFFFFF),
        trackVisibility: false,
        thumbVisibility: false,
        interactive: false,
        fadeDuration: const Duration(milliseconds: 220),
        timeToFade: const Duration(milliseconds: 600),
        pressDuration: Duration.zero,
        mainAxisMargin: mainAxisMargin,
        crossAxisMargin: crossAxisMargin,
        minThumbLength: 16,
        child: child,
      ),
    );
  }
}
