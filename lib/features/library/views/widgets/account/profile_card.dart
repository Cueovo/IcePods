import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/business/entities/account.dart';
import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    required this.profile,
    required this.onLogout,
    super.key,
  });

  final QqMusicUserProfile profile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final vip = profile.isVip == true;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x2EFFFFFF),
                Color(0x12FFFFFF),
              ],
            ),
            border: Border.all(color: const Color(0x28FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: vip
                          ? const Color(0xCCF0C27A)
                          : const Color(0x40FFFFFF),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: profile.avatarUrl.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFF2A2C34),
                            child: Icon(
                              Icons.person_rounded,
                              size: 42,
                              color: Color(0xCCFFFFFF),
                            ),
                          )
                        : ArtworkImage(
                            imageUrl: profile.avatarUrl,
                            cacheWidth: 88,
                            cacheHeight: 88,
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.nickname,
                  key: const ValueKey('qqmusic-profile-name'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: vip
                        ? const Color(0x33F0C27A)
                        : const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: vip
                          ? const Color(0x66F0C27A)
                          : const Color(0x22FFFFFF),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    child: Text(
                      vip
                          ? 'QQ音乐 VIP'
                          : profile.isVip == false
                          ? '普通用户'
                          : '会员状态待确认',
                      style: TextStyle(
                        color: vip
                            ? const Color(0xFFF0C27A)
                            : const Color(0xCCFFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xE6FFFFFF),
                      side: const BorderSide(color: Color(0x40FFFFFF)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onLogout,
                    child: const Text(
                      '退出登录',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
