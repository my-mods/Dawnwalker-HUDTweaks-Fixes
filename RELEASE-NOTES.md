# HUDTweaks Prompt Dismissal Fix v1.0.0

Prevents HUDTweaks from reasserting opacity on the All root set and five temporary
prompt sections. This allows the game's own dismissal opacity to remain in control.

## Installation

Import `HUDTweaks-Prompt-Dismissal-Fix-1.0.0-Vortex.zip` into Vortex.
Keep HUDTweaks v2 and UE4SS installed; let this overlay win `HUDTweaks.ini`.
If using Dawnwalker Controller Tweaks, let that mod win `main.lua`.
Do not install the automatic source-code archives.

The ZIP contains a complete customized INI. Back up your existing preferences;
review and reapply your preferences after installation.

## Compatibility and testing

Prepared for Steam build 25129649 / executable CL-257186 and HUDTweaks v2.
The build checks all six expected opacity edits. Live prompt dismissal still requires
an in-game check; this is an initial testing release.
