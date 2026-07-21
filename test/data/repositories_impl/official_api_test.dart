import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qqmusic_ipod/data/datasources/android_context.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/data/models/device.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/datasources/login.dart';
import 'package:qqmusic_ipod/data/repositories_impl/official_api.dart';
import 'package:qqmusic_ipod/data/datasources/qimei.dart';
import 'package:qqmusic_ipod/data/datasources/session.dart';
import 'package:qqmusic_ipod/core/storage/device_store.dart';

import '../../features/player/state/fake_api.dart';

void main() {
  test('新歌功能直接请求官方 CGI 并解析歌曲模型', () async {
    late http.Request captured;
    final transport = MockClient((request) async {
      captured = request;
      return _cgiResponse({
        'songlist': [
          {
            'id': 101,
            'mid': 'song-mid',
            'title': '官方新歌',
            'singer': [
              {'name': '官方歌手'},
            ],
            'album': {'mid': 'album-mid'},
            'file': {'media_mid': 'media-mid'},
            'pay': {'pay_play': 0},
          },
        ],
      });
    });
    final api = _officialApi(transport);
    addTearDown(api.dispose);

    final result = await api.loadFeature(QqMusicFeature.newSongs);
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;

    expect(captured.url.host, 'u.y.qq.com');
    expect(payload['req_0']['module'], 'newsong.NewSongServer');
    expect(payload['req_0']['method'], 'get_new_song_info');
    expect(payload['req_0']['param']['type'], 5);
    expect(result.items.single.title, '官方新歌');
    expect(result.items.single.mid, 'song-mid');
    expect(result.items.single.mediaMid, 'media-mid');
  });

  test('排行榜官方驼峰字段归一化为列表模型', () async {
    final transport = MockClient((request) async {
      return _cgiResponse({
        'group': [
          {
            'toplist': [
              {
                'topId': 26,
                'title': '热歌榜',
                'titleDetail': 'QQ音乐热歌榜',
                'updateTime': '07-19',
                'frontPicUrl': 'https://example.com/chart.jpg',
              },
            ],
          },
        ],
      });
    });
    final api = _officialApi(transport);
    addTearDown(api.dispose);

    final result = await api.loadFeature(QqMusicFeature.charts);

    expect(result.items.single.id, '26');
    expect(result.items.single.title, '热歌榜');
    expect(result.items.single.type, QqMusicItemType.chart);
  });

  test('个人收藏功能使用登录凭据直接请求官方 CGI', () async {
    late http.Request captured;
    const credential = QqMusicCredential(
      musicId: '10001',
      musicKey: 'music-key',
      encryptUin: 'encrypted-uin',
    );
    final transport = MockClient((request) async {
      captured = request;
      return _cgiResponse({
        'songlist': [
          {
            'id': 202,
            'mid': 'liked-mid',
            'title': '喜欢的歌曲',
            'singer': [
              {'name': '喜欢的歌手'},
            ],
            'album': {'mid': 'album-mid'},
          },
        ],
        'songlist_size': 1,
        'total_song_num': 1,
      });
    });
    final api = _officialApi(transport, credential: credential);
    addTearDown(api.dispose);

    final result = await api.loadFeature(QqMusicFeature.likedSongs);
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;

    expect(payload['req_0']['module'], 'music.srfDissInfo.DissInfo');
    expect(payload['req_0']['method'], 'CgiGetDiss');
    expect(payload['req_0']['param']['enc_host_uin'], 'encrypted-uin');
    expect(result.items.single.title, '喜欢的歌曲');
  });

  test('歌曲喜欢操作直接写入官方 201 目录', () async {
    late http.Request captured;
    const credential = QqMusicCredential(
      musicId: '10001',
      musicKey: 'music-key',
    );
    final transport = MockClient((request) async {
      captured = request;
      return _cgiResponse({'retCode': 0});
    });
    final api = _officialApi(transport, credential: credential);
    addTearDown(api.dispose);

    await api.setSongLiked(FakeQqMusicApi.songs.first, liked: true);
    var payload = jsonDecode(captured.body) as Map<String, dynamic>;

    expect(payload['req_0']['module'], 'music.musicasset.PlaylistDetailWrite');
    expect(payload['req_0']['method'], 'AddSonglist');
    expect(payload['req_0']['param']['dirId'], 201);
    expect(payload['req_0']['param']['bFmtUtf8'], true);
    expect(payload['req_0']['param']['v_songInfo'], [
      {'songId': 1, 'songType': 1},
    ]);

    // unlike_song path: DelSonglist with bools encoded as ints (web default).
    await api.setSongLiked(FakeQqMusicApi.songs.first, liked: false);
    payload = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(payload['req_0']['method'], 'DelSonglist');
    expect(payload['req_0']['param']['dirId'], 201);
    expect(payload['req_0']['param']['bFmtUtf8'], 1);
    expect(payload['req_0']['param']['v_songInfo'], [
      {'songId': 1, 'songType': 1},
    ]);
  });

  test('取消喜欢时缺省 songType 按普通曲 1 发送', () async {
    late http.Request captured;
    const credential = QqMusicCredential(
      musicId: '10001',
      musicKey: 'music-key',
    );
    final transport = MockClient((request) async {
      captured = request;
      return _cgiResponse({'retCode': 0});
    });
    final api = _officialApi(transport, credential: credential);
    addTearDown(api.dispose);

    const song = QqMusicItem(
      id: '99',
      mid: 'mid-99',
      title: '无类型歌曲',
      subtitle: '歌手',
      imageUrl: '',
      type: QqMusicItemType.song,
    );
    await api.setSongLiked(song, liked: false);
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(payload['req_0']['method'], 'DelSonglist');
    expect(payload['req_0']['param']['v_songInfo'], [
      {'songId': 99, 'songType': 1},
    ]);
  });
}

QqMusicOfficialApi _officialApi(
  http.Client transport, {
  QqMusicCredential? credential,
}) {
  final device = QqMusicDevice.random(Random(8))
    ..qimei = 'qimei16'
    ..qimei36 = 'qimei36'
    ..qimeiSavedAt = 1700000000
    ..sessionUid = 'session-uid'
    ..sessionSid = 'session-sid'
    ..sessionSavedAt = 1700000000;
  final client = QqMusicDirectClient(
    client: transport,
    androidContext: QqMusicAndroidContext(
      store: MemoryQqMusicDeviceStore(device),
      qimeiProvider: _UnexpectedQimeiProvider(),
      sessionProvider: _UnexpectedSessionProvider(),
      clock: () => 1700000010,
    ),
  );
  final login = QqMusicLoginModule(client: client);
  if (credential != null) {
    login.useCredential(credential);
  }
  return QqMusicOfficialApi(client: client, login: login);
}

http.Response _cgiResponse(Map<String, dynamic> data) {
  return http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'code': 0,
        'req_0': {'code': 0, 'data': data},
      }),
    ),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _UnexpectedQimeiProvider implements QqMusicQimeiProvider {
  @override
  Future<QqMusicQimeiResult> request(QqMusicDevice device) {
    throw StateError('不应刷新有效 QIMEI');
  }
}

class _UnexpectedSessionProvider implements QqMusicSessionProvider {
  @override
  Future<QqMusicDeviceSession> request({
    required QqMusicDevice device,
    required Map<String, Object?> comm,
  }) {
    throw StateError('不应刷新有效设备会话');
  }
}
