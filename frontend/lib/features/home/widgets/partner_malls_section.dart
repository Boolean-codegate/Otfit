import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

class PartnerMallsSection extends StatelessWidget {
  const PartnerMallsSection({super.key, required this.onViewAll});

  final VoidCallback onViewAll;

  // UI 확인을 위한 예시 브랜드이며 실제 제휴 관계를 의미하지 않습니다.
  static const _exampleMalls = <_MallData>[
    _MallData(name: 'MUSINSA', shortName: 'M'),
    _MallData(name: '29CM', shortName: '29'),
    _MallData(name: 'W CONCEPT', shortName: 'W'),
    _MallData(name: 'ABLY', shortName: 'A'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '인기 쇼핑몰',
          actionLabel: '전체보기',
          onAction: onViewAll,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 680) {
              return Row(
                children: [
                  for (
                    var index = 0;
                    index < _exampleMalls.length;
                    index++
                  ) ...[
                    Expanded(child: _MallCard(data: _exampleMalls[index])),
                    if (index != _exampleMalls.length - 1)
                      const SizedBox(width: 12),
                  ],
                ],
              );
            }

            return SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: _exampleMalls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 116,
                  child: _MallCard(data: _exampleMalls[index]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MallCard extends StatelessWidget {
  const _MallCard({required this.data});

  final _MallData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '${data.name} 예시 쇼핑몰 보기',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onViewMall(context),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lightPurple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    data.shortName,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.mainText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback onViewMall(BuildContext context) {
    return () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${data.name} 상품은 쇼핑 탭에서 확인해보세요.')),
      );
    };
  }
}

class _MallData {
  const _MallData({required this.name, required this.shortName});

  final String name;
  final String shortName;
}
