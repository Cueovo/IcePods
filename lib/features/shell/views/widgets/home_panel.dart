import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/core/theme/tokens/app_tokens.dart';
import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/menu_artwork.dart';

const double _menuTileHeight = 48;
const double _menuTileGap = 5;
const double _menuItemExtent = _menuTileHeight + _menuTileGap;
const double _defaultRailWidth = 158;
const double _minRailWidth = 132;
const double _maxRailWidth = 190;
const double _railGap = 15;

class HomePanel extends StatefulWidget {
  const HomePanel({
    required this.page,
    required this.selectedIndex,
    this.railWidth = _defaultRailWidth,
    this.valueForEntry,
    this.descriptionForEntry,
    super.key,
  });

  final MenuPage page;
  final int selectedIndex;

  /// Width of the menu list column. Clamped so the preview keeps room on
  /// narrow phones and does not become a thin strip on tablets.
  final double railWidth;
  final String? Function(MenuEntry entry)? valueForEntry;
  final String Function(MenuEntry entry)? descriptionForEntry;

  @override
  State<HomePanel> createState() => _HomePanelState();
}

class _HomePanelState extends State<HomePanel> {
  final ScrollController _menuController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelection());
  }

  @override
  void didUpdateWidget(HomePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.section != widget.page.section ||
        oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelection());
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _revealSelection() {
    if (!_menuController.hasClients) {
      return;
    }
    final position = _menuController.position;
    final itemTop = widget.selectedIndex * _menuItemExtent;
    final itemBottom = itemTop + _menuTileHeight;
    final viewTop = position.pixels;
    final viewBottom = viewTop + position.viewportDimension;

    double target;
    if (itemTop < viewTop + 4) {
      target = itemTop;
    } else if (itemBottom > viewBottom - 4) {
      target = itemBottom - position.viewportDimension + 4;
    } else {
      // Already fully visible 鈥?no need to scroll.
      return;
    }

    target = target.clamp(0.0, position.maxScrollExtent).toDouble();
    if ((target - viewTop).abs() < 1) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _menuController.jumpTo(target);
      return;
    }
    _menuController.animateTo(
      target,
      duration: AppDurations.quick,
      curve: AppCurves.strongEaseOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.page.entries[widget.selectedIndex];
    final selectedValue = widget.valueForEntry?.call(selected);
    final selectedDescription =
        widget.descriptionForEntry?.call(selected) ?? selected.description;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // Content floats on ambient; no opaque sheet under the split.
    return Padding(
      // No fixed bottom reserve — list padding clears the glass curve instead.
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Never let the rail eat more than half of the available width.
          final available = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : _defaultRailWidth * 2;
          final railWidth = widget.railWidth
              .clamp(_minRailWidth, _maxRailWidth)
              .clamp(_minRailWidth, (available - _railGap) * .56)
              .toDouble();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: railWidth,
                // Click-wheel navigation owns scrolling; hide the thumb so it
                // never sits against the selected tile highlight.
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView.separated(
                    key: ValueKey('menu-list-${widget.page.section.name}'),
                    controller: _menuController,
                    // Clear superellipse bottom so last menu row is fully
                    // visible.
                    padding: const EdgeInsets.only(bottom: 4),
                    clipBehavior: Clip.none,
                    physics: const ClampingScrollPhysics(),
                    itemCount: widget.page.entries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: _menuTileGap),
                    itemBuilder: (context, index) {
                      return _MenuTile(
                        entry: widget.page.entries[index],
                        selected: widget.selectedIndex == index,
                        reduceMotion: reduceMotion,
                        value: widget.valueForEntry?.call(
                          widget.page.entries[index],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: _railGap),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? AppDurations.reducedMotion
                      : AppDurations.quick,
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    fit: StackFit.expand,
                    children: [
                      if (previousChildren.isNotEmpty) previousChildren.last,
                      ?currentChild,
                    ],
                  ),
                  transitionBuilder: (child, animation) {
                    // Fade the outgoing card out early: two opaque preview cards
                    // stacked in the same plane read as a double exposure.
                    final opacity = CurvedAnimation(
                      parent: animation,
                      curve: AppCurves.sceneEase,
                    );
                    if (reduceMotion) {
                      return FadeTransition(opacity: opacity, child: child);
                    }
                    return FadeTransition(
                      opacity: opacity,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: .985,
                          end: 1,
                        ).animate(opacity),
                        child: child,
                      ),
                    );
                  },
                  child: _PreviewCard(
                    key: ValueKey(selected.id),
                    entry: selected,
                    value: selectedValue,
                    description: selectedDescription,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.entry,
    required this.selected,
    required this.reduceMotion,
    required this.value,
  });

  final MenuEntry entry;
  final bool selected;
  final bool reduceMotion;
  final String? value;

  @override
  Widget build(BuildContext context) {
    // Selection feedback is the highest-frequency motion in the app; keep it
    // short enough that rapid wheel rotation never trails the input.
    final feedback = reduceMotion
        ? AppDurations.reducedMotion
        : AppDurations.press;
    return AnimatedContainer(
      key: selected ? const ValueKey('menu-selection-indicator') : null,
      duration: feedback,
      curve: AppCurves.strongEaseOut,
      height: _menuTileHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.glassMid : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? AppColors.interactionSoft : Colors.transparent,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          if (entry.action == MenuAction.chassisColor &&
              entry.chassisColorValue != null)
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Color(entry.chassisColorValue!),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textTertiary),
              ),
            )
          else
            AnimatedContainer(
              duration: feedback,
              curve: AppCurves.strongEaseOut,
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: selected
                    ? MenuArtwork.accentFor(entry).withValues(alpha: 0.42)
                    : AppColors.glassLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? AppColors.textTertiary.withValues(alpha: .5)
                      : AppColors.border,
                ),
              ),
              child: Icon(
                MenuArtwork.iconFor(entry),
                size: 15,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: feedback,
              curve: AppCurves.strongEaseOut,
              style: (selected ? AppTextStyles.label : AppTextStyles.body)
                  .copyWith(letterSpacing: selected ? 0.1 : 0),
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (value != null)
            AnimatedSwitcher(
              duration: feedback,
              child: Text(
                value!,
                key: ValueKey(value),
                style: (selected ? AppTextStyles.label : AppTextStyles.metadata)
                    .copyWith(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
              ),
            )
          else
            AnimatedOpacity(
              duration: feedback,
              opacity: selected ? 1 : .28,
              child: Icon(
                switch (entry.action) {
                  MenuAction.player => Icons.play_arrow_rounded,
                  MenuAction.info || MenuAction.setting => Icons.tune_rounded,
                  MenuAction.chassisColor => Icons.circle_outlined,
                  _ => Icons.chevron_right_rounded,
                },
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.entry,
    required this.value,
    required this.description,
    super.key,
  });

  final MenuEntry entry;
  final String? value;
  final String description;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final height = maxHeight.isFinite
            ? maxHeight.clamp(140.0, 280.0)
            : 280.0;
        final radius = BorderRadius.circular(22);
        final accent = MenuArtwork.accentFor(entry);
        final icon = MenuArtwork.iconFor(entry);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: ValueKey('menu-artwork-${entry.id}'),
            height: height,
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Frost ambient behind the card so it shares the screen wash.
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: const ColoredBox(color: Color(0x1AFFFFFF)),
                  ),
                  // Soft accent wash 鈥?not a solid opaque panel.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.38),
                          const Color(0x33000000),
                          const Color(0x52000000),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -24,
                    top: -20,
                    child: Icon(
                      icon,
                      size: 140,
                      color: const Color(0x18FFFFFF),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x22FFFFFF)),
                      ),
                      child: Icon(icon, size: 40, color: Colors.white),
                    ),
                  ),
                  // Bottom readability only 鈥?keep top open to ambient.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xB8000000),
                          Color(0x3D000000),
                          Color(0x00000000),
                        ],
                        stops: [0, 0.48, 0.88],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: const Color(0x22FFFFFF)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                entry.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.title.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            if (value != null) ...[
                              const SizedBox(width: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                child: DecoratedBox(
                                  key: ValueKey(value),
                                  decoration: BoxDecoration(
                                    color: const Color(0x24FFFFFF),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: const Color(0x30FFFFFF),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      value!,
                                      style: AppTextStyles.metadata.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: AppTextStyles.strong,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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
