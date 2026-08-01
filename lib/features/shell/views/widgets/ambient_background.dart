import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/core/theme/artwork/artwork_palette.dart';
import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';

/// Blur is applied to a downscaled proxy layer, then upscaled by the same
/// factor, so the effective blur matches a full-surface sigma of ~45.
const double _blurDownscale = 2.5;
const double _blurSigma = 18;

class AmbientBackground extends StatefulWidget {
  const AmbientBackground({
    required this.imageUrl,
    this.customImagePath,
    super.key,
  });

  final String imageUrl;
  final String? customImagePath;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> {
  static final RegExp _qqHttpCoverHost = RegExp(r'^http://y\.gtimg\.cn/');

  String _displayedImageUrl = '';
  String _loadingImageUrl = '';
  String _paletteKey = '';
  ArtworkPalette _palette = ArtworkPalette.neutral;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRequestedImage();
  }

  @override
  void didUpdateWidget(AmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.customImagePath != widget.customImagePath) {
      _loadRequestedImage();
    }
  }

  void _loadRequestedImage() {
    final customImagePath = widget.customImagePath;
    if (customImagePath != null && customImagePath.isNotEmpty) {
      _loadingImageUrl = '';
      // Custom photos bypass the artwork pipeline, so they still need a
      // luminance-aware scrim before white text is painted over them.
      _requestPalette(
        'file://$customImagePath',
        FileImage(File(customImagePath)),
      );
      return;
    }
    final resolved = widget.imageUrl.replaceFirst(
      _qqHttpCoverHost,
      'https://y.gtimg.cn/',
    );
    if (resolved.startsWith('local://')) {
      _loadingImageUrl = '';
      _displayedImageUrl = resolved;
      _resetPalette();
      return;
    }
    if (resolved.isEmpty) {
      _loadingImageUrl = '';
      _displayedImageUrl = '';
      _resetPalette();
      return;
    }
    if (resolved == _displayedImageUrl || resolved == _loadingImageUrl) {
      return;
    }
    _loadingImageUrl = resolved;
    final size = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final provider = ResizeImage.resizeIfNeeded(
      (size.width * pixelRatio / 2).round(),
      (size.height * pixelRatio / 2).round(),
      NetworkImage(resolved),
    );
    var failed = false;
    unawaited(
      precacheImage(
        provider,
        context,
        onError: (error, stackTrace) {
          failed = true;
          if (_loadingImageUrl == resolved) {
            _loadingImageUrl = '';
          }
        },
      ).then((_) {
        if (!mounted || failed || _loadingImageUrl != resolved) {
          return;
        }
        setState(() {
          _displayedImageUrl = resolved;
          _loadingImageUrl = '';
        });
        // Sample after the swap so ambient light and artwork change together.
        _requestPalette(resolved, NetworkImage(resolved));
      }),
    );
  }

  void _resetPalette() {
    _paletteKey = '';
    _palette = ArtworkPalette.neutral;
  }

  void _requestPalette(String key, ImageProvider provider) {
    if (_paletteKey == key) {
      return;
    }
    _paletteKey = key;
    final cached = ArtworkPalettes.peek(key);
    if (cached != null) {
      _palette = cached;
      return;
    }
    unawaited(
      ArtworkPalettes.resolve(key, provider).then((palette) {
        if (!mounted || _paletteKey != key || palette == _palette) {
          return;
        }
        setState(() => _palette = palette);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final ambientShift = reduceMotion
        ? AppDurations.reducedMotion
        : AppDurations.quick;
    final customImagePath = widget.customImagePath;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF18202B),
                  Color(0xFF11151E),
                  Color(0xFF090A0F),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: ambientShift,
            curve: AppCurves.sceneEase,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-.62, -.72),
                radius: 1.28,
                colors: [
                  _palette.primary.withValues(alpha: .46),
                  _palette.primary.withValues(alpha: .14),
                  _palette.secondary.withValues(alpha: .1),
                  Colors.transparent,
                ],
                stops: const [0, .42, .72, 1],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: reduceMotion
                ? AppDurations.reducedMotion
                : AppDurations.scene,
            switchInCurve: AppCurves.sceneEase,
            switchOutCurve: AppCurves.sceneEase,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: StackFit.expand,
              children: [
                if (previousChildren.isNotEmpty) previousChildren.last,
                ?currentChild,
              ],
            ),
            child: customImagePath != null && customImagePath.isNotEmpty
                ? RepaintBoundary(
                    key: ValueKey('custom-background-$customImagePath'),
                    child: Image.file(
                      File(customImagePath),
                      fit: BoxFit.cover,
                      cacheWidth: (screenSize.width * pixelRatio).round(),
                      cacheHeight: (screenSize.height * pixelRatio).round(),
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.expand(
                            key: ValueKey('custom-background-error'),
                          ),
                    ),
                  )
                : _displayedImageUrl.isEmpty
                ? const SizedBox.expand(
                    key: ValueKey('ambient-local-placeholder'),
                  )
                : RepaintBoundary(
                    key: ValueKey(_displayedImageUrl),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Blur a downscaled proxy and upscale the result: the
                        // filtered surface is ~16% of the glass area, and the
                        // effective blur stays at the previous sigma.
                        final width = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : screenSize.width;
                        final height = constraints.maxHeight.isFinite
                            ? constraints.maxHeight
                            : screenSize.height;
                        final proxyWidth = (width / _blurDownscale).clamp(
                          1.0,
                          width,
                        );
                        final proxyHeight = (height / _blurDownscale).clamp(
                          1.0,
                          height,
                        );
                        return Transform.scale(
                          scale: 1.24,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.none,
                            child: SizedBox(
                              width: proxyWidth,
                              height: proxyHeight,
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: _blurSigma,
                                  sigmaY: _blurSigma,
                                ),
                                child: ArtworkImage(
                                  imageUrl: _displayedImageUrl,
                                  fit: BoxFit.cover,
                                  backgroundColor: Colors.transparent,
                                  cacheWidth: proxyWidth,
                                  cacheHeight: proxyHeight,
                                  fadeIn: false,
                                  filterQuality: FilterQuality.low,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          // Luminance-aware scrim so white text stays readable over any art.
          AnimatedContainer(
            duration: ambientShift,
            curve: AppCurves.sceneEase,
            color: _palette.contrastScrim,
          ),
        ],
      ),
    );
  }
}
