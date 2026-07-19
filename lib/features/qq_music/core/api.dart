import '../models/account.dart';
import '../models/auth.dart';
import '../models/music.dart';

abstract interface class QqMusicApi {
  QqMusicCredential? get credential;

  bool get isLoggedIn;

  Future<void> restoreSession();

  Future<QqMusicQrCode> createQrCode({String loginType = 'qq'});

  Future<QqMusicQrStatus> checkQrStatus(QqMusicQrCode qrCode);

  Future<QqMusicCredential> refreshCredential();

  Future<void> logout();

  Future<QqMusicUserProfile> getUserProfile();

  Future<QqMusicFeatureResult> loadFeature(
    QqMusicFeature feature, {
    int page = 1,
    int pageSize = 25,
    bool forceRefresh = false,
  });

  Future<QqMusicFeatureResult> search(
    String keyword, {
    int page = 1,
    int pageSize = 15,
  });

  Future<QqMusicFeatureResult> loadChildren(
    QqMusicItem item, {
    int page = 1,
    int pageSize = 25,
  });

  Future<Uri> getPlayableUrl(QqMusicItem song, {int fileType = 13});

  Future<Map<String, Uri?>> getPlayableUrls(
    List<QqMusicItem> songs, {
    int fileType = 13,
  });

  Future<QqMusicLyrics> getLyrics(QqMusicItem song);

  Future<Uri> getMusicVideoUrl(QqMusicItem musicVideo);

  Future<void> setSongLiked(QqMusicItem song, {required bool liked});

  Future<void> setPlaylistFavorite(String playlistId, {required bool favorite});

  Future<void> setDislike(QqMusicItem item, {required bool disliked});

  Future<QqMusicItem> createPlaylist(String name);

  Future<void> deletePlaylist(String directoryId);

  Future<void> addSongsToPlaylist(String directoryId, List<QqMusicItem> songs);

  Future<void> removeSongsFromPlaylist(
    String directoryId,
    List<QqMusicItem> songs,
  );

  void dispose();
}
