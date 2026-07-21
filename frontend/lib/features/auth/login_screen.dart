import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../models/fitting_result.dart' show ApiException;
import '../../providers/app_providers.dart';

/// 로그인/회원가입 화면 (web-login-demo 이식).
/// 카카오/구글 버튼은 UI만 제공 (MVP는 이메일 로그인/가입만 동작).
/// 백엔드 /auth/social과 AuthRepository.socialLogin은 준비되어 있어
/// SDK 연동만 붙이면 소셜 로그인이 활성화된다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isJoinMode = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _showError(Object error) => setState(() {
        _errorText = error is ApiException ? error.error.message : '$error';
      });

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('$feature은 곧 제공될 예정이에요. 지금은 이메일로 이용해 주세요.')),
      );
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await action();
      if (mounted) context.go('/home');
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitEmail() {
    final auth = ref.read(authSessionProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isJoinMode) {
      if (password.length < 8) {
        _showError('비밀번호는 8자 이상이어야 해요.');
        return Future.value();
      }
      if (password != _passwordConfirmController.text) {
        _showError('비밀번호가 일치하지 않아요.');
        return Future.value();
      }
    }
    return _guard(() async {
      if (_isJoinMode) {
        final nickname = _nicknameController.text.trim();
        await auth.registerWithEmail(
          email: email,
          password: password,
          nickname: nickname.isEmpty ? '오핏유저' : nickname,
        );
      } else {
        await auth.loginWithEmail(email: email, password: password);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(width: 150, height: 48)),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '사진을 보정하다가, 사고 싶어진다',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SocialButton(
                    label: '카카오로 시작하기',
                    background: const Color(0xFFFEE500),
                    foreground: const Color(0xFF191919),
                    icon: Icons.chat_bubble,
                    onTap: _submitting
                        ? null
                        : () => _showComingSoon(context, '카카오 로그인'),
                  ),
                  const SizedBox(height: 10),
                  _SocialButton(
                    label: 'Google로 계속하기',
                    background: Colors.white,
                    foreground: const Color(0xFF3C4043),
                    icon: Icons.g_mobiledata,
                    outlined: true,
                    onTap: _submitting
                        ? null
                        : () => _showComingSoon(context, '구글 로그인'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.divider)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '또는 이메일로',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.disabled,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.divider)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isJoinMode) ...[
                    _FieldLabel('닉네임'),
                    TextField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(hintText: '닉네임'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _FieldLabel('이메일'),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      hintText: 'you@otfit.app',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FieldLabel('비밀번호'),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: _isJoinMode ? null : (_) => _submitEmail(),
                    decoration: const InputDecoration(hintText: '8자 이상'),
                  ),
                  if (_isJoinMode) ...[
                    const SizedBox(height: 12),
                    _FieldLabel('비밀번호 확인'),
                    TextField(
                      controller: _passwordConfirmController,
                      obscureText: true,
                      onSubmitted: (_) => _submitEmail(),
                      decoration:
                          const InputDecoration(hintText: '비밀번호를 한 번 더 입력'),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _submitting ? null : _submitEmail,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isJoinMode ? '가입하고 3크레딧 받기' : '로그인'),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        text: _isJoinMode ? '이미 계정이 있나요? ' : '아직 계정이 없나요? ',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryText,
                        ),
                        children: [
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isJoinMode = !_isJoinMode;
                                _errorText = null;
                              }),
                              child: Text(
                                _isJoinMode ? '로그인' : '회원가입',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: outlined
            ? const BorderSide(color: Color(0xFFDADCE0), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.secondaryText,
            ),
      ),
    );
  }
}

