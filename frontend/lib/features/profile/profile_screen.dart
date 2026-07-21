import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/fitting_history_card.dart';
import '../../providers/app_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature 기능은 곧 연결될 예정이에요.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histories = ref.watch(fittingResultsProvider).take(3).toList();
    final historyCardWidth = (MediaQuery.sizeOf(context).width - 40).clamp(
      280.0,
      380.0,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final textScaleExtra = (textScale - 1).clamp(0.0, 0.35).toDouble();
    final historyHeight = 224.0 + textScaleExtra * 110;

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이'),
        actions: [
          IconButton(
            tooltip: '설정',
            onPressed: () => _showComingSoon(context, '설정'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ProfileCard(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '최근 피팅 기록',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/profile/fittings'),
                        child: const Text('전체 보기'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: historyHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: histories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final history = histories[index];
                        return SizedBox(
                          width: historyCardWidth,
                          child: FittingHistoryCard(
                            result: history,
                            onTap: () => _showComingSoon(context, '피팅 결과 상세'),
                            onTryAgain: () {
                              ref
                                  .read(selectedProductProvider.notifier)
                                  .selectProduct(history.product);
                              ref
                                  .read(selectedColorProvider.notifier)
                                  .selectColor(history.selectedColor);
                              ref
                                  .read(selectedSizeProvider.notifier)
                                  .selectSize(history.selectedSize);
                              if (ref.read(selectedUserPhotoProvider) == null) {
                                context.push('/photo');
                              } else {
                                context.go('/try-on');
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    '내 OTFIT',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _MenuGroup(
                    children: [
                      _MenuItem(
                        icon: Icons.auto_awesome_motion_outlined,
                        label: '내 피팅 기록',
                        onTap: () => context.push('/profile/fittings'),
                      ),
                      _MenuItem(
                        icon: Icons.favorite_border_rounded,
                        label: '찜한 상품',
                        onTap: () => context.push('/profile/favorites'),
                      ),
                      _MenuItem(
                        icon: Icons.photo_outlined,
                        label: '저장한 사진',
                        onTap: () => context.push('/profile/photos'),
                      ),
                      _MenuItem(
                        icon: Icons.workspace_premium_outlined,
                        label: '구독 관리',
                        badge: 'Free',
                        onTap: () => _showComingSoon(context, '구독 관리'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '설정 및 정보',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _MenuGroup(
                    children: [
                      _MenuItem(
                        icon: Icons.notifications_none_rounded,
                        label: '알림 설정',
                        trailing: Switch(
                          value: true,
                          onChanged: (_) => _showComingSoon(context, '알림 설정'),
                        ),
                        onTap: () => _showComingSoon(context, '알림 설정'),
                      ),
                      _MenuItem(
                        icon: Icons.privacy_tip_outlined,
                        label: '개인정보 처리방침',
                        onTap: () => _showComingSoon(context, '개인정보 처리방침'),
                      ),
                      _MenuItem(
                        icon: Icons.description_outlined,
                        label: '이용약관',
                        onTap: () => _showComingSoon(context, '이용약관'),
                      ),
                      _MenuItem(
                        icon: Icons.info_outline_rounded,
                        label: '앱 정보',
                        badge: 'v1.0.0',
                        onTap: () => showAboutDialog(
                          context: context,
                          applicationName: 'OTFIT',
                          applicationVersion: '1.0.0',
                          applicationLegalese: '© 2026 OTFIT',
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        label: '로그아웃',
                        onTap: () async {
                          await ref
                              .read(authSessionProvider.notifier)
                              .logout();
                          if (context.mounted) context.go('/login');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider).value;
    final nickname = user?.nickname ?? 'OTFIT User';
    final planLabel = user == null
        ? 'Free Plan'
        : '${user.email} · ${user.isPremium ? 'Premium' : 'Free Plan'}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final identity = Row(
            children: [
              _ProfileAvatar(nickname: nickname),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      planLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final credits = _CreditBadge(count: user?.creditBalance);
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [identity, const SizedBox(height: 18), credits],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 20),
              credits,
            ],
          );
        },
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$nickname 프로필',
      child: Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: Text(
          nickname.characters.first,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}

class _CreditBadge extends StatelessWidget {
  const _CreditBadge({this.count});

  /// 남은 크레딧 (생성 1회 = 1크레딧). null이면 세션 로딩 중.
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primaryPurple,
            size: 20,
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '남은 AI 피팅',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              Text(
                count == null ? '—' : '$count회',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 1, indent: 62),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 58,
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primaryNavy),
      title: Text(label),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge != null)
                Text(
                  badge!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.secondaryText,
              ),
            ],
          ),
    );
  }
}
