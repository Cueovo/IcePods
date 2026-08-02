import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/data/datasources/login.dart';
import 'package:qqmusic_ipod/data/models/api_exception.dart';
import 'package:qqmusic_ipod/data/models/request.dart';
import 'package:qqmusic_ipod/data/repositories_impl/official_api.dart';

void main() {
  test('playlist writes rebuild the Android session before refreshing credentials', () async {
    final client = _RetryWriteClient();
    final login = _RefreshingLogin(client);
    login.useCredential(_credential('stale-key'));
    final api = QqMusicOfficialApi(client: client, login: login);
    addTearDown(api.dispose);

    await api.setSongLiked(_song, liked: true);

    expect(login.refreshCount, 0);
    expect(client.invalidateCount, 1);
    expect(client.writeKeys, ['stale-key', 'stale-key']);
    expect(client.writeParams, [
      {
        'dirId': 201,
        'tid': 0,
        'bFmtUtf8': true,
        'v_songInfo': [
          {'songId': 523664346, 'songType': 0},
        ],
      },
      {
        'dirId': 201,
        'tid': 0,
        'bFmtUtf8': true,
        'v_songInfo': [
          {'songId': 523664346, 'songType': 0},
        ],
      },
    ]);
    expect(client.preserveBoolValues, [true, true]);
  });
  test(
    'does not report credential expiration when refreshed write still returns 80105',
    () async {
      final client = _AlwaysFailingWriteClient();
      final login = _RefreshingLogin(client);
      login.useCredential(_credential('stale-key'));
      final api = QqMusicOfficialApi(client: client, login: login);
      addTearDown(api.dispose);

      await expectLater(
        api.setSongLiked(_song, liked: true),
        throwsA(
          isA<QqMusicApiException>()
              .having((error) => error.statusCode, 'statusCode', isNull)
              .having((error) => error.code, 'code', 80105)
              .having((error) => error.message, 'message', '添加歌曲失败，请稍后重试'),
        ),
      );
      expect(login.refreshCount, 1);
      expect(client.invalidateCount, 1);
      expect(client.writeKeys, ['stale-key', 'stale-key', 'fresh-key']);
      expect(login.restoredCredential?.musicKey, 'stale-key');
      expect(login.credential?.musicKey, 'stale-key');
    },
  );
}

const _song = QqMusicItem(
  id: '523664346',
  mid: '002it7yt1Da3oN',
  title: 'Song',
  subtitle: 'Artist',
  imageUrl: '',
  type: QqMusicItemType.song,
);

QqMusicCredential _credential(String key) => QqMusicCredential(
  musicId: '10001',
  musicKey: key,
  refreshToken: 'refresh-token',
);

class _RefreshingLogin extends QqMusicLoginModule {
  _RefreshingLogin(QqMusicDirectClient client) : super(client: client);

  int refreshCount = 0;
  QqMusicCredential? restoredCredential;

  @override
  Future<QqMusicCredential> refreshCredential([
    QqMusicCredential? target,
  ]) async {
    refreshCount += 1;
    final refreshed = _credential('fresh-key');
    useCredential(refreshed);
    return refreshed;
  }

  @override
  Future<void> restoreCredential(QqMusicCredential credential) async {
    restoredCredential = credential;
    useCredential(credential);
  }
}

class _AlwaysFailingWriteClient extends QqMusicDirectClient {
  final List<String> writeKeys = [];
  int invalidateCount = 0;

  @override
  Future<void> invalidateAndroidSession() async {
    invalidateCount += 1;
  }

  @override
  Future<Map<String, dynamic>> request(
    QqMusicCgiRequest request, {
    QqMusicCredential? credential,
    Map<String, Object?> comm = const {},
    bool overrideComm = false,
    bool sign = false,
    QqMusicRequestPlatform platform = QqMusicRequestPlatform.web,
    Set<int> allowedErrorCodes = const {},
  }) async {
    if (request.method == 'AddSonglist') {
      writeKeys.add(credential!.musicKey);
    }
    throw const QqMusicDirectException('QQ 音乐业务请求失败 (80105)', code: 80105);
  }
}

class _RetryWriteClient extends QqMusicDirectClient {
  final List<String> writeKeys = [];
  final List<Map<String, Object?>> writeParams = [];
  final List<bool> preserveBoolValues = [];
  int invalidateCount = 0;

  @override
  Future<void> invalidateAndroidSession() async {
    invalidateCount += 1;
  }

  @override
  Future<Map<String, dynamic>> request(
    QqMusicCgiRequest request, {
    QqMusicCredential? credential,
    Map<String, Object?> comm = const {},
    bool overrideComm = false,
    bool sign = false,
    QqMusicRequestPlatform platform = QqMusicRequestPlatform.web,
    Set<int> allowedErrorCodes = const {},
  }) async {
    if (request.method == 'AddSonglist') {
      writeKeys.add(credential!.musicKey);
      writeParams.add(request.param);
      preserveBoolValues.add(request.preserveBool);
      if (writeKeys.length == 1) {
        throw const QqMusicDirectException('QQ 音乐业务请求失败 (80105)', code: 80105);
      }
    }
    return const {'retCode': 0};
  }
}
