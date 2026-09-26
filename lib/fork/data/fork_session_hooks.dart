/// Minimal hook points called from upstream's `SessionRepository` (marked
/// `FORK`), so fork features learn about session changes without touching
/// upstream logic.
library;

import '../../features/live/live_session.dart';

/// Receives session persistence events.
abstract interface class SessionChangeListener {
  void sessionSaved(LiveSession session);
  void sessionDeleted(String sessionId);
  void allSessionsDeleted();
}

/// Static registry for the single fork listener (the observation index).
abstract final class ForkSessionHooks {
  static SessionChangeListener? listener;

  static void saved(LiveSession session) => listener?.sessionSaved(session);

  static void deleted(String sessionId) => listener?.sessionDeleted(sessionId);

  static void allDeleted() => listener?.allSessionsDeleted();
}
