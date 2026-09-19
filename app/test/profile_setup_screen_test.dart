import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/data/asset_legal_document_repository.dart';
import 'package:snap_here/src/features/auth/data/session_store.dart';
import 'package:snap_here/src/features/auth/presentation/profile_setup_screen.dart';

void main() {
  testWidgets('bio keeps four visible lines under the app search field theme', (
    tester,
  ) async {
    await _pumpProfileSetup(tester);

    final bio = find.byType(TextField).last;
    final editableFinder = find.byType(EditableText).last;
    final editable = tester
        .state<EditableTextState>(editableFinder)
        .renderEditable;
    expect(
      editable.size.height,
      greaterThanOrEqualTo(editable.preferredLineHeight * 4),
    );
    expect(find.text('소개글을 입력해 주세요'), findsOneWidget);

    const text = '첫 번째 줄\n두 번째 줄\n세 번째 줄\n네 번째 줄';
    await tester.enterText(bio, text);
    await tester.pumpAndSettle();

    final counter = find.text('${text.length}/160');
    expect(counter, findsOneWidget);
    expect(
      tester.getRect(counter).top,
      greaterThan(tester.getRect(editableFinder).bottom),
    );
    expect(tester.widget<TextField>(bio).controller!.text, text);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bio remains reachable above the keyboard with larger text', (
    tester,
  ) async {
    await _pumpProfileSetup(tester, size: const Size(360, 640), textScale: 1.5);
    final bio = find.byType(TextField).last;
    await tester.ensureVisible(bio);
    await tester.enterText(bio, '여행 기록\n사진 이야기');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final editableFinder = find.byType(EditableText).last;
    await tester.ensureVisible(editableFinder);
    await tester.pumpAndSettle();
    final editable = tester
        .state<EditableTextState>(editableFinder)
        .renderEditable;
    final bounds = tester.getRect(editableFinder);
    expect(
      editable.size.height,
      greaterThanOrEqualTo(editable.preferredLineHeight * 4),
    );
    expect(bounds.top, greaterThanOrEqualTo(52));
    expect(bounds.bottom, lessThanOrEqualTo(340));
    expect(tester.widget<TextField>(bio).controller!.text, '여행 기록\n사진 이야기');
    expect(tester.takeException(), isNull);
  });

  testWidgets('bio keeps the existing 160 character limit and counter', (
    tester,
  ) async {
    await _pumpProfileSetup(tester);
    final bio = find.byType(TextField).last;
    await tester.enterText(bio, '가' * 161);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(bio).controller!.text, '가' * 160);
    expect(find.text('160/160'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpProfileSetup(
  WidgetTester tester, {
  Size size = const Size(412, 893),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(MemorySessionStore()),
        legalDocumentRepositoryProvider.overrideWithValue(
          AssetLegalDocumentRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ProfileSetupScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
