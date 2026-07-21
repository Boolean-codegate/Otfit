import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../models/social.dart';
import '../../providers/app_providers.dart';

/// 계정 검색 (계약 §12 GET /users/search) → 유저 피드로 이동.
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserSummary> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results =
          await ref.read(socialRepositoryProvider).searchUsers(query.trim());
      if (mounted) setState(() => _results = results);
    } on Object {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 검색')),
      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: const InputDecoration(
                    hintText: '닉네임으로 검색',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.trim().isEmpty
                              ? '닉네임을 입력해 친구를 찾아보세요'
                              : '검색 결과가 없어요',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.secondaryText),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.lightPurple,
                              child: Text(
                                user.nickname.characters.first,
                                style: const TextStyle(
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(user.nickname),
                            trailing:
                                const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/users/${user.id}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
