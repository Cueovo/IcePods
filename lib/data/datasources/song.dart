import 'package:qqmusic_ipod/data/datasources/direct_client.dart';
import 'package:qqmusic_ipod/business/entities/auth.dart';
import 'package:qqmusic_ipod/business/entities/music.dart';
import 'package:qqmusic_ipod/data/models/request.dart';

class QqMusicSongModule {
  const QqMusicSongModule(this.client);

  final QqMusicDirectClient client;

  Future<Map<String, dynamic>> detail(
    QqMusicItem song, {
    QqMusicCredential? credential,
  }) {
    return client.request(
      QqMusicCgiRequest(
        module: 'music.pf_song_detail_svr',
        method: 'get_song_detail_yqq',
        param: song.mid.isNotEmpty
            ? {'song_mid': song.mid}
            : {'song_id': int.tryParse(song.id) ?? 0},
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.web,
    );
  }

  Future<Map<String, dynamic>> urls(
    List<QqMusicItem> songs, {
    required int fileType,
    QqMusicCredential? credential,
  }) async {
    final prefix = _filePrefix(fileType);
    final extension = _fileExtension(fileType);
    final guid = await client.androidGuid(credential);
    return client.request(
      QqMusicCgiRequest(
        module: 'music.vkey.GetVkey',
        method: 'UrlGetVkey',
        param: {
          'uin': credential?.stringMusicId ?? '',
          'filename': [
            for (final song in songs)
              '$prefix${song.mediaMid.isEmpty ? '${song.mid}${song.mid}' : song.mediaMid}$extension',
          ],
          'guid': guid,
          'songmid': [for (final song in songs) song.mid],
          'songtype': [for (final song in songs) song.songType ?? 0],
          'ctx': 0,
        },
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
  }

  Future<Map<String, dynamic>> cdn({QqMusicCredential? credential}) async {
    final guid = await client.androidGuid(credential);
    return client.request(
      QqMusicCgiRequest(
        module: 'music.audioCdnDispatch.cdnDispatch',
        method: 'GetCdnDispatch',
        param: {'guid': guid, 'uid': '0', 'use_new_domain': 1, 'use_ipv6': 1},
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
  }

  Future<Map<String, dynamic>> lyric(
    QqMusicItem song, {
    QqMusicCredential? credential,
  }) {
    return client.request(
      QqMusicCgiRequest(
        module: 'music.musichallSong.PlayLyricInfo',
        method: 'GetPlayLyricInfo',
        // Match qqmusic-web LyricApi.get_lyric: crypt=1 + qrc for word timeline.
        // Response lyric field is hex ciphertext when crypt==1 (see qrcDecrypt).
        param: {
          'crypt': 1,
          'lrc_t': 0,
          'qrc': true,
          'qrc_t': 0,
          'roma': false,
          'roma_t': 0,
          'trans': false,
          'trans_t': 0,
          'type': 1,
          'ct': 11,
          'cv': 13050008,
          if (song.mid.isNotEmpty)
            'songMid': song.mid
          else
            'songId': int.tryParse(song.id) ?? 0,
        },
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
  }

  Future<Uri> musicVideoUrl(
    QqMusicItem musicVideo, {
    QqMusicCredential? credential,
  }) async {
    final guid = await client.androidGuid(credential);
    final data = await client.request(
      QqMusicCgiRequest(
        module: 'music.stream.MvUrlProxy',
        method: 'GetMvUrls',
        param: {
          'vids': [musicVideo.mid],
          'request_type': 10003,
          'guid': guid,
        },
      ),
      credential: credential,
      platform: QqMusicRequestPlatform.android,
    );
    final urls = <String>[];

    void collect(Object? value) {
      if (value is List) {
        for (final child in value) {
          collect(child);
        }
      } else if (value is Map) {
        for (final child in value.values) {
          collect(child);
        }
      } else if (value is String && value.startsWith('http')) {
        urls.add(value);
      }
    }

    collect(data);
    if (urls.isEmpty) {
      throw StateError('MV 没有可用播放地址');
    }
    return Uri.parse(urls.first);
  }

  String _filePrefix(int fileType) => switch (fileType) {
    1 => 'C200',
    2 => 'C400',
    3 => 'C600',
    4 => 'M800',
    5 => 'F000',
    13 => 'M500',
    _ => 'M500',
  };

  String _fileExtension(int fileType) => switch (fileType) {
    1 || 2 || 3 => '.m4a',
    5 => '.flac',
    _ => '.mp3',
  };
}
