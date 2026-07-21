import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../models/fitting_result.dart' show ApiException, PhotoAnalysis;
import '../../providers/app_providers.dart';
import 'widgets/photo_analysis_card.dart';
import 'widgets/photo_consent_card.dart';
import 'widgets/photo_guide_card.dart';
import 'widgets/photo_upload_card.dart';
import 'widgets/selected_photo_preview.dart';

class PhotoSelectionScreen extends ConsumerStatefulWidget {
  const PhotoSelectionScreen({super.key});

  @override
  ConsumerState<PhotoSelectionScreen> createState() =>
      _PhotoSelectionScreenState();
}

class _PhotoSelectionScreenState extends ConsumerState<PhotoSelectionScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isPicking = false;
  bool _isAnalyzing = false;
  int _analysisRun = 0;

  @override
  void initState() {
    super.initState();
    final hasPhoto = ref.read(selectedUserPhotoProvider) != null;
    final hasConsent = ref.read(imageProcessingConsentProvider);
    final hasAnalysis = ref.read(lastPhotoAnalysisProvider) != null;
    if (hasPhoto && hasConsent && !hasAnalysis) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_analyzeSelectedPhoto());
      });
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isPicking || _isAnalyzing) return;

    setState(() => _isPicking = true);
    var shouldAnalyze = false;

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1800,
        // 셀피 피팅이 기본 시나리오 — 모바일 웹/앱 모두 전면 카메라 우선
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('Empty image');
      if (!mounted) return;

      final photo = SelectedUserPhoto(
        name: file.name,
        bytes: bytes,
        path: kIsWeb ? null : file.path,
      );
      ref.read(selectedUserPhotoProvider.notifier).setPhoto(photo);
      ref.read(lastPhotoAnalysisProvider.notifier).clear();
      shouldAnalyze = ref.read(imageProcessingConsentProvider);
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMessage(_pickerErrorMessage(error.code));
    } on Object {
      if (!mounted) return;
      _showMessage('사진을 불러오지 못했어요. 다른 사진으로 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }

    if (shouldAnalyze && mounted) await _analyzeSelectedPhoto();
  }

  Future<void> _analyzeSelectedPhoto() async {
    if (ref.read(selectedUserPhotoProvider) == null ||
        !ref.read(imageProcessingConsentProvider)) {
      return;
    }

    final currentRun = ++_analysisRun;
    setState(() => _isAnalyzing = true);
    ref.read(lastPhotoAnalysisProvider.notifier).clear();

    try {
      final repository = ref.read(tryOnRepositoryProvider);
      final selectedPhoto = ref.read(selectedUserPhotoProvider)!;
      final existingUpload = ref.read(uploadedPhotoProvider);
      var uploaded = existingUpload;
      uploaded ??= await repository.uploadPhoto(
        photo: selectedPhoto,
        consentImageProcessing: true,
      );
      if (!mounted || currentRun != _analysisRun) {
        if (existingUpload == null) {
          await repository.deletePhoto(uploaded.id);
        }
        return;
      }
      ref.read(uploadedPhotoProvider.notifier).setPhoto(uploaded);

      final analysis = await repository.analyzePhoto(uploaded.id);
      if (!mounted || currentRun != _analysisRun) return;
      ref.read(lastPhotoAnalysisProvider.notifier).setAnalysis(analysis);
      setState(() => _isAnalyzing = false);
    } on ApiException catch (error) {
      if (!mounted || currentRun != _analysisRun) return;
      setState(() => _isAnalyzing = false);
      _showMessage(error.error.message);
    } on Object {
      if (!mounted || currentRun != _analysisRun) return;
      setState(() => _isAnalyzing = false);
      _showMessage('사진 품질을 확인하지 못했어요. 다시 시도해주세요.');
    }
  }

  void _setConsent(bool isGranted) {
    ref.read(imageProcessingConsentProvider.notifier).setGranted(isGranted);

    if (!isGranted) {
      _analysisRun++;
      final uploaded = ref.read(uploadedPhotoProvider);
      ref.read(uploadedPhotoProvider.notifier).clear();
      if (uploaded != null) unawaited(_deleteUploadedPhoto(uploaded.id));
      ref.read(lastPhotoAnalysisProvider.notifier).clear();
      setState(() => _isAnalyzing = false);
      return;
    }

    if (ref.read(selectedUserPhotoProvider) != null) {
      unawaited(_analyzeSelectedPhoto());
    }
  }

  void _removePhoto() {
    _analysisRun++;
    ref.read(selectedUserPhotoProvider.notifier).clear();
    ref.read(lastPhotoAnalysisProvider.notifier).clear();
    setState(() => _isAnalyzing = false);
    _showMessage('선택한 사진을 삭제했어요.');
  }

  Future<void> _deleteUploadedPhoto(String photoId) async {
    try {
      await ref.read(tryOnRepositoryProvider).deletePhoto(photoId);
    } on Object {
      // Local state is cleared immediately; a real repository can retry.
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '사진 다시 선택',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (!mounted || source == null) return;
    await _pickPhoto(source);
  }

  void _usePhoto() {
    final hasPhoto = ref.read(selectedUserPhotoProvider) != null;
    final hasConsent = ref.read(imageProcessingConsentProvider);
    final analysis = ref.read(lastPhotoAnalysisProvider);
    if (!hasPhoto || !hasConsent || analysis?.isValid != true || _isAnalyzing) {
      _showMessage('사진 처리 동의와 품질 확인을 완료해주세요.');
      return;
    }
    context.go('/try-on');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _pickerErrorMessage(String code) {
    if (code.contains('camera_access_denied')) {
      return '카메라 권한이 필요해요. 기기 설정에서 권한을 허용해주세요.';
    }
    if (code.contains('photo_access_denied')) {
      return '사진 접근 권한이 필요해요. 기기 설정에서 권한을 허용해주세요.';
    }
    return '사진을 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  @override
  Widget build(BuildContext context) {
    final selectedPhoto = ref.watch(selectedUserPhotoProvider);
    final hasConsent = ref.watch(imageProcessingConsentProvider);
    final analysis = ref.watch(lastPhotoAnalysisProvider);
    final canUsePhoto =
        selectedPhoto != null &&
        hasConsent &&
        analysis?.isValid == true &&
        !_isAnalyzing &&
        !_isPicking;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const OTFITAppBar(title: '내 사진 선택'),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ResponsiveContent(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '정면에서 촬영한 밝은 사진일수록 결과가 좋아요.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.secondaryText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOut,
                  child: selectedPhoto == null
                      ? _EmptyPhotoLayout(
                          key: const ValueKey('empty-photo-layout'),
                          isPicking: _isPicking,
                          onPickGallery: () => _pickPhoto(ImageSource.gallery),
                          onTakePhoto: () => _pickPhoto(ImageSource.camera),
                        )
                      : _SelectedPhotoLayout(
                          key: const ValueKey('selected-photo-layout'),
                          photo: selectedPhoto,
                          hasConsent: hasConsent,
                          isAnalyzing: _isAnalyzing,
                          analysis: analysis,
                          onConsentChanged: _setConsent,
                          onRemove: _removePhoto,
                          onReselect: _showPhotoSourceSheet,
                        ),
                ),
                const SizedBox(height: 28),
                const PhotoGuideCard(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: selectedPhoto == null
          ? null
          : Material(
              color: AppColors.surface,
              elevation: 4,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: GradientPrimaryButton(
                        label: '이 사진 사용하기',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _usePhoto,
                        isLoading: _isAnalyzing,
                        isEnabled: canUsePhoto,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _EmptyPhotoLayout extends StatelessWidget {
  const _EmptyPhotoLayout({
    super.key,
    required this.isPicking,
    required this.onPickGallery,
    required this.onTakePhoto,
  });

  final bool isPicking;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: PhotoUploadCard(
          isPicking: isPicking,
          cameraAvailable: true,
          onPickGallery: onPickGallery,
          onTakePhoto: onTakePhoto,
        ),
      ),
    );
  }
}

class _SelectedPhotoLayout extends StatelessWidget {
  const _SelectedPhotoLayout({
    super.key,
    required this.photo,
    required this.hasConsent,
    required this.isAnalyzing,
    required this.analysis,
    required this.onConsentChanged,
    required this.onRemove,
    required this.onReselect,
  });

  final SelectedUserPhoto photo;
  final bool hasConsent;
  final bool isAnalyzing;
  final PhotoAnalysis? analysis;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onRemove;
  final VoidCallback onReselect;

  @override
  Widget build(BuildContext context) {
    final preview = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: SelectedPhotoPreview(
        bytes: photo.bytes,
        fileName: photo.name,
        onRemove: onRemove,
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhotoConsentCard(
          value: hasConsent,
          onChanged: onConsentChanged,
          enabled: !isAnalyzing,
        ),
        const SizedBox(height: 12),
        PhotoAnalysisCard(
          hasConsent: hasConsent,
          isAnalyzing: isAnalyzing,
          isValid: analysis?.isValid,
          rejectReason: analysis?.rejectReason,
          personCount: analysis?.personCount ?? 1,
          pose: analysis?.pose ?? 'front',
          brightness: analysis?.lighting.brightness ?? 0,
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: '다시 선택',
          icon: Icons.refresh_rounded,
          onPressed: onReselect,
          isEnabled: !isAnalyzing,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 820) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: preview),
              const SizedBox(width: 26),
              Expanded(flex: 6, child: details),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.center, child: preview),
            const SizedBox(height: 18),
            details,
          ],
        );
      },
    );
  }
}
