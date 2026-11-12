enum Engine { base, finalAss, gpt, claude, gemini, deepseek }

String engineToStr(Engine e) => e == Engine.finalAss ? 'final' : e.name;

Engine? inferEngineFromName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('_final.ass')) return Engine.finalAss;
  if (n.contains('gpt')) return Engine.gpt;
  if (n.contains('claude')) return Engine.claude;
  if (n.contains('gemini')) return Engine.gemini;
  if (n.contains('deepseek') || n.contains('ds')) return Engine.deepseek;
  return null;
}
