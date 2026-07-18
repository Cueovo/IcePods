import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qqmusic_ipod/ipod_models.dart';
import 'package:qqmusic_ipod/services/qq_music_cache.dart';
import 'package:qqmusic_ipod/services/qq_music_http_api.dart';
import 'package:qqmusic_ipod/services/qq_music_models.dart';
import 'package:qqmusic_ipod/services/qq_music_session.dart';

void main() {
  const credential = QqMusicCredential(
    musicId: '10001',
    musicKey: 'music-key',
    openId: 'open-id',
    refreshToken: 'refresh-token',
  );

  http.Response jsonResponse(
    Map<String, Object?> data, {
    int statusCode = 200,
  }) {
    return http.Response(
      jsonEncode(data),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  test('QR login persists credential returned by status endpoint', () async {
    final store = MemoryQqMusicCredentialStore();
    final requests = <http.Request>[];
    late http.Request homepageRequest;
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      credentialStore: store,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/login/qrcode/qq') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'qr_type': 'qq',
              'identifier': 'qr-id',
              'mimetype': 'image/png',
              'data': base64Encode([1, 2, 3]),
              'img': '',
            },
          });
        }
        if (request.url.path == '/login/qrcode/qq/status') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'event': 0,
              'done': true,
              'identifier': 'qr-id',
              'login_type': 'qq',
              'credential': {
                'musicid': 10001,
                'musickey': 'music-key',
                'openid': 'open-id',
                'refresh_token': 'refresh-token',
                'encrypt_uin': 'encrypted-uin**',
              },
            },
          });
        }
        if (request.url.path == '/user/encrypted-uin**/homepage') {
          homepageRequest = request;
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'base_info': {
                'name': 'Test User',
                'avatar': 'https://example.test/avatar.png',
              },
            },
          });
        }
        if (request.url.path == '/user/get_vip_info') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'identity': {'vip': 0, 'huge_vip': 0},
            },
          });
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );

    final qr = await api.createQrCode();
    final status = await api.checkQrStatus(qr);
    final profile = await api.getUserProfile();

    expect(qr.identifier, 'qr-id');
    expect(qr.imageBytes, [1, 2, 3]);
    expect(
      requests
          .firstWhere(
            (request) => request.url.path == '/login/qrcode/qq/status',
          )
          .url
          .queryParameters['identifier'],
      'qr-id',
    );
    expect(status.done, isTrue);
    expect(status.message, '登录成功');
    expect(api.isLoggedIn, isTrue);
    expect(status.credential?.encryptUin, 'encrypted-uin**');
    expect((await store.read())?.musicKey, 'music-key');
    expect(profile.nickname, 'Test User');
    expect(profile.isVip, isFalse);
    expect(homepageRequest.url.path, '/user/encrypted-uin**/homepage');
    expect(homepageRequest.url.path, isNot(contains('/10001/')));
    expect(homepageRequest.headers['Cookie'], contains('musicid=10001'));
    expect(homepageRequest.headers['Cookie'], contains('musickey=music-key'));
  });

  test('VIP status recognizes OpenAPI root flags', () async {
    final store = MemoryQqMusicCredentialStore()..credential = credential;
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      credentialStore: store,
      client: MockClient((request) async {
        if (request.url.path == '/login/check_expired') {
          return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
        }
        if (request.url.path == '/user/10001/homepage') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'base_info': {'name': 'VIP User', 'avatar': ''},
            },
          });
        }
        if (request.url.path == '/user/get_vip_info') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'svip': 1,
              'star': 0,
              'ystar': 0,
              'identity': {'vip': 0, 'huge_vip': 0},
            },
          });
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    await api.restoreSession();

    final profile = await api.getUserProfile();

    expect(profile.isVip, isTrue);
    expect(profile.hasConfirmedVipStatus, isTrue);
  });

  test('VIP request failure keeps membership status unknown', () async {
    final store = MemoryQqMusicCredentialStore()..credential = credential;
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      credentialStore: store,
      client: MockClient((request) async {
        if (request.url.path == '/login/check_expired') {
          return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
        }
        if (request.url.path == '/user/10001/homepage') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'base_info': {'name': 'Unknown VIP User', 'avatar': ''},
            },
          });
        }
        if (request.url.path == '/user/get_vip_info') {
          return jsonResponse({
            'code': 503,
            'msg': 'temporary unavailable',
            'data': null,
          }, statusCode: 503);
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    await api.restoreSession();

    final profile = await api.getUserProfile();

    expect(profile.isVip, isNull);
    expect(profile.hasConfirmedVipStatus, isFalse);
  });

  test('missing VIP status fields keep membership status unknown', () async {
    final store = MemoryQqMusicCredentialStore()..credential = credential;
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      credentialStore: store,
      client: MockClient((request) async {
        if (request.url.path == '/login/check_expired') {
          return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
        }
        if (request.url.path == '/user/10001/homepage') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'base_info': {'name': 'Unknown User', 'avatar': ''},
            },
          });
        }
        if (request.url.path == '/user/get_vip_info') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {'identity': <String, Object?>{}},
          });
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    await api.restoreSession();

    expect((await api.getUserProfile()).isVip, isNull);
  });

  test(
    'liked songs reuse persistent user cache until a forced refresh',
    () async {
      final credentialStore = MemoryQqMusicCredentialStore()
        ..credential = credential;
      final cacheStore = MemoryQqMusicCacheStore();
      var likedRequests = 0;
      var songTitle = '缓存歌曲';

      QqMusicHttpApi createApi() {
        return QqMusicHttpApi(
          baseUri: Uri.parse('http://localhost:8899'),
          credentialStore: credentialStore,
          cacheStore: cacheStore,
          client: MockClient((request) async {
            if (request.url.path == '/login/check_expired') {
              return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
            }
            if (request.url.path == '/user/10001/fav/songs') {
              likedRequests += 1;
              return jsonResponse({
                'code': 0,
                'msg': 'ok',
                'data': {
                  'songs': [
                    {
                      'id': 1,
                      'mid': 'liked-mid',
                      'title': songTitle,
                      'singer': [
                        {'name': '测试歌手'},
                      ],
                      'album': {'mid': 'album-mid'},
                    },
                  ],
                  'total': 1,
                  'size': 1,
                  'has_more': false,
                },
              });
            }
            throw StateError('Unexpected request: ${request.url}');
          }),
        );
      }

      final firstApi = createApi();
      await firstApi.restoreSession();
      final first = await firstApi.loadFeature(QqMusicFeature.likedSongs);
      songTitle = '服务端新歌曲';

      final restartedApi = createApi();
      await restartedApi.restoreSession();
      final cached = await restartedApi.loadFeature(QqMusicFeature.likedSongs);
      final refreshed = await restartedApi.loadFeature(
        QqMusicFeature.likedSongs,
        forceRefresh: true,
      );
      final updatedCache = await restartedApi.loadFeature(
        QqMusicFeature.likedSongs,
      );

      expect(first.items.single.title, '缓存歌曲');
      expect(cached.items.single.title, '缓存歌曲');
      expect(refreshed.items.single.title, '服务端新歌曲');
      expect(updatedCache.items.single.title, '服务端新歌曲');
      expect(likedRequests, 2);
    },
  );

  test(
    'protected feature request sends documented credential Cookie',
    () async {
      final store = MemoryQqMusicCredentialStore()..credential = credential;
      late http.Request favoriteRequest;
      final api = QqMusicHttpApi(
        baseUri: Uri.parse('http://localhost:8899'),
        credentialStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/login/check_expired') {
            return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
          }
          favoriteRequest = request;
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {'songs': [], 'total': 0, 'size': 0},
          });
        }),
      );

      await api.restoreSession();
      await api.loadFeature(QqMusicFeature.likedSongs, page: 2, pageSize: 30);

      expect(favoriteRequest.url.path, '/user/10001/fav/songs');
      expect(favoriteRequest.url.queryParameters, {'page': '2', 'num': '30'});
      expect(favoriteRequest.headers['Cookie'], contains('musicid=10001'));
      expect(favoriteRequest.headers['Cookie'], contains('musickey=music-key'));
      expect(favoriteRequest.headers['Cookie'], contains('openid=open-id'));
    },
  );

  test(
    'personalized recommendations send restored credential Cookie',
    () async {
      final store = MemoryQqMusicCredentialStore()..credential = credential;
      final recommendationRequests = <http.Request>[];
      final api = QqMusicHttpApi(
        baseUri: Uri.parse('http://localhost:8899'),
        credentialStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/login/check_expired') {
            return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
          }
          recommendationRequests.add(request);
          if (request.url.path == '/recommend/get_guess_recommend') {
            return jsonResponse({
              'code': 0,
              'msg': 'ok',
              'data': {
                'songs': [
                  {
                    'id': 1,
                    'mid': 'guess-mid',
                    'title': '猜你喜欢种子',
                    'singer': [
                      {'name': '测试歌手'},
                    ],
                    'album': {'mid': 'album-mid'},
                  },
                ],
              },
            });
          }
          if (request.url.path == '/recommend/get_home_feed') {
            return jsonResponse({
              'code': 0,
              'msg': 'ok',
              'data': {
                'shelves': [
                  {
                    'title_template': '排行榜',
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
              },
            });
          }
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {'songs': []},
          });
        }),
      );

      await api.restoreSession();
      final guess = await api.loadFeature(QqMusicFeature.guessRecommendations);
      final home = await api.loadFeature(QqMusicFeature.homeFeed);
      await api.loadFeature(QqMusicFeature.radar);

      expect(
        recommendationRequests.map((request) => request.url.path).toList(),
        [
          '/recommend/get_guess_recommend',
          '/recommend/get_home_feed',
          '/recommend/get_radar_recommend',
        ],
      );
      final homeRequest = recommendationRequests.firstWhere(
        (request) => request.url.path == '/recommend/get_home_feed',
      );
      expect(homeRequest.url.queryParameters['page'], '1');
      expect(homeRequest.url.queryParameters['s_num'], '0');
      expect(guess.items.map((item) => item.title), ['猜你喜欢种子']);
      expect(home.items.single.title, '热歌榜');
      for (final request in recommendationRequests) {
        expect(request.headers['Cookie'], contains('musicid=10001'));
        expect(request.headers['Cookie'], contains('musickey=music-key'));
      }
    },
  );

  test('lyrics request QRC and parse word-level timeline', () async {
    late http.Request lyricRequest;
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      client: MockClient((request) async {
        lyricRequest = request;
        return jsonResponse({
          'code': 0,
          'msg': 'ok',
          'data': {
            'lyric':
                '[1200,1800]你(1200,500)好(1700,600)世界(2300,700)\n[4000,1000]下一句(4000,1000)',
          },
        });
      }),
    );
    const song = QqMusicItem(
      id: '1',
      mid: 'song-mid',
      title: 'Song',
      subtitle: 'Artist',
      imageUrl: '',
      type: QqMusicItemType.song,
    );

    final lyrics = await api.getLyrics(song);

    expect(lyricRequest.url.path, '/song/song-mid/lyric');
    expect(lyricRequest.url.queryParameters, {
      'qrc': 'true',
      'trans': 'false',
      'roma': 'false',
    });
    expect(lyrics.lines.map((line) => line.text), ['你好世界', '下一句']);
    expect(lyrics.lines.first.time, const Duration(milliseconds: 1200));
    expect(lyrics.lines.first.duration, const Duration(milliseconds: 1800));
    expect(lyrics.lines.first.hasWordTimeline, isTrue);
    expect(lyrics.lines.first.words.map((word) => word.text), ['你', '好', '世界']);
    expect(
      lyrics.lines.first.words[1].time,
      const Duration(milliseconds: 1700),
    );
    expect(
      lyrics.lines.first.words[1].duration,
      const Duration(milliseconds: 600),
    );
  });

  test('lyrics fall back to timestamped LRC when QRC is unavailable', () async {
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      client: MockClient((request) async {
        return jsonResponse({
          'code': 0,
          'msg': 'ok',
          'data': {'lyric': '[00:01.20]第一行\n[01:02.345]第二行'},
        });
      }),
    );
    const song = QqMusicItem(
      id: '1',
      mid: 'song-mid',
      title: 'Song',
      subtitle: 'Artist',
      imageUrl: '',
      type: QqMusicItemType.song,
    );

    final lyrics = await api.getLyrics(song);

    expect(lyrics.lines.map((line) => line.text), ['第一行', '第二行']);
    expect(lyrics.lines.first.hasWordTimeline, isFalse);
    expect(lyrics.lines.first.time, const Duration(milliseconds: 1200));
    expect(
      lyrics.lines.last.time,
      const Duration(minutes: 1, seconds: 2, milliseconds: 345),
    );
  });

  test(
    'playback URL uses song metadata and resolves relative purl via CDN',
    () async {
      final store = MemoryQqMusicCredentialStore()..credential = credential;
      late http.Request playbackRequest;
      final api = QqMusicHttpApi(
        baseUri: Uri.parse('http://localhost:8899'),
        credentialStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/login/check_expired') {
            return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
          }
          if (request.url.path == '/song/song-mid/url') {
            playbackRequest = request;
            return jsonResponse({
              'code': 0,
              'msg': 'ok',
              'data': {
                'expiration': 3600,
                'data': [
                  {
                    'mid': 'song-mid',
                    'filename': 'M500song-mid.mp3',
                    'purl': 'M500song-mid.mp3?vkey=test',
                    'vkey': 'test',
                    'ekey': '',
                    'result': 0,
                  },
                ],
              },
            });
          }
          if (request.url.path == '/song/get_cdn_dispatch') {
            return jsonResponse({
              'code': 0,
              'msg': 'ok',
              'data': {
                'retcode': 0,
                'sip': ['http://cdn.invalid/', 'https://cdn.example/music/'],
                'sipinfo': [],
                'test_file': '',
                'expiration': 3600,
                'refresh_time': 1800,
                'cache_time': 3600,
              },
            });
          }
          throw StateError('Unexpected request: ${request.url}');
        }),
      );
      await api.restoreSession();

      final url = await api.getPlayableUrl(
        const QqMusicItem(
          id: '123',
          mid: 'song-mid',
          mediaMid: 'media-mid',
          title: 'Song',
          subtitle: 'Singer',
          imageUrl: '',
          type: QqMusicItemType.song,
          songType: 1,
        ),
      );

      expect(playbackRequest.url.queryParameters['file_type'], '13');
      expect(playbackRequest.url.queryParameters['song_type'], '1');
      expect(playbackRequest.url.queryParameters['media_mid'], 'media-mid');
      expect(playbackRequest.headers['Cookie'], contains('musicid=10001'));
      expect(
        url.toString(),
        'https://cdn.example/music/M500song-mid.mp3?vkey=test',
      );
    },
  );

  test('absolute HTTP playback URLs are upgraded to HTTPS', () async {
    final store = MemoryQqMusicCredentialStore()..credential = credential;
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      credentialStore: store,
      client: MockClient((request) async {
        if (request.url.path == '/login/check_expired') {
          return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
        }
        if (request.url.path == '/song/direct-mid/url') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'data': [
                {
                  'mid': 'direct-mid',
                  'purl': 'http://cdn.example/direct.mp3?vkey=test',
                  'result': 0,
                },
              ],
            },
          });
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    addTearDown(api.dispose);
    await api.restoreSession();

    final url = await api.getPlayableUrl(
      const QqMusicItem(
        id: 'direct',
        mid: 'direct-mid',
        title: 'Direct',
        subtitle: '',
        imageUrl: '',
        type: QqMusicItemType.song,
      ),
    );

    expect(url.toString(), 'https://cdn.example/direct.mp3?vkey=test');
  });

  test('single playback URL rejects explicit authorization denial', () async {
    final store = MemoryQqMusicCredentialStore()..credential = credential;
    var dispatchRequested = false;
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      credentialStore: store,
      client: MockClient((request) async {
        if (request.url.path == '/login/check_expired') {
          return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
        }
        if (request.url.path == '/song/restricted-mid/url') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'data': [
                {
                  'mid': 'restricted-mid',
                  'purl': 'stale-or-invalid.mp3?vkey=invalid',
                  'result': 104003,
                },
              ],
            },
          });
        }
        if (request.url.path == '/song/get_cdn_dispatch') {
          dispatchRequested = true;
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    await api.restoreSession();

    expect(
      () => api.getPlayableUrl(
        const QqMusicItem(
          id: '1',
          mid: 'restricted-mid',
          title: 'Restricted',
          subtitle: '',
          imageUrl: '',
          type: QqMusicItemType.song,
        ),
      ),
      throwsA(
        isA<QqMusicApiException>().having(
          (error) => error.message,
          'message',
          contains('没有可用播放地址'),
        ),
      ),
    );
    expect(dispatchRequested, isFalse);
  });

  test('single playback URL reports VKey failures as retryable', () async {
    final store = MemoryQqMusicCredentialStore()..credential = credential;
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      credentialStore: store,
      client: MockClient((request) async {
        if (request.url.path == '/login/check_expired') {
          return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
        }
        if (request.url.path == '/song/retryable-mid/url') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'data': [
                {'mid': 'retryable-mid', 'purl': '', 'result': 104004},
              ],
            },
          });
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    await api.restoreSession();

    expect(
      () => api.getPlayableUrl(
        const QqMusicItem(
          id: '2',
          mid: 'retryable-mid',
          title: 'Retryable',
          subtitle: '',
          imageUrl: '',
          type: QqMusicItemType.song,
        ),
      ),
      throwsA(
        isA<QqMusicApiException>()
            .having((error) => error.code, 'code', 104004)
            .having((error) => error.message, 'message', contains('稍后重试')),
      ),
    );
  });

  test(
    'bulk playback URL probe posts JSON and returns unavailable entries',
    () async {
      final store = MemoryQqMusicCredentialStore()..credential = credential;
      late http.Request bulkRequest;
      final api = QqMusicHttpApi(
        baseUri: Uri.parse('http://localhost:8899'),
        credentialStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/login/check_expired') {
            return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
          }
          if (request.url.path == '/song/get_song_urls') {
            bulkRequest = request;
            return jsonResponse({
              'code': 0,
              'msg': 'ok',
              'data': {
                'data': [
                  {
                    'mid': 'available-mid',
                    'filename': 'M500available-mid.mp3',
                    'purl': 'M500available-mid.mp3?vkey=test',
                    'vkey': 'test',
                    'ekey': '',
                    'result': 0,
                  },
                  {
                    'mid': 'unavailable-mid',
                    'filename': 'M500unavailable-mid.mp3',
                    'purl': '',
                    'vkey': '',
                    'ekey': '',
                    'result': 104003,
                  },
                  {
                    'mid': 'retryable-mid',
                    'filename': 'M500retryable-mid.mp3',
                    'purl': '',
                    'vkey': '',
                    'ekey': '',
                    'result': 104004,
                  },
                ],
              },
            });
          }
          if (request.url.path == '/song/get_cdn_dispatch') {
            return jsonResponse({
              'code': 0,
              'msg': 'ok',
              'data': {
                'sip': ['https://cdn.example/music/'],
              },
            });
          }
          throw StateError('Unexpected request: ${request.url}');
        }),
      );
      await api.restoreSession();

      final urls = await api.getPlayableUrls(const [
        QqMusicItem(
          id: '1',
          mid: 'available-mid',
          mediaMid: 'available-media-mid',
          title: 'Available',
          subtitle: '',
          imageUrl: '',
          type: QqMusicItemType.song,
          songType: 1,
        ),
        QqMusicItem(
          id: '2',
          mid: 'unavailable-mid',
          title: 'Unavailable',
          subtitle: '',
          imageUrl: '',
          type: QqMusicItemType.song,
          songType: 2,
        ),
        QqMusicItem(
          id: '3',
          mid: 'retryable-mid',
          title: 'Retryable',
          subtitle: '',
          imageUrl: '',
          type: QqMusicItemType.song,
          songType: 3,
        ),
      ]);

      final body = jsonDecode(bulkRequest.body) as Map<String, dynamic>;
      expect(bulkRequest.method, 'POST');
      expect(bulkRequest.headers['content-type'], 'application/json');
      expect(bulkRequest.headers['Cookie'], contains('musicid=10001'));
      expect(body['file_type'], 13);
      expect(body['file_info'], [
        {
          'mid': 'available-mid',
          'song_type': 1,
          'media_mid': 'available-media-mid',
        },
        {'mid': 'unavailable-mid', 'song_type': 2},
        {'mid': 'retryable-mid', 'song_type': 3},
      ]);
      expect(
        urls['available-mid'].toString(),
        'https://cdn.example/music/M500available-mid.mp3?vkey=test',
      );
      expect(urls['unavailable-mid'], isNull);
      expect(urls.containsKey('retryable-mid'), isFalse);
    },
  );

  test(
    'ID-only dislike song is resolved through song detail before playback',
    () async {
      final store = MemoryQqMusicCredentialStore()..credential = credential;
      final paths = <String>[];
      final api = QqMusicHttpApi(
        baseUri: Uri.parse('http://localhost:8899'),
        credentialStore: store,
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == '/login/check_expired') {
            return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
          }
          if (request.url.path == '/song/123/detail') {
            return jsonResponse({
              'code': 0,
              'msg': 'ok',
              'data': {
                'track': {
                  'id': 123,
                  'mid': 'resolved-mid',
                  'name': 'Resolved Song',
                  'title': 'Resolved Song',
                  'subtitle': '',
                  'type': 1,
                  'singer': [
                    {'id': 1, 'mid': 'singer-mid', 'name': 'Singer'},
                  ],
                  'album': {'id': 1, 'mid': 'album-mid', 'name': 'Album'},
                  'file': {'media_mid': 'resolved-media-mid'},
                  'interval': 180,
                },
              },
            });
          }
          if (request.url.path == '/song/resolved-mid/url') {
            return jsonResponse({
              'code': 0,
              'msg': 'ok',
              'data': {
                'data': [
                  {'purl': 'https://cdn.example/resolved.mp3'},
                ],
              },
            });
          }
          throw StateError('Unexpected request: ${request.url}');
        }),
      );
      await api.restoreSession();

      final url = await api.getPlayableUrl(
        const QqMusicItem(
          id: '123',
          title: 'ID only',
          subtitle: '',
          imageUrl: '',
          type: QqMusicItemType.song,
        ),
      );

      expect(
        paths,
        containsAllInOrder(['/song/123/detail', '/song/resolved-mid/url']),
      );
      expect(url.toString(), 'https://cdn.example/resolved.mp3');
    },
  );

  test(
    'song liked mutation updates directory 201 and persistent cache',
    () async {
      final store = MemoryQqMusicCredentialStore()..credential = credential;
      final cache = MemoryQqMusicCacheStore();
      final mutations = <http.Request>[];
      final api = QqMusicHttpApi(
        baseUri: Uri.parse('http://localhost:8899'),
        credentialStore: store,
        cacheStore: cache,
        client: MockClient((request) async {
          if (request.url.path == '/login/check_expired') {
            return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
          }
          mutations.add(request);
          return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
        }),
      );
      await api.restoreSession();
      const song = QqMusicItem(
        id: '1',
        mid: 'liked-mid',
        title: 'Liked Song',
        subtitle: 'Singer',
        imageUrl: '',
        type: QqMusicItemType.song,
        songType: 1,
      );
      await cache.write(
        'feature.liked_songs.10001',
        const QqMusicFeatureResult(title: '我喜欢的音乐', items: [song]).toJson(),
      );

      await api.setSongLiked(song, liked: false);

      expect(mutations.single.url.path, '/songlist/del_songs');
      expect(mutations.single.url.queryParametersAll['dirid'], ['201']);
      final removed = await api.loadFeature(QqMusicFeature.likedSongs);
      expect(removed.items, isEmpty);

      mutations.clear();
      await api.setSongLiked(song, liked: true);

      expect(mutations.single.url.path, '/songlist/add_songs');
      expect(mutations.single.url.queryParametersAll['dirid'], ['201']);
      final added = await api.loadFeature(QqMusicFeature.likedSongs);
      expect(added.items.single.mid, 'liked-mid');
    },
  );

  test(
    'playlist song mutations repeat FastAPI array query parameters',
    () async {
      final store = MemoryQqMusicCredentialStore()..credential = credential;
      late http.Request mutationRequest;
      final api = QqMusicHttpApi(
        baseUri: Uri.parse('http://localhost:8899'),
        credentialStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/login/check_expired') {
            return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
          }
          mutationRequest = request;
          return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
        }),
      );
      await api.restoreSession();

      await api.addSongsToPlaylist('88', const [
        QqMusicItem(
          id: '1',
          title: 'One',
          subtitle: '',
          imageUrl: '',
          type: QqMusicItemType.song,
          songType: 1,
        ),
        QqMusicItem(
          id: '2',
          title: 'Two',
          subtitle: '',
          imageUrl: '',
          type: QqMusicItemType.song,
          songType: 2,
        ),
      ]);

      expect(mutationRequest.method, 'POST');
      expect(mutationRequest.url.path, '/songlist/add_songs');
      expect(mutationRequest.url.queryParametersAll['dirid'], ['88']);
      expect(mutationRequest.url.queryParametersAll['song_id'], ['1', '2']);
      expect(mutationRequest.url.queryParametersAll['song_type'], ['1', '2']);
      expect(mutationRequest.headers['Cookie'], contains('musickey=music-key'));
    },
  );

  test('daily 30 playlist loads via real songlist id detail', () async {
    final store = MemoryQqMusicCredentialStore()..credential = credential;
    final requests = <http.Request>[];
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      credentialStore: store,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/login/check_expired') {
          return jsonResponse({'code': 0, 'msg': 'ok', 'data': null});
        }
        if (request.url.path == '/songlist/7971796071/detail') {
          return jsonResponse({
            'code': 0,
            'msg': 'ok',
            'data': {
              'songlist': [
                {
                  'id': 11,
                  'mid': 'daily-mid-1',
                  'title': '每日歌曲1',
                  'singer': [
                    {'name': '歌手A'},
                  ],
                  'album': {'mid': 'album-mid-1'},
                  'interval': 180,
                },
                {
                  'id': 12,
                  'mid': 'daily-mid-2',
                  'title': '每日歌曲2',
                  'singer': [
                    {'name': '歌手B'},
                  ],
                  'album': {'mid': 'album-mid-2'},
                  'interval': 200,
                },
              ],
            },
          });
        }
        return jsonResponse({'code': 0, 'msg': 'ok', 'data': {}});
      }),
    );

    await api.restoreSession();
    final result = await api.loadChildren(
      const QqMusicItem(
        id: '7971796071',
        directoryId: '202',
        title: '每日30首',
        subtitle: '今日个性推荐',
        imageUrl: '',
        type: QqMusicItemType.playlist,
      ),
      pageSize: 30,
    );

    final detailRequest = requests.singleWhere(
      (request) => request.url.path == '/songlist/7971796071/detail',
    );
    expect(detailRequest.url.queryParameters['dirid'], '202');
    expect(detailRequest.url.queryParameters['num'], '30');
    expect(detailRequest.url.queryParameters['page'], '1');
    expect(detailRequest.headers['Cookie'], contains('musickey=music-key'));
    expect(result.items.map((item) => item.title), ['每日歌曲1', '每日歌曲2']);
  });

  test('HTTP and service errors become typed API exceptions', () async {
    final api = QqMusicHttpApi(
      baseUri: Uri.parse('http://localhost:8899'),
      credentialStore: MemoryQqMusicCredentialStore(),
      client: MockClient((request) async {
        return jsonResponse({'code': -1, 'msg': '未提供有效的登录凭证'}, statusCode: 401);
      }),
    );

    expect(
      () => api.getPlayableUrl(
        const QqMusicItem(
          id: '1',
          mid: 'mid',
          title: 'Song',
          subtitle: '',
          imageUrl: '',
          type: QqMusicItemType.song,
        ),
      ),
      throwsA(
        isA<QqMusicApiException>()
            .having((error) => error.isUnauthorized, 'isUnauthorized', isTrue)
            .having((error) => error.message, 'message', contains('扫码登录')),
      ),
    );
  });
}
