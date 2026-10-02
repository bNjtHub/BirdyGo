/// GPS positions during a Live listening session.
///
/// Live used to store one position per session, taken at start (sometimes
/// stale or missing). While the listening runs, [LivePositionTracker] follows
/// the phone through a [LivePositionSource] and:
///
///   - tags each new detection with the last measured fix;
///   - keeps the measured track in [LiveSession.gpsTrack] (LPO accuracy,
///     HTML report map);
///   - replaces a missing or stale start position with the first fix.
///
/// It never asks for a permission: [LivePositionTracker.canTrack] only
/// checks the "Use GPS" setting, the location switch and an already granted
/// permission. Screen off, the Live foreground service (J2b) keeps the
/// position stream alive: its manifest type is `microphone|location`.
///
/// iOS: [GeolocatorLivePositionSource] works as is in the foreground; the
/// background needs `UIBackgroundModes: location` (fork/PLAN.md, Phase iOS).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/location_service.dart';
import '../../features/inference/models/detection.dart';
import '../../features/live/live_session.dart';
import '../../features/survey/survey_gps_tracker.dart';
import '../../shared/models/altitude_reference.dart';
import '../../shared/models/gps_point.dart';
import '../reliability/reliability_config.dart';

/// Where Live positions come from. One instance per session.
abstract class LivePositionSource {
  /// Latest accepted fix, or null before the first one.
  GpsPoint? get lastPoint;

  /// Distance covered along the accepted fixes, in meters.
  double get distanceMeters;

  /// Called for each accepted fix.
  set onPoint(void Function(GpsPoint point)? callback);

  Future<void> start();

  Future<void> stop();
}

/// Android (and later iOS) source on geolocator, through the Survey tracker
/// (jitter, speed and accuracy filters).
class GeolocatorLivePositionSource implements LivePositionSource {
  GeolocatorLivePositionSource()
    : _tracker = SurveyGpsTracker(
        intervalSeconds: ReliabilityConfig.liveGpsIntervalSeconds,
        distanceFilterMeters: ReliabilityConfig.liveGpsDistanceFilterMeters,
        maxAccuracyMeters: ReliabilityConfig.liveGpsMaxAccuracyMeters,
      );

  final SurveyGpsTracker _tracker;

  @override
  GpsPoint? get lastPoint => _tracker.lastPoint;

  @override
  double get distanceMeters => _tracker.distanceMeters;

  @override
  set onPoint(void Function(GpsPoint point)? callback) =>
      _tracker.onPoint = callback;

  @override
  Future<void> start() async {
    await _logApproximateLocation();
    await _tracker.startTracking();
  }

  @override
  Future<void> stop() => _tracker.stopTracking();

  /// Android "approximate location" gives fixes of about 2 km, all dropped
  /// by the accuracy filter: detections then keep the session position.
  static Future<void> _logApproximateLocation() async {
    try {
      final status = await Geolocator.getLocationAccuracy();
      if (status == LocationAccuracyStatus.reduced) {
        debugPrint(
          '[LivePosition] approximate location only: '
          'detections keep the session position',
        );
      }
    } catch (error) {
      debugPrint('[LivePosition] accuracy status unavailable: $error');
    }
  }
}

/// [LivePositionTracker.canTrack] on the app [LocationService]: "Use GPS"
/// on, location switched on, permission already granted. Never prompts
/// ([LocationService.hasPermission] only checks).
Future<bool> Function() liveTrackingGate(LocationService service) {
  return () async =>
      service.isGpsEnabled &&
      await service.isLocationServiceEnabled() &&
      await service.hasPermission();
}

/// Follows the phone during one Live session at a time.
class LivePositionTracker {
  LivePositionTracker({LivePositionSource Function()? createSource})
    : _createSource = createSource ?? GeolocatorLivePositionSource.new;

  final LivePositionSource Function() _createSource;

  /// True when positions may be followed now, without prompting: "Use GPS"
  /// on, location switched on, permission already granted. Null: never.
  Future<bool> Function()? canTrack;

  LiveSession? _session;
  LivePositionSource? _source;
  bool _replaceStartPosition = false;
  bool _running = false;
  int _generation = 0;

