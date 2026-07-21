import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../models/fitting_result.dart' show ApiException;
import '../../providers/app_providers.dart';

/// web-login-demo(index.html)를 Flutter로 이식한 로그인/회원가입 화면.
/// - 이메일 로그인·가입: 백엔드 /auth/login, /auth/register
/// - 카카오/구글: 키(KAKAO_JS_KEY/GOOGLE_CLIENT_ID dart-define) 미설정 시 안내만
/// - 개발자 도구: 소셜 SDK 토큰을 붙여넣어 /auth/social 검증 (데모와 동일)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'test@otfit.app');
  final _passwordController = TextEditingController(text: 'test1234');
  final _nicknameController = TextEditingController();
  final _rawTokenController = TextEditingController();

  bool _isJoinMode = false;
  bool _submitting = false;
  String? _errorText;
  String? _infoText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _rawTokenController.dispose();
    super.dispose();
  }

  void _showInfo(String text) =>
      setState(() {
        _infoText = text;
        _errorText = null;
      });

  void _showError(Object error) => setState(() {
        _errorText = error is ApiException ? error.error.message : '$error';
        _infoText = null;
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

  Future<void> _submitSocialToken(String provider) {
    final token = _rawTokenController.text.trim();
    if (token.isEmpty) {
      _showInfo('소셜 SDK에서 발급받은 토큰을 먼저 붙여넣어 주세요.');
      return Future<void>.value();
    }
    return _guard(() => ref
        .read(authSessionProvider.notifier)
        .loginWithSocial(provider: provider, token: token));
  }

  void _onSocialButton(String provider) {
    final hasKey = provider == 'kakao'
        ? AppConfig.kakaoJsKey.isNotEmpty
        : AppConfig.googleClientId.isNotEmpty;
    if (!hasKey) {
      _showInfo(
        provider == 'kakao'
            ? 'KAKAO_JS_KEY 미설정 — 키 발급 후 빌드에 넣으면 실제 카카오 로그인이 동작해요. (아래 개발자 도구로 토큰 테스트 가능)'
            : 'GOOGLE_CLIENT_ID 미설정 — 키 발급 후 빌드에 넣으면 실제 구글 로그인이 동작해요. (아래 개발자 도구로 토큰 테스트 가능)',
      );
      return;
    }
    // TODO: 키 확보 시 kakao/google JS SDK 연동 (웹 인터롭). 현재는 토큰 직접 테스트 지원.
    _showInfo('SDK 연동 준비 중 — 개발자 도구의 토큰 로그인으로 검증해 주세요.');
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
                    onTap: _submitting ? null : () => _onSocialButton('kakao'),
                  ),
                  const SizedBox(height: 10),
                  _SocialButton(
                    label: 'Google로 계속하기',
                    background: Colors.white,
                    foreground: const Color(0xFF3C4043),
                    icon: Icons.g_mobiledata,
                    outlined: true,
                    onTap: _submitting ? null : () => _onSocialButton('google'),
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
                                _infoText = null;
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
                  if (_errorText != null || _infoText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText ?? _infoText!,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: _errorText != null
                            ? AppColors.error
                            : AppColors.primaryPurple,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    title: Text(
                      '개발자 도구 — 소셜 토큰 직접 테스트',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.disabled,
                      ),
                    ),
                    children: [
                      TextField(
                        controller: _rawTokenController,
                        decoration: const InputDecoration(
                          hintText: '카카오 access_token 또는 구글 id_token 붙여넣기',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _submitting
                                  ? null
                                  : () => _submitSocialToken('kakao'),
                              child: const Text('카카오 토큰 로그인'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _submitting
                                  ? null
                                  : () => _submitSocialToken('google'),
                              child: const Text('구글 토큰 로그인'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
