HUDTweaks - Prompt Dismissal Fix

Compatibility submod for **HUDTweaks v4** in The Blood of Dawnwalker. Version 1.1.0
preserves v4's layout and visual defaults while restoring the missing local fixes:

- Let the game control both HUD prompt lines' opacity, so dismissing a prompt is not undone.
- Allow idle fading while injured (`showWhenHurt = false`); health-change notifications remain enabled.
- Revalidate local controller possession, skip menu/remote/default controllers, and safely retry unavailable or malformed player lookups.

V4's world-interaction prompt fix, child dimming, parent-based quickslot placement,
compass behavior, fade timing and visual settings remain intact. The retired
ControllerCompass feature is not included or required.

 Download and install

Get **HUDTweaks-Prompt-Dismissal-Fix.zip** from
[Releases](https://github.com/my-mods/Dawnwalker-HUDTweaks-Prompt-Fix/releases).
GitHub's source-code archives are not installable mods.

Requires original HUDTweaks **v4** and its Dawnwalker-compatible UE4SS loader.
Captured against installed Steam build 25129649 / executable CL-257186. Later
HUDTweaks and game versions require review. Release 1.1.0 is a prerelease pending
in-game validation.

1. Close the game and back up any customized HUDTweaks.ini.
2. Keep original HUDTweaks v4 enabled. Replace/reinstall the existing Prompt Dismissal
   Fix entry from this ZIP, rather than creating another installed variant.
3. Select **Root (game folder)**. This overlay must win **both** conflicts:
   `HUDTweaks/Scripts/HUDTweaks.ini` and `HUDTweaks/Scripts/main.lua`.
4. Deploy with Vortex and fully restart the game. Redeploying the older installed
   entry alone cannot add the new Lua payload or read updated version metadata.

Both payloads use the explicit archive prefix
`Dawnwalker/Binaries/Win64/ue4ss/Mods/`. Do not use ReShade Preset.
The original mod supplies enabled.txt and remains required. Current Controller
Tweaks 1.3.0+ is independent and has no HUDTweaks file conflicts; earlier controller
compass or standalone controller-compatibility entries must remain disabled.

If upgrading from broken 1.0.0 packaging, disable/remove that entry and deploy in
Vortex to remove the misplaced INI beside Dawnwalker.exe before reinstalling.

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
