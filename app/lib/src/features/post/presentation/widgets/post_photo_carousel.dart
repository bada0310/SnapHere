import 'package:flutter/material.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';

/// Figma `07_게시글_상세 / PhotoArea`. 최대 4장을 좌우로 넘기고 인디케이터를
/// 아래 가운데에 겹쳐 둔다 (PST-001, PST-002).
class PostPhotoCarousel extends StatefulWidget {
  const PostPhotoCarousel({required this.images, super.key});

  final List<PostImage> images;

  @override
  State<PostPhotoCarousel> createState() => _PostPhotoCarouselState();
}

class _PostPhotoCarouselState extends State<PostPhotoCarousel> {
  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const AspectRatio(aspectRatio: 1, child: RemoteImage());
    }

    // 대표 사진 비율로 높이를 잡는다. 장마다 비율이 달라도 캐러셀이 튀지 않는다.
    final ratio = widget.images.first.aspectRatio;
    return AspectRatio(
      aspectRatio: ratio <= 0 ? 1 : ratio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (_, index) =>
                RemoteImage(url: widget.images[index].imageUrl),
          ),
          if (widget.images.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _Indicator(count: widget.images.length, index: _index),
            ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++)
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == index ? AppColors.brand : Colors.white70,
          ),
        ),
    ],
  );
}
