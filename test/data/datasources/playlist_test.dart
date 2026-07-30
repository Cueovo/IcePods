import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/data/datasources/playlist.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

void main() {
  test('playlist mutation uses the QQ authenticated web write payload', () async {
    final client = _RecordingClient();
    final module = QqMusicPlaylistModule(client);
    const song = QqMusicItem(
      id: '12345',
      mid: 'radar-mid',
      title: 'Radar song',
      subtitle: 'Artist',
      imageUrl: '',
      type: QqMusicItemType.song,
      songType: 111,
    );

    await module.mutateSongs(
      '201',
      const [song],
      add: true,
      credential: const QqMusicCredential(musicId: '1', musicKey: 'key'),
    );

    final info = client.lastRequest!.param['v_songInfo']! as List<Object?>;
    expect(info.single, {'songId': 12345, 'songType': 0});
    expect(client.lastPlatform, QqMusicRequestPlatform.web);
    expect(client.lastComm, containsPair('ct', '11'));
    expect(client.lastComm, containsPair('authst', 'key'));
    expect(client.lastComm, containsPair('tmeLoginType', '2'));
  });
}

class _RecordingClient extends QqMusicDirectClient {
  QqMusicCgiRequest? lastRequest;
  Map<String, Object?>? lastComm;
  QqMusicRequestPlatform? lastPlatform;

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
    lastRequest = request;
    lastComm = comm;
    lastPlatform = platform;
    return const {'retCode': 0};
  }
}
