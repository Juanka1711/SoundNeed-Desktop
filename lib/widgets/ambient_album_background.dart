import 'dart:math' as math;
import 'dart:ui' as ui show Image, ImageByteFormat, ImageFilter;

import 'package:flutter/material.dart';

class AmbientAlbumBackground extends StatefulWidget {
  const AmbientAlbumBackground({required this.artwork, super.key});

  final ImageProvider<Object>? artwork;

  @override
  State<AmbientAlbumBackground> createState() => _AmbientAlbumBackgroundState();
}

class _AmbientAlbumBackgroundState extends State<AmbientAlbumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 13),
  )..repeat(reverse: true);
  ImageStream? _paletteStream;
  ImageStreamListener? _paletteListener;
  int _paletteRequest = 0;
  Color? _albumColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenForArtworkColor();
  }

  @override
  void didUpdateWidget(covariant AmbientAlbumBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artwork != widget.artwork) _listenForArtworkColor();
  }

  void _listenForArtworkColor() {
    final request = ++_paletteRequest;
    final oldStream = _paletteStream;
    final oldListener = _paletteListener;
    if (oldStream != null && oldListener != null) {
      oldStream.removeListener(oldListener);
    }
    _paletteStream = null;
    _paletteListener = null;
    _albumColor = null;

    final artwork = widget.artwork;
    if (artwork == null) return;
    final sampleProvider = ResizeImage(artwork, width: 32, height: 32);
    final stream = sampleProvider.resolve(
      createLocalImageConfiguration(context),
    );
    _paletteStream = stream;
    final listener = ImageStreamListener((info, synchronousCall) {
      _readArtworkColor(info.image, request);
    });
    _paletteListener = listener;
    stream.addListener(listener);
  }

  Future<void> _readArtworkColor(ui.Image image, int request) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null || !mounted || request != _paletteRequest) return;
      var hueX = 0.0;
      var hueY = 0.0;
      var saturationTotal = 0.0;
      var valueTotal = 0.0;
      var weightTotal = 0.0;
      for (var offset = 0; offset + 3 < data.lengthInBytes; offset += 4) {
        final alpha = data.getUint8(offset + 3) / 255;
        if (alpha < .75) continue;
        final color = Color.fromARGB(
          255,
          data.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        );
        final hsv = HSVColor.fromColor(color);
        if (hsv.saturation < .2 || hsv.value < .14 || hsv.value > .96) {
          continue;
        }
        final weight = hsv.saturation * hsv.saturation;
        final radians = hsv.hue * math.pi / 180;
        hueX += math.cos(radians) * weight;
        hueY += math.sin(radians) * weight;
        saturationTotal += hsv.saturation * weight;
        valueTotal += hsv.value * weight;
        weightTotal += weight;
      }
      if (weightTotal == 0) return;
      final hue = (math.atan2(hueY, hueX) * 180 / math.pi + 360) % 360;
      final color = HSVColor.fromAHSV(
        1,
        hue,
        (saturationTotal / weightTotal).clamp(.38, .82).toDouble(),
        (valueTotal / weightTotal).clamp(.42, .8).toDouble(),
      ).toColor();
      if (!mounted || request != _paletteRequest) return;
      setState(() => _albumColor = color);
    } catch (_) {
      // The artwork remains blurred behind the black fade if sampling fails.
    }
  }

  @override
  void dispose() {
    final stream = _paletteStream;
    final listener = _paletteListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (widget.artwork != null)
          AnimatedBuilder(
            animation: _motion,
            builder: (context, child) {
              final phase = _motion.value * math.pi * 2;
              return Transform.translate(
                offset: Offset(math.sin(phase) * 18, math.cos(phase) * 8),
                child: Transform.scale(
                  scale: 1.2 + math.sin(phase) * .035,
                  child: child,
                ),
              );
            },
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 44, sigmaY: 44),
                child: Image(
                  key: ValueKey(widget.artwork.hashCode),
                  image: widget.artwork!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.expand(),
                ),
              ),
            ),
          ),
        if (_albumColor != null)
          AnimatedBuilder(
            animation: _motion,
            builder: (context, child) {
              final drift = math.sin(_motion.value * math.pi * 2) * .14;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + drift, 0),
                    end: Alignment(1 + drift, 0),
                    colors: [
                      _albumColor!.withValues(alpha: .34),
                      _albumColor!.withValues(alpha: .5),
                      _albumColor!.withValues(alpha: .34),
                    ],
                    stops: const [0, .5, 1],
                  ),
                ),
              );
            },
          ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .34, .72, 1],
                colors: [
                  Color(0x5C000000),
                  Color(0x80000000),
                  Color(0xE6000000),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
