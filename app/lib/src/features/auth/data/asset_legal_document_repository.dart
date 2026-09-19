import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/auth/domain/auth_repository.dart';

/// Loads the legal text displayed in the app from reviewed bundled documents.
class AssetLegalDocumentRepository implements LegalDocumentRepository {
  AssetLegalDocumentRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const privacyPolicyAsset = 'assets/legal/privacy-policy.ko.md';
  static const privacyConsentAsset = 'assets/legal/privacy-consent.ko.md';
  static const termsAsset = 'assets/legal/terms-of-service.ko.md';

  final AssetBundle _bundle;

  @override
  Future<LegalDocument> fetch(LegalDocumentType type) async {
    final assetPath = switch (type) {
      LegalDocumentType.terms => termsAsset,
      LegalDocumentType.privacyConsent => privacyConsentAsset,
      LegalDocumentType.privacyPolicy => privacyPolicyAsset,
    };
    return parseDocument(type, await _bundle.loadString(assetPath));
  }

  static LegalDocument parseDocument(LegalDocumentType type, String source) {
    String? title;
    String? version;
    DateTime? effectiveDate;
    String? sectionHeading;
    final sectionLines = <String>[];
    final sections = <LegalSection>[];

    void addSection() {
      final body = sectionLines.join('\n').trim();
      if (body.isNotEmpty) {
        sections.add(LegalSection(heading: sectionHeading ?? '안내', body: body));
      }
      sectionLines.clear();
    }

    for (final line in const LineSplitter().convert(source)) {
      if (line.startsWith('# ')) {
        title = line.substring(2).trim();
      } else if (line.startsWith('버전:')) {
        version = line.substring('버전:'.length).trim();
      } else if (line.startsWith('시행일:')) {
        effectiveDate = DateTime.tryParse(line.substring('시행일:'.length).trim());
      } else if (line.startsWith('## ')) {
        addSection();
        sectionHeading = line.substring(3).trim();
      } else {
        sectionLines.add(line);
      }
    }
    addSection();

    if (title == null ||
        title.isEmpty ||
        version == null ||
        version.isEmpty ||
        effectiveDate == null ||
        sections.isEmpty) {
      throw const FormatException('법적 문서의 제목, 버전, 시행일 또는 본문이 없습니다.');
    }
    return LegalDocument(
      type: type,
      title: title,
      version: version,
      effectiveDate: effectiveDate,
      sections: sections,
    );
  }
}
