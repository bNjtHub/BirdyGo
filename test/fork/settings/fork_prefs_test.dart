import 'package:birdnet_live/fork/settings/fork_prefs.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('first name: default null, trimmed, cut, empty clears', () async {
    final c = await _container({});
    expect(c.read(firstNameProvider), isNull);
    await c.read(firstNameProvider.notifier).set('  Benjamin ');
    expect(c.read(firstNameProvider), 'Benjamin');
    await c.read(firstNameProvider.notifier).set('x' * 40);
    expect(c.read(firstNameProvider)!.length, kFirstNameMaxLength);
    await c.read(firstNameProvider.notifier).set('   ');
    expect(c.read(firstNameProvider), isNull);
    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.containsKey(kFirstNamePref), isFalse);
  });

  test('first name is read back from the preferences', () async {
    final c = await _container({kFirstNamePref: ' Lou '});
    expect(c.read(firstNameProvider), 'Lou');
  });

  test(
    'live theme: dark by default, persisted, unknown value falls back',
    () async {
      final c = await _container({});
      expect(c.read(liveThemeProvider), LiveTheme.dark);
      await c.read(liveThemeProvider.notifier).set(LiveTheme.light);
      expect(c.read(liveThemeProvider), LiveTheme.light);
      expect(
        c.read(sharedPreferencesProvider).getString(kLiveThemePref),
        'light',
      );
      final other = await _container({kLiveThemePref: 'nope'});
      expect(other.read(liveThemeProvider), LiveTheme.dark);
    },
  );
}
