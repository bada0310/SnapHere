import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/map/application/map_configuration.dart';

const koreaCamera = CameraPosition(target: LatLng(36.2, 127.7), zoom: 6.3);

class SnapMap extends ConsumerWidget {
  const SnapMap({
    this.markers = const {},
    this.onCreated,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.myLocationEnabled = false,
    this.initialCamera = koreaCamera,
    this.onCameraMove,
    this.onCameraIdle,
    super.key,
  });
  final Set<Marker> markers;
  final ValueChanged<GoogleMapController>? onCreated;
  final ValueChanged<LatLng>? onTap;
  final EdgeInsets padding;
  final bool myLocationEnabled;
  final CameraPosition initialCamera;

  /// 카메라가 움직이는 동안 줌을 추적할 때 쓴다.
  final ValueChanged<CameraPosition>? onCameraMove;

  /// 카메라가 멈췄을 때만 서버를 부른다 — 이동 중 호출은 낭비다.
  final VoidCallback? onCameraIdle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(mapConfiguredProvider)
      .when(
        loading: () => const ColoredBox(
          color: AppColors.brandSubtle,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const _MapUnavailable(),
        data: (configured) => !configured
            ? const _MapUnavailable()
            : GoogleMap(
                initialCameraPosition: initialCamera,
                markers: markers,
                onMapCreated: onCreated,
                onTap: onTap,
                onCameraMove: onCameraMove,
                onCameraIdle: onCameraIdle,
                padding: padding,
                myLocationEnabled: myLocationEnabled,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                minMaxZoomPreference: const MinMaxZoomPreference(4, 20),
                style:
                    '[{"featureType":"poi","stylers":[{"visibility":"off"}]},'
                    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#e9f8fb"}]}]',
              ),
      );
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.brandSubtle,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '지도를 표시하려면 Android·iOS 지도 키 설정이 필요해요.\n키 설정 후 앱을 다시 실행해 주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    ),
  );
}
