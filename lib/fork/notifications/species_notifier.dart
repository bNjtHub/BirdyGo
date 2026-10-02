/// « New species » notifications (J6h): while the app is in the background
/// (screen off), one local notification per species, the first time it is
/// heard reliably (Sûr or Probable) in the current listening session.
///
/// Tapping a notification brings the app back on the live screen, which is
/// still the top route: the listening never left it (J2b foreground service).
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/announcements/geo_commonness_provider.dart';
import '../../features/explore/explore_providers.dart';
import '../../features/live/live_session.dart';
import '../../shared/providers/settings_providers.dart';
import '../design/species_accents.dart';
import '../reliability/geo_presence_service.dart';
import '../settings/fork_prefs.dart';
import '../reliability/reliability_config.dart';
import 'notification_images.dart';
import 'notification_images_config.dart';
import 'notifications_gateway.dart';

/// First id of the species notifications; the group summary takes the id
/// just below.
const int kSpeciesNotificationBaseId = 200000;
const int _summaryId = kSpeciesNotificationBaseId - 1;

/// Localized texts, built by the live screen from AppLocalizations.
class SpeciesNotifierStrings {
  const SpeciesNotifierStrings({
    required this.channelName,
    required this.channelDescription,
    required this.body,
    required this.summaryTitle,
  });

  final String channelName;
  final String channelDescription;

  /// « Entendu à 7:38 · Sûr », with « · Rare ici » when [rare].
  final String Function(DateTime heardAt, ReliabilityLevel level, bool rare)
  body;

  /// « 3 nouvelles espèces ».
  final String Function(int count) summaryTitle;
}

class SpeciesNotifier {
  SpeciesNotifier({
    required NotificationsGateway gateway,
    bool Function()? isBackground,
    NotificationImageLoader? imageLoader,
    this.imageTimeout = kNotificationImageTimeout,
  }) : _gateway = gateway,
       _isBackground = isBackground ?? _appNotResumed,
       _imageLoader = imageLoader ?? _defaultImageLoader;

  final NotificationsGateway _gateway;
  final bool Function() _isBackground;
  final NotificationImageLoader _imageLoader;

  /// Longest wait for the images of one notification.
  final Duration imageTimeout;

  /// Images already prepared (or being prepared) this session, per species.
  final Map<String, Future<NotificationImages?>> _images = {};

  static Future<NotificationImages?> _defaultImageLoader(
    String scientificName,
    String? photoAsset,
  ) => loadNotificationImages(
    scientificName,
    photoAsset,
    tint: SpeciesAccents.tintOf(scientificName),
  );

  /// Images of a species within [imageTimeout], else null: the notification
  /// is then posted without image.
  Future<NotificationImages?> _imagesFor(String name, String? photo) async {
    final pending = _images.putIfAbsent(name, () => _imageLoader(name, photo));
    try {
      return await pending.timeout(imageTimeout);
    } catch (_) {
      return null;
    }
  }

  String? _sessionId;
  final Set<String> _seen = {};
  final List<int> _posted = [];

