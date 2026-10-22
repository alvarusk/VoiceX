# VoiceX Windows speech patch

Vendored from speech_to_text_windows 1.0.1 (see LICENSE).
The upstream SAPI implementation ignores localeId and reports hardcoded English
locales. This copy selects an installed Spanish recognizer before creating its
recognition context, preferring Spain, and reports its actual locale. Without a
Spanish engine initialization fails instead of using the system language.

The root pubspec dependency override ensures this fix also applies to the
transitive Windows implementation used by speech_to_text.
