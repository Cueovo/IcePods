import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/business/entities/account.dart';
import 'package:qqmusic_ipod/core/theme/widgets/artwork_image.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    required this.profile,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onLogout,
    super.key,
  });

  final QqMusicUserProfile profile;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final vip = profile.isVip == true;
    final membership = vip
        ? 'VIP 会员'
        : profile.isVip == false
        ? '普通用户'
        : '状态待确认';
    final accent = vip
        ? const Color(0xFFF0C27A)
        : const Color(0xFF72D6A8);

    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x38000000),
                          blurRadius: 30,
                          offset: Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: vip
                                  ? const [
                                      Color(0x3DD8A94E),
                                      Color(0x20FFFFFF),
                                      Color(0x17000000),
                                    ]
                                  : const [
                                      Color(0x3052B788),
                                      Color(0x20FFFFFF),
                                      Color(0x17000000),
                                    ],
                              stops: const [0, .48, 1],
                            ),
                            border: Border.all(
                              color: const Color(0x2EFFFFFF),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -74,
                                top: -92,
                                child: Container(
                                  width: 210,
                                  height: 210,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        accent.withValues(alpha: .22),
                                        accent.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        _ProfileAvatar(
                                          imageUrl: profile.avatarUrl,
                                          vip: vip,
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const _ConnectedBadge(),
                                              const SizedBox(height: 8),
                                              Text(
                                                profile.nickname,
                                                key: const ValueKey(
                                                  'qqmusic-profile-name',
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  height: 1.08,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -.2,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                profile.id.isEmpty
                                                    ? 'QQ 音乐身份已验证'
                                                    : 'QQ ${profile.id}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0x8FFFFFFF),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: .2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _AccountMetric(
                                            icon: Icons.workspace_premium_rounded,
                                            label: '会员状态',
                                            value: membership,
                                            accent: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: _AccountMetric(
                                            icon: Icons.cloud_done_rounded,
                                            label: '云端资料',
                                            value: '已同步',
                                            accent: Color(0xFF72D6A8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _AccountActionButton(
                                            icon: Icons.refresh_rounded,
                                            label: '续期登录',
                                            loading: isRefreshing,
                                            onTap: onRefresh,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _AccountActionButton(
                                            icon: Icons.logout_rounded,
                                            label: '退出登录',
                                            destructive: true,
                                            onTap: onLogout,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl, required this.vip});

  final String imageUrl;
  final bool vip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: vip
              ? const [Color(0xFFFFE0A4), Color(0xFFA96E20)]
              : const [Color(0xFFE6FFF3), Color(0xFF3F9B73)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x2EFFFFFF)),
        ),
        child: ClipOval(
          child: imageUrl.isEmpty
              ? const ColoredBox(
                  color: Color(0xFF242830),
                  child: Icon(
                    Icons.person_rounded,
                    size: 38,
                    color: Color(0xD9FFFFFF),
                  ),
                )
              : ArtworkImage(
                  imageUrl: imageUrl,
                  cacheWidth: 82,
                  cacheHeight: 82,
                ),
        ),
      ),
    );
  }
}

class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x2472D6A8),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x3872D6A8)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 12,
              color: Color(0xFF93E8BC),
            ),
            SizedBox(width: 4),
            Text(
              'QQ 音乐已连接',
              style: TextStyle(
                color: Color(0xFFE4FFF0),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountMetric extends StatelessWidget {
  const _AccountMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x73FFFFFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountActionButton extends StatefulWidget {
  const _AccountActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool destructive;

  @override
  State<_AccountActionButton> createState() => _AccountActionButtonState();
}

class _AccountActionButtonState extends State<_AccountActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.loading) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.destructive
        ? const Color(0xFFFFB1B1)
        : const Color(0xE6FFFFFF);
    return Semantics(
      button: true,
      label: widget.label,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? .96 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Material(
            color: widget.destructive
                ? const Color(0x16FF7D7D)
                : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: widget.loading ? null : widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.destructive
                        ? const Color(0x2EFF8F8F)
                        : const Color(0x24FFFFFF),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.loading)
                      const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Color(0xCCFFFFFF),
                        ),
                      )
                    else
                      Icon(widget.icon, size: 17, color: foreground),
                    const SizedBox(width: 7),
                    Text(
                      widget.loading ? '刷新中' : widget.label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
