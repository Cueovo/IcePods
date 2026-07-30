import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/menu_artwork.dart';

const double _menuTileHeight = 48;
const double _menuTileGap = 5;
const double _menuItemExtent = _menuTileHeight + _menuTileGap;

class HomePanel extends StatefulWidget {
  const HomePanel({
    required this.page,
    required this.selectedIndex,
    this.valueForEntry,
    this.descriptionForEntry,
    super.key,
  });

  final MenuPage page;
  final int selectedIndex;
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
    _menuController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.page.entries[widget.selectedIndex];
    final selectedValue = widget.valueForEntry?.call(selected);
    final selectedDescription =
        widget.descriptionForEntry?.call(selected) ?? selected.description;
    // Content floats on ambient; no opaque sheet under the split.
    return Padding(
      // No fixed bottom reserve — list padding clears the glass curve instead.
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 158,
            // Click-wheel navigation owns scrolling; hide the thumb so it
            // never sits against the selected tile highlight.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ListView.separated(
                key: ValueKey('menu-list-${widget.page.section.name}'),
                controller: _menuController,
                // Clear superellipse bottom so last menu row is fully visible.
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
                    value: widget.valueForEntry?.call(
                      widget.page.entries[index],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: const Cubic(0.2, 0.8, 0.2, 1),
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [
                  if (previousChildren.isNotEmpty) previousChildren.last,
                  ?currentChild,
                ],
              ),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: .985, end: 1).animate(animation),
                child: child,
              ),
              child: _PreviewCard(
                key: ValueKey(selected.id),
                entry: selected,
                value: selectedValue,
                description: selectedDescription,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.entry,
    required this.selected,
    required this.value,
  });

  final MenuEntry entry;
  final bool selected;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: selected ? const ValueKey('menu-selection-indicator') : null,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: _menuTileHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0x26FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? const Color(0x33FFFFFF) : Colors.transparent,
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
                border: Border.all(color: const Color(0x66FFFFFF)),
              ),
            )
          else
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: selected
                    ? MenuArtwork.accentFor(entry).withValues(alpha: 0.42)
                    : const Color(0x18FFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? const Color(0x40FFFFFF)
                      : const Color(0x14FFFFFF),
                ),
              ),
              child: Icon(
                MenuArtwork.iconFor(entry),
                size: 15,
                color: selected ? Colors.white : const Color(0xB3FFFFFF),
              ),
            ),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0x99FFFFFF),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                letterSpacing: selected ? 0.1 : 0,
              ),
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (value != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                value!,
                key: ValueKey(value),
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0x99FFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
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
                          style: const TextStyle(
                            color: Color(0xBFFFFFFF),
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
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
