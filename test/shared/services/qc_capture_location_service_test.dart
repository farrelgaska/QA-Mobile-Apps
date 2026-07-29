import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/shared/services/qc_capture_location_service.dart';

class _FakeGeolocationClient implements QCCaptureGeolocationClient {
  bool serviceEnabled = true;
  LocationPermission checkedPermission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  QCCapturePosition? cachedPosition;
  QCCapturePosition? freshPosition;
  Future<QCCapturePosition> Function()? freshPositionHandler;
  LocationSettings? receivedSettings;
  int serviceChecks = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int cachedPositionRequests = 0;
  int freshPositionRequests = 0;

  @override
  Future<LocationPermission> checkPermission() async {
    permissionChecks++;
    return checkedPermission;
  }

  @override
  Future<QCCapturePosition> getCurrentPosition({
    required LocationSettings locationSettings,
  }) {
    freshPositionRequests++;
    receivedSettings = locationSettings;
    final handler = freshPositionHandler;
    if (handler != null) return handler();
    return Future.value(freshPosition);
  }

  @override
  Future<QCCapturePosition?> getLastKnownPosition() async {
    cachedPositionRequests++;
    return cachedPosition;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    serviceChecks++;
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestedPermission;
  }
}

void main() {
  final referenceTime = DateTime(2026, 7, 29, 10, 30);

  test(
    'recent cached location succeeds without requesting a fresh position',
    () async {
      final client = _FakeGeolocationClient()
        ..cachedPosition = QCCapturePosition(
          latitude: -6.2088,
          longitude: 106.8456,
          accuracyMeters: 8,
          timestamp: referenceTime.subtract(const Duration(seconds: 60)),
        );
      final service = GeolocatorQCCaptureLocationService(
        client: client,
        clock: () => referenceTime,
      );

      final result = await service.captureLocation();

      expect(result.isAvailable, isTrue);
      expect(result.latitude, -6.2088);
      expect(result.longitude, 106.8456);
      expect(result.accuracyMeters, 8);
      expect(result.failure, isNull);
      expect(client.cachedPositionRequests, 1);
      expect(client.freshPositionRequests, 0);
    },
  );

  test('stale cache requests a fresh high-accuracy position', () async {
    final client = _FakeGeolocationClient()
      ..cachedPosition = QCCapturePosition(
        latitude: -6.2,
        longitude: 106.8,
        accuracyMeters: 20,
        timestamp: referenceTime.subtract(const Duration(seconds: 61)),
      )
      ..freshPosition = QCCapturePosition(
        latitude: -6.2088,
        longitude: 106.8456,
        accuracyMeters: 3.25,
        timestamp: referenceTime,
      );
    final service = GeolocatorQCCaptureLocationService(
      client: client,
      clock: () => referenceTime,
    );

    final result = await service.captureLocation();

    expect(result.isAvailable, isTrue);
    expect(result.accuracyMeters, 3.25);
    expect(client.freshPositionRequests, 1);
    expect(client.receivedSettings?.accuracy, LocationAccuracy.high);
    expect(
      client.receivedSettings?.timeLimit,
      GeolocatorQCCaptureLocationService.locationTimeout,
    );
    expect(
      GeolocatorQCCaptureLocationService.locationTimeout,
      const Duration(seconds: 8),
    );
  });

  test('fresh location timeout returns the timeout failure reason', () async {
    final pendingPosition = Completer<QCCapturePosition>();
    final client = _FakeGeolocationClient()
      ..freshPositionHandler = () => pendingPosition.future;
    final service = GeolocatorQCCaptureLocationService(
      client: client,
      clock: () => referenceTime,
      timeout: const Duration(milliseconds: 10),
    );

    final result = await service.captureLocation();

    expect(result.isAvailable, isFalse);
    expect(result.failure, QCCaptureLocationFailure.timeout);
    expect(client.freshPositionRequests, 1);
  });

  test('denied permission returns without requesting a position', () async {
    final client = _FakeGeolocationClient()
      ..checkedPermission = LocationPermission.denied
      ..requestedPermission = LocationPermission.denied;
    final service = GeolocatorQCCaptureLocationService(
      client: client,
      clock: () => referenceTime,
    );

    final result = await service.captureLocation();

    expect(result.failure, QCCaptureLocationFailure.permissionDenied);
    expect(client.permissionChecks, 1);
    expect(client.permissionRequests, 1);
    expect(client.cachedPositionRequests, 0);
    expect(client.freshPositionRequests, 0);
  });

  test(
    'disabled location service returns before checking permission',
    () async {
      final client = _FakeGeolocationClient()..serviceEnabled = false;
      final service = GeolocatorQCCaptureLocationService(
        client: client,
        clock: () => referenceTime,
      );

      final result = await service.captureLocation();

      expect(result.failure, QCCaptureLocationFailure.serviceDisabled);
      expect(client.serviceChecks, 1);
      expect(client.permissionChecks, 0);
      expect(client.permissionRequests, 0);
      expect(client.cachedPositionRequests, 0);
      expect(client.freshPositionRequests, 0);
    },
  );
}
