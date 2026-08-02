import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/core/storage/credential_store.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/data/datasources/login.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

void main() {
  test('credentials refresh proactively on the configured interval', () async {
    final client = QqMusicDirectClient();
    final login = _PeriodicLogin(
      client,
      credentialRefreshInterval: const Duration(milliseconds: 10),
    );
    addTearDown(() {
      login.close();
      client.close();
    });

    login.useCredential(_credential('initial-key'));
    await login.firstRefresh.future.timeout(const Duration(seconds: 1));

    expect(login.refreshCount, 1);
    expect(login.credential?.musicKey, 'refreshed-key');
  });

  test('concurrent credential refreshes share one request', () async {
    final client = _GatedRefreshClient();
    final login = QqMusicLoginModule(
      client: client,
      credentialStore: _MemoryCredentialStore(null),
    );
    addTearDown(() {
      login.close();
      client.close();
    });

    login.useCredential(_credential('initial-key'));
    final first = login.refreshCredential();
    final second = login.refreshCredential();

    expect(client.refreshRequestCount, 1);
    client.release();

    final results = await Future.wait([first, second]);
    expect(results[0].musicKey, 'refreshed-key');
    expect(results[1].musicKey, 'refreshed-key');
  });

  test('credential refresh uses the Android request platform', () async {
    final client = _RefreshPlatformClient();
    final login = QqMusicLoginModule(
      client: client,
      credentialStore: _MemoryCredentialStore(null),
    );
    addTearDown(() {
      login.close();
      client.close();
    });

    login.useCredential(
      const QqMusicCredential(
        musicId: '10001',
        musicKey: 'Q_H_old_key',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        loginType: 2,
      ),
    );
    await login.refreshCredential();

    expect(client.platform, QqMusicRequestPlatform.android);
    expect(client.comm, isEmpty);
  });

  test('an overdue persisted key refreshes during session restore', () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    final client = QqMusicDirectClient();
    final stored = QqMusicCredential(
      musicId: '10001',
      musicKey: 'overdue-key',
      refreshToken: 'refresh-token',
      musicKeyCreatedAt:
          now.subtract(const Duration(hours: 25)).millisecondsSinceEpoch ~/
          1000,
    );
    final login = _RestoringLogin(
      client,
      store: _MemoryCredentialStore(stored),
      now: () => now,
    );
    addTearDown(() {
      login.close();
      client.close();
    });

    await login.restoreSession();

    expect(login.refreshCount, 1);
    expect(login.expiryCheckCount, 0);
    expect(login.credential?.musicKey, 'refreshed-key');
  });

  test('refresh preserves legacy fields omitted by the server', () {
    final original = QqMusicCredential(
      musicId: '10001',
      musicKey: 'old-key',
      refreshToken: 'refresh-token',
      refreshKey: 'refresh-key',
      loginType: 2,
      musicKeyCreatedAt: 123,
      keyExpiresIn: 86400,
    );
    const response = QqMusicCredential(musicId: '10001', musicKey: 'new-key');

    final merged = response.merge(original);

    expect(merged.musicKey, 'new-key');
    expect(merged.refreshToken, 'refresh-token');
    expect(merged.refreshKey, 'refresh-key');
    expect(merged.loginType, 2);
    expect(merged.musicKeyCreatedAt, 123);
    expect(merged.keyExpiresIn, 86400);
  });

  test('restoreCredential replaces the active and persisted credential', () async {
    final client = QqMusicDirectClient();
    final store = _MemoryCredentialStore(_credential('fresh-key'));
    final login = QqMusicLoginModule(
      client: client,
      credentialStore: store,
    );
    addTearDown(() {
      login.close();
      client.close();
    });

    await login.restoreCredential(_credential('original-key'));

    expect(login.credential?.musicKey, 'original-key');
    expect(store.value?.musicKey, 'original-key');
  });

  test('credential key prefix overrides a stale login type field', () {
    const qqCredential = QqMusicCredential(
      musicId: '10001',
      musicKey: 'Q_H_qq_key',
      loginType: 1,
    );
    const wxCredential = QqMusicCredential(
      musicId: '10001',
      musicKey: 'W_X_wx_key',
      loginType: 2,
    );

    expect(qqCredential.effectiveLoginType, 2);
    expect(wxCredential.effectiveLoginType, 1);
  });

  test('the production credential refresh interval is 24 hours', () {
    final client = QqMusicDirectClient();
    final login = QqMusicLoginModule(client: client);
    addTearDown(() {
      login.close();
      client.close();
    });

    expect(login.credentialRefreshInterval, const Duration(hours: 24));
  });
}

