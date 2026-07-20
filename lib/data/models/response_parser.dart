import 'dart:convert';

import 'package:qqmusic_ipod/business/entities/music.dart';

class QqMusicResponseParser {
  const QqMusicResponseParser();

  QqMusicFeatureResult parseFeature(
    QqMusicFeature feature,
    Object? data, {
    required String title,
    int limit = 25,
    int page = 1,
  }) {
    final map = _map(data);
    final items = switch (feature) {
      QqMusicFeature.guessRecommendations => _songs(map['songs']),
      QqMusicFeature.homeFeed => _homeFeed(data),
      QqMusicFeature.radar => _songs(map['songs']),
      QqMusicFeature.newSongs => _songs(map['songs']),
      QqMusicFeature.recommendedPlaylists => _playlists(map['songlists']),
      QqMusicFeature.charts => _charts(map['group']),
      QqMusicFeature.singers => _singers(map['singerlist']),
      QqMusicFeature.likedSongs => _songs(map['songs']),
      QqMusicFeature.favoriteAlbums => _albums(map['albums']),
      QqMusicFeature.favoriteMusicVideos => _musicVideos(map['mv_list']),
      QqMusicFeature.favoriteSingers => _relationSingers(map['users']),
      QqMusicFeature.createdPlaylists => _playlists(map['playlists']),
      QqMusicFeature.collectedPlaylists => _playlists(map['playlists']),
      QqMusicFeature.dislikes => _dislikes(map),
      QqMusicFeature.search || QqMusicFeature.account => const <QqMusicItem>[],
    };
    final returnedSize = _int(map['size']);
    final total = _int(map['total']);
    final loadedThrough =
        (page - 1) * limit + (returnedSize > 0 ? returnedSize : items.length);
    final limitedItems = feature == QqMusicFeature.homeFeed
        ? items
        : items.take(limit).toList(growable: false);
    return QqMusicFeatureResult(
      title: title,
      items: limitedItems,
      hasMore:
          _bool(map['has_more']) ||
          _int(map['hasmore']) != 0 ||
          (total > 0 && loadedThrough < total) ||
          (feature == QqMusicFeature.homeFeed &&
              _int(map['d_num']) > limitedItems.length),
      message: _string(map['msg'] ?? map['toast'] ?? map['ret_msg']),
    );
  }

  QqMusicFeatureResult parseSearch(Object? data, {required String keyword}) {
    final map = _map(data);
    // Songs / artists / albums / playlists only — skip MVs (they open externally).
    final items = <QqMusicItem>[
      ..._songs(_map(map['song'])['items']),
      ..._singers(_map(map['singer'])['items']),
      ..._albums(_map(map['album'])['items']),
      ..._playlists(_map(map['songlist'])['items']),
    ];
    return QqMusicFeatureResult(
      title: '搜索：$keyword',
      items: items,
      hasMore: _int(map['nextpage']) > 0,
    );
  }

  QqMusicFeatureResult parseChildren(
    QqMusicItem parent,
    Object? data, {
    int limit = 25,
    int page = 1,
  }) {
    final map = _map(data);
    final rawSongs = map['songs'] ?? map['song_list'] ?? map['songlist'];
    final items = _songs(rawSongs);
    final returnedSize = _int(map['size']);
    final total = _int(map['total']);
    final loadedThrough =
        (page - 1) * limit + (returnedSize > 0 ? returnedSize : items.length);
    return QqMusicFeatureResult(
      title: parent.title,
      items: items,
      hasMore:
          _bool(map['has_more']) ||
          _int(map['hasmore']) != 0 ||
          (total > 0 && loadedThrough < total),
      message: _string(map['msg']),
    );
  }

  QqMusicLyrics parseLyrics(Object? data) {
    final map = _map(data);
    var raw = _string(map['lyric']);
    if (raw.isEmpty) {
      raw = _string(map['qrc']);
    }
    if (raw.isEmpty) {
      raw = _string(map['lrc']);
    }
    raw = _decodeLyric(raw);
    final qrcLines = _parseQrcLyrics(raw);
    if (qrcLines.isNotEmpty) {
      return QqMusicLyrics(lines: List.unmodifiable(qrcLines));
    }
    return QqMusicLyrics(lines: List.unmodifiable(_parseLrcLyrics(raw)));
  }

