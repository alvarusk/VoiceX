# VoiceX & TakoWorks Companion

Desktop toolkit (Flutter) to review ASS subtitles, manage series, attach per-folder glossaries, and track translation costs logged by TakoWorks. Includes tight Supabase integration, per-engine candidates (GPT, Claude, Gemini, DeepSeek), and handy keyboard shortcuts for fast editing.

## Features
- Import projects from base ASS + engine outputs; organize them into folders (per series) with persistent glossaries.
- Review view with per-line candidates, quick navigation (even without video), doubt flag, and in-place edits.
- Ctrl+Enter in edit dialogs to save; folders/glossaries persist across runs.
- Cost sheet reads Supabase table `voicex_api_costs` to show cost/token breakdown by episode/engine.
- Voice input modes (local STT or OpenAI), configurable in Settings.

## Requirements
- Flutter 3.10+/Dart 3.10+.
- Supabase project (for sync and cost logging).
- TakoWorks producing translations and logging costs (optional but recommended).
- For STT/voice features: microphone access; OpenAI key if using OpenAI mode.

## Configuration
1) Copy `.env.sample` to `.env` and fill:
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```
2) Optional env (TakoWorks cost logging):
```
SUPABASE_SERVICE_KEY=...      # if you want to write costs
SUPABASE_COST_TABLE=voicex_api_costs
```
3) API keys (OpenAI) are stored via the Settings page; you can also prefill them in a local config if desired.

## Running
```
flutter pub get
flutter run -d windows   # or your target device
```

## Builds
- Windows: `powershell -ExecutionPolicy Bypass -File scripts/package_windows.ps1`  
  Genera la build release, la copia en `dist/windows/voicex_win_<timestamp>` y un `.zip`, y abre la carpeta en el Explorador.
- Android APK: `flutter build apk --release`
- Android App Bundle: `flutter build appbundle`

### Instalador Windows (Inno Setup)
1) Genera la build: `powershell -ExecutionPolicy Bypass -File scripts/package_windows.ps1`
2) Instala Inno Setup y compila el script:  
   - Abrir `scripts/voicex_installer.iss` en Inno Setup y pulsa *Compile*, o  
   - CLI: `iscc scripts/voicex_installer.iss`
3) Salida: `dist/installer/voicex_installer.exe` listo para distribuir.

### Android signing (release)
1) Genera un keystore (una sola vez):
```
keytool -genkey -v -keystore ~/voicex-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias voicex
```
2) Crea `android/key.properties` (no lo subas a git):
```
storeFile=/ruta/completa/voicex-keystore.jks
storePassword=TU_PASSWORD
keyAlias=voicex
keyPassword=TU_PASSWORD
```
3) Construye: `flutter build apk --release` o `flutter build appbundle`.  
   Si `key.properties` no existe, el build sigue usando la firma debug para no bloquear builds locales.

## Project Workflow
- Create folders from the top bar or when importing a project; folders persist across sessions.
- Import a project: base ASS (and optionally engine ASS files, video). Folders appear immediately in selectors.
- Review: navigate lines, edit candidates, play segments if video is present; navigation works even without video.
- Glossaries (Settings > Glosarios):
  - Select folder/series, edit “Términos” (comma-separated); changes persist.
  - “Subir TXT” replaces the glossary for that folder (one term per line). Edits in the field append to existing terms.
  - Moving a project to another folder switches to that folder’s glossary; removing the folder leaves it without glossary.

## Costs
- Costs are written by TakoWorks to Supabase (`voicex_api_costs`) if you set `SUPABASE_URL` + service key and cost envs (`COST_*`).
- In VoiceX, tap the receipt icon (Costes API) to see totals per episode and per engine.

## Key Shortcuts
- Edit dialog: Ctrl+Enter to save (desktop).
- Line review: navigation buttons work with or without video.

## Notes
- If no video is imported, line navigation still works (playback buttons are no-ops).
- Folders are stored in app settings; deleting a folder via UI removes it from cache/persisted list, but deleting projects alone won’t delete the folder.
