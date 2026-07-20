import 'dart:math';

import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

class QqMusicSearchModule {
  QqMusicSearchModule(this.client, {Random? random, int Function()? clock})
    : _random = random ?? Random.secure(),
      _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final QqMusicDirectClient client;
  final Random _random;
  final int Function() _clock;

  Future<Map<String, dynamic>> search(
    String keyword, {
    required int page,
    required int pageSize,
    QqMusicCredential? credential,
  }) {
    return client
        .request(
          QqMusicCgiRequest(
            module: 'music.adaptor.SearchAdaptor',
            method: 'do_search_v2',
            param: {
              'searchid': _searchId(),
              'search_type': 100,
              'page_num': pageSize,
              'query': keyword,
              'page_id': page,
              'highlight': false,
              'grp': true,
            },
          ),
          credential: credential,
          platform: QqMusicRequestPlatform.android,
        )
        .then(_normalize);
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final body = _map(data['body']);
    final meta = _map(data['meta']);
    return {
      ...data,
      'song': _bucket(body['item_song']),
      'singer': _bucket(body['singer']),
      'album': _bucket(body['item_album']),
      'songlist': _bucket(body['item_songlist']),
      'mv': _bucket(body['item_mv']),
      'nextpage': meta['nextpage'],
    };
  }

  Map<String, dynamic> _bucket(Object? value) {
    final bucket = _map(value);
    return {...bucket, 'items': bucket['items'] ?? const []};
  }

  String _searchId() {
    final factor = 1 + _random.nextInt(20);
    final high = factor * 18014398509481984;
    final middle = _random.nextInt(4194305) * 4294967296;
    final dayMilliseconds = _clock() % const Duration(days: 1).inMilliseconds;
    return '${high + middle + dayMilliseconds}';
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
