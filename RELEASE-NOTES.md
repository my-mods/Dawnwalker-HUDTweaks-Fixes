# HUD Tweaks - Fixes 1.1.2

Fix repeated Vortex external-change warnings by using the same **UE4SS (Lua mods)**
deployment type as original HUDTweaks. The old Root package reached the correct
files through a separate deployment record, causing false external modifications
and potentially contaminating the original staging copy when changes were saved.

The ZIP now places its single Lua/INI payloads under Data/HUDTweaks/Scripts. The
installed extension strips Data and routes both to the original HUDTweaks Scripts
directory as dawnwalker-ue4ss. Display name, ID and ZIP filename stay unchanged.
Runtime bytes are identical to 1.1.1. Original HUDTweaks v4 remains required.

Repair: close the game, cancel a pending deployment, and Purge Mods through Vortex.
For the two HUDTweaks reference changes, select Revert change (use staging file),
not Save/Use newer. Remove both installed HUDTweaks and old fixes entries while
keeping downloaded archives. Reinstall original Nexus v4 and this 1.1.2 ZIP. Both
must use UE4SS (Lua mods); set HUD Tweaks - Fixes after original HUDTweaks and deploy.
Keep one fixes entry. Do not edit hardlinks, staging or inventories manually.

Full INI/Lua replacement; back up custom preferences. Runtime files are unchanged.
Native checks remain pending; prerelease.
