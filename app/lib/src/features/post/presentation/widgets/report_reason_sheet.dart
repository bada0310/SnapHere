import 'package:flutter/material.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';

/// 게시글 신고 사유 (PST-043). 값은 백엔드 `CreateReportRequest`의 패턴과 같아야 한다.
enum ReportReason {
  inappropriate('INAPPROPRIATE', '부적절한 내용'),
  copyright('COPYRIGHT', '저작권 침해'),
  placeMismatch('PLACE_MISMATCH', '장소가 사진과 다름'),
  spam('SPAM', '스팸·광고'),
  other('OTHER', '기타');

  const ReportReason(this.code, this.label);

  final String code;
  final String label;
}

/// Missing States Audit의 `07 게시글 신고 — 사유 선택` 항목.
Future<ReportReason?> showReportReasonSheet(BuildContext context) =>
    showModalBottomSheet<ReportReason>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '신고 사유를 골라 주세요',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '신고 내용은 운영진만 확인합니다',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final reason in ReportReason.values)
              ListTile(
                title: Text(reason.label),
                onTap: () => Navigator.of(context).pop(reason),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
