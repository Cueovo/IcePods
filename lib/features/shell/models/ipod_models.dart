import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/core/storage/app_settings_store.dart';

enum PlayerMode { menu, coverFlow, player, feature }

enum MenuAction {
  submenu,
  feature,
  coverFlow,
  player,
  info,
  chassisColor,
  setting,
}

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
    this.setting,
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
  final AppSetting? setting;
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
    imageUrl: 'local://album/midnight-city',
  ),
  Album(
    title: 'Lover Boy 88',
    artist: 'Higher Brothers',
    imageUrl: 'local://album/lover-boy-88',
  ),
  Album(
    title: 'Starboy',
    artist: 'The Weeknd',
    imageUrl: 'local://album/starboy',
  ),
  Album(
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    imageUrl: 'local://album/blinding-lights',
  ),
  Album(
    title: 'Random Access',
    artist: 'Daft Punk',
    imageUrl: 'local://album/random-access',
  ),
  Album(
    title: 'Plastic Love',
    artist: 'Mariya Takeuchi',
    imageUrl: 'local://album/plastic-love',
  ),
];
