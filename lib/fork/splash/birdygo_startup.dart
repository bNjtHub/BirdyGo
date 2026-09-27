import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/birdy_theme.dart';
import 'birdygo_launch_handoff.dart';
import 'birdygo_splash.dart';
import 'birdygo_warm_up.dart';

/// Shows the splash while the app really loads: initialization
/// ([bootstrap]), then the heavy resources ([warmUp]), with App mounted
/// behind. Opens App once both are done and the splash has been up for
/// [BirdyGoSplash.minimumDisplay]; a slower start keeps the splash singing.
/// Explicit launch actions bypass the remaining wait once their route is ready.
class BirdyGoStartup extends StatefulWidget {
  const BirdyGoStartup({super.key, required this.bootstrap, this.warmUp});

  final Future<Widget> Function() bootstrap;

  /// Loads the heavy resources after [bootstrap], marking each step done in
  /// the progress it gets. Without it, loading ends with [bootstrap].
  final Future<void> Function(BirdyGoLoadProgress progress)? warmUp;

  /// Past this, App opens even if [warmUp] has not finished.
  static const loadTimeout = Duration(seconds: 25);

  @override
  State<BirdyGoStartup> createState() => _BirdyGoStartupState();
}

class _BirdyGoStartupState extends State<BirdyGoStartup> {
  Widget? _app;
  bool _failed = false;
  bool _running = false;
  bool _showSplash = true;
  bool _introComplete = false;
  bool _launchHandoffReady = false;
  bool _revealScheduled = false;
  late final _handoff = BirdyGoLaunchHandoff(_launchHandoffReleased);
  final _progress = BirdyGoLoadProgress();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_running) return;
    _running = true;
    try {
      final app = await widget.bootstrap();
      if (mounted) {
        _progress.markDone(BirdyGoLoadStep.start);
        setState(() => _app = app);
        _warmUp();
      }
    } catch (error, stackTrace) {
      debugPrint('BirdyGo startup failed: $error\n$stackTrace');
      if (mounted) setState(() => _failed = true);
    } finally {
      _running = false;
    }
  }

  Future<void> _warmUp() async {
    final warmUp = widget.warmUp;
    if (warmUp != null) {
      try {
        await warmUp(_progress).timeout(BirdyGoStartup.loadTimeout);
      } catch (error) {
        debugPrint('BirdyGo loading did not finish: $error');
      }
    }
    if (!mounted) return;
    _progress.markAllDone();
    setState(() {}); // Mounts App behind the splash.
    _scheduleReveal();
  }

  void _retry() {
    if (_running) return;
    setState(() => _failed = false);
    _start();
  }

  void _completeIntro() {
    if (!mounted || _introComplete) return;
    _introComplete = true;
    _scheduleReveal();
  }

  void _launchHandoffReleased() {
    if (!mounted || _handoff.isPending) return;
    // Quick Listen may start recording as its route mounts. Never hide its
    // controls behind the rest of the intro (the same applies to shared audio).
    _launchHandoffReady = true;
    _scheduleReveal();
  }

  void _scheduleReveal() {
    final loaded = _progress.value.complete && _introComplete;
    if (!mounted ||
        _app == null ||
        !(loaded || _launchHandoffReady) ||
        !_showSplash ||
        _revealScheduled) {
      return;
    }
    _revealScheduled = true;
    // Mount and lay out App behind the splash so its launch listeners can
    // register their holds and its Navigator can prepare the actual destination.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (mounted && !_handoff.isPending && _showSplash) {
        setState(() => _showSplash = false);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return BirdyGoLaunchScope(
      handoff: _handoff,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // App mounts once loading is done: its home screen would
            // otherwise start the same loads all at once and stall the
            // animation. Explicit launches skip [BirdyGoStartup.warmUp], so
            // their App still mounts right after initialization.
            Offstage(
              offstage: _showSplash,
              child: _progress.value.complete ? _app : null,
            ),
            if (_showSplash) _buildSplash(),
          ],
        ),
      ),
    );
  }

  Widget _buildSplash() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BirdyTheme.light(),
    // Same background as the native launch (values-night): the startup
    // follows the device theme, like App does by default.
    darkTheme: BirdyTheme.dark(),
    themeMode: ThemeMode.system,
    // A notification launch route belongs to App, after initialization.
    initialRoute: '/',
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('en'), Locale('fr')],
    localeListResolutionCallback: (preferred, supported) {
      for (final locale in preferred ?? const <Locale>[]) {
        if (locale.languageCode == 'fr') return const Locale('fr');
        if (locale.languageCode == 'en') return const Locale('en');
      }
      return const Locale('en');
    },
    home: BirdyGoSplash(
      progress: _progress,
      onRetry: _failed ? _retry : null,
      onIntroComplete: _completeIntro,
    ),
  );
}
