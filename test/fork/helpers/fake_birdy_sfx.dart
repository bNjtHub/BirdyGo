import 'package:birdnet_live/fork/sound/birdy_sfx.dart';

/// Records what the short-sound player is asked, plays nothing.
class FakeBirdySfx implements BirdySfx {
  final List<String> prepared = [];
  final List<String> played = [];

  @override
  Future<void> prepare(Iterable<String> assets) async =>
      prepared.addAll(assets);

  @override
  Future<void> play(String asset) async => played.add(asset);

  @override
  Future<void> dispose() async {}
}
