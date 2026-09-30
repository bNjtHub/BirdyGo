/// Bottom navigation of BirdyGo (J6e, SPEC.md 5.8): Accueil, Carnet, Carte,
/// Profil, and « Écouter » as a disc in the middle of the bar (J6j, see
/// `ForkNavBar`): it opens the listening screen and is never a tab. Listening,
/// fiches and the other screens open above it, full screen.
///
/// The tabs sit side by side in a [PageView] (J6f): a horizontal swipe moves
/// to the next tab in the order of the bar, and the bar follows. On the Carte
/// tab the map pans with horizontal drags, so swiping is off there; the bar
/// still leaves it, and swiping from Carnet or Profil into the map works.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/live/live_controller.dart';
import '../../features/live/live_providers.dart';
import '../../features/live/live_screen.dart';
import '../design/birdy_motion.dart';
import '../design/birdy_tokens.dart';
import '../home/fork_home.dart';
import '../map/contact_map_screen.dart';
import '../notebook/notebook_screen.dart';
import '../profile/profile_screen.dart';
import 'fork_nav_bar.dart';

enum ForkTab { home, notebook, map, profile }

/// Lets a tab open another one (the home's status card opens Profil).
class ForkShellScope extends InheritedWidget {
  const ForkShellScope({super.key, required this.select, required super.child});

  final void Function(ForkTab tab) select;

  /// Null outside the bottom navigation.
  static ForkShellScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ForkShellScope>();

  @override
  bool updateShouldNotify(ForkShellScope old) => false;
}

class ForkShell extends ConsumerStatefulWidget {
  const ForkShell({super.key});

  @override
  ConsumerState<ForkShell> createState() => _ForkShellState();
}

class _ForkShellState extends ConsumerState<ForkShell> {
  final PageController _pages = PageController();

  /// Tab shown by the bar. Follows a swipe as soon as the next page is
  /// more than half on screen.
  ForkTab _tab = ForkTab.home;

  /// Tab the pages rest on (or are heading to after a tap). Decides whether
  /// swiping is allowed: not on the map, whose drags pan it.
  ForkTab _settled = ForkTab.home;

  /// Target of a tap on the bar while the pages slide to it: the pages
  /// crossed on the way do not move the bar.
  ForkTab? _slidingTo;

  /// Tabs opened at least once. A tab is built on its first visit (the map
  /// loads its tiles only then), then kept with its scroll and filters.
  final Set<ForkTab> _built = {ForkTab.home};

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(ForkTab tab) {
    // Where the pages are now, before the bar moves.
    final from =
        _pages.hasClients ? (_pages.page ?? tab.index).round() : tab.index;
    setState(() {
      _tab = tab;
      _settled = tab;
      _built.add(tab);
    });
    if (!_pages.hasClients) return;
    // A tap that skips tabs jumps: sliding through them would flash the
    // ones in between (possibly never built yet).
    if (BirdyMotion.reduced(context) || (tab.index - from).abs() > 1) {
      _slidingTo = null;
      _pages.jumpToPage(tab.index);
      return;
    }
    _slidingTo = tab;
    _pages
        .animateToPage(
          tab.index,
          duration: BirdyMotion.reorder,
          curve: BirdyMotion.move,
        )
        .whenComplete(() {
          if (_slidingTo == tab) _slidingTo = null;
        });
  }

  void _onPageChanged(int index) {
    if (_slidingTo != null) return;
    setState(() => _tab = ForkTab.values[index]);
  }

  /// Only the shell's own pages, not the scrollers inside the tabs.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || !_pages.hasClients) return false;
    final page = _pages.page ?? _settled.index.toDouble();
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      // A swipe brings the next tab on screen: build it now.
      final coming = {
        ForkTab.values[page.floor().clamp(0, ForkTab.values.length - 1)],
        ForkTab.values[page.ceil().clamp(0, ForkTab.values.length - 1)],
      };
      if (!_built.containsAll(coming)) setState(() => _built.addAll(coming));
    } else if (n is ScrollEndNotification) {
      final rest = ForkTab.values[page.round()];
      _slidingTo = null;
      if (rest != _settled || rest != _tab) {
        setState(() {
          _settled = rest;
          _tab = rest;
        });
      }
    }
    return false;
  }

  /// The « Écouter » disc: starts listening, or reopens the screen of the
  /// listening already on (active or paused). The selected tab stays.
  void _listen() {
    final state = ref.read(liveStateProvider);
    final running = state == LiveState.active || state == LiveState.paused;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) =>
                running
                    ? const LiveScreen()
                    : const LiveScreen(forceAutoStart: true),
      ),
    );
  }

  Widget _page(ForkTab tab) => switch (tab) {
    ForkTab.home => const ForkHome(),
    ForkTab.notebook => const NotebookScreen(),
    ForkTab.map => const ContactMapScreen(showBack: false),
    ForkTab.profile => const ProfileScreen(),
  };

  /// Whether [tab]'s page shows at least in part.
  bool _onScreen(ForkTab tab) {
    final position = _pages.hasClients ? _pages.position : null;
    if (position == null || !position.hasContentDimensions) {
      return tab == _settled;
    }
    return ((_pages.page ?? _settled.index) - tab.index).abs() < 1;
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Keyboard open (a search field in a tab's sheet): the bar hides, as the
    // Scaffold's own bar used to stay under the keyboard.
    final showBar = MediaQuery.viewInsetsOf(context).bottom == 0;
    return PopScope(
      // Back from another tab returns to Accueil; back from Accueil leaves.
      canPop: _tab == ForkTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(ForkTab.home);
      },
      child: Scaffold(
        // The bar is not the Scaffold's: its disc overhangs the pages, so the
        // pages stop at the bar's surface and the bar floats over them.
        body: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: showBar ? BirdySizes.navBar + safeBottom : 0,
              // The pages' own screens must not add the safe inset a second
              // time (the Scaffold used to remove it under its bar).
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: ForkShellScope(
                  select: _select,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: PageView(
                      controller: _pages,
                      // The map pans with horizontal drags: no swiping out
                      // of it.
                      physics:
                          _settled == ForkTab.map
                              ? const NeverScrollableScrollPhysics()
                              : null,
                      onPageChanged: _onPageChanged,
                      children: [
                        for (final tab in ForkTab.values)
                          _TabPage(
                            key: ValueKey(tab),
                            pages: _pages,
                            visible: () => _onScreen(tab),
                            child:
                                _built.contains(tab)
                                    ? _page(tab)
                                    : const SizedBox.expand(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ForkNavBar(
                  selected: _tab,
                  onSelect: _select,
                  onListen: _listen,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One tab in the pages: kept alive off screen (scroll, filters, map), and
/// hidden for [Visibility.of] once fully off screen, as the IndexedStack did
/// (the home's logo only sings while seen).
class _TabPage extends StatefulWidget {
  const _TabPage({
    super.key,
    required this.pages,
    required this.visible,
    required this.child,
  });

  final PageController pages;
  final bool Function() visible;
  final Widget child;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: widget.pages,
      builder:
          (context, child) =>
              Visibility.maintain(visible: widget.visible(), child: child!),
      child: widget.child,
    );
  }
}
