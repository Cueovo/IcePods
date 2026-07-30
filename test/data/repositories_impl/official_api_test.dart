import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/data/datasources/login.dart';
import 'package:qqmusic_ipod/data/models/request.dart';
import 'package:qqmusic_ipod/data/repositories_impl/official_api.dart';

void main() {
  test('playlist writes refresh stale credentials once on 80105', () async {
    final client = _RetryWriteClient();
    final login = _RefreshingLogin(client);
    login.useCredential(_credential('stale-key'));
    final api = QqMusicOfficialApi(client: client, login: login);
    addTearDown(api.dispose);

    await api.setSongLiked(_song, liked: true);

    expect(login.refreshCount, 1);
    expect(client.writeKeys, ['stale-key', 'fresh-key']);
  });
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

  @override
  Future<QqMusicCredential> refreshCredential([
    QqMusicCredential? target,
  ]) async {
    refreshCount += 1;
    final refreshed = _credential('fresh-key');
    useCredential(refreshed);
    return refreshed;
  }
}

class _RetryWriteClient extends QqMusicDirectClient {
  final List<String> writeKeys = [];

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
      if (writeKeys.length == 1) {
        throw const QqMusicDirectException('QQ 音乐业务请求失败 (80105)', code: 80105);
      }
    }
    return const {'retCode': 0};
  }
}
