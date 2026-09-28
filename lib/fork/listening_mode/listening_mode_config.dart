/// Values of the listening modes « Conditions d'écoute » (fork/PLAN.md J6f).
///
/// The modes only drive the existing pre-inference DSP (gain and high-pass
/// filter of AudioCaptureService) plus, for « Ville », the fork's continuous
/// noise reducer. They never touch the model, the detection thresholds or
/// the confidence settings.
library;

import 'package:flutter/foundation.dart';

/// SharedPreferences key of the last chosen mode.
const String kListeningModePref = 'fork_listening_mode';

/// « Ville » is still experimental: shown in debug and profile builds only,
/// same idea as `_showAdvancedInferenceSettings` in settings_screen.dart.
/// Flip to `true` once field tests (road, ventilation, light rain) are done.
const bool kCityModeEnabled = !kReleaseMode;

// ---------------------------------------------------------------------------
// Normal: upstream defaults (settings_providers.dart: gain 1.0, HPF 0 = off).
// ---------------------------------------------------------------------------

/// Unity gain, the default of `audioGainProvider`.
const double kNormalGain = 1.0;

/// High-pass bypassed, the default of `highPassFilterProvider`.
const double kNormalHighPassHz = 0;

// ---------------------------------------------------------------------------
// Vent (wind)
// ---------------------------------------------------------------------------

/// Wind noise and handling rumble on a phone mic sit mostly below
/// 150–200 Hz. Most song is above 1 kHz, but some species sing low:
/// Eurasian eagle-owl (~300–400 Hz fundamental), tawny owl (~400–800 Hz),
/// collared and wood pigeons (~400–600 Hz), Eurasian bittern (~150–200 Hz
/// boom, lost anyway in wind). The upstream filter is a 4th-order
/// Butterworth (-3 dB at the cutoff, 24 dB/octave), so 250 Hz leaves the
/// owls and doves above ~350 Hz within ~1 dB while cutting 60–120 Hz rumble
/// by 25–50 dB. Same order as the "wind cut" switch of field recorders.
const double kWindHighPassHz = 250;

/// Wind mode keeps unity gain: wind already loads the mic.
const double kWindGain = 1.0;

// ---------------------------------------------------------------------------
// Boost
// ---------------------------------------------------------------------------

/// +6 dB. That is the top of the upstream gain slider (0–2), so the setting
/// stays representable in Settings. Samples are clipped to ±1 after the gain
/// (AudioCaptureService._applyDsp), so a loud close bird saturates instead of
/// wrapping. Phone mics are usually 20–30 dB below full scale on birds at
/// distance, so +6 dB rarely clips.
const double kBoostGain = 2.0;

/// A light cut keeps the extra gain from amplifying handling rumble,
/// hence « Garde le téléphone immobile ». Well below every low singer
/// listed for [kWindHighPassHz].
const double kBoostHighPassHz = 120;

// ---------------------------------------------------------------------------
// Ville (city)
// ---------------------------------------------------------------------------

/// City noise (traffic, ventilation) has most of its energy below 250 Hz:
/// same cut as [kWindHighPassHz], then the reducer handles the broadband
/// part that remains.
const double kCityHighPassHz = 250;

/// Unity gain: raising a noisy signal only raises the noise.
const double kCityGain = 1.0;

/// Frame of the STFT noise reducer: 512 samples = 16 ms at 32 kHz, 62.5 Hz
/// per bin. Short enough for chirps (a few tens of ms), long enough to
/// separate a tonal song from the noise floor. Adds a fixed delay of one
/// frame (16 ms), invisible next to 3 s model windows.
const int kCityFrameSize = 512;

/// Hop of the reducer: 50 % overlap, the minimum for perfect
/// reconstruction with a square-root Hann window pair.
const int kCityHopSize = kCityFrameSize ~/ 2;

/// Noise floor time constant, in seconds. Noise that stays for a few
/// seconds (road, fan, rain) is learnt; a song phrase (0.2–3 s) that is
/// much louder than the floor is gated out of the estimate (see
/// [kCitySignalGate]), so it is not learnt as noise.
const double kCityNoiseTimeConstantS = 1.5;

/// While a bin is louder than the floor by this power ratio (4 = +6 dB) it
/// is treated as signal and the floor follows it only [kCitySignalLeak]
/// times as fast, so a steady rise in noise is still learnt eventually.
const double kCitySignalGate = 4.0;

/// Relative speed of the floor update on bins gated as signal.
const double kCitySignalLeak = 0.05;

/// First 0.25 s after enabling: the floor is a plain running mean, so the
/// reducer converges fast instead of starting from zero.
const double kCityWarmupS = 0.25;

/// Over-subtraction factor of the power-subtraction gain: 2 (+3 dB) absorbs
/// what is left of the periodogram variance after [kCityPowerSmoothing].
const double kCityOverSubtraction = 2.0;

/// Share of the previous frame kept in the smoothed power the gain is
/// computed from (recursive average over ~3 hops ≈ 25 ms). A noise-only
/// periodogram bin fluctuates by ±5 dB frame to frame; smoothing it is what
/// keeps noise from poking through as "musical noise". A chirp 20 dB above
/// the floor still opens its bins on its first frame.
const double kCityPowerSmoothing = 0.6;

/// Lowest gain applied to a bin: 0.18 ≈ -15 dB. Keeping a residual floor
/// avoids "musical noise" and guarantees a faint song is never erased.
const double kCityMinGain = 0.18;

/// Per-hop decay of the gain (8 ms hops): the gain rises instantly on a
/// chirp onset but falls back over ~40 ms, which keeps song tails intact.
const double kCityGainRelease = 0.8;
