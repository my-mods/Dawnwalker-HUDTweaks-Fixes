HUD Tweaks - Fixes

Fixes and compatibility backports for **HUDTweaks v4** in The Blood of Dawnwalker. Version 1.1.2
preserves v4's layout and visual defaults while restoring the missing local fixes:

- Let the game control both HUD prompt lines' opacity, so dismissing a prompt is not undone.
- Allow idle fading while injured (`showWhenHurt = false`); health-change notifications remain enabled.
- Revalidate local controller possession, skip menu/remote/default controllers, and safely retry unavailable or malformed player lookups.

V4's world-interaction prompt fix, child dimming, parent-based quickslot placement,
compass behavior, fade timing and visual settings remain intact. The retired
ControllerCompass feature is not included or required.

 Download and install

Get **HUDTweaks-Fixes.zip** from
[Releases](https://github.com/my-mods/Dawnwalker-HUDTweaks-Fixes/releases).
GitHub's source-code archives are not installable mods.

Requires original HUDTweaks **v4** and its Dawnwalker-compatible UE4SS loader.
Captured against installed Steam build 25129649 / executable CL-257186. Later
HUDTweaks and game versions require review. Release 1.1.2 is a prerelease pending
in-game validation.

1. Close the game and back up any custom HUDTweaks.ini preferences.
2. Keep original HUDTweaks v4 enabled. Replace/reinstall this overlay from the new
   ZIP. Select **UE4SS (Lua mods)**, matching the original mod's type.
3. Set **HUD Tweaks - Fixes after original HUDTweaks** so its main.lua and
   HUDTweaks.ini win the file conflicts. Deploy through Vortex and restart the game.

The ZIP contains one copy of each payload under `Data/HUDTweaks/Scripts/`.
The installed Dawnwalker extension strips Data and deploys to
`Dawnwalker/Binaries/Win64/ue4ss/Mods/HUDTweaks/Scripts/`.
Original HUDTweaks supplies enabled.txt and remains required. Current Controller
Tweaks is independent and does not conflict with this submod.

 Repairing an installation from 1.1.1 or earlier

The old Root package collided with original HUDTweaks deployed as UE4SS. Each
deployment type tracked the same files independently, causing repeated external
change warnings. Version 1.1.2 fixes the packaging, not the Lua/INI.

1. Cancel any pending deployment dialog. Close the game. In Vortex, **Purge Mods**.
   If it asks about the two HUDTweaks Lua/INI reference changes, choose **Revert
   change (use staging file)**. Do not use Save or Use newer file to resolve this
   packaging collision. Handle unrelated mods separately.
2. Remove the installed original HUDTweaks and old fixes entries in Vortex while
   keeping their downloaded archives. Previous external-change handling may have
   linked the two staging copies together; rebuilding just one may retain that state.
3. Reinstall original HUDTweaks from the clean Nexus v4 download and this submod
   from **HUDTweaks-Fixes.zip version 1.1.2**. Both must be **UE4SS (Lua mods)**.
4. Enable both, set fixes after original HUDTweaks, and deploy. Keep one fixes entry.
   Repeating Deploy on the old installed entry cannot change its stored layout.

All purge/remove/reinstall actions belong to Vortex. Do not edit staging files,
hardlinks or deployment records manually. If custom preferences existed, reapply
them deliberately after repair; this ZIP is a full-file replacement.

 Rename and migration

Version 1.1.1 renames **Prompt Dismissal Fix** to **HUD Tweaks - Fixes** to reflect
the broader scope. The repository is now `my-mods/Dawnwalker-HUDTweaks-Fixes`, the
archive is `HUDTweaks-Fixes.zip`, and the internal manifest ID is `HUDTweaksFixes`.
The existing repository, commits and historical releases are preserved. Runtime
Lua and INI payloads are byte-for-byte identical to 1.1.0.

The new filename does not automatically merge Vortex entries. If Vortex imports a
separate entry, disable/remove the old Prompt Dismissal Fix entry and deploy through
Vortex, then enable this one and set both conflict winners. Do not run both overlays.
Replacing/reinstalling also lets Vortex remove the old package layout note; ordinary
redeployment cannot read the new archive name/version metadata.

 Configuration and uninstall

This ZIP replaces the **full v4 INI and main.lua**. It does not automatically merge
preferences. Exactly three INI values change; all other v4 INI bytes are retained.
Any later custom preferences should be backed up and reviewed/reapplied explicitly.
Do not apply this v4 Lua replacement over a future HUDTweaks release without review.

Disable/remove this overlay and deploy through Vortex to restore original v4 files.
Leave original HUDTweaks enabled if you still want its functionality.

 Reproducible maintenance

 Credits and scope

The original HUDTweaks Lua and configuration belong to their author. This repository
is an unofficial compatibility overlay; it grants no new license over third-party
content. Only the three INI changes and isolated pawn lookup are maintained here. The upstream world-prompt and quickslot fixes are retained,
not claimed as local work. Report issues with versions, symptoms, UE4SS.log and both
Vortex conflict winners.
