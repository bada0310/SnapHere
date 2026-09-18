import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';

final photoMarkerIconProvider = FutureProvider.autoDispose
    .family<BitmapDescriptor, String>((ref, url) async {
      // 교체할 때마다 같은 썸네일을 다운로드·변환하지 않는다.
      final link = ref.keepAlive();
      final expiry = Timer(const Duration(minutes: 1), link.close);
      ref.onDispose(expiry.cancel);
      return photoMarkerIcon(ResizeImage(NetworkImage(url), width: 180));
    });

/// 공개 썸네일을 60×68 논리 픽셀의 사진 말풍선으로 만든다.
Future<BitmapDescriptor> photoMarkerIcon(ImageProvider image) async {
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
  const rect = Rect.fromLTWH(3, 3, 54, 54);
  final frame = RRect.fromRectAndRadius(rect, const Radius.circular(10));
  final pointer = Path()
    ..moveTo(24, 55)
    ..lineTo(30, 65)
    ..lineTo(36, 55)
    ..close();
  canvas.drawPath(pointer, Paint()..color = AppColors.brand);
  canvas.drawRRect(frame, Paint()..color = AppColors.brandSubtle);
  canvas.save();
  canvas.clipRRect(frame);
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
    canvas.drawRect(const Rect.fromLTWH(16, 18, 28, 24), paint);
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
  canvas.drawRRect(
    frame,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );
  canvas.drawRRect(
    frame,
    Paint()
      ..color = AppColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  final picture = recorder.endRecording();
  final raster = await picture.toImage(180, 204);
  try {
    final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 60,
      height: 68,
    );
  } finally {
    info?.dispose();
    raster.dispose();
    picture.dispose();
  }
}
