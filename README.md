# HUD Tweaks - Fixes

A fixes add-on for **HUDTweaks v4** in *The Blood of Dawnwalker*.

- Keeps dismissed HUD prompts from reappearing.
- Allows the HUD to fade while injured, while keeping health-change notifications.
- Fixes player detection across loading and possession changes.
- Keeps delayed widget updates on the game thread and discards old work after a player restart.
- Checks HUD activity every 0.5 seconds and rechecks layout every 5 seconds, reducing recurring work while preserving fade animation speed.

Preserves HUDTweaks v4's layout and visual defaults. Activity changes can take an additional fraction of a second to reveal the HUD. HUD visibility watches reuse discovered widgets; unavailable or custom classes retain discovery checks.

## Requirements

- Original **HUDTweaks v4**.
- A Dawnwalker-compatible **UE4SS** installation.

## Installation

1. Download **HUDTweaks-Fixes.zip** from [Releases](https://github.com/my-mods/Dawnwalker-HUDTweaks-Fixes/releases).
2. Install it through Vortex as **UE4SS (Lua mods)**, with original HUDTweaks v4 enabled.
3. Load **HUD Tweaks - Fixes after HUDTweaks** so it wins both `main.lua` and `HUDTweaks.ini` conflicts, then deploy.

The mod replaces the full HUDTweaks INI and Lua script. Back up any custom INI settings and reapply them after installation.

For updates, replace/reinstall the existing fixes entry from the new ZIP through Vortex, keep it after original HUDTweaks, deploy, and restart the game.

Configuration: [AutoFade] checkSeconds = 0.5 controls activity detection; [General] reassertSeconds = 5.0 controls layout maintenance. Fade durations and animation cadence retain the v4 defaults. Delayed widget updates always use the game thread, including when the legacy gameThreadTimers option is disabled.

To uninstall, disable/remove this add-on and deploy through Vortex, leaving original HUDTweaks enabled.

## Compatibility

Prepared against Steam build **25129649 / CL-257186** and HUDTweaks v4. Later versions are unverified.

## Credits

Original HUDTweaks code and configuration belong to its author. This is an unofficial fixes add-on.