  String _decodeLyric(String raw) {
    var decoded = raw;
    if (decoded.isNotEmpty &&
        !decoded.contains('[') &&
        !decoded.contains('<Lyric_1')) {
      try {
        decoded = utf8.decode(base64Decode(decoded));
      } catch (_) {}
    }
    final content = RegExp(
      'LyricContent="([\\s\\S]*?)"',
    ).firstMatch(decoded)?.group(1);
    return (content ?? decoded)
        .replaceAll('&#10;', '\n')
        .replaceAll('&#13;', '\r')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  List<QqMusicLyricLine> _parseQrcLyrics(String raw) {
    final lines = <QqMusicLyricLine>[];
    final linePattern = RegExp(r'^\[(\d+),(\d+)\](.*)$');
    final wordPattern = RegExp(r'([^()]*)\((\d+),(\d+)\)');
    for (final sourceLine in const LineSplitter().convert(raw)) {
      final lineMatch = linePattern.firstMatch(sourceLine.trim());
      if (lineMatch == null) {
        continue;
      }
      final lineStart = int.parse(lineMatch.group(1)!);
      final lineDuration = int.parse(lineMatch.group(2)!);
      final words = <QqMusicLyricWord>[];
      for (final match in wordPattern.allMatches(lineMatch.group(3)!)) {
        final text = match.group(1) ?? '';
        if (text.isEmpty || text == '\r') {
          continue;
        }
        words.add(
          QqMusicLyricWord(
            text: text,
            time: Duration(milliseconds: int.parse(match.group(2)!)),
            duration: Duration(milliseconds: int.parse(match.group(3)!)),
          ),
        );
      }
      if (words.isEmpty) {
        continue;
      }
      lines.add(
        QqMusicLyricLine(
          time: Duration(milliseconds: lineStart),
          duration: Duration(milliseconds: lineDuration),
          text: words.map((word) => word.text).join(),
          words: List.unmodifiable(words),
        ),
      );
    }
    lines.sort((left, right) => left.time.compareTo(right.time));
    return lines;
  }

  List<QqMusicLyricLine> _parseLrcLyrics(String raw) {
    final lines = <QqMusicLyricLine>[];
    final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
    for (final sourceLine in const LineSplitter().convert(raw)) {
      final matches = timestamp.allMatches(sourceLine).toList(growable: false);
      final text = sourceLine.replaceAll(timestamp, '').trim();
      if (matches.isEmpty || text.isEmpty) {
        continue;
      }
      for (final match in matches) {
        final fraction = match.group(3) ?? '';
        lines.add(
          QqMusicLyricLine(
            time: Duration(
              minutes: int.parse(match.group(1)!),
              seconds: int.parse(match.group(2)!),
              milliseconds: fraction.isEmpty
                  ? 0
                  : int.parse(fraction.padRight(3, '0').substring(0, 3)),
            ),
            text: text,
          ),
        );
      }
    }
    lines.sort((left, right) => left.time.compareTo(right.time));
    return lines;
  }

  QqMusicItem parseSongDetail(Object? data) {
    return parseSong(_map(data)['track']);
  }

  QqMusicItem parseSong(Object? value) {
    final song = _map(value);
    final album = _map(song['album']);
    final file = _map(song['file']);
    final pay = _map(song['pay']);
    final singers = _list(song['singer']);
    final singerNames = singers
        .map((singer) => _string(_map(singer)['name']))
        .where((name) => name.isNotEmpty)
        .join(' / ');
    final albumMid = _string(album['mid']);
    return QqMusicItem(
      id: _string(song['id'] ?? song['songid'] ?? song['song_id']),
      mid: _string(song['mid'] ?? song['songmid'] ?? song['song_mid']),
      mediaMid: _string(file['media_mid']),
      title: _clean(_string(song['title'] ?? song['name'])),
      subtitle: _clean(
        singerNames.isNotEmpty
            ? singerNames
            : _string(song['subtitle'] ?? album['name']),
      ),
      imageUrl: albumMid.isEmpty ? '' : _albumCover(albumMid),
      type: QqMusicItemType.song,
      duration: Duration(seconds: _int(song['interval'])),
      songType: _nullableInt(song['type']),
      requiresVip: _int(pay['pay_play']) != 0,
      isCopyrightRestricted: _isCopyrightRestricted(file),
    );
  }

  List<QqMusicItem> _songs(Object? value) {
    return _list(
      value,
    ).map(parseSong).where((item) => item.id.isNotEmpty).toList();
  }

  List<QqMusicItem> _playlists(Object? value) {
    return _list(value)
        .map((raw) {
          final item = _map(raw);
          return QqMusicItem(
            id: _string(item['id'] ?? item['tid']),
            directoryId: _string(item['dirid']),
            title: _clean(_string(item['title'] ?? item['name'])),
            subtitle: _clean(
              _string(
                item['creator_nick'] ??
                    item['nickname'] ??
                    item['nick'] ??
                    item['desc'],
              ),
            ),
            imageUrl: _string(
              item['picurl'] ?? item['bigpic_url'] ?? item['album_pic_url'],
            ),
            type: QqMusicItemType.playlist,
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  List<QqMusicItem> _charts(Object? value) {
    final charts = <QqMusicItem>[];
    for (final rawGroup in _list(value)) {
      final group = _map(rawGroup);
      for (final rawChart in _list(group['toplist'])) {
        final chart = _map(rawChart);
        charts.add(
          QqMusicItem(
            id: _string(chart['id']),
            title: _clean(_string(chart['name'])),
            subtitle: _clean(
              _string(chart['title_detail'] ?? chart['update_time']),
            ),
            imageUrl: _string(chart['front_pic_url'] ?? chart['head_pic_url']),
            type: QqMusicItemType.chart,
          ),
        );
      }
    }
    return charts;
  }

  List<QqMusicItem> _singers(Object? value) {
    return _list(value)
        .map((raw) {
          final singer = _map(raw);
          final mid = _string(singer['mid']);
          return QqMusicItem(
            id: _string(singer['id'] ?? mid),
            mid: mid,
            title: _clean(_string(singer['name'] ?? singer['title'])),
            subtitle: _clean(
              _string(
                singer['subtitle'] ?? singer['other_name'] ?? singer['country'],
              ),
            ),
            imageUrl: _string(singer['pic'] ?? singer['singer_pic']).isNotEmpty
                ? _string(singer['pic'] ?? singer['singer_pic'])
                : mid.isEmpty
                ? ''
                : _singerCover(mid),
            type: QqMusicItemType.singer,
          );
        })
        .where((item) => item.mid.isNotEmpty)
        .toList();
  }

  List<QqMusicItem> _relationSingers(Object? value) {
    return _list(value)
        .map((raw) {
          final singer = _map(raw);
          final mid = _string(singer['mid']);
          return QqMusicItem(
            id: _string(singer['enc_uin'] ?? mid),
            mid: mid,
            title: _clean(_string(singer['name'])),
            subtitle: _clean(_string(singer['desc'])),
            imageUrl: _string(singer['avatar_url']),
            type: QqMusicItemType.singer,
          );
        })
        .where((item) => item.mid.isNotEmpty)
        .toList();
  }

  List<QqMusicItem> _albums(Object? value) {
    return _list(value)
        .map((raw) {
          final album = _map(raw);
          final mid = _string(album['mid']);
          final singer = album['singer'] is String
              ? _string(album['singer'])
              : _list(album['singers'])
                    .map((value) => _string(_map(value)['name']))
                    .where((name) => name.isNotEmpty)
                    .join(' / ');
          return QqMusicItem(
            id: _string(album['id'] ?? mid),
            mid: mid,
            title: _clean(_string(album['title'] ?? album['name'])),
            subtitle: _clean(singer),
            imageUrl: _string(album['pic']).isNotEmpty
                ? _string(album['pic'])
                : mid.isEmpty
                ? ''
                : _albumCover(mid),
            type: QqMusicItemType.album,
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  List<QqMusicItem> _musicVideos(Object? value) {
    return _list(value)
        .map((raw) {
          final mv = _map(raw);
          return QqMusicItem(
            id: _string(mv['id'] ?? mv['vid']),
            mid: _string(mv['vid']),
            title: _clean(_string(mv['title'] ?? mv['name'])),
            subtitle: _clean(_string(mv['singer_name'])),
            imageUrl: _string(mv['picurl'] ?? mv['pic']),
            type: QqMusicItemType.musicVideo,
            duration: Duration(seconds: _int(mv['duration'])),
          );
        })
        .where((item) => item.mid.isNotEmpty)
        .toList();
  }

  List<QqMusicItem> _dislikes(Map<String, dynamic> data) {
    return [
      ..._dislikeItems(data['songs'], QqMusicItemType.song),
      ..._dislikeItems(data['singers'], QqMusicItemType.singer),
    ];
  }

  List<QqMusicItem> _dislikeItems(Object? value, QqMusicItemType type) {
    return _list(value)
        .map((raw) {
          final item = _map(raw);
          return QqMusicItem(
            id: _string(item['id']),
            title: _clean(_string(item['name'])),
            subtitle: '不喜欢',
            imageUrl: _string(item['img']),
            type: type,
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  List<QqMusicItem> _homeFeed(Object? value) {
    final map = _map(value);
    final shelves = _list(map['shelves']).isNotEmpty
        ? _list(map['shelves'])
        : _list(value);
    final items = <QqMusicItem>[];
    final seen = <String>{};

    void addItem(QqMusicItem item) {
      if (item.id.isEmpty && item.mid.isEmpty) {
        return;
      }
      final key = '${item.type.name}:${item.id}:${item.mid}:${item.title}';
      if (seen.add(key)) {
        items.add(item);
      }
    }

    for (final rawShelf in shelves) {
      final shelf = _map(rawShelf);
      final shelfId = _string(shelf['id']);
      final shelfTitle = _homeShelfTitle(shelf);
      final containers = <QqMusicItem>[];
      final songs = <QqMusicItem>[];

      for (final rawNiche in _list(shelf['niches'])) {
        final niche = _map(rawNiche);
        for (final rawCard in _list(niche['cards'])) {
          final card = _map(rawCard);
          final kind = _homeFeedCardKind(card);
          if (kind == _HomeFeedCardKind.skip) {
            continue;
          }
          final item = _homeFeedCard(card, shelfTitle: shelfTitle);
          if (item == null) {
            continue;
          }
          if (kind == _HomeFeedCardKind.song) {
            if (!songs.any(
              (song) => song.id == item.id && song.mid == item.mid,
            )) {
              songs.add(item);
            }
          } else {
            containers.add(item);
          }
        }
      }

      for (final container in containers) {
        addItem(container);
      }

      // Keep pure song shelves as one nested list instead of mixing songs into
      // the top-level home feed playlist view.
      if (songs.isNotEmpty) {
        final title = shelfTitle.isEmpty ? '推荐歌曲' : shelfTitle;
        final cover = songs
            .map((song) => song.imageUrl)
            .firstWhere((url) => url.isNotEmpty, orElse: () => '');
        addItem(
          QqMusicItem(
            id: 'home-shelf-songs-${shelfId.isEmpty ? title : shelfId}',
            title: title,
            subtitle: '${songs.length} 首推荐歌曲',
            imageUrl: cover,
            type: QqMusicItemType.playlist,
            children: List.unmodifiable(songs),
          ),
        );
      }
    }

    if (items.isEmpty) {
      void visit(Object? node) {
        if (node is List) {
          for (final child in node) {
            visit(child);
          }
        } else if (node is Map) {
          final nested = Map<String, dynamic>.from(node);
          if (_looksLikeSong(nested)) {
            addItem(parseSong(nested));
          } else {
            for (final child in nested.values) {
              visit(child);
            }
          }
        }
      }

      visit(value);
    }
    return items;
  }

  String _homeShelfTitle(Map<String, dynamic> shelf) {
    final template = _string(shelf['title_template']);
    final content = _string(shelf['title_content']);
    if (template.contains('{String}')) {
      return _clean(template.replaceAll('{String}', content));
    }
    final cleanedTemplate = _clean(template);
    if (cleanedTemplate.isNotEmpty) {
      return cleanedTemplate;
    }
    return _clean(content);
  }

  _HomeFeedCardKind _homeFeedCardKind(Map<String, dynamic> card) {
    final type = _int(card['type']);
    final jumpType = _int(card['jumptype']);
    final title = _clean(_string(card['title']));
    final scheme = _string(card['scheme']);
    final id = _string(card['id']);

    // Settings / ad / empty cards.
    if (type < 0 || title.isEmpty && _string(card['cover']).isEmpty) {
      return _HomeFeedCardKind.skip;
    }
    // Special app-only modes already have dedicated menu entries.
    if (type == 700 || type == 900 || jumpType == 20001) {
      return _HomeFeedCardKind.skip;
    }
    if (type == 200 || jumpType == 10046) {
      return _HomeFeedCardKind.song;
    }
    if (type == 1000 || jumpType == 10005) {
      return _HomeFeedCardKind.container;
    }
    if (type == 400 || jumpType == 10025) {
      return _HomeFeedCardKind.container;
    }
    if (type == 500 ||
        jumpType == 10014 ||
        jumpType == 3003 ||
        scheme.contains('gedan') ||
        scheme.contains('playlist')) {
      if (_isDailyThirtyCard(card)) {
        return _HomeFeedCardKind.container;
      }
      // Keep only playlists that have a real public songlist id.
      if (id.isEmpty || id == '0' || id.startsWith('0') && id.length <= 3) {
        return _HomeFeedCardKind.skip;
      }
      // Mini-game / activity cards use large synthetic ids without songlists.
      if (type == 900 ||
          jumpType == 3003 && _looksLikeActivityCard(title, id)) {
        return _HomeFeedCardKind.skip;
      }
      return _HomeFeedCardKind.container;
    }
    // Unknown card types without a real id are noise in this list UI.
    if (id.isEmpty || id.startsWith('http')) {
      return _HomeFeedCardKind.skip;
    }
    return _HomeFeedCardKind.container;
  }

  bool _isDailyThirtyCard(Map<String, dynamic> card) {
    final title = _clean(_string(card['title']));
    final id = _string(card['id']);
    final directoryId = _string(_map(card['miscellany'])['dirid']);
    final jumpType = _int(card['jumptype']);
    return title.contains('每日30') ||
        title == '每日30首' ||
        ((id.isEmpty || id == '0') && directoryId == '202') ||
        (jumpType == 10014 && (id.isEmpty || id == '0'));
  }

  bool _looksLikeActivityCard(String title, String id) {
    const activityTitles = {
      '梦幻农场',
      '斗战胜佛',
      '音乐接龙',
      '宠物消消乐',
      '快听',
      '在听',
      '歌手漫游',
      '雷达模式',
    };
    if (activityTitles.contains(title)) {
      return true;
    }
    return id.length >= 6 && id.startsWith('070') || id.startsWith('123123');
  }

  QqMusicItem? _homeFeedCard(
    Map<String, dynamic> card, {
    required String shelfTitle,
  }) {
    final type = _int(card['type']);
    final jumpType = _int(card['jumptype']);
    final title = _clean(_string(card['title']));
    final subtitle = _clean(
      _string(card['subtitle']).isNotEmpty
          ? _string(card['subtitle'])
          : shelfTitle,
    );
    final cover = _string(card['cover']);
    final id = _string(card['id']);
    final subId = _string(card['subid']);
    final miscellany = _map(card['miscellany']);

    if (type == 200 || jumpType == 10046) {
      final songMid = subId.isNotEmpty ? subId : _string(miscellany['vid']);
      if (id.isEmpty && songMid.isEmpty) {
        return null;
      }
      return QqMusicItem(
        id: id.isEmpty ? songMid : id,
        mid: songMid,
        title: title,
        subtitle: subtitle,
        imageUrl: cover,
        type: QqMusicItemType.song,
        requiresVip: _string(miscellany['Pay_status']) == '1',
      );
    }

    if (type == 1000 || jumpType == 10005) {
      return QqMusicItem(
        id: id,
        title: title,
        subtitle: '排行榜',
        imageUrl: cover,
        type: QqMusicItemType.chart,
      );
    }

    if (type == 400 || jumpType == 10025) {
      return QqMusicItem(
        id: id,
        mid: subId,
        title: title.split('|').first,
        subtitle: subtitle.isEmpty
            ? (title.contains('|')
                  ? title.split('|').skip(1).join(' · ')
                  : '专辑')
            : subtitle,
        imageUrl: cover,
        type: QqMusicItemType.album,
      );
    }

    if (_isDailyThirtyCard(card)) {
      final directoryId = _string(miscellany['dirid']).isEmpty
          ? '202'
          : _string(miscellany['dirid']);
      final playlistId = id.isEmpty || id == '0' ? '0' : id;
      return QqMusicItem(
        id: playlistId,
        title: title.isEmpty ? '每日30首' : title,
        subtitle: '今日个性推荐',
        imageUrl: cover.isNotEmpty ? cover : _string(miscellany['layer_url']),
        type: QqMusicItemType.playlist,
        directoryId: directoryId,
      );
    }

    final directoryId = _string(miscellany['dirid']);
    final playlistId = id == '0' || id.isEmpty ? '' : id;
    if (playlistId.isEmpty && directoryId.isEmpty) {
      return null;
    }
    return QqMusicItem(
      id: playlistId.isEmpty ? '0' : playlistId,
      directoryId: directoryId,
      title: title,
      subtitle: subtitle.isEmpty ? '推荐歌单' : subtitle,
      imageUrl: cover,
      type: QqMusicItemType.playlist,
    );
  }

  List<QqMusicItem> parseSimilarSongs(Object? data) {
    final map = _map(data);
    final groups = _list(map['song']);
    final items = <QqMusicItem>[];
    final seen = <String>{};
    for (final rawGroup in groups) {
      final group = _map(rawGroup);
      final groupTitle = _clean(
        _string(group['title_template'])
            .replaceAll('{String}', _string(group['title_content']))
            .replaceAll('「', '')
            .replaceAll('」', ''),
      );
      for (final rawSong in _list(group['song'])) {
        final song = parseSong(rawSong);
        if (song.id.isEmpty || !seen.add(song.id)) {
          continue;
        }
        items.add(
          QqMusicItem(
            id: song.id,
            mid: song.mid,
            mediaMid: song.mediaMid,
            title: song.title,
            subtitle: groupTitle.isEmpty
                ? song.subtitle
                : '$groupTitle · ${song.subtitle}',
            imageUrl: song.imageUrl,
            type: QqMusicItemType.song,
            duration: song.duration,
            songType: song.songType,
            requiresVip: song.requiresVip,
            isCopyrightRestricted: song.isCopyrightRestricted,
          ),
        );
      }
    }
    if (items.isEmpty) {
      return _songs(map['songs']);
    }
    return items;
  }

  bool _looksLikeSong(Map<String, dynamic> map) {
    return (map.containsKey('mid') ||
            map.containsKey('songmid') ||
            map.containsKey('song_mid')) &&
        (map.containsKey('singer') ||
            map.containsKey('album') ||
            map.containsKey('name') ||
            map.containsKey('title'));
  }
}

enum _HomeFeedCardKind { song, container, skip }

Map<String, dynamic> _map(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : const {};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];
bool _isCopyrightRestricted(Map<String, dynamic> file) {
  if (file.isEmpty) {
    return false;
  }
  const audioSizeFields = [
    'size_24aac',
    'size_48aac',
    'size_96aac',
    'size_192ogg',
    'size_192aac',
    'size_128mp3',
    'size_320mp3',
    'size_flac',
    'size_dts',
    'size_try',
    'size_96ogg',
    'size_dolby',
  ];
  final hasAudioFile =
      audioSizeFields.any((field) => _int(file[field]) > 0) ||
      _list(file['size_new']).isNotEmpty;
  return !hasAudioFile;
}

String _string(Object? value) => value?.toString() ?? '';

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

int? _nullableInt(Object? value) => value == null ? null : _int(value);

bool _bool(Object? value) => value == true || value == 1;

String _clean(String value) => value.replaceAll(RegExp('<[^>]*>'), '').trim();

String _albumCover(String mid) =>
    'https://y.gtimg.cn/music/photo_new/T002R500x500M000$mid.jpg';

String _singerCover(String mid) =>
    'https://y.gtimg.cn/music/photo_new/T001R500x500M000$mid.jpg';
