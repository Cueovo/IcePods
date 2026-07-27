import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:web/web.dart' as web;

import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({required this.imageUrl, super.key});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('local://')) {
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
              child: Transform.scale(
                scale: 1.18,
                child: ArtworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            const ColoredBox(color: Color(0x3D000000)),
          ],
        ),
      );
    }
    final resolvedImageUrl = imageUrl.replaceFirst(
      RegExp(r'^http://y\.gtimg\.cn/'),
      'https://y.gtimg.cn/',
    );
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
            child: SizedBox.expand(
              key: ValueKey(resolvedImageUrl),
              child: IgnorePointer(
                child: HtmlElementView.fromTagName(
                  tagName: 'img',
                  hitTestBehavior: PlatformViewHitTestBehavior.transparent,
                  onElementCreated: (element) {
                    final image = element as web.HTMLImageElement;
                    image
                      ..alt = ''
                      ..referrerPolicy = 'no-referrer'
                      ..draggable = false;
                    image.style
                      ..width = '100%'
                      ..height = '100%'
                      ..objectFit = 'cover'
                      ..objectPosition = 'center'
                      ..filter = 'blur(34px) saturate(1.2) brightness(0.68)'
                      ..transform = 'scale(1.16)'
                      ..transformOrigin = 'center'
                      ..pointerEvents = 'none';
                    image.src = resolvedImageUrl;
                  },
                ),
              ),
            ),
          ),
          const ColoredBox(color: Color(0x52000000)),
        ],
      ),
    );
  }
}
