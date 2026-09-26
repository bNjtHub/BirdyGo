/// Small spectrogram of an audio clip, for review cards (J3).
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../features/history/services/spectrogram_renderer.dart';
import '../../features/recording/audio_decoder.dart';
import '../../features/recording/native_audio_decoder.dart';
import '../../shared/providers/settings_providers.dart';

/// Decodes [path] and draws its spectrogram; a neutral box meanwhile.
class ClipSpectrogram extends ConsumerStatefulWidget {
  const ClipSpectrogram({super.key, required this.path, this.height = 120});

  final String path;
  final double height;

  @override
  ConsumerState<ClipSpectrogram> createState() => _ClipSpectrogramState();
}

class _ClipSpectrogramState extends ConsumerState<ClipSpectrogram> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    try {
      if (!File(widget.path).existsSync()) return;
      final audio =
          await AudioDecoder.canDecodeDart(widget.path)
              ? await AudioDecoder.decodeFile(widget.path)
              : await NativeAudioDecoder.decodeFile(widget.path);
      final pixels = renderSpectrogram(
        audio,
        targetSampleRate: AppConstants.sampleRate,
        fftSize: 1024,
        hop: 256,
        maxDisplayBins: 256,
        colorMapName: ref.read(colorMapProvider),
      );
      if (pixels == null || !mounted) return;
      ui.decodeImageFromPixels(
        pixels.pixels,
        pixels.width,
        pixels.height,
        ui.PixelFormat.rgba8888,
        (image) {
          if (mounted) {
            setState(() => _image = image);
          } else {
            image.dispose();
          }
        },
      );
    } catch (_) {
      // A clip that cannot be decoded just shows no spectrogram.
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: widget.height,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child:
            _image == null ? null : RawImage(image: _image, fit: BoxFit.fill),
      ),
    );
  }
}
