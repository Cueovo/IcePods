import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../ipod_models.dart';
import '../ui_tokens.dart';
import 'artwork_image.dart';

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
      return const Center(
        child: Text(
          '暂无封面数据',
          style: TextStyle(color: Color(0x80FFFFFF), fontSize: 14),
        ),
      );
    }
    final safeIndex = selectedIndex.clamp(0, albums.length - 1);
    final album = albums[safeIndex];

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

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // 3D 舞台
        SizedBox(
          height: 235,
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
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        AnimatedSwitcher(
          duration: AppDurations.standard,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: SizedBox(
            key: ValueKey(safeIndex),
            width: 288,
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
  }
}

class _CoverFlowItem extends StatelessWidget {
  const _CoverFlowItem({required this.album, required this.offset, super.key});

  final Album album;
  final int offset;

  @override
  Widget build(BuildContext context) {
    final targetOffset = offset.toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetOffset),
      duration: AppDurations.emphasized,
      curve: AppCurves.standard,
      builder: (context, animatedOffset, child) {
        final distance = animatedOffset.abs();
        final direction = animatedOffset.sign;

        final sideProgress = distance.clamp(0.0, 1.0);
        final extraDistance = math.max(distance - 1.0, 0.0);

        // ================== 1:1 完美复刻 HTML 的 3D 数学 ==================

        // 1. X轴位移：中心0，侧边第一张 105，后续每张堆叠 25
        final translateX =
            direction * (sideProgress * 105.0 + extraDistance * 25.0);

        // 2. Flutter 的 Z 轴方向与 CSS 透视相反，因此 rotateY 也要反号。
        // 右侧使用正角度，让右边缘朝镜头抬起；左侧保持镜像。
        final rotateY = direction * sideProgress * 65.0 * math.pi / 180.0;

        // 3. Z轴深度：Flutter 中负数代表弹出，正数代表后退。
        // 中心弹出 (-50)，侧面后退 (+40)，更远处的继续后退 (+40)
        final translateZ = -50.0 + sideProgress * 90.0 + extraDistance * 40.0;

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
            // 【核心修复 2】：旋转轴心固定在 140x140 实体封面的几何中心
            // 完整倒影通过溢出绘制，不参与变换组件的布局尺寸
            alignment: Alignment.center,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // --- 下半部：玻璃倒影 ---
                  Positioned(
                    left: -2,
                    top: 142,
                    child: SizedBox(
                      width: 144,
                      height: 144,
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
                                  cacheWidth: 144,
                                  cacheHeight: 144,
                                  fadeIn: false,
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
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.artwork),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 30,
                          offset: Offset(0, 15),
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
                          cacheWidth: 144,
                          cacheHeight: 144,
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
