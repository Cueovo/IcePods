import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/models/response_parser.dart';

void main() {
  const parser = QqMusicResponseParser();

  test('parses official home feed shelves into clean container lists', () {
    final result = parser.parseFeature(QqMusicFeature.homeFeed, {
      'shelves': [
        {
          'id': '301',
          'title_template': 'hi 今日为你打造',
          'title_content': '',
          'niches': [
            {
              'cards': [
                {
                  'id': '99',
                  'title': '猜你喜欢',
                  'type': 700,
                  'jumptype': 20001,
                  'cover': '',
                  'miscellany': {},
                },
                {
                  'id': '7971796071',
                  'title': '每日30首',
                  'type': 500,
                  'jumptype': 10014,
                  'cover': 'https://example.com/daily.jpg',
                  'miscellany': {'dirid': '202'},
                  'extra_info': {'songid': '4986321'},
                  'trace': 'ai_day_3_4_0_4986321_0_3256298640406170687#daily30',
                },
                {
                  'id': '211111',
                  'title': '百万收藏',
                  'type': 500,
                  'jumptype': 3003,
                  'cover': 'https://example.com/million.jpg',
                  'scheme':
                      'qqmusic://qq.com/ui/gedan?p=%7B%22id%22:%22211111%22%7D',
                },
                {
                  'id': '123123124',
                  'title': '梦幻农场',
                  'type': 900,
                  'jumptype': 3003,
                  'cover': '',
                },
              ],
            },
          ],
        },
        {
          'id': '207',
          'title_template': '{String}',
          'title_content': '大家都在听',
          'niches': [
            {
              'cards': [
                {
                  'id': '278383232',
                  'subid': 'i0034wvnk1y',
                  'title': 'Afterthought',
                  'subtitle': 'Joji/BENEE',
                  'type': 200,
                  'jumptype': 10046,
                  'cover': 'https://example.com/song.jpg',
                  'miscellany': {'Pay_status': '0'},
                },
              ],
            },
          ],
        },
        {
          'id': '114',
          'title_template': '排行榜',
          'title_content': '',
          'niches': [
            {
              'cards': [
                {
                  'id': '26',
                  'title': '热歌榜',
                  'type': 1000,
                  'jumptype': 10005,
                  'cover': 'https://example.com/chart.jpg',
                },
              ],
            },
          ],
        },
      ],
    }, title: '首页推荐');

    expect(result.items.map((item) => item.title).toList(), [
      '每日30首',
      '百万收藏',
      '大家都在听',
      '热歌榜',
    ]);
    expect(result.items[0].id, '7971796071');
    expect(result.items[0].directoryId, '202');
    expect(result.items[0].isDirectoryPlaylist, isFalse);
    expect(result.items[1].id, '211111');
    expect(result.items[2].hasEmbeddedChildren, isTrue);
    expect(result.items[2].children.single.title, 'Afterthought');
    expect(result.items[3].type, QqMusicItemType.chart);
  });

  test('parses also-listening similar song groups', () {
    final items = parser.parseSimilarSongs({
      'song': [
        {
          'title_template': '听「{String}」的也在听',
          'title_content': '王艳薇',
          'song': [
            {
              'id': 9,
              'mid': 'similar-mid',
              'title': '相似歌曲',
              'singer': [
                {'name': '影子'},
              ],
              'album': {'mid': 'album-mid'},
            },
          ],
        },
      ],
    });

    expect(items, hasLength(1));
    expect(items.single.title, '相似歌曲');
    expect(items.single.subtitle, contains('听王艳薇的也在听'));
  });

  test('container song total drives pagination across pages', () {
    const playlist = QqMusicItem(
      id: 'playlist-1',
      title: '长歌单',
      subtitle: '',
      imageUrl: '',
      type: QqMusicItemType.playlist,
    );
    final songs = List.generate(
      25,
      (index) => {
        'id': index + 1,
        'mid': 'song-mid-$index',
        'title': '歌曲$index',
      },
    );

    final first = parser.parseChildren(
      playlist,
      {'songs': songs, 'size': 25, 'total': 60},
      limit: 25,
      page: 1,
    );
    final last = parser.parseChildren(
      playlist,
      {'songs': songs.take(10).toList(), 'size': 10, 'total': 60},
      limit: 25,
      page: 3,
    );

    expect(first.items, hasLength(25));
    expect(first.hasMore, isTrue);
    expect(last.items, hasLength(10));
    expect(last.hasMore, isFalse);
  });

  test('parses official lyric payload into timeline lines', () {
    final lyrics = parser.parseLyrics({
      'lyric': base64Encode(utf8.encode('[00:01.00]开始直接歌词\n[00:12.50]第二行')),
    });

    expect(lyrics.lines, hasLength(2));
    expect(lyrics.lines.first.time, const Duration(seconds: 1));
    expect(lyrics.lines.first.text, '开始直接歌词');
    expect(
      lyrics.lines.last.time,
      const Duration(seconds: 12, milliseconds: 500),
    );
  });

  test('parses QQ Music pay_play as the VIP playback requirement', () {
    final vipSong = parser.parseSong({
      'id': 1,
      'mid': 'vip-mid',
      'title': 'VIP Song',
      'pay': {'pay_play': 1},
    });
    final freeSong = parser.parseSong({
      'id': 2,
      'mid': 'free-mid',
      'title': 'Free Song',
      'pay': {'pay_play': 0},
    });
    final songWithoutPayData = parser.parseSong({
      'id': 3,
      'mid': 'unknown-mid',
      'title': 'Unknown Song',
    });

    expect(vipSong.requiresVip, isTrue);
    expect(freeSong.requiresVip, isFalse);
    expect(songWithoutPayData.requiresVip, isFalse);
  });
}