  /// The session being followed, or null.
  LiveSession? get session => _session;

  /// Whether a position source is currently started.
  bool get isRunning => _running;

  /// Start following [session]. Returns at once: the permission check and
  /// the first fix never delay the listening.
  ///
  /// [startPositionUncertain]: the session position is missing or came from
  /// the OS cache (stale). The first accurate fix then replaces it. A fresh
  /// start fix is kept: it is where the listening began.
  void begin(LiveSession session, {required bool startPositionUncertain}) {
    _stopSource();
    _session = session;
    _source = null;
    _replaceStartPosition = startPositionUncertain;
    unawaited(_start(++_generation));
  }

  /// Stop the position stream, keeping the session (pause).
  void pause() {
    _generation++;
    _stopSource();
  }

  /// Restart the stream after [pause].
  void resume() {
    if (_session == null || _running) return;
    unawaited(_start(++_generation));
  }

  /// Stop following the session (stop, dispose).
  void end() {
    _generation++;
    _stopSource();
    _session = null;
    _source = null;
    _replaceStartPosition = false;
  }

  /// Record for a new detection: the default Live record, plus the last
  /// measured position.
  ///
  /// Without any fix yet, the session position is used when it is trusted;
  /// when it is about to be replaced, the position stays empty so readers
  /// fall back to the corrected session position. Without tracking at all
  /// (GPS off, manual location, no permission, practice), the record is the
  /// one Live has always created: no position of its own.
  DetectionRecord createRecord(Detection detection, DateTime timestamp) {
    final session = _session;
    final point = _source?.lastPoint;
    double? latitude;
    double? longitude;
    double? altitude;
    double? altitudeAccuracy;
    AltitudeReference? altitudeReference;
    DateTime? locationFixTime;
    if (point != null) {
      latitude = point.latitude;
      longitude = point.longitude;
      altitude = point.altitude;
      altitudeAccuracy = point.altitudeAccuracy;
      altitudeReference = point.altitudeReference;
      locationFixTime = point.timestamp;
    } else if (session != null && _source != null && !_replaceStartPosition) {
      latitude = session.latitude;
      longitude = session.longitude;
      altitude = session.altitude;
      altitudeAccuracy = session.altitudeAccuracy;
      altitudeReference = session.altitudeReference;
      locationFixTime = session.locationFixTime;
    }
    return DetectionRecord(
      scientificName: detection.species.scientificName,
      commonName: detection.species.commonName,
      confidence: detection.confidence,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      altitudeAccuracy: altitudeAccuracy,
      altitudeReference: altitudeReference,
      locationFixTime: locationFixTime,
    );
  }

  Future<void> _start(int generation) async {
    final gate = canTrack;
    if (gate == null) return;
    var allowed = false;
    try {
      allowed = await gate();
    } catch (error) {
      debugPrint('[LivePosition] location check failed: $error');
    }
    if (!allowed || generation != _generation || _session == null) return;

    final source = _source ??= _createSource()..onPoint = _onPoint;
    _running = true;
    try {
      await source.start();
    } catch (error) {
      debugPrint('[LivePosition] start failed: $error');
      _running = false;
      return;
    }
    // Paused or stopped while starting.
    if (generation != _generation) {
      _running = false;
      unawaited(source.stop());
    }
  }

  void _stopSource() {
    final source = _source;
    if (source == null || !_running) return;
    _running = false;
    unawaited(source.stop());
  }

  void _onPoint(GpsPoint point) {
    final session = _session;
    final source = _source;
    if (session == null || source == null) return;
    session.gpsTrack.add(point);
    session.distanceMeters = source.distanceMeters;
    if (_replaceStartPosition) {
      _replaceStartPosition = false;
      session.latitude = point.latitude;
      session.longitude = point.longitude;
      session.altitude = point.altitude;
      session.altitudeAccuracy = point.altitudeAccuracy;
      session.altitudeReference = point.altitudeReference;
      session.locationFixTime = point.timestamp;
      debugPrint('[LivePosition] session position set from first fix');
    }
  }
}
