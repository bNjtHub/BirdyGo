import 'package:birdnet_live/features/live/live_session.dart';
import 'package:birdnet_live/fork/notifications/notifications_gateway.dart';
import 'package:birdnet_live/fork/notifications/species_notifier.dart';
import 'package:birdnet_live/fork/reliability/reliability_config.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements NotificationsGateway {
  final shown = <({int id, String title, String body})>[];
  final summaries = <String>[];
  final cancelled = <int>[];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    required String channelName,
    required String channelDescription,
  }) async => shown.add((id: id, title: title, body: body));

  @override
  Future<void> showSummary({
    required int id,
    required String title,
    required String body,
    required String groupKey,
    required String channelName,
    required String channelDescription,
  }) async => summaries.add(title);

  @override
  Future<void> cancel(Iterable<int> ids) async => cancelled.addAll(ids);
}

const _strings = SpeciesNotifierStrings(
  channelName: 'Nouvelles espèces',
  channelDescription: 'desc',
  body: _body,
  summaryTitle: _summary,
);

String _body(DateTime at, ReliabilityLevel level, bool rare) =>
    '${at.hour}:${at.minute} ${level.name}${rare ? ' rare' : ''}';
String _summary(int n) => '$n species';

DetectionRecord _det(String name, double score) => DetectionRecord(
  scientificName: name,
  commonName: 'Common $name',
  confidence: score,
  timestamp: DateTime(2026, 9, 29, 7, 38),
);

void main() {
  late _FakeGateway gateway;
  var background = true;
  late SpeciesNotifier notifier;

  setUp(() {
    gateway = _FakeGateway();
    background = true;
    notifier = SpeciesNotifier(
      gateway: gateway,
      isBackground: () => background,
    );
  });

  Future<void> feed(
    List<DetectionRecord> detections, {
    String session = 's1',
    bool enabled = true,
    GeoPresence? presence,
  }) => notifier.onDetections(
    sessionId: session,
    detections: detections,
    enabled: enabled,
    presenceOf: (_) => presence,
    nameOf: (d) => d.commonName,
    strings: _strings,
  );

  test('first reliable detection in background notifies once', () async {
    await feed([_det('Parus major', 0.9)]);
    expect(gateway.shown, hasLength(1));
    expect(gateway.shown.single.title, 'Common Parus major');
    expect(gateway.shown.single.body, '7:38 probable');
    await feed([_det('Parus major', 0.95)]);
    expect(gateway.shown, hasLength(1));
  });

  test('a second species adds a group summary', () async {
    await feed([_det('Parus major', 0.9), _det('Erithacus rubecula', 0.7)]);
    expect(gateway.shown, hasLength(2));
    expect(gateway.summaries, ['2 species']);
  });

  test('foreground does not notify, and the species is then known', () async {
    background = false;
    await feed([_det('Parus major', 0.9)]);
    expect(gateway.shown, isEmpty);
    background = true;
    await feed([_det('Parus major', 0.9)]);
    expect(gateway.shown, isEmpty);
  });

  test('a to-check detection does not notify, a later reliable one does', () async {
    await feed([_det('Parus major', 0.3)]);
    expect(gateway.shown, isEmpty);
    await feed([_det('Parus major', 0.7)]);
    expect(gateway.shown, hasLength(1));
  });

  test('an unexpected species is to check and does not notify', () async {
    await feed([
      _det('Parus major', 0.95),
    ], presence: const GeoPresence(unexpected: true));
    expect(gateway.shown, isEmpty);
  });

  test('sure with a plausible place says so', () async {
    await feed([
      _det('Parus major', 0.95),
    ], presence: const GeoPresence(unexpected: false));
    expect(gateway.shown.single.body, '7:38 sure');
  });

  test('switch off does not notify', () async {
    await feed([_det('Parus major', 0.9)], enabled: false);
    expect(gateway.shown, isEmpty);
  });

  test('a new session resets and clears the previous notifications', () async {
    await feed([_det('Parus major', 0.9)]);
    await feed([_det('Parus major', 0.9)], session: 's2');
    expect(gateway.shown, hasLength(2));
    expect(gateway.cancelled, contains(kSpeciesNotificationBaseId));
  });
}
