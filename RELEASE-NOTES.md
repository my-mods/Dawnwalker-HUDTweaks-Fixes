# HUDTweaks - Prompt Dismissal Fix 1.1.0

Rebase the existing compatibility submod onto HUDTweaks v4 while preserving its
layout and visual defaults. Restore game-controlled opacity for both HUD prompt
lines, idle fading while injured, and robust player lookup through loading and
possession changes. Preserve v4's world-prompt fix and parent-based quickslot layout.

Requires original HUDTweaks v4 and its UE4SS loader. No ControllerCompass dependency.
Replace/reinstall the existing Vortex overlay from HUDTweaks-Prompt-Dismissal-Fix.zip,
select Root (game folder), and let it win BOTH main.lua and HUDTweaks.ini in
HUDTweaks/Scripts. Deploy via Vortex and fully restart the game.

This contains a full v4 INI and patched Lua replacement, not an automatic preferences
merge. Back up custom settings. Do not use over later HUDTweaks versions without review.
Current Controller Tweaks remains independent. Disable the overlay and deploy to
restore original HUDTweaks files.

Validation: full Lua 5.4 compilation; mocked startup/client restart and player
lifecycle regressions; malformed/throwing lookup recovery; prompt opacity and fade
exclusion checks; exact three-value INI diff; isolated Lua patch; upstream drift
rejection; actual-ZIP allowlist and bytes; two consecutive stable-name builds;
installed Vortex 2.6.3 installer and metadata planning against mocked state.

Prerelease: not installed or tested in game by this build. Acceptance checks remain
prompt dismissal, drawing/sheathing quickslot position, dialogue dismissal,
injured idle fading, and loading/save/possession transitions. Captured installed
Steam build 25129649 / CL-257186; no broader current-patch compatibility claim.
