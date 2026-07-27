import 'package:flutter/material.dart';

class ArtworkImage extends StatelessWidget {
  static final RegExp _qqHttpCoverHost = RegExp(r'^http://y\.gtimg\.cn/');
  static const _localPalettes = <(Color, Color, Color)>[
    (Color(0xFF6548D8), Color(0xFF241A55), Color(0xFFD7C8FF)),
    (Color(0xFF168B70), Color(0xFF0D3537), Color(0xFF9CF0CF)),
    (Color(0xFFD54F7B), Color(0xFF4E1935), Color(0xFFFFC0D4)),
    (Color(0xFFE0813D), Color(0xFF4A241D), Color(0xFFFFD1A3)),
    (Color(0xFF347BC1), Color(0xFF142C52), Color(0xFFA8D7FF)),
    (Color(0xFF8F55C7), Color(0xFF321B4C), Color(0xFFE2C1FF)),
  ];
  static const _localIcons = [
    Icons.graphic_eq_rounded,
    Icons.album_rounded,
    Icons.music_note_rounded,
    Icons.auto_awesome_rounded,
    Icons.headphones_rounded,
    Icons.library_music_rounded,
  ];

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

    Widget localArtwork() {
      final seed = resolvedImageUrl.codeUnits.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      final palette = _localPalettes[seed % _localPalettes.length];
      final icon = _localIcons[seed % _localIcons.length];
      return LayoutBuilder(
        builder: (context, constraints) {
          final rawSize = constraints.biggest.shortestSide;
          final size = rawSize.isFinite ? rawSize : 160.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.$1, palette.$2],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: -size * .2,
                  top: -size * .24,
                  child: Container(
                    width: size * .72,
                    height: size * .72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.$3.withValues(alpha: .18),
                    ),
                  ),
                ),
                Positioned(
                  left: -size * .2,
                  bottom: -size * .32,
                  child: Container(
                    width: size * .82,
                    height: size * .82,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x16000000),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: size * .42,
                    height: size * .42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x1FFFFFFF),
                      border: Border.all(color: const Color(0x26FFFFFF)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: size * .23,
                      color: palette.$3,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return ColoredBox(
      color: backgroundColor,
      child: resolvedImageUrl.startsWith('local://')
          ? localArtwork()
          : resolvedImageUrl.isEmpty
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
