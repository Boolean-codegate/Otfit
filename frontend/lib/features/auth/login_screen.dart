import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../models/fitting_result.dart' show ApiException;
import '../../providers/app_providers.dart';

/// 로그인/회원가입 화면 (web-login-demo 이식, MVP: 이메일만).
/// 소셜 로그인은 MVP 범위 밖 — 백엔드 /auth/social과
/// AuthRepository.socialLogin은 유지되어 있어 이후 UI만 붙이면 된다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'test@otfit.app');
  final _passwordController = TextEditingController(text: 'test1234');
  final _nicknameController = TextEditingController();

  bool _isJoinMode = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _showError(Object error) => setState(() {
        _errorText = error is ApiException ? error.error.message : '$error';
      });

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
                    onSubmitted: (_) => _submitEmail(),
                    decoration: const InputDecoration(hintText: '8자 이상'),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _submitting ? null : _submitEmail,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isJoinMode ? '가입하고 10크레딧 받기' : '로그인'),
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

