import 'features/qq_music/models/music.dart';
import 'ipod_models.dart';

const _dailyImage =
    'https://images.unsplash.com/photo-1493225457124-a1a2a53b111b?q=80&w=400&fit=crop';
const _hallImage =
    'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=400&fit=crop';
const _libraryImage =
    'https://images.unsplash.com/photo-1619983081563-430f63602796?q=80&w=400&fit=crop';
const _playlistImage =
    'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?q=80&w=400&fit=crop';
const _coverImage =
    'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=400&fit=crop';
const _settingsImage =
    'https://images.unsplash.com/photo-1586772002130-b0f3daa6288b?q=80&w=400&fit=crop';

MenuEntry _section(
  String id,
  String label,
  MenuSection section,
  String imageUrl,
  String title,
  String description,
) {
  return MenuEntry(
    id: id,
    label: label,
    action: MenuAction.submenu,
    section: section,
    imageUrl: imageUrl,
    title: title,
    description: description,
  );
}

MenuEntry _feature(
  String id,
  String label,
  QqMusicFeature feature,
  String apiOperation,
  String imageUrl,
  String title,
  String description,
  List<String> capabilities,
) {
  return MenuEntry(
    id: id,
    label: label,
    action: MenuAction.feature,
    feature: feature,
    apiOperation: apiOperation,
    imageUrl: imageUrl,
    title: title,
    description: description,
    capabilities: capabilities,
  );
}

const qqMusicApiOperations = <String>{
  'music.radioProxy.MbTrackRadioSvr.get_radio_track',
  'music.recommend.RecommendFeed.get_recommend_feed',
  'music.recommend.TrackRelationServer.GetRadarSong',
  'newsong.NewSongServer.get_new_song_info',
  'music.playlist.PlaylistSquare.GetRecommendFeed',
  'music.adaptor.SearchAdaptor.do_search_v2',
  'music.login.LoginServer.CreateQRCode',
  'music.musicToplist.Toplist.GetAll',
  'music.musichallSinger.SingerList.GetSingerListIndex',
  'music.srfDissInfo.DissInfo.CgiGetDiss',
  'music.musicasset.AlbumFavRead.CgiGetAlbumFavInfo',
  'music.musicasset.MVFavRead.getMyFavMV_v2',
  'music.concern.RelationList.GetFollowSingerList',
  'music.musicasset.PlaylistBaseRead.GetPlaylistByUin',
  'music.musicasset.PlaylistFavRead.CgiGetPlaylistFavInfo',
  'music.feedback.FeedbackBlack.GetDislikeList',
};

