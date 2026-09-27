/// Bottom navigation of BirdyGo (J6e, SPEC.md 5.8): Accueil, Carnet, Carte,
/// Profil. Listening, fiches and the other screens open above it, full
/// screen.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/widgets/empty_state.dart';
import '../home/fork_home.dart';
import '../map/contact_map_screen.dart';
import '../notebook/notebook_screen.dart';

enum ForkTab { home, notebook, map, profile }

class ForkShell extends StatefulWidget {
  const ForkShell({super.key});

  @override
  State<ForkShell> createState() => _ForkShellState();
}

class _ForkShellState extends State<ForkShell> {
  ForkTab _tab = ForkTab.home;

  /// Tabs opened at least once. A tab is built on its first visit (the map
  /// loads its tiles only then), then kept with its scroll and filters.
  final Set<ForkTab> _built = {ForkTab.home};

  void _select(ForkTab tab) => setState(() {
    _tab = tab;
    _built.add(tab);
  });

  Widget _page(ForkTab tab) => switch (tab) {
    ForkTab.home => const ForkHome(),
    ForkTab.notebook => const NotebookScreen(),
    ForkTab.map => const ContactMapScreen(showBack: false),
    ForkTab.profile => const _ProfileSoon(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      // Back from another tab returns to Accueil; back from Accueil leaves.
      canPop: _tab == ForkTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(ForkTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            for (final tab in ForkTab.values)
              _built.contains(tab) ? _page(tab) : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: Semantics(
          container: true,
          label: l10n.forkNavLabel,
          child: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (i) => _select(ForkTab.values[i]),
            // Seen a hundred times a day: no indicator animation.
            animationDuration: Duration.zero,
            destinations: [
              NavigationDestination(
                icon: const Icon(AppIcons.home),
                label: l10n.forkNavHome,
              ),
              NavigationDestination(
                icon: const Icon(AppIcons.menuBook),
                label: l10n.forkNavNotebook,
              ),
              NavigationDestination(
                icon: const Icon(AppIcons.mapSheet),
                label: l10n.forkMap,
              ),
              NavigationDestination(
                icon: const Icon(AppIcons.personOutline),
                label: l10n.forkNavProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profil tab until J6e-b.
class _ProfileSoon extends StatelessWidget {
  const _ProfileSoon();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: BirdyColors.of(context).background,
      body: SafeArea(
        bottom: false,
        child: BirdyEmptyState(
          icon: AppIcons.personOutline,
          title: l10n.forkProfileSoonTitle,
          body: l10n.forkProfileSoon,
        ),
      ),
    );
  }
}
