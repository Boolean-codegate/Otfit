import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// 피팅 이미지 저장 — 플랫폼별 최적 경로.
/// - 모바일(웹 포함): 공유 시트 → '이미지 저장' 선택 시 갤러리에 저장
/// - PC: 브라우저 파일 저장 (다운로드 폴더 / 위치 선택)
Future<void> saveImageBytes(
  BuildContext context,
  Uint8List bytes,
  String filename,
) async {
  final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  if (isMobile) {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: filename, mimeType: 'image/jpeg')],
          fileNameOverrides: [filename],
        ),
      );
      if (result.status != ShareResultStatus.unavailable) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("공유 시트에서 '이미지 저장'을 누르면 갤러리에 저장돼요.")),
          );
        }
        return;
      }
    } on Object {
      // 공유 미지원 브라우저 → 파일 저장으로 폴백
    }
  }
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
