import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum QCCaptureLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  positionUnavailable,
  unexpectedError,
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

  const QCCaptureLocationResult.unavailable(
    QCCaptureLocationFailure this.failure,
  )   : latitude = null,
        longitude = null,
        accuracyMeters = null,
        locationLabel = null;

  bool get isAvailable =>
      latitude != null && longitude != null && accuracyMeters != null;
}

class QCCapturePosition {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime? timestamp;

  const QCCapturePosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  factory QCCapturePosition.fromGeolocator(Position position) =>
      QCCapturePosition(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
}

abstract class QCCaptureGeolocationClient {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<QCCapturePosition?> getLastKnownPosition();

  Future<QCCapturePosition> getCurrentPosition({
    required LocationSettings locationSettings,
  });
}

class GeolocatorQCCaptureGeolocationClient
    implements QCCaptureGeolocationClient {
  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<QCCapturePosition?> getLastKnownPosition() async {
    final position = await Geolocator.getLastKnownPosition();
    return position == null ? null : QCCapturePosition.fromGeolocator(position);
  }

  @override
  Future<QCCapturePosition> getCurrentPosition({
    required LocationSettings locationSettings,
  }) async =>
      QCCapturePosition.fromGeolocator(
        await Geolocator.getCurrentPosition(locationSettings: locationSettings),
      );
}

abstract class QCCaptureLocationService {
  Future<QCCaptureLocationResult> captureLocation();
}

class GeolocatorQCCaptureLocationService implements QCCaptureLocationService {
  static const Duration locationTimeout = Duration(seconds: 8);
  static const Duration maximumCachedPositionAge = Duration(seconds: 60);

  final QCCaptureGeolocationClient _client;
  final DateTime Function() _clock;
  final Duration _locationTimeout;
  final Duration _maximumCachedPositionAge;
  final bool _isWeb;

  GeolocatorQCCaptureLocationService({
    QCCaptureGeolocationClient? client,
    DateTime Function()? clock,
    Duration? timeout,
    Duration? maximumCachedAge,
    bool? isWeb,
  })  : _client = client ?? GeolocatorQCCaptureGeolocationClient(),
        _clock = clock ?? DateTime.now,
        _locationTimeout = timeout ?? locationTimeout,
        _maximumCachedPositionAge =
            maximumCachedAge ?? maximumCachedPositionAge,
        _isWeb = isWeb ?? kIsWeb;

  @override
  Future<QCCaptureLocationResult> captureLocation() async {
    try {
      if (!await _client.isLocationServiceEnabled()) {
        return _failure(
          QCCaptureLocationFailure.serviceDisabled,
          code: 'LOCATION_SERVICE_DISABLED',
          message: 'Location services are disabled.',
        );
      }

      var permission = await _client.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _client.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return _failure(
          QCCaptureLocationFailure.permissionDeniedForever,
          code: 'PERMISSION_DENIED_FOREVER',
          message: 'Location permission is permanently denied.',
        );
      }
      if (permission == LocationPermission.denied) {
        return _failure(
          QCCaptureLocationFailure.permissionDenied,
          code: 'PERMISSION_DENIED',
          message: 'Location permission was denied.',
        );
      }

      final cachedPosition = _isWeb ? null : await _recentCachedPosition();
      if (cachedPosition != null) {
        return _availablePosition(cachedPosition);
      }

      final position = await _client
          .getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: _locationTimeout,
            ),
          )
          .timeout(_locationTimeout);
      return _availablePosition(position);
    } on TimeoutException catch (error) {
      return _failure(
        QCCaptureLocationFailure.timeout,
        code: 'TIMEOUT',
        message: error.message ?? 'Location request timed out.',
      );
    } on LocationServiceDisabledException catch (error) {
      return _failure(
        QCCaptureLocationFailure.serviceDisabled,
        code: 'LOCATION_SERVICE_DISABLED',
        message: error.toString(),
      );
    } on PermissionDeniedException catch (error) {
      return _failure(
        QCCaptureLocationFailure.permissionDenied,
        code: 'PERMISSION_DENIED',
        message: error.toString(),
      );
    } on PositionUpdateException catch (error) {
      return _failure(
        QCCaptureLocationFailure.positionUnavailable,
        code: 'POSITION_UNAVAILABLE',
        message: error.message ?? 'The position is unavailable.',
      );
    } catch (error) {
      return _failure(
        QCCaptureLocationFailure.unexpectedError,
        code: error.runtimeType.toString(),
        message: error.toString(),
      );
    }
  }

  Future<QCCapturePosition?> _recentCachedPosition() async {
    try {
      final position = await _client.getLastKnownPosition();
      final timestamp = position?.timestamp;
      if (position == null || timestamp == null || !_isValid(position)) {
        return null;
      }
      final age = _clock().difference(timestamp);
      return !age.isNegative && age <= _maximumCachedPositionAge
          ? position
          : null;
    } catch (error) {
      _debugLog(code: 'CACHED_POSITION_UNAVAILABLE', message: error.toString());
      return null;
    }
  }

  QCCaptureLocationResult _availablePosition(QCCapturePosition position) {
    if (!_isValid(position)) {
      return _failure(
        QCCaptureLocationFailure.positionUnavailable,
        code: 'POSITION_UNAVAILABLE',
        message: 'The location provider returned an invalid position.',
      );
    }
    return QCCaptureLocationResult.available(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracyMeters,
    );
  }

  bool _isValid(QCCapturePosition position) =>
      position.latitude.isFinite &&
      position.latitude >= -90 &&
      position.latitude <= 90 &&
      position.longitude.isFinite &&
      position.longitude >= -180 &&
      position.longitude <= 180 &&
      position.accuracyMeters.isFinite &&
      position.accuracyMeters >= 0;

  QCCaptureLocationResult _failure(
    QCCaptureLocationFailure failure, {
    required String code,
    required String message,
  }) {
    _debugLog(code: code, message: message);
    return QCCaptureLocationResult.unavailable(failure);
  }

  void _debugLog({required String code, required String message}) {
    if (!kDebugMode) return;
    debugPrint('[QC_CAPTURE_LOCATION] code=$code message=$message');
  }
}
