import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum QCCaptureLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
}

class QCCaptureLocationResult {
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? locationLabel;
  final QCCaptureLocationFailure? failure;

  const QCCaptureLocationResult.available({
    required double this.latitude,
    required double this.longitude,
    required double this.accuracyMeters,
    this.locationLabel,
  }) : failure = null;

  const QCCaptureLocationResult.unavailable(this.failure)
    : latitude = null,
      longitude = null,
      accuracyMeters = null,
      locationLabel = null;

  bool get isAvailable =>
      latitude != null && longitude != null && accuracyMeters != null;
}

abstract class QCCaptureLocationService {
  Future<QCCaptureLocationResult> captureLocation();
}

class GeolocatorQCCaptureLocationService implements QCCaptureLocationService {
  static const Duration locationTimeout = Duration(seconds: 5);

  @override
  Future<QCCaptureLocationResult> captureLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const QCCaptureLocationResult.unavailable(
          QCCaptureLocationFailure.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const QCCaptureLocationResult.unavailable(
          QCCaptureLocationFailure.permissionDeniedForever,
        );
      }
      if (permission == LocationPermission.denied) {
        return const QCCaptureLocationResult.unavailable(
          QCCaptureLocationFailure.permissionDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: locationTimeout,
        ),
      );
      return QCCaptureLocationResult.available(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on TimeoutException {
      return const QCCaptureLocationResult.unavailable(
        QCCaptureLocationFailure.timeout,
      );
    } on LocationServiceDisabledException {
      return const QCCaptureLocationResult.unavailable(
        QCCaptureLocationFailure.serviceDisabled,
      );
    } on PermissionDeniedException {
      return const QCCaptureLocationResult.unavailable(
        QCCaptureLocationFailure.permissionDenied,
      );
    } catch (_) {
      return const QCCaptureLocationResult.unavailable(
        QCCaptureLocationFailure.unavailable,
      );
    }
  }
}
