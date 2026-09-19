import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/auth/presentation/auth_ui.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _terms = false;
  bool _privacy = false;
  String? _submissionError;

  bool get _all => _terms && _privacy;

  bool get _isNicknameValid {
    final nickname = _nicknameController.text.trim();
    return nickname.length >= 2 &&
        nickname.length <= 12 &&
        RegExp(r'^[가-힣A-Za-z0-9]+$').hasMatch(nickname);
  }

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_onNicknameChanged);
    final suggestedName = ref
        .read(authControllerProvider)
        .value
        ?.user
        ?.displayName;
    if (suggestedName != null &&
        suggestedName.length <= 12 &&
        RegExp(r'^[가-힣A-Za-z0-9]+$').hasMatch(suggestedName)) {
      _nicknameController.text = suggestedName;
    }
  }

  void _onNicknameChanged() => setState(() {});

  @override
  void dispose() {
    _nicknameController.removeListener(_onNicknameChanged);
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _setAll(bool value) {
    setState(() {
      _terms = value;
      _privacy = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final termsDocument = ref.watch(
      legalDocumentProvider(LegalDocumentType.terms),
    );
    final privacyDocument = ref.watch(
      legalDocumentProvider(LegalDocumentType.privacyConsent),
    );
    final documentsReady = termsDocument.hasValue && privacyDocument.hasValue;
    final canComplete =
        _isNicknameValid &&
        _terms &&
        _privacy &&
        documentsReady &&
        !auth.isLoading;
    final nicknameIsEmpty = _nicknameController.text.isEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AuthTopBar(
        title: '프로필 설정',
        onBack: () => ref.read(authControllerProvider.notifier).signOut(),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileAvatar(photoUrl: auth.value?.user?.photoUrl),
              const SizedBox(height: 28),
              const _FieldLabel('닉네임'),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                maxLength: 12,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.nickname],
                decoration: _inputDecoration('닉네임을 입력해 주세요').copyWith(
                  counterText: '',
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(
                      color: AuthColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nicknameIsEmpty || _isNicknameValid
                    ? '2~12자, 한글/영문/숫자'
                    : '닉네임 형식을 확인해 주세요',
                style: TextStyle(
                  color: nicknameIsEmpty || _isNicknameValid
                      ? AuthColors.primaryDark
                      : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('소개글 (선택)'),
              const SizedBox(height: 8),
              TextField(
                controller: _bioController,
                minLines: 4,
                maxLines: 4,
                maxLength: 160,
                decoration: _inputDecoration('소개글을 입력해 주세요'),
              ),
              const SizedBox(height: 28),
              const Divider(height: 1, color: AuthColors.border),
              const SizedBox(height: 8),
              _ConsentRow(
                label: '전체 동의',
                value: _all,
                bold: true,
                onChanged: _setAll,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  children: [
                    _ConsentRow(
                      label: '[필수] 서비스 이용약관 동의',
                      value: _terms,
                      bold: true,
                      onChanged: (value) => setState(() => _terms = value),
                      onViewDetails: () => context.push('/legal/terms'),
                    ),
                    _ConsentRow(
                      label: '[필수] 개인정보 수집·이용 동의',
                      value: _privacy,
                      bold: true,
                      onChanged: (value) => setState(() => _privacy = value),
                      onViewDetails: () =>
                          context.push('/legal/privacy-consent'),
                    ),
                  ],
                ),
              ),
              if (!documentsReady) ...[
                const SizedBox(height: 8),
                const Text(
                  '약관 정보를 불러오는 중입니다.',
                  style: TextStyle(
                    color: AuthColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_submissionError != null || auth.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  _submissionError ?? auth.error.toString(),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              AuthPrimaryButton(
                label: auth.isLoading ? '저장 중...' : '완료',
                onPressed: canComplete
                    ? () => _submit(
                        termsDocument.requireValue,
                        privacyDocument.requireValue,
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Center(
                child: AuthTextLink(
                  label: '개인정보 처리방침',
                  onTap: () => context.push('/legal/privacy-policy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(LegalDocument terms, LegalDocument privacy) {
    final bio = _bioController.text.trim();
    setState(() => _submissionError = null);
    return ref
        .read(authControllerProvider.notifier)
        .completeProfile(
          ProfileSubmission(
            nickname: _nicknameController.text.trim(),
            bio: bio.isEmpty ? null : bio,
            consents: ConsentRecord(
              termsVersion: terms.version,
              privacyVersion: privacy.version,
              marketingVersion: null,
              marketingAccepted: false,
              acceptedAt: DateTime.now().toUtc(),
            ),
          ),
        )
        .catchError((Object error) {
          if (mounted) {
            setState(() => _submissionError = error.toString());
          }
        });
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      // Form fields must not inherit the app search bar's fixed 38px height.
      constraints: const BoxConstraints(),
      contentPadding: const EdgeInsets.all(16),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: AuthColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: AuthColors.primary, width: 1.5),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.photoUrl});
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final image = photoUrl == null ? null : NetworkImage(photoUrl!);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: CircleAvatar(
          radius: 55,
          backgroundColor: AuthColors.canvas,
          backgroundImage: image,
          child: image == null
              ? const Icon(
                  Icons.person_outline,
                  size: 42,
                  color: AuthColors.iconMuted,
                )
              : null,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AuthColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.bold = false,
    this.onViewDetails,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool bold;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            activeColor: AuthColors.primary,
            checkColor: Colors.white,
            side: const BorderSide(color: AuthColors.border, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  label,
                  style: TextStyle(
                    color: AuthColors.textPrimary,
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          if (onViewDetails != null)
            TextButton(
              onPressed: onViewDetails,
              child: const Text(
                '보기',
                style: TextStyle(
                  color: AuthColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
