import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:qqmusic_ipod/core/theme/artwork/artwork_identity.dart';
import 'package:qqmusic_ipod/core/theme/artwork/artwork_palette.dart';

/// Builds with the palette of [imageUrl], starting from the shared cache.
///
/// The first frame always paints: [ArtworkPalette.neutral] is used until
/// sampling finishes, and a cached palette is picked up synchronously so
/// surfaces showing the same artwork agree immediately.
class ArtworkPaletteBuilder extends StatefulWidget {
  const ArtworkPaletteBuilder({
    required this.imageUrl,
    required this.builder,
    super.key,
  });

  final String imageUrl;
  final Widget Function(BuildContext context, ArtworkPalette palette) builder;

  @override
  State<ArtworkPaletteBuilder> createState() => _ArtworkPaletteBuilderState();
}

class _ArtworkPaletteBuilderState extends State<ArtworkPaletteBuilder> {
  ArtworkPalette _palette = ArtworkPalette.neutral;
  String _requested = '';

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ArtworkPaletteBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _sync();
    }
  }

  void _sync() {
    final url = resolveArtworkUrl(widget.imageUrl);
    if (url.isEmpty || url.startsWith('local://')) {
      _requested = '';
      _palette = ArtworkPalette.neutral;
      return;
    }
    if (_requested == url) {
      return;
    }
    _requested = url;
    final cached = ArtworkPalettes.peek(url);
    if (cached != null) {
      _palette = cached;
      return;
    }
    unawaited(
      ArtworkPalettes.resolve(url, NetworkImage(url)).then((palette) {
        if (!mounted || _requested != url || palette == _palette) {
          return;
        }
        setState(() => _palette = palette);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _palette);
}
