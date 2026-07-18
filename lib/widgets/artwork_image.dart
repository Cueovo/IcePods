import 'package:flutter/material.dart';

class ArtworkImage extends StatelessWidget {
  static final RegExp _qqHttpCoverHost = RegExp(r'^http://y\.gtimg\.cn/');

  const ArtworkImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.backgroundColor = const Color(0xFF222228),
    this.color,
    this.colorBlendMode,
    this.cacheWidth,
    this.cacheHeight,
    this.fadeIn = true,
    this.filterQuality = FilterQuality.medium,
    super.key,
  });

  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final Color backgroundColor;
  final Color? color;
  final BlendMode? colorBlendMode;
  final double? cacheWidth;
  final double? cacheHeight;
  final bool fadeIn;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = imageUrl.replaceFirst(
      _qqHttpCoverHost,
      'https://y.gtimg.cn/',
    );
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final decodedWidth = cacheWidth == null
        ? null
        : (cacheWidth! * devicePixelRatio).round();
    final decodedHeight = cacheHeight == null
        ? null
        : (cacheHeight! * devicePixelRatio).round();
    Widget fallback() {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF454554), Color(0xFF15151B)],
          ),
        ),
        child: Center(
          child: Icon(Icons.album_rounded, color: Color(0x99FFFFFF), size: 48),
        ),
      );
    }

    return ColoredBox(
      color: backgroundColor,
      child: resolvedImageUrl.isEmpty
          ? fallback()
          : Image.network(
              resolvedImageUrl,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              fit: fit,
              alignment: alignment,
              color: color,
              colorBlendMode: colorBlendMode,
              cacheWidth: decodedWidth,
              cacheHeight: decodedHeight,
              filterQuality: filterQuality,
              gaplessPlayback: true,
              frameBuilder: fadeIn
                  ? (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) {
                        return child;
                      }
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    }
                  : null,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
    );
  }
}
