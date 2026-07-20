import 'package:qqmusic_ipod/business/entities/music.dart';

enum PlayerMode { menu, coverFlow, player, feature }

enum MenuAction { submenu, feature, coverFlow, player, info, chassisColor }

enum MenuSection {
  root,
  recommendations,
  musicHall,
  myMusic,
  settings,
  chassisColor,
}

class MenuEntry {
  const MenuEntry({
    required this.id,
    required this.label,
    required this.action,
    required this.imageUrl,
    required this.title,
    required this.description,
    this.section,
    this.feature,
    this.apiOperation,
    this.capabilities = const [],
    this.chassisColorValue,
  });

  final String id;
  final String label;
  final MenuAction action;
  final String imageUrl;
  final String title;
  final String description;
  final MenuSection? section;
  final QqMusicFeature? feature;
  final String? apiOperation;
  final List<String> capabilities;
  /// ARGB color used by [MenuAction.chassisColor] entries.
  final int? chassisColorValue;
}

class MenuPage {
  const MenuPage({
    required this.section,
    required this.title,
    required this.entries,
  });

  final MenuSection section;
  final String title;
  final List<MenuEntry> entries;
}

class Album {
  const Album({
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.songId = '',
    this.songMid = '',
  });

  final String title;
  final String artist;
  final String imageUrl;
  final String songId;
  final String songMid;

  bool get hasLinkedSong => songId.isNotEmpty || songMid.isNotEmpty;
}

const coverFlowLibrary = <Album>[
  Album(
    title: 'Midnight City',
    artist: 'M83',
    imageUrl:
        'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=400&fit=crop',
  ),
  Album(
    title: 'Lover Boy 88',
    artist: 'Higher Brothers',
    imageUrl:
        'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?q=80&w=400&fit=crop',
  ),
  Album(
    title: 'Starboy',
    artist: 'The Weeknd',
    imageUrl:
        'https://images.unsplash.com/photo-1619983081563-430f63602796?q=80&w=400&fit=crop',
  ),
  Album(
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    imageUrl:
        'https://images.unsplash.com/photo-1493225457124-a1a2a53b111b?q=80&w=400&fit=crop',
  ),
  Album(
    title: 'Random Access',
    artist: 'Daft Punk',
    imageUrl:
        'https://images.unsplash.com/photo-1586772002130-b0f3daa6288b?q=80&w=400&fit=crop',
  ),
  Album(
    title: 'Plastic Love',
    artist: 'Mariya Takeuchi',
    imageUrl:
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=400&fit=crop',
  ),
];
