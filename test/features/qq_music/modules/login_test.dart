import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qqmusic_ipod/features/qq_music/core/client.dart';
import 'package:qqmusic_ipod/features/qq_music/models/auth.dart';
import 'package:qqmusic_ipod/features/qq_music/modules/login.dart';
import 'package:qqmusic_ipod/features/qq_music/utils/credential_store.dart';

void main() {
  const credential = QqMusicCredential(
    musicId: '10001',
    musicKey: 'music-key',
    openId: 'open-id',
    refreshToken: 'refresh-token',
    accessToken: 'access-token',
    stringMusicId: '10001',
    refreshKey: 'refresh-key',
    loginType: 2,
  );

  test('QQ QR creation and pending status use official endpoints', () async {
    final rawRequests = <http.Request>[];
    final login = QqMusicLoginModule(
      client: _directClient(
        MockClient((request) async {
          throw StateError('CGI should not be called while pending');
        }),
      ),
      httpClient: MockClient((request) async {
        rawRequests.add(request);
        if (request.url.host == 'ssl.ptlogin2.qq.com' &&
            request.url.path.endsWith('/ptqrshow')) {
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'set-cookie': 'qrsig=qr-signature; Path=/; HttpOnly'},
          );
        }
        if (request.url.path.endsWith('/ptqrlogin')) {
          expect(request.headers['cookie'], 'qrsig=qr-signature');
          expect(request.url.queryParameters['ptqrtoken'], '1876578754');
          return http.Response.bytes(
            utf8.encode("ptuiCB('66','0','0','0','等待扫码','0')"),
            200,
          );
        }
        throw StateError('Unexpected raw request: ${request.url}');
      }),
    );
    addTearDown(login.close);

    final qr = await login.createQrCode();
    final status = await login.checkQrStatus(qr);

    expect(qr.loginType, 'qq');
    expect(qr.identifier, 'qr-signature');
    expect(qr.imageBytes, [1, 2, 3]);
    expect(status.event, 1);
    expect(status.done, isFalse);
    expect(rawRequests.map((request) => request.url.host), [
      'ssl.ptlogin2.qq.com',
      'ssl.ptlogin2.qq.com',
    ]);
  });

  test('QQ QR completion exchanges authorization code for credential', () async {
    final cgiRequests = <http.Request>[];
    final login = QqMusicLoginModule(
      client: _directClient(
        MockClient((request) async {
          cgiRequests.add(request);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final item = body['req_0'] as Map<String, dynamic>;
          expect(item['module'], 'QQConnectLogin.LoginServer');
          expect(item['method'], 'QQLogin');
          expect(item['param']['code'], 'qq-code');
          return _cgiResponse({
            'code': 0,
            'data': {
              'musicid': 10001,
              'musickey': 'music-key',
              'openid': 'open-id',
              'loginType': 2,
            },
          });
        }),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/ptqrlogin')) {
          return http.Response.bytes(
            utf8.encode(
              "ptuiCB('0','0','https://ssl.ptlogin2.qq.com/check_sig?uin=10001&service=ptqrlogin&ptsigx=sig-x&s_url=https%3A%2F%2Fgraph.qq.com%2Foauth2.0%2Flogin_jump','登录成功','0')",
            ),
            200,
            headers: {'set-cookie': 'qrsig=qr-signature; Path=/;'},
          );
        }
        if (request.url.path.endsWith('/check_sig')) {
          expect(request.url.host, 'ssl.ptlogin2.graph.qq.com');
          expect(request.url.queryParameters['uin'], '10001');
          expect(request.url.queryParameters['ptsigx'], 'sig-x');
          expect(request.headers['user-agent'], 'QQMusic 14090008(android 10)');
          expect(request.headers['cookie'], isNull);
          return http.Response(
            '',
            302,
            headers: {
              'set-cookie':
                  'pt2gguin=o10001; Domain=.qq.com; Path=/, '
                  'p_uin=o10001; Domain=graph.qq.com; Path=/, '
                  'p_skey=p-skey; Domain=graph.qq.com; Path=/, '
                  'pt4_token=pt4-token; Domain=graph.qq.com; Path=/, '
                  'p_skey_forbid=1; Domain=.qq.com; Path=/, '
                  'p_skey=; Domain=.qq.com; Max-Age=0; Path=/, '
                  'skey=s-key; Domain=.qq.com; Path=/',
            },
          );
        }
        if (request.url.path.endsWith('/authorize')) {
          expect(request.headers['referer'], isNull);
          expect(request.headers['user-agent'], 'QQMusic 14090008(android 10)');
          expect(request.headers['cookie'], contains('p_uin=o10001'));
          expect(request.headers['cookie'], contains('p_skey=p-skey'));
          expect(request.headers['cookie'], contains('pt4_token=pt4-token'));
          expect(request.headers['cookie'], contains('p_skey_forbid=1'));
          expect(request.headers['cookie'], contains('skey=s-key'));
          expect(request.bodyFields['auth_time'], '1700000000000');
          expect(
            request.bodyFields['ui'],
            matches(
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
              ),
            ),
          );
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://y.qq.com/portal/wx_redirect.html?code=qq-code&state=state',
            },
          );
        }
        throw StateError('Unexpected raw request: ${request.url}');
      }),
      credentialStore: MemoryQqMusicCredentialStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1700000000123),
    );
    addTearDown(login.close);

    final status = await login.checkQrStatus(
      const QqMusicQrCode(
        loginType: 'qq',
        identifier: 'qr-signature',
        mimeType: 'image/png',
        imageBytes: [1],
      ),
    );

    expect(status.done, isTrue);
    expect(status.credential?.musicId, '10001');
    expect(login.credential?.musicKey, 'music-key');
    expect(cgiRequests, hasLength(1));
  });

  test(
    'WeChat QR creation and pending status parse official responses',
    () async {
      final login = QqMusicLoginModule(
        client: _directClient(
          MockClient((request) async {
            throw StateError('CGI should not be called while pending');
          }),
        ),
        httpClient: MockClient((request) async {
          if (request.url.host == 'open.weixin.qq.com' &&
              request.url.path.endsWith('/qrconnect')) {
            return http.Response(
              '<script>var config="uuid=wx-uuid"</script>',
              200,
            );
          }
          if (request.url.path.endsWith('/qrcode/wx-uuid')) {
            return http.Response.bytes(
              [0xFF, 0xD8, 0xFF, 0xD9],
              200,
              headers: {'content-type': 'image/jpeg'},
            );
          }
          if (request.url.host == 'lp.open.weixin.qq.com') {
            return http.Response(
              "window.wx_errcode=408;window.wx_code='';",
              200,
            );
          }
          throw StateError('Unexpected raw request: ${request.url}');
        }),
      );
      addTearDown(login.close);

      final qr = await login.createQrCode(loginType: 'wx');
      final status = await login.checkQrStatus(qr);

      expect(qr.identifier, 'wx-uuid');
      expect(qr.mimeType, 'image/jpeg');
      expect(qr.imageBytes, [0xFF, 0xD8, 0xFF, 0xD9]);
      expect(status.event, 1);
      expect(status.done, isFalse);
    },
  );

  test(
    'refresh and logout use official LoginServer CGI and persist state',
    () async {
      final store = MemoryQqMusicCredentialStore()..credential = credential;
      final requests = <Map<String, dynamic>>[];
      final login = QqMusicLoginModule(
        client: _directClient(
          MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            requests.add(body);
            final item = body['req_0'] as Map<String, dynamic>;
            if (item['method'] == 'Login') {
              return _cgiResponse({
                'code': 0,
                'data': {
                  'musicid': 10001,
                  'musickey': 'refreshed-key',
                  'openid': 'open-id',
                  'refresh_token': 'new-refresh-token',
                  'loginType': 2,
                },
              });
            }
            return _cgiResponse({'code': 0, 'data': {}});
          }),
        ),
        credentialStore: store,
      );
      addTearDown(login.close);
      login.useCredential(credential);

      final refreshed = await login.refreshCredential();
      await login.logout();

      expect(refreshed.musicKey, 'refreshed-key');
      expect((await store.read()), isNull);
      expect(requests, hasLength(2));
      expect(requests[0]['req_0']['module'], 'music.login.LoginServer');
      expect(requests[0]['req_0']['method'], 'Login');
      expect(requests[1]['req_0']['method'], 'Logout');
    },
  );
}

QqMusicDirectClient _directClient(http.Client transport) {
  return QqMusicDirectClient(
    client: transport,
    apiUri: Uri.parse('https://u.y.qq.com/cgi-bin/musicu.fcg'),
  );
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
