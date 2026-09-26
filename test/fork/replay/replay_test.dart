import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/features/live/widgets/detection_list_widget.dart';
import 'package:birdnet_live/fork/data/species_totals_provider.dart';
import 'package:birdnet_live/fork/replay/replay_button.dart';
import 'package:birdnet_live/fork/replay/replay_guard.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DetectionRecord _record(String sci, {String? clip, int minute = 0}) =>
    DetectionRecord(
      scientificName: sci,
      commonName: sci,
      confidence: 0.8,
      timestamp: DateTime(2026, 9, 26, 7, minute),
      audioClipPath: clip,
    );

void main() {
  group('ReplayGuard', () {
    test('no replay: nothing is skipped', () {
      final guard = ReplayGuard();
      expect(guard.overlaps(0, 96000), isFalse);
      expect(guard.isReplaying, isFalse);
    });

    test('an open replay skips every window that reaches past its start', () {
      final guard = ReplayGuard()..begin(100000);
      expect(guard.isReplaying, isTrue);
      expect(guard.overlaps(4000, 100000), isFalse); // ends exactly at start
      expect(guard.overlaps(10000, 106000), isTrue);
      expect(guard.overlaps(200000, 296000), isTrue);
    });

    test('a closed replay skips its range plus the tail, then stops', () {
      final guard =
          ReplayGuard()
            ..begin(100000)
            ..end(196000, paddingSamples: 16000); // 0.5 s at 32 kHz
      expect(guard.isReplaying, isFalse);
      expect(guard.overlaps(150000, 246000), isTrue);
      expect(guard.overlaps(200000, 296000), isTrue); // in the tail
      expect(guard.overlaps(212000, 308000), isFalse); // after the tail
      // Once passed, the range is forgotten.
      expect(guard.overlaps(100000, 196000), isFalse);
    });

    test('begin is idempotent while playing; reset forgets everything', () {
      final guard =
          ReplayGuard()
            ..begin(1000)
            ..begin(5000);
      expect(guard.overlaps(0, 2000), isTrue);
      guard.reset();
      expect(guard.overlaps(0, 2000), isFalse);
      expect(guard.isReplaying, isFalse);
    });
  });

  test('latestClipBySpecies keeps the newest clip of each species', () {
    final clips = latestClipBySpecies([
      _record('Erithacus rubecula', clip: '/c/new.flac', minute: 5),
      _record('Parus major', minute: 4),
      _record('Erithacus rubecula', clip: '/c/old.flac', minute: 1),
    ]);
    expect(clips, {'Erithacus rubecula': '/c/new.flac'});
  });

  test('liveTotals adds the running session to saved totals', () {
    expect(
      liveTotals(
        saved: {'Erithacus rubecula': 139, 'Strix aluco': 4},
        sessionCounts: {'Erithacus rubecula': 3, 'Upupa epops': 1},
      ),
      {'Erithacus rubecula': 142, 'Upupa epops': 1},
    );
  });

  testWidgets('a live row shows "×session · total" and the trailing button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DetectionList(
              detections: [_record('Erithacus rubecula')],
              isActive: true,
              speciesDetectionCounts: const {'Erithacus rubecula': 3},
              speciesTotalCounts: const {'Erithacus rubecula': 142},
              trailingBuilder:
                  (_) => const Icon(Icons.play_arrow, key: Key('replay')),
            ),
          ),
        ),
      ),
    );
    expect(find.text('×3 · 142'), findsOneWidget);
    expect(find.byKey(const Key('replay')), findsOneWidget);
  });
}
