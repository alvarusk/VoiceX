; VoiceX Windows installer (Inno Setup)
; Requisitos:
;  - Instala Inno Setup (https://jrsoftware.org/isinfo.php) y añade iscc.exe al PATH (opcional).
;  - Ejecuta antes el script de empaquetado: powershell -ExecutionPolicy Bypass -File scripts/package_windows.ps1
;  - Apunta AppDir a la carpeta Release copiada (dist/windows/voicex_win_YYYYMMDD_HHMM o build/windows/x64/runner/Release).

[Setup]
AppId={{B6C4FD9E-1A2D-4C62-9D44-VOICEX}}
AppName=VoiceX
AppVersion=1.0.0
AppPublisher=VoiceX
DefaultDirName={autopf}\VoiceX
DefaultGroupName=VoiceX
OutputDir=..\dist\installer
OutputBaseFilename=voicex_installer
Compression=lzma
SolidCompression=yes
; Usa identificador compatible (evita warning deprecado)
ArchitecturesInstallIn64BitMode=x64compatible
; Puedes sobreescribir AppDir al compilar: iscc /DAppDir="C:\VoiceX\dist\windows\voicex_win_20260101_2038" scripts\voicex_installer.iss
#define AppDir "..\dist\windows\voicex_win_20260101_2038"

[Files]
; Ajusta AppDir a la carpeta con .exe y DLLs (relativo a scripts/ o absoluta si defines AppDir)
Source: "{#AppDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\VoiceX"; Filename: "{app}\VoiceX.exe"
Name: "{commondesktop}\VoiceX"; Filename: "{app}\VoiceX.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crear icono en el escritorio"; GroupDescription: "Iconos adicionales:"
