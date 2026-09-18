import 'package:flutter/material.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';

class RemoteImage extends StatelessWidget {
  const RemoteImage({
    this.url,
    this.avatar = false,
    this.fit = BoxFit.cover,
    super.key,
  });
  final String? url;
  final bool avatar;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.brandSubtle,
      child: Center(
        child: Icon(
          avatar ? Icons.person_outline : Icons.photo_outlined,
          color: AppColors.textSecondary,
          size: avatar ? 24 : 32,
        ),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(url!, fit: fit, errorBuilder: (_, _, _) => fallback);
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({this.url, this.size = 64, super.key});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipOval(child: RemoteImage(url: url, avatar: true)),
  );
}
