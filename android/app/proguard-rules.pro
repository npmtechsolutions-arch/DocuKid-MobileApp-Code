# DocuKit R8 rules (ARCHITECTURE §11).
# PDFium is reached through JNI/FFI by pdfrx; keep native-facing classes.
-keep class io.github.espresso3389.** { *; }
-keep class com.npmtechsolutions.docukit_native.** { *; }
-keepclasseswithmembernames class * { native <methods>; }
# flutter_image_compress / heifwriter
-keep class com.fluttercandies.flutter_image_compress.** { *; }
-dontwarn com.google.errorprone.annotations.**
# google_mlkit_text_recognition references every script's options class
# (compileOnly); only the scripts added in build.gradle.kts ship (ADR-045).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
# PdfBox-Android (Protect / Unlock PDF, ADR-049). BouncyCastle is excluded
# (only certificate security uses it) and the JPEG 2000 codec is optional.
-dontwarn org.bouncycastle.**
-dontwarn com.gemalto.jp2.**
# Security handlers are created by reflection (SecurityHandlerFactory).
-keep class com.tom_roush.pdfbox.pdmodel.encryption.** { *; }
