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

On this PC the real display is 1920x1080 (`Win32_VideoController` `CurrentHorizontalResolution` / `CurrentVerticalResolution`) and `HKCU\Control Panel\Desktop\WindowMetrics` `AppliedDPI` is 144 (150%). A DPI-unaware process, including PowerShell, reports `Screen.Bounds` as 1280x720. That reading is the bug, not the screen size. Do not change the Windows display scale.

## Which launch the flag must match

Double-clicking `game-files\Game.rxproj` starts the long path:

```text
"C:\Program Files (x86)\Steam\steamapps\common\RPGXP\RPGXP.exe" "C:\Users\shira\Documents\evyatar\DESERT-TOWN\game-files\Game.rxproj"
```

The 8.3 value `C:\PROGRA~2\Steam\STEAMA~1\common\RPGXP\RPGXP.exe` = `~ HIGHDPIAWARE` was already present and the dialog still appeared. That entry does not apply to this launch. Leave it. Add the long path.

## Fix

Set this exact value.

```bat
reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "C:\Program Files (x86)\Steam\steamapps\common\RPGXP\RPGXP.exe" /t REG_SZ /d "~ HIGHDPIAWARE" /f
```

Confirm with `reg query` on that same long path. The data must be `~ HIGHDPIAWARE`. If the value is missing, the error is back. Re-add it.

The layer is read only when a process starts. An error dialog that is already open stays DPI-unaware (`GetProcessDpiAwareness` = 0) and keeps showing the message. Close that process, then start `RPGXP.exe` again.

Two `RPGXP.exe` processes can be open at once. Close only the error one:

- Error dialog: visible class `#32770`, title exactly `RPG Maker XP`, no `Afx` window. Small box (about 347x149).
- Editor: visible class starts with `Afx`, title `Pokemon Essentials v21.1 - RPG Maker XP`.
- Playtest: a second `#32770` titled `Now Playtesting` belongs to the editor process. Leave that process alone.

## Done when

The process that started after the registry write stays running, its visible window class starts with `Afx`, and `GetProcessDpiAwareness` is not unaware. After this long-path value, the working process reported per-monitor awareness (2).

`GetWindowRect` from DPI-unaware PowerShell virtualizes a maximized 1920x1080 editor to about -7,-7 and 1295x695. That rect does not mean the fix failed. Trust the `Afx` class and the awareness value.
