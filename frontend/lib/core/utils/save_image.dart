import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// 피팅 이미지 저장 — 플랫폼별 최적 경로.
/// - 모바일(웹 포함): 공유 시트 → '이미지 저장' 선택 시 갤러리에 저장.
///   브라우저 공유 시트는 '사용자 탭 직후'에만 열 수 있어서, 바이트를 먼저
///   받아둔 뒤 버튼 탭 핸들러 안에서 곧바로 share를 호출한다.
/// - PC: 파일 저장 (다운로드 폴더 / 위치 선택)
Future<void> saveImageBytes(
  BuildContext context,
  Uint8List bytes,
  String filename,
) async {
  final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  if (!isMobile) {
    await _saveAsFile(context, bytes, filename);
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('사진이 준비됐어요',
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              "공유 시트에서 '이미지 저장'을 누르면 갤러리에 저장돼요.",
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('갤러리에 저장 (공유)'),
              onPressed: () async {
                // 탭 제스처가 살아있는 동안 즉시 share 호출 (await 금지 구간)
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [
                        XFile.fromData(bytes,
                            name: filename, mimeType: 'image/jpeg'),
                      ],
                      fileNameOverrides: [filename],
                    ),
                  );
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                } on Object {
                  // 공유 미지원 → 파일 저장 폴백
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  if (context.mounted) {
                    await _saveAsFile(context, bytes, filename);
                  }
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: const Text('파일로 저장'),
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                if (context.mounted) {
                  await _saveAsFile(context, bytes, filename);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _saveAsFile(
  BuildContext context,
  Uint8List bytes,
  String filename,
) async {
  await FileSaver.instance.saveFile(
    name: filename.replaceAll('.jpg', ''),
    bytes: bytes,
    fileExtension: 'jpg',
    mimeType: MimeType.jpeg,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('사진을 저장했어요. 다운로드 폴더를 확인해 주세요.')),
    );
  }
}
