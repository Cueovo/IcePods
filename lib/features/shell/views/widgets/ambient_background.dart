import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';

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
  static const _accents = [
    Color(0xFF31C27C),
    Color(0xFF5A8DEE),
    Color(0xFFE15D8A),
    Color(0xFFF0A44B),
    Color(0xFF8B6BE8),
  ];

  String _displayedImageUrl = '';
  String _loadingImageUrl = '';

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
    if (widget.customImagePath?.isNotEmpty == true) {
      _loadingImageUrl = '';
      return;
    }
    final resolved = widget.imageUrl.replaceFirst(
      _qqHttpCoverHost,
      'https://y.gtimg.cn/',
    );
    if (resolved.startsWith('local://')) {
      _loadingImageUrl = '';
      _displayedImageUrl = resolved;
      return;
    }
    if (resolved.isEmpty) {
      _loadingImageUrl = '';
      _displayedImageUrl = '';
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
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final customImagePath = widget.customImagePath;
    final seed = widget.imageUrl.codeUnits.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final accent = _accents[seed % _accents.length];
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
            duration: AppDurations.standard,
            curve: AppCurves.standard,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-.62, -.72),
                radius: 1.28,
                colors: [
                  accent.withValues(alpha: .46),
                  accent.withValues(alpha: .12),
                  Colors.transparent,
                ],
                stops: const [0, .46, 1],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: AppDurations.emphasized,
            switchInCurve: AppCurves.menuPage,
            switchOutCurve: AppCurves.standard,
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
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 44, sigmaY: 44),
                      child: Transform.scale(
                        scale: 1.24,
                        child: ArtworkImage(
                          imageUrl: _displayedImageUrl,
                          fit: BoxFit.cover,
                          backgroundColor: Colors.transparent,
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
