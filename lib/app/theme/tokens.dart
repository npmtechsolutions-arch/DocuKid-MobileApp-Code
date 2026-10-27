import 'package:flutter/material.dart';

/// Design tokens (DESIGN_SYSTEM §1–3). Widgets never hard-code colours or sizes.
/// Heading font (ADR-032). Bundled: SemiBold 600 + Bold 700.
const headingFont = 'PlusJakartaSans';

abstract final class Space {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;

  static const contentMaxWidth = 720.0;
  static double screenPadding(double width) => width >= 600 ? x6 : x4;
}

abstract final class Radii {
  static const xs = 4.0; // badges
  static const sm = 8.0; // thumbnails
  static const md = 12.0; // cards, tiles, fields
  static const lg = 16.0; // sheets (top corners)
  static const xl = 24.0; // hero surfaces (Home header, Result summary)
  static const card = 20.0; // ToolCard v2 (UI_REFRESH §3)
  static const hero = 28.0; // bottom corners of the Home hero (UI_REFRESH §2)
  static const full = 999.0;
}

abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 840.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
  static const countUp = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;

  /// DESIGN_SYSTEM §5: reduce motion → 0 except short fades.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : d;
}

abstract final class Palette {
  static const seed = Color(0xFF2F5BEA);

  // Light
  static const primaryL = Color(0xFF2F5BEA);
  static const onPrimaryL = Color(0xFFFFFFFF);
  static const primaryContainerL = Color(0xFFDCE4FF);
  static const surfaceL = Color(0xFFFBFBFE);
  static const surfaceContainerL = Color(0xFFF0F1F7);
  static const surfaceContainerHighL = Color(0xFFE8E9F1);
  static const onSurfaceL = Color(0xFF1A1B21);
  static const onSurfaceVariantL = Color(0xFF4A4D5A);
  static const outlineVariantL = Color(0xFFC9CBD6);
  static const imageAccentL = Color(0xFF00796B);
  static const pdfAccentL = Color(0xFFC2410C);
  static const successL = Color(0xFF187536); // was #1B7F3B: 4.40:1 on its container (ADR-033)
  static const successContainerL = Color(0xFFDDF5E3);
  static const warningL = Color(0xFF8A5A00);
  static const warningContainerL = Color(0xFFFFF1D6);
  static const errorL = Color(0xFFB3261E);
  static const errorContainerL = Color(0xFFF9DEDC);
  static const checkerAL = Color(0xFFE6E6E6);
  static const checkerBL = Color(0xFFFFFFFF);

  // Dark
  static const primaryD = Color(0xFFA9C1FF);
  static const onPrimaryD = Color(0xFF0A1F66);
  static const primaryContainerD = Color(0xFF1F3A9E);
  static const surfaceD = Color(0xFF121318);
  static const surfaceContainerD = Color(0xFF1C1D24);
  static const surfaceContainerHighD = Color(0xFF24262E);
  static const onSurfaceD = Color(0xFFE3E3EA);
  static const onSurfaceVariantD = Color(0xFFC2C5D3);
  static const outlineVariantD = Color(0xFF40434F);
  static const imageAccentD = Color(0xFF5FD3C3);
  static const pdfAccentD = Color(0xFFFFA27A);
  static const successD = Color(0xFF7FDB98);
  static const successContainerD = Color(0xFF123D20);
  static const warningD = Color(0xFFFFC860);
  static const warningContainerD = Color(0xFF3D2A00);
  static const errorD = Color(0xFFF2B8B5);
  static const errorContainerD = Color(0xFF601410);
  static const checkerAD = Color(0xFF2A2A2A);
  static const checkerBD = Color(0xFF1E1E1E);
}

/// Roles Material's ColorScheme doesn't have.
@immutable
class DocuColors extends ThemeExtension<DocuColors> {
  const DocuColors({
    required this.imageAccent,
    required this.pdfAccent,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.checkerA,
    required this.checkerB,
    required this.heroStart,
    required this.heroEnd,
    required this.imageGradStart,
    required this.imageGradEnd,
    required this.pdfGradStart,
    required this.pdfGradEnd,
    required this.successGradStart,
    required this.successGradEnd,
    required this.glassFill,
    required this.glassBorder,
  });

  final Color imageAccent, pdfAccent;
  final Color success, successContainer;
  final Color warning, warningContainer;
  final Color checkerA, checkerB;

