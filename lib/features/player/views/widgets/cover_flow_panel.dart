import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/feature_message_state.dart';

class CoverFlowPanel extends StatelessWidget {
  const CoverFlowPanel({
    required this.selectedIndex,
    this.albums = coverFlowLibrary,
    super.key,
  });

  final int selectedIndex;
  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const FeatureMessageState(
        icon: Icons.album_rounded,
        title: '暂无封面数据',
        subtitle: '播放一些歌曲后，这里会展示封面',
      );
    }
    final safeIndex = selectedIndex.clamp(0, albums.length - 1);
    final album = albums[safeIndex];
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    const renderRadius = 4;
    final firstVisible = math.max(0, safeIndex - renderRadius);
    final lastVisible = math.min(albums.length - 1, safeIndex + renderRadius);
    final paintOrder =
        List<int>.generate(
          lastVisible - firstVisible + 1,
          (index) => firstVisible + index,
        )..sort((a, b) {
          final aDistance = (a - safeIndex).abs();
          final bDistance = (b - safeIndex).abs();
          return bDistance.compareTo(aDistance);
        });

    return LayoutBuilder(
      builder: (context, constraints) {
        final metaGap = constraints.maxHeight < 260 ? 10.0 : 18.0;
        final metaWidth = constraints.maxWidth.isFinite
            ? math.min(288.0, constraints.maxWidth - 24)
            : 288.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 3D 舞台：占据除元数据之外的全部高度，短屏也不会压到文字。
            Expanded(
              child: LayoutBuilder(
                builder: (context, stage) {
                  final stageHeight = stage.maxHeight.isFinite
                      ? stage.maxHeight
                      : 200.0;
                  final stageWidth = stage.maxWidth.isFinite
                      ? stage.maxWidth
                      : 320.0;
                  // Card leaves room for its reflection below the centre line.
                  final cardSize = math
                      .min(stageHeight * .58, stageWidth * .42)
                      .clamp(72.0, 168.0)
                      .toDouble();
                  // Reflection is clipped to the floor plane of the stage
                  // instead of a fixed pixel height, so it never reaches the
                  // metadata on short viewports.
                  final reflectionHeight = math
                      .max(0.0, (stageHeight - cardSize) / 2 - 4)
                      .clamp(0.0, cardSize)
                      .toDouble();
                  return SizedBox(
                    width: double.infinity,
                    // 【核心修复 1】：全局透视摄像机！
                    // 正数的 0.00125 完美等价于 HTML 的 perspective: 800px
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..setEntry(3, 2, 0.00125),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          for (final index in paintOrder)
                            _CoverFlowItem(
                              key: ValueKey('cover-$index'),
                              album: albums[index],
                              offset: index - safeIndex,
                              reduceMotion: reduceMotion,
                              cardSize: cardSize,
                              reflectionHeight: reflectionHeight,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: metaGap),
            AnimatedSwitcher(
              duration: reduceMotion
                  ? AppDurations.reducedMotion
                  : AppDurations.quick,
              switchInCurve: AppCurves.sceneEase,
              switchOutCurve: AppCurves.sceneEase,
              transitionBuilder: (child, animation) {
                if (reduceMotion) {
                  return FadeTransition(opacity: animation, child: child);
                }
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.18),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                key: ValueKey(safeIndex),
                width: metaWidth,
                child: Column(
                  children: [
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.metadata.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CoverFlowItem extends StatelessWidget {
  const _CoverFlowItem({
    required this.album,
    required this.offset,
    required this.reduceMotion,
    required this.cardSize,
    required this.reflectionHeight,
    super.key,
  });

  /// Authored card size all the 3D constants were tuned against.
  static const double _referenceCard = 140;

  final Album album;
  final int offset;
  final bool reduceMotion;
  final double cardSize;
  final double reflectionHeight;

  @override
  Widget build(BuildContext context) {
    final targetOffset = offset.toDouble();
    // Geometry scales with the card so the stage keeps its proportions on
    // every viewport instead of assuming a 140px cover.
    final cardScale = cardSize / _referenceCard;
    final decodeSize = (cardSize + 4).round();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetOffset),
      duration: reduceMotion ? Duration.zero : AppDurations.emphasized,
      curve: AppCurves.movementEase,
      builder: (context, animatedOffset, child) {
        final distance = animatedOffset.abs();
        final direction = animatedOffset.sign;

        final sideProgress = distance.clamp(0.0, 1.0);
        final extraDistance = math.max(distance - 1.0, 0.0);

        // ================== 1:1 完美复刻 HTML 的 3D 数学 ==================

        // 1. X轴位移：中心0，侧边第一张 105，后续每张堆叠 25
        final translateX =
            direction *
            (sideProgress * 105.0 + extraDistance * 25.0) *
            cardScale;

        // 2. Flutter 的 Z 轴方向与 CSS 透视相反，因此 rotateY 也要反号。
        // 右侧使用正角度，让右边缘朝镜头抬起；左侧保持镜像。
        // Reduced motion keeps the covers flat instead of rotating them in 3D.
        final rotateY = reduceMotion
            ? 0.0
            : direction * sideProgress * 65.0 * math.pi / 180.0;

        // 3. Z轴深度：Flutter 中负数代表弹出，正数代表后退。
        // 中心弹出 (-50)，侧面后退 (+40)，更远处的继续后退 (+40)
        final translateZ = reduceMotion
            ? 0.0
            : (-50.0 + sideProgress * 90.0 + extraDistance * 40.0) * cardScale;

        // 4. 缩放比例
        final scale = 1.15 - sideProgress * 0.25;

        // ================== 光影与透明度 ==================
        final opacity = math.max(1.0 - distance * 0.25, 0.0);
        final brightness = 1.0 - sideProgress * 0.6;
        final brightnessChannel = (brightness * 255).round();
        final brightnessColor = Color.fromARGB(
          255,
          brightnessChannel,
          brightnessChannel,
          brightnessChannel,
        );

        // 纯粹的 TRS 矩阵，透视已交给外层 Stack
        final matrix = Matrix4.identity()
          ..translateByDouble(translateX, 0.0, translateZ, 1.0)
          ..rotateY(rotateY)
          ..scaleByDouble(scale, scale, scale, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform(
            transform: matrix,
            // 【核心修复 2】：旋转轴心固定在实体封面的几何中心
            // 完整倒影通过溢出绘制，不参与变换组件的布局尺寸
            alignment: Alignment.center,
            child: SizedBox(
              width: cardSize,
              height: cardSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // --- 下半部：玻璃倒影 ---
                  if (reflectionHeight > 0)
                    Positioned(
                      left: -2,
                      top: cardSize + 2,
                      child: SizedBox(
                        width: cardSize + 4,
                        height: reflectionHeight,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: cardSize + 4,
                            child: SizedBox(
                              width: cardSize + 4,
                              height: cardSize + 4,
                              child: ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (bounds) {
                                  return const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x66FFFFFF),
                                      Color(0x66FFFFFF),
                                      Color(0x00FFFFFF),
                                      Color(0x00FFFFFF),
                                    ],
                                    stops: [0, .014, .403, 1],
                                  ).createShader(bounds);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Transform.flip(
                                    flipY: true,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.artwork,
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: Transform.scale(
                                        scale: 1.015,
                                        filterQuality: FilterQuality.high,
                                        child: ArtworkImage(
                                          imageUrl: album.imageUrl,
                                          backgroundColor: Colors.transparent,
                                          color: brightnessColor,
                                          colorBlendMode: BlendMode.modulate,
                                          cacheWidth: decodeSize.toDouble(),
                                          cacheHeight: decodeSize.toDouble(),
                                          fadeIn: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // --- 上半部：实体卡片 ---
                  Container(
                    width: cardSize,
                    height: cardSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.artwork),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x99000000),
                          blurRadius: 30 * cardScale,
                          offset: Offset(0, 15 * cardScale),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.artwork),
                      clipBehavior: Clip.antiAlias,
                      child: Transform.scale(
                        scale: 1.015,
                        filterQuality: FilterQuality.high,
                        child: ArtworkImage(
                          imageUrl: album.imageUrl,
                          backgroundColor: Colors.transparent,
                          color: brightnessColor,
                          colorBlendMode: BlendMode.modulate,
                          cacheWidth: decodeSize.toDouble(),
                          cacheHeight: decodeSize.toDouble(),
                          fadeIn: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
