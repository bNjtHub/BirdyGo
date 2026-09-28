import 'package:birdnet_live/fork/design/activity_scale.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/design/species_tint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityScale.kingfisher', () {
    test('the quietest non-zero step still reaches 3:1 on a light card', () {
      final scale = ActivityScale.kingfisher(Colors.white);
      // A tiny share of a huge busiest hour: close to the scale's own
      // "quiet" end.
      final quiet = scale.of(1, 1000000);
      expect(
        contrastRatio(quiet, Colors.white),
        greaterThanOrEqualTo(ActivityScale.minContrast - 0.05),
      );
    });

    test('the quietest non-zero step still reaches 3:1 on a dark card', () {
      final scale = ActivityScale.kingfisher(BirdyBrand.ink);
      final quiet = scale.of(1, 1000000);
      expect(
        contrastRatio(quiet, BirdyBrand.ink),
        greaterThanOrEqualTo(ActivityScale.minContrast - 0.05),
      );
    });

    test('the busiest hour is the strongest, distinct from the quietest', () {
      final scale = ActivityScale.kingfisher(Colors.white);
      final quiet = scale.of(1, 1000000);
      final busy = scale.of(10, 10);
      expect(quiet, isNot(busy));
      expect(
        contrastRatio(busy, Colors.white),
        greaterThanOrEqualTo(contrastRatio(quiet, Colors.white)),
      );
    });

    test('every bar sharing the busiest value gets the same, strongest color', () {
      final scale = ActivityScale.kingfisher(Colors.white);
      expect(scale.of(5, 5), scale.of(100, 100));
    });
  });
}
