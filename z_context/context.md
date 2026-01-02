# VoiceX — context.md (para Codex)

Fecha: 2025-12-29  
Entorno principal: **Flutter** (targets: **Windows desktop** y **Chrome web**)  
IDE a partir de ahora: **VS Code**

---

## 1) Objetivo del proyecto (resumen)
VoiceX es una app Flutter orientada a **operar con voz** (STT = Speech-to-Text) y a acelerar un flujo de **review** (p. ej. revisar ítems y ejecutar acciones con comandos de voz).  
Se prioriza un flujo rápido y automatizable, con fallback cuando STT no esté disponible.

---

## 2) Estado actual conocido (a partir del hilo “VoiceX 1” + este chat)
### Error reportado
Al ejecutar en Chrome se obtuvo:

- `Error: The method 'ensureInitialized' isn't defined for the type 'SpeechService'.`
- Apunta a: `lib/review/review_page.dart` llamando `await _speech.ensureInitialized();`
- `SpeechService` está en: `lib/stt/speech_service.dart`

**Conclusión:** faltaba implementar `ensureInitialized()` en `SpeechService` (o cambiar el llamado en `review_page.dart`).

### Problemas pendientes
- **Windows:** el micrófono / STT no funciona (posible: permisos Windows + soporte beta del paquete STT).
- **Edge:** no se quiere usar como target web (se elimina del flujo de ejecución).

---

## 3) Decisiones y cambios propuestos (este chat)
### 3.1 Quitar Edge del flujo
No “se desinstala” Edge como device, pero se evita **forzando el device**:

- Windows: `flutter run -d windows`
- Web (Chrome): `flutter run -d chrome`

En VS Code: quitar configuración Edge del `launch.json` y dejar solo Windows + Chrome.

### 3.2 STT en Windows
Si se está usando `speech_to_text`, **Windows está en beta**.  
Acción propuesta:
- Subir/asegurar `speech_to_text` (ej. `^7.3.0`)  
- Añadir / fijar implementación Windows (ej. `speech_to_text_windows` beta)

Además, manejar el caso “STT no disponible” (initialize==false) con feedback UI y fallback.

### 3.3 Implementar SpeechService.ensureInitialized()
Implementación propuesta (mínima):
- `ensureInitialized()` que llama `SpeechToText.initialize(...)` una sola vez
- `startListening(...)` que falla de forma controlada si STT no está disponible
- `stop()` para detener escucha

---

## 4) Próximos pasos propuestos (roadmap inmediato)
### Paso A — “Voice Commands + fallback”
Objetivo: avanzar sin bloquearse por Windows STT.

1) Crear `CommandRouter`:
   - Mapea frases → acciones (ej. “siguiente”, “anterior”, “aceptar”, “rechazar”, “repetir”).
   - Normalización: lower, trim, quitar puntuación, alias, etc.
2) Integrar en `review_page.dart`:
   - Mostrar estado: “Escuchando…”, “No disponible (Windows beta)”, “Error…”
   - Si STT disponible: al recibir texto, pasar al router y ejecutar acción.
   - Si no disponible: fallback UI (botones + input manual, o modo teclado).
3) Telemetría básica de debug:
   - Logs `onStatus`, `onError`, texto reconocido.

### Paso B — Robustez
4) Unificar comportamiento Windows/Web (feature flag por plataforma).
5) (Opcional) Alternativa STT en Windows:
   - Backend (Azure / Whisper / etc.) si el soporte local no es suficiente.

---

## 5) Archivos involucrados (esperados)
- `pubspec.yaml`  
  - Dependencias STT (`speech_to_text`, `speech_to_text_windows` si aplica).
- `lib/stt/speech_service.dart`  
  - Implementación de `ensureInitialized`, `startListening`, `stop`.
- `lib/review/review_page.dart`  
  - Llama a `ensureInitialized()` antes de escuchar.
  - Manejo de “STT no disponible”.
  - Integración con `CommandRouter`.
- (Nuevo) `lib/commands/command_router.dart`  
  - Parseo de comandos y dispatch.
- `.vscode/launch.json`  
  - Solo Windows + Chrome (sin Edge).

---

## 6) Snippets (referencia rápida)

### 6.1 SpeechService (referencia)
```dart
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;

  Future<bool> ensureInitialized() async {
    if (_ready) return true;

    _ready = await _stt.initialize(
      onStatus: (s) => debugPrint('STT status: $s'),
      onError: (e) => debugPrint('STT error: $e'),
    );

    return _ready;
  }

  Future<void> startListening(ValueChanged<String> onText) async {
    final ok = await ensureInitialized();
    if (!ok) {
      throw StateError('Speech recognition not available on this platform/build.');
    }

    await _stt.listen(
      onResult: (r) => onText(r.recognizedWords),
      listenOptions: const SpeechListenOptions(
        partialResults: true,
        autoPunctuation: true,
      ),
    );
  }

  Future<void> stop() => _stt.stop();
}
```

### 6.2 VS Code launch.json (sin Edge)
```json
{
  "version": "0.2.0",
  "configurations": [
    { "name": "VoiceX (Windows)", "request": "launch", "type": "dart", "deviceId": "windows" },
    { "name": "VoiceX (Chrome)",  "request": "launch", "type": "dart", "deviceId": "chrome" }
  ]
}
```

---

## 7) Checklist rápido para Windows (fuera del código)
- Permisos de micrófono habilitados para apps de escritorio.
- Configuración de Speech / Online speech recognition según la configuración del sistema.
- Probar dictado del sistema (Win+H) para aislar problema del SO.

---

## 8) Comandos útiles
```bash
flutter doctor
flutter pub get
flutter clean
flutter run -d windows
flutter run -d chrome
```
