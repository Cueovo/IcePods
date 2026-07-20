class QqMusicUserProfile {
  const QqMusicUserProfile({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
    this.isVip,
  });

  final String id;
  final String nickname;
  final String avatarUrl;
  final bool? isVip;

  bool get hasConfirmedVipStatus => isVip != null;
}
