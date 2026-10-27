import '../files/mime_sniffer.dart';

/// User-facing output format choice (FR-IMG-08).
enum OutputFormatChoice { same, jpeg, png, webp, heic }

enum ImageFormat {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp'),
  heic('image/heic', 'heic');

  const ImageFormat(this.mime, this.ext);
  final String mime;
  final String ext;

  bool get supportsAlpha => this == png || this == webp;
  bool get usesQuality => this != png;

  SniffedType get sniffed => switch (this) {
        jpeg => SniffedType.jpeg,
        png => SniffedType.png,
        webp => SniffedType.webp,
        heic => SniffedType.heic,
      };

  static ImageFormat fromSniffed(SniffedType t) => switch (t) {
        SniffedType.png => png,
        SniffedType.webp => webp,
        SniffedType.heic => heic,
        _ => jpeg,
      };
}

/// Resolves "Same as original" (ADR-014: HEIC input → JPEG unless the
/// platform can encode HEIC and the user explicitly picked HEIC).
ImageFormat resolveOutputFormat(OutputFormatChoice choice, SniffedType input, {required bool heicSupported}) {
  switch (choice) {
    case OutputFormatChoice.same:
      if (input == SniffedType.heic) return ImageFormat.jpeg;
      return ImageFormat.fromSniffed(input);
    case OutputFormatChoice.jpeg:
      return ImageFormat.jpeg;
    case OutputFormatChoice.png:
      return ImageFormat.png;
    case OutputFormatChoice.webp:
      return ImageFormat.webp;
    case OutputFormatChoice.heic:
      return heicSupported ? ImageFormat.heic : ImageFormat.jpeg;
  }
}

enum PadColor { white, black, transparent }
