import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_theme.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/domain/auth_models.dart';
import 'package:snap_here/src/features/post/application/post_providers.dart';
import 'package:snap_here/src/features/post/data/fake_post_repository.dart';
import 'package:snap_here/src/features/post/presentation/comments_screen.dart';

class _MeAuth extends AuthController {
  @override
  Future<AuthSession?> build() async => const AuthSession.authenticated(
    accessToken: 'test',
    refreshToken: 'test',
    user: AuthUser(
      id: 'usr_me',
      email: 'me@example.test',
      nickname: '여행하는 너구리',
      needsProfileSetup: false,
    ),
  );
}

void main() {
  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 893));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const CommentsScreen(postId: 'pst_1'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_MeAuth.new),
          postRepositoryProvider.overrideWithValue(FakePostRepository()),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('스레드와 대댓글을 함께 보여준다', (tester) async {
    await mount(tester);
    expect(find.text('봄날 풍경이 정말 좋았어요!'), findsOneWidget);
    expect(find.text('한옥마을은 해질 무렵도 예뻐요.'), findsOneWidget);
    expect(find.text('해질 무렵도 꼭 가보세요!'), findsOneWidget);
  });

  testWidgets('댓글을 작성하면 목록에 붙는다', (tester) async {
    await mount(tester);
    await tester.enterText(find.byType(TextField), '사진이 정말 따뜻하게 담겼네요!');
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();
    expect(find.text('사진이 정말 따뜻하게 담겼네요!'), findsOneWidget);
  });

  testWidgets('답글 달기를 누르면 안내 줄과 취소가 뜬다', (tester) async {
    await mount(tester);
    await tester.tap(find.text('답글 달기').first);
    await tester.pumpAndSettle();
    expect(find.text('여행하는 너구리 (나)님에게 답글'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
  });

  testWidgets('답글 작성을 취소하면 새 댓글 상태로 돌아간다', (tester) async {
    await mount(tester);
    await tester.tap(find.text('답글 달기').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.textContaining('님에게 답글'), findsNothing);
  });

  testWidgets('내 댓글에만 관리 버튼이 있다', (tester) async {
    await mount(tester);
    // 내 댓글 1개(`여행하는 너구리 (나)`)에만 `⋯`가 붙는다.
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });

  testWidgets('관리 메뉴에서 수정을 고르면 입력창이 저장 모드가 된다', (tester) async {
    await mount(tester);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('댓글 관리'), findsOneWidget);

    await tester.tap(find.text('댓글 수정'));
    await tester.pumpAndSettle();
    expect(find.text('댓글 수정 중'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
  });

  testWidgets('댓글 삭제는 확인 대화상자를 거친다', (tester) async {
    await mount(tester);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('댓글 삭제'));
    await tester.pumpAndSettle();

    expect(find.text('댓글을 삭제할까요?'), findsOneWidget);
    expect(find.text('삭제한 댓글과 연결된 대댓글은 복구할 수 없습니다.'), findsOneWidget);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('봄날 풍경이 정말 좋았어요!'), findsNothing);
  });
}