  static bool _appNotResumed() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state != null && state != AppLifecycleState.resumed;
  }

  /// Asks the notification permission (when the switch is turned on).
  Future<bool> requestPermission() => _gateway.requestPermission();

  /// Looks at the session's [detections]. [presenceOf] gives the geo-model's
  /// opinion for a species; [nameOf] its localized common name.
  Future<void> onDetections({
    required String sessionId,
    required List<DetectionRecord> detections,
    required bool enabled,
    required GeoPresence? Function(String scientificName) presenceOf,
    required String Function(DetectionRecord detection) nameOf,
    required SpeciesNotifierStrings strings,
    String? Function(String scientificName)? photoAssetOf,
  }) async {
    if (sessionId != _sessionId) {
      // New session: forget the old one and clear its notifications.
      final old = List<int>.of(_posted);
      _sessionId = sessionId;
      _seen.clear();
      _images.clear();
      _posted.clear();
      if (old.isNotEmpty) await _gateway.cancel([...old, _summaryId]);
    }
    for (final record in detections) {
      final name = record.scientificName;
      if (record.isUnknown || _seen.contains(name)) continue;
      final presence = presenceOf(name);
      final level = reliabilityFor(
        score: record.confidence,
        review: record.reviewStatus,
        presence: presence,
      );
      if (level == ReliabilityLevel.toCheck) continue;
      // Heard reliably: it is no longer new, in the foreground as well.
      _seen.add(name);
      if (!enabled || !_isBackground()) continue;
      final id = kSpeciesNotificationBaseId + _posted.length;
      _posted.add(id);
      final groupKey = 'birdygo_species_$sessionId';
      final images = await _imagesFor(name, photoAssetOf?.call(name));
      await _gateway.show(
        id: id,
        title: nameOf(record),
        body: strings.body(
          record.timestamp,
          level,
          presence?.unexpected ?? false,
        ),
        groupKey: groupKey,
        channelName: strings.channelName,
        channelDescription: strings.channelDescription,
        images: images,
      );
      if (_posted.length >= 2) {
        await _gateway.showSummary(
          id: _summaryId,
          title: strings.summaryTitle(_posted.length),
          body: '',
          groupKey: groupKey,
          channelName: strings.channelName,
          channelDescription: strings.channelDescription,
        );
      }
    }
  }
}

final speciesNotifierProvider = Provider<SpeciesNotifier>(
  (ref) => SpeciesNotifier(gateway: LocalNotificationsGateway()),
);

/// Clock time of a notification: « 7:41 » (24 h) for locales that use it,
/// « 7:41 PM » for locales whose default is 12 h (English) unless the
/// platform asks for 24 h ([alwaysUse24Hour], default: the platform setting).
String notificationTime(
  DateTime time,
  String localeName, {
  bool? alwaysUse24Hour,
}) {
  final use24 =
      alwaysUse24Hour ??
      PlatformDispatcher.instance.alwaysUse24HourFormat;
  final twelveHourLocale = DateFormat.jm(localeName).pattern!.contains('a');
  return twelveHourLocale && !use24
      ? DateFormat.jm(localeName).format(time)
      : DateFormat('H:mm', localeName).format(time);
}

/// Strings of the notifications from the app's localizations.
SpeciesNotifierStrings speciesNotifierStrings(
  AppLocalizations l10n, {
  bool? alwaysUse24Hour,
}) => SpeciesNotifierStrings(
      channelName: l10n.forkNewSpeciesChannel,
      channelDescription: l10n.forkNewSpeciesChannelDesc,
      body: (heardAt, level, rare) {
        final time = notificationTime(
          heardAt,
          l10n.localeName,
          alwaysUse24Hour: alwaysUse24Hour,
        );
        final label =
            level == ReliabilityLevel.sure
                ? l10n.forkLevelSure
                : l10n.forkLevelProbable;
        return rare
            ? l10n.forkNewSpeciesBodyRare(time, label)
            : l10n.forkNewSpeciesBody(time, label);
      },
      summaryTitle: l10n.forkNewSpeciesSummary,
    );

/// Feeds the notifier from the live screen after each controller update.
Future<void> notifyNewSpecies(
  WidgetRef ref,
  AppLocalizations l10n,
  LiveSession? session,
  List<DetectionRecord> detections,
) async {
  if (session == null || session.practice) return;
  final commonness = ref.read(geoCommonnessProvider).value;
  final taxonomy = ref.read(taxonomyServiceProvider).value;
  final locale = ref.read(effectiveSpeciesLocaleProvider);
  await ref
      .read(speciesNotifierProvider)
      .onDetections(
        sessionId: session.id,
        detections: detections,
        enabled: ref.read(newSpeciesNotifProvider),
        presenceOf: (name) => livePresence(commonness, name),
        nameOf:
            (d) =>
                taxonomy
                    ?.lookup(d.scientificName)
                    ?.commonNameForLocale(locale) ??
                d.commonName,
        strings: speciesNotifierStrings(l10n),
        photoAssetOf: (name) => taxonomy?.assetImagePath(name),
      );
}