  /// `brandGradient` stops (UI_REFRESH §1): Home hero, Result success header,
  /// primary button fill.
  final Color heroStart, heroEnd;

  /// `imageGradient` / `pdfGradient`: tool icon tiles.
  final Color imageGradStart, imageGradEnd, pdfGradStart, pdfGradEnd;

  /// `successGradient`: savings ring, celebration check.
  final Color successGradStart, successGradEnd;

  /// `surfaceGlass`: chips and the search bar on top of gradients.
  final Color glassFill, glassBorder;

  LinearGradient get brandGradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [heroStart, heroEnd]);
  LinearGradient get imageGradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [imageGradStart, imageGradEnd]);
  LinearGradient get pdfGradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pdfGradStart, pdfGradEnd]);
  LinearGradient get successGradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [successGradStart, successGradEnd]);

  static const light = DocuColors(
    imageAccent: Palette.imageAccentL,
    pdfAccent: Palette.pdfAccentL,
    success: Palette.successL,
    successContainer: Palette.successContainerL,
    warning: Palette.warningL,
    warningContainer: Palette.warningContainerL,
    checkerA: Palette.checkerAL,
    checkerB: Palette.checkerBL,
    heroStart: Color(0xFF2F5BEA),
    heroEnd: Color(0xFF6A4CFF),
    imageGradStart: Color(0xFF00897B),
    imageGradEnd: Color(0xFF0097A7), // spec #26C6DA → darkened for 3:1 glyph contrast (ADR-033)
    pdfGradStart: Color(0xFFE8590C),
    pdfGradEnd: Color(0xFFF0437A),
    successGradStart: Color(0xFF1B9E4B),
    successGradEnd: Color(0xFF4CC38A),
    glassFill: Color(0x1A000000), // black @ 10% (spec white 14% fails 4.5:1 for white text; ADR-033)
    glassBorder: Color(0x3DFFFFFF), // white @ 24%
  );

  static const dark = DocuColors(
    imageAccent: Palette.imageAccentD,
    pdfAccent: Palette.pdfAccentD,
    success: Palette.successD,
    successContainer: Palette.successContainerD,
    warning: Palette.warningD,
    warningContainer: Palette.warningContainerD,
    checkerA: Palette.checkerAD,
    checkerB: Palette.checkerBD,
    heroStart: Color(0xFF3D5BD9),
    heroEnd: Color(0xFF6B53E8),
    imageGradStart: Color(0xFF1E9E8F),
    imageGradEnd: Color(0xFF1593A4), // spec #3BB8C9 → darkened for 3:1 (ADR-033)
    pdfGradStart: Color(0xFFE2702E),
    pdfGradEnd: Color(0xFFE8578A),
    successGradStart: Color(0xD91B9E4B), // same as light, at 85%
    successGradEnd: Color(0xD94CC38A),
    glassFill: Color(0x1A000000),
    glassBorder: Color(0x29FFFFFF),
  );

  @override
  DocuColors copyWith() => this;

  @override
  DocuColors lerp(ThemeExtension<DocuColors>? other, double t) {
    if (other is! DocuColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return DocuColors(
      imageAccent: c(imageAccent, other.imageAccent),
      pdfAccent: c(pdfAccent, other.pdfAccent),
      success: c(success, other.success),
      successContainer: c(successContainer, other.successContainer),
      warning: c(warning, other.warning),
      warningContainer: c(warningContainer, other.warningContainer),
      checkerA: c(checkerA, other.checkerA),
      checkerB: c(checkerB, other.checkerB),
      heroStart: c(heroStart, other.heroStart),
      heroEnd: c(heroEnd, other.heroEnd),
      imageGradStart: c(imageGradStart, other.imageGradStart),
      imageGradEnd: c(imageGradEnd, other.imageGradEnd),
      pdfGradStart: c(pdfGradStart, other.pdfGradStart),
      pdfGradEnd: c(pdfGradEnd, other.pdfGradEnd),
      successGradStart: c(successGradStart, other.successGradStart),
      successGradEnd: c(successGradEnd, other.successGradEnd),
      glassFill: c(glassFill, other.glassFill),
      glassBorder: c(glassBorder, other.glassBorder),
    );
  }
}

extension DocuTheme on BuildContext {
  DocuColors get docu => Theme.of(this).extension<DocuColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
