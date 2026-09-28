/// Public way to open the « Bilan de l'écoute » of a saved session from
/// anywhere (J6g-e), e.g. « Bilan du jour » on the home or a notebook entry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/live/live_providers.dart';
import '../../features/live/live_session.dart';
import 'listening_summary_screen.dart';

/// Pushes the Bilan of the saved session [sessionId] and completes when it
/// closes. Closing pops exactly one level, back to the caller (unlike the
/// Bilan that follows « Arrêter », which returns to the first route).
///
/// Returns false, and pushes nothing, when no saved session has this id.
Future<bool> openListeningSummary(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
}) async {
  final navigator = Navigator.of(context);
  final session = await ref.read(sessionRepositoryProvider).load(sessionId);
  if (session == null || !navigator.mounted) return false;
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => ListeningSummaryScreen(session: session, fromLive: false),
    ),
  );
  return true;
}

/// Route of the Bilan that follows « Arrêter » (J6g-e): always the Bilan,
/// whether the session was saved automatically or not. Closing it returns to
/// the first route.
Route<void> afterStopSummaryRoute(LiveSession session, {required bool saved}) =>
    MaterialPageRoute<void>(
      builder: (_) => ListeningSummaryScreen(session: session, saved: saved),
    );
