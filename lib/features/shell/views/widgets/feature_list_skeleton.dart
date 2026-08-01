import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';

class FeatureListSkeleton extends StatefulWidget {
  const FeatureListSkeleton({super.key});

  @override
  State<FeatureListSkeleton> createState() => _FeatureListSkeletonState();
}

class _FeatureListSkeletonState extends State<FeatureListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion gets a static skeleton: a repeating shimmer is exactly
    // the kind of continuous decoration the setting asks us to stop.
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_animation.isAnimating) {
        _animation.stop();
      }
      _animation.value = .5;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          key: const ValueKey('feature-list-skeleton'),
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.8 + _animation.value * 3.6, 0),
            end: Alignment(-.8 + _animation.value * 3.6, 0),
            colors: const [
              AppColors.skeletonBase,
              AppColors.skeletonHighlight,
              AppColors.skeletonBase,
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 14),
        itemCount: 6,
        separatorBuilder: (context, index) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          return Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.skeletonBase,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: index.isEven ? .62 : .76,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.skeletonBase,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      FractionallySizedBox(
                        widthFactor: index.isEven ? .38 : .48,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.skeletonBase,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
