---
name: desert-town-rpgxp-resolution
description: >-
  Fix RPG Maker XP "Cannot run with less than 1024 x 768 resolution."
  Windows display scale makes DPI-unaware RPGXP.exe see 1280x720 on a
  1920x1080 screen at 150%. Set the AppCompat HIGHDPIAWARE layer on the
  long path of RPGXP.exe. Use when RPG Maker XP shows that dialog, the
  Hebrew OK button אישור, or the editor will not start because of resolution.
---

# RPG Maker XP 1024x768 startup error

The dialog is from `RPGXP.exe`, before the editor window opens. The screen is large enough. Windows scale (150% on 1920x1080) makes an unaware process see 1280x720, and 720 is under 768.

## Fix

Set this exact value. A short path such as `C:\PROGRA~2\...` does not match a normal or Steam launch.

```bat
reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "C:\Program Files (x86)\Steam\steamapps\common\RPGXP\RPGXP.exe" /t REG_SZ /d "~ HIGHDPIAWARE" /f
```

Confirm with `reg query` on that same long path. The data must be `~ HIGHDPIAWARE`. If the value is missing, the error is back. Re-add it. Do not change the Windows display scale.

Then start `RPGXP.exe`. Close an already-open error dialog first so the old process is not the one still on screen.

## Done when

The process stays running and its visible window class starts with `Afx` (the editor). The error dialog is a small message box, not that window.
