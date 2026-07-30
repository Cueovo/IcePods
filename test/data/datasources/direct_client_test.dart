import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

void main() {
  test('authenticated web requests include QQ write-session cookies', () async {
    http.Request? captured;
    final httpClient = MockClient((request) async {
      captured = request;
      return http.Response(
        '{"code":0,"req_0":{"code":0,"data":{}}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = QqMusicDirectClient(client: httpClient);
    addTearDown(client.close);

    await client.request(
      const QqMusicCgiRequest(
        module: 'music.musicasset.PlaylistDetailWrite',
        method: 'AddSonglist',
        param: {},
      ),
      credential: const QqMusicCredential(
        musicId: '10001',
        stringMusicId: 'wx-user',
        musicKey: 'W_X_test_key',
        loginType: 1,
      ),
      platform: QqMusicRequestPlatform.web,
    );

    final cookie = captured!.headers['cookie']!;
    expect(cookie, contains('tmeLoginType=1'));
    expect(cookie, contains('wxuin=wx-user'));
    expect(cookie, contains('qm_keyst=W_X_test_key'));
  });
}
