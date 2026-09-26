/// Session counters of the live screen (J6c): duration, species, contacts.
library;

import 'dart:async';

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/animated_count.dart';

/// « 12:47 », or « 1 h 05 » past an hour.
String formatLiveDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  if (minutes >= 60) {
    return '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// Three tiles, or one line of text when the spectrogram is enlarged.
class LiveStats extends StatelessWidget {
  const LiveStats({
    super.key,
    required this.elapsed,
    required this.ticking,
    required this.species,
    required this.contacts,
    this.compact = false,
  });

  /// Listening time of the session (pauses excluded).
  final Duration Function() elapsed;

  /// The duration moves once a second while listening.
  final bool ticking;

  final int species;
  final int contacts;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          BirdySpace.l,
          0,
          BirdySpace.l,
          BirdySpace.s,
        ),
        child: _Ticking(
          elapsed: elapsed,
          ticking: ticking,
          builder:
              (text) => Text(
                l10n.forkLiveSummary(text, species, contacts),
                style: BirdyText.bodyCompact.copyWith(
                  color: c.text2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.gutterDark,
        0,
        BirdySpace.gutterDark,
        BirdySpace.m,
      ),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              value: _Ticking(
                elapsed: elapsed,
                ticking: ticking,
                builder: (text) => Text(text, style: BirdyText.numberL),
              ),
              label: l10n.forkLiveDuration,
            ),
          ),
          const SizedBox(width: BirdySpace.s),
          Expanded(
            child: StatTile.count(
              count: species,
              label: l10n.forkLiveSpeciesLabel,
            ),
          ),
          const SizedBox(width: BirdySpace.s),
          Expanded(
            child: StatTile.count(
              count: contacts,
              label: l10n.forkLiveContactsLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rebuilds only the duration text, once a second, while [ticking].
class _Ticking extends StatefulWidget {
  const _Ticking({
    required this.elapsed,
    required this.ticking,
    required this.builder,
  });

  final Duration Function() elapsed;
  final bool ticking;
  final Widget Function(String text) builder;

  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Ticking old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.ticking && _timer == null) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!widget.ticking && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(formatLiveDuration(widget.elapsed()));
}