final qqMusicMenuPages = <MenuSection, MenuPage>{
  MenuSection.root: MenuPage(
    section: MenuSection.root,
    title: 'QQ音乐',
    entries: [
      _section(
        'recommendations',
        '为你推荐',
        MenuSection.recommendations,
        _dailyImage,
        'QQ音乐推荐',
        '猜你喜欢、首页推荐、雷达、新歌和推荐歌单。',
      ),
      _section(
        'music_hall',
        '音乐馆',
        MenuSection.musicHall,
        _hallImage,
        '发现音乐',
        '浏览新歌、排行榜和歌手。',
      ),
      _section(
        'my_music',
        '我的音乐',
        MenuSection.myMusic,
        _libraryImage,
        '个人音乐库',
        '查看账号收藏、关注、歌单和不喜欢列表。',
      ),
      _feature(
        'search',
        '搜索',
        QqMusicFeature.search,
        'music.adaptor.SearchAdaptor.do_search_v2',
        _hallImage,
        '搜索 QQ 音乐',
        '快速找到想听的歌曲、歌手、专辑与歌单。',
        ['综合搜索', '分类搜索', '快速搜索', '热词', '补全建议'],
      ),
      _feature(
        'account',
        '账号与会员',
        QqMusicFeature.account,
        'music.login.LoginServer.CreateQRCode',
        _settingsImage,
        'QQ账号',
        '扫码登录，查看账号状态、个人主页与会员权益。',
        ['QQ 扫码', '微信扫码', '状态轮询', '凭据刷新', '用户主页', 'VIP 信息'],
      ),
      const MenuEntry(
        id: 'cover_flow',
        label: 'Cover Flow',
        action: MenuAction.coverFlow,
        imageUrl: _coverImage,
        title: '专辑封面流',
        description: '转动滚轮穿梭于专辑封面，重温收藏与最近播放。',
      ),
      const MenuEntry(
        id: 'now_playing',
        label: '正在播放',
        action: MenuAction.player,
        imageUrl: _playlistImage,
        title: '回到当前歌曲',
        description: '回到此刻的旋律，查看歌曲信息与播放进度。',
      ),
    ],
  ),
  MenuSection.recommendations: MenuPage(
    section: MenuSection.recommendations,
    title: '为你推荐',
    entries: [
      _feature(
        'guess',
        '猜你喜欢',
        QqMusicFeature.guessRecommendations,
        'music.radioProxy.MbTrackRadioSvr.get_radio_track',
        _dailyImage,
        '猜你喜欢',
        '根据你的聆听喜好，发现下一首心动歌曲。',
        ['推荐歌曲', '分页加载', '播放歌曲'],
      ),
      _feature(
        'home_feed',
        '首页推荐',
        QqMusicFeature.homeFeed,
        'music.recommend.RecommendFeed.get_recommend_feed',
        _playlistImage,
        '首页推荐',
        '汇集今日热门与个性推荐，轻松发现好音乐。',
        ['首页模块', '推荐内容', '内容跳转'],
      ),
      _feature(
        'radar',
        '雷达',
        QqMusicFeature.radar,
        'music.recommend.TrackRelationServer.GetRadarSong',
        _coverImage,
        '音乐雷达',
        '沿着你的音乐品味，探索熟悉又新鲜的旋律。',
        ['雷达推荐', '歌曲列表', '连续播放'],
      ),
      _feature(
        'new_songs',
        '新歌推荐',
        QqMusicFeature.newSongs,
        'newsong.NewSongServer.get_new_song_info',
        _hallImage,
        '新歌推荐',
        '抢先聆听近期新作，发现乐坛新鲜声音。',
        ['推荐新歌', '歌曲详情', '播放歌曲'],
      ),
      _feature(
        'recommended_playlists',
        '推荐歌单',
        QqMusicFeature.recommendedPlaylists,
        'music.playlist.PlaylistSquare.GetRecommendFeed',
        _libraryImage,
        '推荐歌单',
        '精选不同心情与场景的歌单，随时开启播放。',
        ['推荐歌单', '歌单详情', '收藏歌单'],
      ),
    ],
  ),
  MenuSection.musicHall: MenuPage(
    section: MenuSection.musicHall,
    title: '音乐馆',
    entries: [
      _feature(
        'hall_new_songs',
        '新歌',
        QqMusicFeature.newSongs,
        'newsong.NewSongServer.get_new_song_info',
        _hallImage,
        '新歌推荐',
        '汇集近期新作与热门单曲，探索新鲜声音。',
        ['推荐新歌', '歌曲详情', '播放歌曲'],
      ),
      _feature(
        'charts',
        '排行榜',
        QqMusicFeature.charts,
        'music.musicToplist.Toplist.GetAll',
        _dailyImage,
        'QQ音乐榜单',
        '查看热门榜单与实时趋势，听见此刻流行。',
        ['榜单分类', '榜单详情', '榜单歌曲'],
      ),
      _feature(
        'singers',
        '歌手',
        QqMusicFeature.singers,
        'music.musichallSinger.SingerList.GetSingerListIndex',
        _coverImage,
        '歌手分类',
        '按分类发现歌手，浏览热门歌曲、专辑与 MV。',
        ['歌手列表', '歌手主页', '歌手歌曲', '歌手专辑', '歌手 MV'],
      ),
    ],
  ),
  MenuSection.myMusic: MenuPage(
    section: MenuSection.myMusic,
    title: '我的音乐',
    entries: [
      _feature(
        'liked',
        '我喜欢',
        QqMusicFeature.likedSongs,
        'music.srfDissInfo.DissInfo.CgiGetDiss',
        _dailyImage,
        '我喜欢的音乐',
        '重温你点亮红心的歌曲，随时继续播放。',
        ['收藏歌曲', '分页加载', '播放歌曲'],
      ),
      _feature(
        'favorite_albums',
        '收藏专辑',
        QqMusicFeature.favoriteAlbums,
        'music.musicasset.AlbumFavRead.CgiGetAlbumFavInfo',
        _coverImage,
        '收藏专辑',
        '浏览珍藏的专辑，完整聆听喜欢的作品。',
        ['收藏专辑', '专辑详情', '专辑歌曲'],
      ),
      _feature(
        'favorite_mvs',
        '收藏MV',
        QqMusicFeature.favoriteMusicVideos,
        'music.musicasset.MVFavRead.getMyFavMV_v2',
        _hallImage,
        '收藏 MV',
        '重温收藏的音乐影像，感受声音之外的精彩。',
        ['收藏 MV', 'MV 详情', 'MV 播放地址'],
      ),
      _feature(
        'favorite_singers',
        '关注歌手',
        QqMusicFeature.favoriteSingers,
        'music.concern.RelationList.GetFollowSingerList',
        _libraryImage,
        '关注歌手',
        '关注喜欢的歌手，不错过他们的热门作品。',
        ['关注歌手', '歌手主页', '歌手歌曲'],
      ),
      _feature(
        'created',
        '自建歌单',
        QqMusicFeature.createdPlaylists,
        'music.musicasset.PlaylistBaseRead.GetPlaylistByUin',
        _playlistImage,
        '自建歌单',
        '整理亲手创建的歌单，自由添加或移除歌曲。',
        ['歌单列表', '创建歌单', '添加歌曲', '删除歌曲'],
      ),
      _feature(
        'collected',
        '收藏歌单',
        QqMusicFeature.collectedPlaylists,
        'music.musicasset.PlaylistFavRead.CgiGetPlaylistFavInfo',
        _coverImage,
        '收藏歌单',
        '集中浏览收藏歌单，继续发现喜欢的歌曲。',
        ['收藏歌单', '歌单详情', '收藏与取消收藏'],
      ),
      _feature(
        'dislikes',
        '不喜欢',
        QqMusicFeature.dislikes,
        'music.feedback.FeedbackBlack.GetDislikeList',
        _settingsImage,
        '不喜欢列表',
        '管理不合口味的歌曲与歌手，让推荐更懂你。',
        ['不喜欢列表', '添加不喜欢', '取消不喜欢'],
      ),
    ],
  ),
};