QqMusicCredential _credential(String key) => QqMusicCredential(
  musicId: '10001',
  musicKey: key,
  refreshToken: 'refresh-token',
);

class _RefreshPlatformClient extends QqMusicDirectClient {
  QqMusicRequestPlatform? platform;
  Map<String, Object?>? comm;

  @override
  Future<List<Map<String, dynamic>>> requestBatch(
    List<QqMusicCgiRequest> requests, {
    QqMusicCredential? credential,
    Map<String, Object?> comm = const {},
    bool overrideComm = false,
    bool sign = false,
    QqMusicRequestPlatform platform = QqMusicRequestPlatform.web,
    Set<int> allowedErrorCodes = const {},
  }) async {
    this.platform = platform;
    this.comm = comm;
    return [
      {
        'code': 0,
        'data': {
          'musicid': credential!.musicId,
          'musickey': 'Q_H_refreshed_key',
          'loginType': 2,
        },
      },
    ];
  }
}

class _GatedRefreshClient extends QqMusicDirectClient {
  final Completer<void> _gate = Completer<void>();
  int refreshRequestCount = 0;

  void release() => _gate.complete();

  @override
  Future<List<Map<String, dynamic>>> requestBatch(
    List<QqMusicCgiRequest> requests, {
    QqMusicCredential? credential,
    Map<String, Object?> comm = const {},
    bool overrideComm = false,
    bool sign = false,
    QqMusicRequestPlatform platform = QqMusicRequestPlatform.web,
    Set<int> allowedErrorCodes = const {},
  }) async {
    refreshRequestCount += 1;
    await _gate.future;
    return [
      {
        'code': 0,
        'data': {'musicid': credential!.musicId, 'musickey': 'refreshed-key'},
      },
    ];
  }
}

class _RestoringLogin extends QqMusicLoginModule {
  _RestoringLogin(
    QqMusicDirectClient client, {
    required QqMusicCredentialStore store,
    required DateTime Function() now,
  }) : super(client: client, credentialStore: store, now: now);

  int refreshCount = 0;
  int expiryCheckCount = 0;

  @override
  Future<bool> checkExpired([QqMusicCredential? target]) async {
    expiryCheckCount += 1;
    return false;
  }

  @override
  Future<QqMusicCredential> refreshCredential([
    QqMusicCredential? target,
  ]) async {
    refreshCount += 1;
    final refreshed = _credential('refreshed-key');
    useCredential(refreshed);
    return refreshed;
  }
}

class _MemoryCredentialStore implements QqMusicCredentialStore {
  _MemoryCredentialStore(this.value);

  QqMusicCredential? value;

  @override
  Future<QqMusicCredential?> read() async => value;

  @override
  Future<void> write(QqMusicCredential credential) async {
    value = credential;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class _PeriodicLogin extends QqMusicLoginModule {
  _PeriodicLogin(
    QqMusicDirectClient client, {
    required super.credentialRefreshInterval,
  }) : super(client: client);

  final Completer<void> firstRefresh = Completer<void>();
  int refreshCount = 0;

  @override
  Future<QqMusicCredential> refreshCredential([
    QqMusicCredential? target,
  ]) async {
    refreshCount += 1;
    final refreshed = _credential('refreshed-key');
    useCredential(refreshed);
    if (!firstRefresh.isCompleted) {
      firstRefresh.complete();
    }
    return refreshed;
  }
}
