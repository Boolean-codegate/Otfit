import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

/// 게시물/댓글 신고 시트 — 사유 선택, '기타'는 직접 입력.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetType, // post | comment
  required String targetId,
  String title = '신고하기',
}) async {
  const reasons = [
    ('inappropriate', '부적절한 콘텐츠 (선정성·폭력 등)'),
    ('spam', '스팸 · 광고'),
    ('copyright', '저작권 침해 · 타인 사진 도용'),
    ('other', '기타 (직접 입력)'),
  ];
  var selected = 'inappropriate';
  final detailController = TextEditingController();
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '신고 사유를 선택해 주세요. 검토 후 조치돼요.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) =>
                  setSheetState(() => selected = value ?? selected),
              child: Column(
                children: [
                  for (final (value, label) in reasons)
                    RadioListTile<String>(
                      value: value,
                      title: Text(label),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            if (selected == 'other')
              TextField(
                controller: detailController,
                maxLength: 300,
                maxLines: 2,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '신고 사유를 적어주세요',
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: const Text('신고하기'),
            ),
          ],
        ),
      ),
    ),
  );
  if (submitted != true || !context.mounted) return;
  try {
    await ref.read(postRepositoryProvider).report(
          targetType: targetType,
          targetId: targetId,
          reason: selected,
          detail: selected == 'other' && detailController.text.trim().isNotEmpty
              ? detailController.text.trim()
              : null,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고가 접수되었어요. 검토 후 조치할게요.')),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('신고 실패: $error')));
    }
  }
}
