class OpenAiUsage {
  const OpenAiUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.durationSeconds = 0,
  });

  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final double durationSeconds;

  bool get hasUsage =>
      inputTokens > 0 ||
      outputTokens > 0 ||
      totalTokens > 0 ||
      durationSeconds > 0;
}

class OpenAiTextResult {
  const OpenAiTextResult({
    required this.text,
    required this.model,
    this.usage = const OpenAiUsage(),
  });

  final String text;
  final String model;
  final OpenAiUsage usage;
}

class OpenAiTranscriptionResult {
  const OpenAiTranscriptionResult({
    required this.text,
    required this.model,
    this.usage = const OpenAiUsage(),
  });

  final String text;
  final String model;
  final OpenAiUsage usage;
}
