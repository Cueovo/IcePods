import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/core/storage/credential_store.dart';
import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/data/datasources/login.dart';

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
