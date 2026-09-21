import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/profile/application/profile_providers.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileSnapshotProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('프로필 편집'),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => NetworkErrorView(
          onRetry: () => ref.invalidate(profileSnapshotProvider),
        ),
        data: (data) {
          if (data == null) {
            return const EmptyStateView(title: '프로필을 불러오지 못했어요');
          }
          if (!_initialized) {
            _initialized = true;
            _nickname.text = data.nickname;
            _bio.text = data.bio ?? '';
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Center(child: ProfileAvatar(url: data.imageUrl, size: 88)),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _nickname,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  helperText: '2~12자, 한글·영문·숫자',
                  constraints: BoxConstraints(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _bio,
                minLines: 4,
                maxLines: 6,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: '소개글',
                  constraints: BoxConstraints(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '저장 중...' : '저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final nickname = _nickname.text.trim();
    if (nickname.length < 2 ||
        nickname.length > 12 ||
        !RegExp(r'^[가-힣A-Za-z0-9]+$').hasMatch(nickname)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('닉네임 형식을 확인해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final bio = _bio.text.trim();
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(nickname: nickname, bio: bio.isEmpty ? null : bio);
      ref.invalidate(profileSnapshotProvider);
      if (mounted) context.pop();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
