# HUD Tweaks - Fixes

A fixes add-on for **HUDTweaks v4** in *The Blood of Dawnwalker*.

- Keeps dismissed HUD prompts from reappearing.
- Allows the HUD to fade while injured, while keeping health-change notifications.
- Fixes player detection across loading and possession changes.
- Keeps delayed widget updates on the game thread and discards old work after a player restart.
- Checks HUD activity every 0.5 seconds and rechecks layout every 5 seconds, reducing recurring work while preserving fade animation speed.

Preserves HUDTweaks v4's layout and visual defaults. Activity changes can take an additional fraction of a second to reveal the HUD. Tracks widget creation instead of repeatedly searching all objects, and spreads large updates across frames.

## Requirements

- Original **HUDTweaks v4**.
- A Dawnwalker-compatible **UE4SS** installation.

## Installation

Install original HUDTweaks v4, UE4SS, and Mod Setting Menu 1.0.5 or later through Vortex. Replace this mod using its existing entry and let it win the Lua script conflict with HUDTweaks. This update adds files and retires the packaged HUDTweaks.ini override, so reinstall the updated ZIP through the installer.

Back up your existing HUDTweaks.ini before replacement: previous versions replaced the full INI. Restore that backed-up file as the legacy input before the first launch if Vortex restored upstream defaults during replacement. This version imports it, verifies the new menu settings and advanced snapshot, then removes the migrated legacy file. See SETTINGS.md for the generated settings and advanced-snapshot backup paths.

## Compatibility

Prepared against Steam build **25129649 / CL-257186** and HUDTweaks v4. Later versions are unverified.

## Credits

Original HUDTweaks code and configuration belong to its author. This is an unofficial fixes add-on.

Debug output is controlled by the Debug logging toggle in Mod Settings. Apply, then restart.

## Settings

Use Mod Setting Menu 1.0.5 or later, Apply, then fully restart. See [SETTINGS.md](SETTINGS.md) for controls, migration and backups.
