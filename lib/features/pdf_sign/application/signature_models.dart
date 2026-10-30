/// How a signature was made (RELEASE_V1_4 §5.1 `kind`).
enum SignatureKind { draw, type, photo }

/// A signature PNG ready to place: transparent, cropped to the ink. [savedId]
/// is set when the user chose to keep it (FR-SIG-10).
class CreatedSignature {
  const CreatedSignature({required this.pngPath, required this.kind, required this.widthPx, required this.heightPx, this.savedId});
  final String pngPath;
  final SignatureKind kind;
  final int widthPx, heightPx;
  final String? savedId;

  double get aspect => widthPx / heightPx;
}

/// One kept signature: `appSupport/signatures/<file>`.
class SavedSignature {
  const SavedSignature({required this.id, required this.file, required this.createdAt, required this.kind});
  final String id, file;
  final DateTime createdAt;
  final SignatureKind kind;

  Map<String, Object?> toJson() => {'id': id, 'file': file, 'createdAt': createdAt.toIso8601String(), 'kind': kind.name};

  static SavedSignature fromJson(Map<String, dynamic> j) => SavedSignature(
        id: j['id'] as String,
        file: j['file'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        kind: SignatureKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => SignatureKind.draw),
      );
}
