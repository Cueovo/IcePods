import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({required this.imageUrl, super.key});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 750),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [...previousChildren, ?currentChild],
            ),
            child: RepaintBoundary(
              key: ValueKey(imageUrl),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 44, sigmaY: 44),
                child: Transform.scale(
                  scale: 1.24,
                  child: ArtworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    backgroundColor: const Color(0xFF090A0F),
                    cacheWidth: screenSize.width / 2,
                    cacheHeight: screenSize.height / 2,
                    fadeIn: false,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
            ),
          ),
          // Lighter dim so status bar + preview share the same ambient wash.
          const ColoredBox(color: Color(0x3D000000)),
        ],
      ),
    );
  }
}
