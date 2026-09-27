import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../design/birdy_theme.dart';
import 'birdygo_launch_handoff.dart';
import 'birdygo_splash.dart';

/// Paints the launch screen while real initialization runs. No minimum delay.
class BirdyGoStartup extends StatefulWidget {
  const BirdyGoStartup({super.key, required this.bootstrap});

  final Future<Widget> Function() bootstrap;

  @override
  State<BirdyGoStartup> createState() => _BirdyGoStartupState();
}

class _BirdyGoStartupState extends State<BirdyGoStartup> {
  Widget? _app;
  bool _failed = false;
  bool _running = false;
  bool _showSplash = true;
  bool _revealScheduled = false;
  late final _handoff = BirdyGoLaunchHandoff(_scheduleReveal);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_running) return;
    _running = true;
    try {
      final app = await widget.bootstrap();
      if (mounted) {
        setState(() => _app = app);
        _scheduleReveal();
      }
    } catch (error, stackTrace) {
      debugPrint('BirdyGo startup failed: $error\n$stackTrace');
      if (mounted) setState(() => _failed = true);
    } finally {
      _running = false;
    }
  }

  void _retry() {
    if (_running) return;
    setState(() => _failed = false);
    _start();
  }

  void _scheduleReveal() {
    if (!mounted || _app == null || !_showSplash || _revealScheduled) return;
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
            Offstage(offstage: _showSplash, child: _app),
            if (_showSplash) _buildSplash(),
          ],
        ),
      ),
    );
  }

  Widget _buildSplash() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BirdyTheme.dark(),
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
    home: BirdyGoSplash(onRetry: _failed ? _retry : null),
  );
}
