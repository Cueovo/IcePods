import 'package:flutter/foundation.dart';

import 'package:qqmusic_ipod/features/shell/models/ipod_models.dart';

final RegExp _qqHttpCoverHost = RegExp(r'^http://y\.gtimg\.cn/');

/// QQ covers sometimes arrive over plain http. Every surface must resolve them
/// the same way or the image cache and the palette cache split in two.
String resolveArtworkUrl(String imageUrl) {
  return imageUrl.replaceFirst(_qqHttpCoverHost, 'https://y.gtimg.cn/');
}

/// Identifies one piece of artwork as it travels between surfaces.
///
/// Cover Flow, Now Playing and the queue all describe the same album with the
/// same [key] and [imageUrl], so they share decoded images, palettes and
/// transition identity instead of each fetching their own.
@immutable
class ArtworkIdentity {
  const ArtworkIdentity({required this.key, required this.imageUrl});

  ArtworkIdentity.album(Album album)
    : key = 'album:${album.title}·${album.artist}',
      imageUrl = album.imageUrl;

  static const empty = ArtworkIdentity(key: '', imageUrl: '');

  final String key;
  final String imageUrl;

  bool get isEmpty => imageUrl.isEmpty;

  /// Cache key shared with the ambient palette sampler.
  String get paletteKey => resolveArtworkUrl(imageUrl);

  @override
  bool operator ==(Object other) {
    return other is ArtworkIdentity &&
        other.key == key &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode => Object.hash(key, imageUrl);

  @override
  String toString() => 'ArtworkIdentity($key)';
}
