import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';

final photoMarkerIconProvider = FutureProvider.autoDispose
    .family<
      BitmapDescriptor,
      ({String url, int count, bool countIsLowerBound})
    >((ref, args) async {
      final link = ref.keepAlive();
      final expiry = Timer(const Duration(minutes: 1), link.close);
      ref.onDispose(expiry.cancel);
      return photoMarkerIcon(
        ResizeImage(NetworkImage(args.url), width: 180),
        args.count,
        args.countIsLowerBound,
      );
    });

/// 공개 대표 썸네일과 클러스터 수를 하나의 60×60 원형 비트맵으로 만든다.
Future<BitmapDescriptor> photoMarkerIcon(
  ImageProvider image, [
  int count = 1,
  bool countIsLowerBound = false,
]) async {
  ImageInfo? info;
  final stream = image.resolve(ImageConfiguration.empty);
  final loaded = Completer<ImageInfo>();
  final listener = ImageStreamListener(
    (value, _) {
      if (!loaded.isCompleted) {
        loaded.complete(value);
      } else {
        value.dispose();
      }
    },
    onError: (Object error, StackTrace? stack) {
      if (!loaded.isCompleted) loaded.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  try {
    info = await loaded.future.timeout(const Duration(seconds: 8));
  } on Object {
    // 이미지 오류여도 사진 자리를 표시하고 게시글 탭은 유지한다.
  } finally {
    stream.removeListener(listener);
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(3);
  const rect = Rect.fromLTWH(4, 4, 52, 52);
  canvas.drawOval(rect, Paint()..color = AppColors.brandSubtle);
  canvas.save();
  canvas.clipPath(Path()..addOval(rect));
  if (info != null) {
    paintImage(
      canvas: canvas,
      rect: rect,
      image: info.image,
      fit: BoxFit.cover,
    );
  } else {
    final paint = Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(const Rect.fromLTWH(16, 18, 28, 22), paint);
    canvas.drawPath(
      Path()
        ..moveTo(17, 38)
        ..lineTo(26, 28)
        ..lineTo(33, 35)
        ..lineTo(39, 30)
        ..lineTo(43, 36),
      paint,
    );
  }
  canvas.restore();
  canvas.drawOval(
    rect,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );
  canvas.drawOval(
    rect,
    Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  const badgeCenter = Offset(48, 12);
  canvas.drawCircle(badgeCenter, 11, Paint()..color = AppColors.brand);
  canvas.drawCircle(
    badgeCenter,
    11,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final label = countIsLowerBound
      ? '${count.clamp(1, 99)}+'
      : count > 99
      ? '99+'
      : '${count.clamp(1, 99)}';
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: Colors.white,
        fontSize: label.length > 2 ? 8 : 10,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    badgeCenter - Offset(painter.width / 2, painter.height / 2),
  );
  final picture = recorder.endRecording();
  final raster = await picture.toImage(180, 180);
  try {
    final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 60,
      height: 60,
    );
  } finally {
    info?.dispose();
    raster.dispose();
    picture.dispose();
  }
}
