/// The BirdyGo tweet: a short chirp played when the user taps the home logo
/// (assets/fork/sounds/birdygo_tweet.wav, 1.6 s). Played by the shared
/// short-sound player; silent while a listening runs.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sound/birdy_sfx.dart';

const String kLogoTweetAsset = 'assets/fork/sounds/birdygo_tweet.wav';

/// Loads and warms the tweet ahead of the first tap (no sound), unless a
/// listening runs.
void prepareLogoTweet(WidgetRef ref) => prepareSfx(ref, [kLogoTweetAsset]);

/// Plays the tweet unless a listening is running.
void playLogoTweet(WidgetRef ref) => playSfx(ref, kLogoTweetAsset);
