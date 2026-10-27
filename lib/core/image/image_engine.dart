import '../files/picked_file.dart';
import 'image_options.dart';
import 'resize_math.dart';

class ImageTransform {
  const ImageTransform({
    required this.format,
    this.quality = 90,
    this.targetWidth,
    this.targetHeight,
    this.maxLongEdge,
    this.fit = FitMode.stretch,
    this.pad = PadColor.white,
    this.extraRotation = 0,
    this.stripMetadata = true,
  });

  final ImageFormat format;

  /// 1–100; ignored for PNG.
  final int quality;

  /// Exact final size (after orientation + [extraRotation]).
  final int? targetWidth, targetHeight;

  /// Proportional cap on the longest edge when no exact size is given.
  final int? maxLongEdge;
  final FitMode fit;
  final PadColor pad;

  /// Extra clockwise rotation: 0/90/180/270.
  final int extraRotation;
  final bool stripMetadata;

  ImageTransform copyWith({int? quality, int? maxLongEdge, int? targetWidth, int? targetHeight}) => ImageTransform(
        format: format,
        quality: quality ?? this.quality,
        targetWidth: targetWidth ?? this.targetWidth,
        targetHeight: targetHeight ?? this.targetHeight,
        maxLongEdge: maxLongEdge ?? this.maxLongEdge,
        fit: fit,
        pad: pad,
        extraRotation: extraRotation,
        stripMetadata: stripMetadata,
      );
}

class EncodedImage {
  const EncodedImage({
    required this.path,
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });
  final String path;
  final int bytes;
  final int width, height;
  final ImageFormat format;
}

abstract interface class ImageEngine {
  /// Header-only: oriented dimensions, format, alpha, orientation, GPS presence.
  Future<ImageMeta> inspect(String path);

  /// Writes [outPath] (inside a work dir). Never touches [inPath].
  Future<EncodedImage> transform(String inPath, String outPath, ImageTransform t, {ImageMeta? meta});

  /// Whether the platform can encode [format] (HEIC: iOS only; WebP: both).
  bool canEncode(ImageFormat format);
}
