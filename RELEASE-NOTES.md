# HUD Tweaks - Fixes 1.1.1

The former Prompt Dismissal Fix is now **HUD Tweaks - Fixes**. Its scope includes
prompt dismissal, idle fading while injured and robust player lookup through
loading/possession changes. Repository history and prior releases are preserved.

New repository: my-mods/Dawnwalker-HUDTweaks-Fixes.
New archive: HUDTweaks-Fixes.zip. New manifest ID: HUDTweaksFixes.
The Lua and INI are byte-for-byte identical to 1.1.0; v4's layout/visuals remain intact.

Requires original HUDTweaks v4 and its Dawnwalker-compatible UE4SS installation.
Replace/reinstall the existing Prompt Dismissal Fix entry in Vortex using this ZIP;
select Root (game folder). Let HUD Tweaks - Fixes win BOTH main.lua and HUDTweaks.ini
under HUDTweaks/Scripts, deploy and fully restart the game. If Vortex creates a
separate entry, disable/remove the old overlay and deploy with Vortex; keep only one
fixes overlay enabled. The renamed ZIP does not automatically merge installed entries.

This is still a full INI and Lua replacement, not an automatic preferences merge.
Back up custom settings. Current Controller Tweaks remains independent. Disable this
overlay and deploy to restore original HUDTweaks files. Do not apply over newer
HUDTweaks versions without review.

Validation: unchanged runtime hashes versus 1.1.0, actual ZIP allowlist and metadata,
two builds using the new stable filename, and installed Vortex destination planning.
The existing Lua 5.4/lifecycle regressions remain applicable. In-game prompt dismissal,
injured idle fade, and loading/possession checks remain pending; retained as prerelease.
