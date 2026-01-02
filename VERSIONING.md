# Versioning & Branching

- Ramas: trabajo en `dev`; `main` solo para estable.
- Versión inicial: `1.0.0` en `main`.
- Regla de bumps:
  - En `dev`: cada commit sube el patch (`+0.0.1`).
  - Antes de mergear `dev` → `main`: sube el minor (`+0.1.0`, resetea patch) y crea tag `vX.Y.Z`.
- Ejemplo: `dev` pasa de `1.0.0` → `1.0.1`, `1.0.2`, etc. Merge a `main` = `1.1.0` + tag `v1.1.0`.

# Releases & CI

- Push a `main` o tag `v*` dispara `.github/workflows/release.yml`:
  - Build Windows (`flutter build windows --release`) y APK Android (`flutter build apk --release`).
  - Artefactos se suben como artifacts del workflow.
- Para auto-instalar en tu PC, usa un runner self-hosted en Windows y añade un step final que ejecute `Add-AppxPackage` sobre el `.msix`/`voicex.exe` resultante.
