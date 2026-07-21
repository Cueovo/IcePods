import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:qqmusic_ipod/features/library/views/widgets/account/profile_card.dart';
import 'package:qqmusic_ipod/features/player/state/controller.dart';
import 'package:qqmusic_ipod/features/shell/views/widgets/feature_message_state.dart';

class AccountView extends StatelessWidget {
  const AccountView({required this.controller, super.key});

  final QqMusicController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '账号',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            controller.isLoggedIn ? '已登录 QQ 音乐' : '扫码登录以同步收藏与歌单',
            style: const TextStyle(
              color: Color(0x80FFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: _accountBody()),
        ],
      ),
    );
  }

  Widget _accountBody() {
    if (controller.error.isNotEmpty) {
      return FeatureMessageState(
        icon: Icons.error_outline_rounded,
        title: controller.error,
        actionLabel: '重新获取二维码',
        onAction: controller.startQrLogin,
      );
    }
    final profile = controller.profile;
    if (controller.isLoggedIn && profile != null) {
      return ProfileCard(profile: profile, onLogout: controller.logout);
    }
    final qrCode = controller.qrCode;
    if (controller.isLoading || qrCode == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xCCFFFFFF),
          ),
        ),
      );
    }
    final status = controller.qrStatus;
    final isWx = controller.qrLoginType == 'wx';
    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = (constraints.maxHeight * .38).clamp(96.0, 148.0);
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Login type segmented control
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _LoginTypeTab(
                              key: const ValueKey('qq-qr-login'),
                              label: 'QQ 扫码',
                              icon: Icons.chat_bubble_rounded,
                              selected: !isWx,
                              enabled: !controller.isLoading,
                              onTap: () =>
                                  controller.startQrLogin(loginType: 'qq'),
                            ),
                          ),
                          Expanded(
                            child: _LoginTypeTab(
                              key: const ValueKey('wx-qr-login'),
                              label: '微信扫码',
                              icon: Icons.forum_rounded,
                              selected: isWx,
                              enabled: !controller.isLoading,
                              onTap: () =>
                                  controller.startQrLogin(loginType: 'wx'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Frosted QR plate
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x18FFFFFF),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0x28FFFFFF)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Container(
                                key: const ValueKey('qqmusic-qr-code'),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Image.memory(
                                  Uint8List.fromList(qrCode.imageBytes),
                                  width: qrSize,
                                  height: qrSize,
                                  gaplessPlayback: true,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                status?.message ?? '等待扫码',
                                key: const ValueKey('qqmusic-qr-status'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isWx ? '使用微信扫码并确认登录' : '使用手机 QQ 扫码并确认登录',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0x99FFFFFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (controller.statusMessage.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  controller.statusMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xB3FFFFFF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (status?.event == 3 || status?.event == 4) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0x22FFFFFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => controller.startQrLogin(
                          loginType: controller.qrLoginType,
                        ),
                        child: const Text(
                          '刷新二维码',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoginTypeTab extends StatelessWidget {
  const _LoginTypeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0x33FFFFFF) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : const Color(0x99FFFFFF),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0x99FFFFFF),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
