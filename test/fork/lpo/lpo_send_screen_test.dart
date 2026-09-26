import 'package:birdnet_live/features/announcements/geo_commonness_provider.dart';
import 'package:birdnet_live/features/explore/explore_providers.dart';
import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/lpo/lpo_send_button.dart';
import 'package:birdnet_live/fork/lpo/lpo_send_screen.dart';
import 'package:birdnet_live/fork/reliability/geo_presence_service.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:birdnet_live/shared/services/taxonomy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Presence service that never runs the geo-model.
class _NoGeo extends GeoPresenceService {
  _NoGeo(super.ref);

  @override
  Future<GeoPresence?> presenceAt(
    String scientificName, {
    required double? latitude,
    required double? longitude,
    required DateTime time,
  }) async => null;
}

LiveSession _session() {
  final start = DateTime.utc(2026, 9, 26, 5, 12);
  Map<String, dynamic> det(String sci, int minute, [String? review]) => {
    'scientificName': sci,
    'commonName': sci,
    'confidence': 0.95,
    'timestamp': start.add(Duration(minutes: minute)).toIso8601String(),
    'detLat': 47.2101,
    'detLon': -1.5502,
    if (review != null) 'reviewStatus': review,
  };
  return LiveSession.fromJson({
    'id': 'bilan',
    'startTime': start.toIso8601String(),
    'detections': [
      det('Dendrocopos major', 14, 'confirmed'),
      det('Upupa epops', 20),
      det('Strix aluco', 25, 'rejected'),
      det('Bubo bubo', 30, 'confirmed'),
    ],
  });
}

void main() {
  late List<String> clipboard;

  setUp(() {
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geoCommonnessProvider.overrideWith((ref) async => null),
          currentLocationProvider.overrideWith((ref) async => null),
          taxonomyServiceProvider.overrideWith(
            (ref) async => TaxonomyService(),
          ),
          geoPresenceServiceProvider.overrideWith(_NoGeo.new),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the Bilan button opens the screen with confirmed birds only', (
    tester,
  ) async {
    await pump(tester, Scaffold(body: LpoSendButton(session: _session())));
    expect(find.text('Envoyer à Faune-France (LPO)'), findsOneWidget);
    expect(
      find.text('Seuls les oiseaux que tu confirmes partent à la LPO.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Envoyer à Faune-France (LPO)'));
    await tester.pumpAndSettle();

    expect(find.text('Envoyer à la LPO'), findsOneWidget);
    expect(find.text('Dendrocopos major'), findsWidgets);
    expect(find.text('Bubo bubo'), findsWidgets);
    expect(find.text('Upupa epops'), findsNothing);
    expect(find.text('Strix aluco'), findsNothing);
    expect(find.textContaining('2 détections de cette sortie'), findsOneWidget);
    expect(find.textContaining('mot de passe'), findsOneWidget);
  });

  testWidgets('nothing to send without a confirmed bird', (tester) async {
    final session = _session();
    await pump(
      tester,
      LpoSendScreen(
        session: session,
        detections: [
          for (final d in session.detections)
            if (!d.isConfirmed) d,
        ],
      ),
    );
    expect(find.textContaining('Aucun oiseau confirmé'), findsOneWidget);
    expect(find.text('Copier'), findsNothing);
  });

  testWidgets('the card appears after both questions, then copies', (
    tester,
  ) async {
    final session = _session();
    await pump(
      tester,
      LpoSendScreen(session: session, detections: [session.detections.first]),
    );
    expect(find.text('Copier'), findsNothing);

    await tester.tap(find.text('Non'));
    await tester.pump();
    expect(find.text('Copier'), findsNothing);

    // Not sure of the song: compare with xeno-canto first.
    await tester.tap(find.text('Pas sûr'));
    await tester.pump();
    expect(find.text('Copier'), findsNothing);
    await tester.tap(find.text("J'ai comparé, c'est bien lui"));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Copier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copier'));
    await tester.pumpAndSettle();
    expect(clipboard, hasLength(1));
    expect(clipboard.single, contains('Espèce : Dendrocopos major'));
    expect(clipboard.single, contains('Contact : entendu'));
    expect(
      clipboard.single,
      contains(
        'Contact auditif ; identification assistée par IA puis confirmée '
        "par l'observateur.",
      ),
    );
    // September: outside the Great Spotted Woodpecker's breeding period.
    expect(clipboard.single, isNot(contains('Code atlas')));
  });

  testWidgets('a sensitive species proposes to hide the data', (tester) async {
    final session = _session();
    await pump(
      tester,
      LpoSendScreen(session: session, detections: [session.detections.last]),
    );
    expect(find.textContaining('Espèce sensible'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
  });
}
