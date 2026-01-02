# Build scripts

## Windows

```
.\scripts\package_windows.ps1 [-SkipPubGet]

# Si necesitas dart-define manual, usa build_windows.ps1:
.\scripts\build_windows.ps1 `
  -SupabaseUrl "https://xxx.supabase.co" `
  -SupabaseAnonKey "..." `
  -R2AccountId "..." -R2AccessKey "..." -R2SecretKey "..." `
  -R2Bucket "voicex-video" -R2PublicBase "https://pub-xxxx.r2.dev"
```

Artifacts: `dist/windows/voicex_win_<stamp>` y zip adyacente (Release dentro).

## Android

```
powershell -ExecutionPolicy Bypass -File scripts/package_android.ps1 `
  -SupabaseUrl "https://xxx.supabase.co" -SupabaseAnonKey "..." `
  -R2AccountId "..." -R2AccessKey "..." -R2SecretKey "..." `
  -R2Bucket "voicex-video" -R2PublicBase "https://pub-xxxx.r2.dev"

# O con bash si prefieres:
# chmod +x scripts/build_android.sh
# ./scripts/build_android.sh \
#   --supabase-url "https://xxx.supabase.co" --supabase-key "..." \
#   --r2-account "..." --r2-access "..." --r2-secret "..." \
#   --r2-bucket "voicex-video" --r2-public "https://pub-xxxx.r2.dev"
```

Artifacts: `dist/android/voicex_android_<stamp>.apk` (+ .aab si no se usa -SkipAab).

## Notas de secretos

- Las claves **no** deben quedar en `.env` para builds de distribución. Pasa todo con `--dart-define` (lo aceptan los scripts).
- `.env` se puede usar solo en desarrollo local; no lo incluyas en builds finales ni en control de versiones.
- Variables soportadas: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET`, `R2_PUBLIC_BASE`.
