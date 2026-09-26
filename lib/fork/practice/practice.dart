/// « Écouter un enregistrement » (fork/PLAN.md J5c): one rule, recorded
/// sounds do not count. A session played from the web or a CD, or an
/// analysed audio file, is not an observation.
///
/// The home menu opens `LiveScreen(forkPractice: true)`; nothing is kept in
/// the preferences, so the mode is off at every start.
library;

import '../../features/live/live_session.dart';

/// Whether [session] is a real observation. The single gate: the index
/// (ranking, map, home, sound library, quick review, precision) and the LPO
/// report all go through it.
bool countsAsObservation(LiveSession session) =>
    !session.practice && session.type != SessionType.fileUpload;
