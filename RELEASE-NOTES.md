# HUDTweaks Prompt Dismissal Fix v1.0.3

Fix the documentation-only Data/PACKAGE-LAYOUT.txt conflict between the two mods.
This archive uses Data/HUDTweaks-Prompt-Dismissal-Fix-PACKAGE-LAYOUT.txt instead.
Replace/reinstall the existing Vortex entry with this updated ZIP, then deploy so
Vortex removes the old shared note. Redeploying the previous archive is insufficient.
ZIP filenames remain unchanged. Runtime behavior and required HUDTweaks conflicts
are unchanged. This release does not add Vortex metadata display support.

Packaging-only update: always use `HUDTweaks-Prompt-Dismissal-Fix.zip`. Versions remain in metadata and release tags, not the filename.
The corrected installation paths and all six opacity fixes are unchanged from 1.0.1.

Fixes the installation paths. The previous INI-only Data layout was detected as a
ReShade preset, flattening HUDTweaks.ini beside Dawnwalker.exe. This archive uses
explicit game-root paths and Vortex's Root installer instead.

Prevents HUDTweaks from reasserting opacity on the All root set and five temporary
prompt sections. This allows the game's own dismissal opacity to remain in control.

## Installation

1. Close the game. Disable/remove the old v1.0.0 installation in Vortex and deploy
   to remove its misplaced INI.
2. Import `HUDTweaks-Prompt-Dismissal-Fix.zip` using Vortex's replace/update flow
   for the same mod entry. Migrating from v1.0.0 needs the new archive processed by
   the installer; simply redeploying that old installation does not repair its paths.
3. Confirm Root (game folder) type, enable and deploy.

Keep HUDTweaks v2 and UE4SS installed; let this overlay win `HUDTweaks.ini`.
If using Dawnwalker Controller Tweaks, let that mod win `main.lua`.
Do not install the automatic source-code archives.

The single INI must land at:
`Dawnwalker/Binaries/Win64/ue4ss/Mods/HUDTweaks/Scripts/HUDTweaks.ini`

The ZIP contains a complete customized INI. Back up your existing preferences;
review and reapply your preferences after installation.

## Compatibility and testing

Prepared for Steam build 25129649 / executable CL-257186 and HUDTweaks v2.
The actual ZIP passes exact-path, payload-byte, and six-opacity-edit checks.
The installed Vortex extension reproduces v1.0.0's ReShade routing and selects the
correct game-root destination for v1.0.1. Deployment and live prompt dismissal still
require a user-controlled test; this remains a prerelease.
