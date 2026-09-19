import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/features/auth/data/asset_legal_document_repository.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all published legal documents load without draft wording', () async {
    final repository = AssetLegalDocumentRepository();
    for (final type in LegalDocumentType.values) {
      final document = await repository.fetch(type);
      final body = document.sections.map((section) => section.body).join('\n');
      expect(document.title, isNotEmpty);
      expect(document.version, isNotEmpty);
      expect(document.sections, isNotEmpty);
      expect(body, isNot(contains('개발용')));
      expect(body, isNot(contains('출시 전 교체')));
    }
  });

  test('published privacy text matches the account retention policy', () async {
    final repository = AssetLegalDocumentRepository();
    final policy = await repository.fetch(LegalDocumentType.privacyPolicy);
    final consent = await repository.fetch(LegalDocumentType.privacyConsent);
    final policyBody = policy.sections
        .map((section) => section.body)
        .join('\n');
    final consentBody = consent.sections
        .map((section) => section.body)
        .join('\n');

    expect(policy.title, '개인정보처리방침');
    expect(policy.version, '2026-09-18');
    expect(policyBody, contains('팀 너구리즈'));
    expect(policyBody, contains('felinedorcus@gmail.com'));
    expect(policyBody, contains('30일'));
    expect(consentBody, contains('30일'));
  });
}
