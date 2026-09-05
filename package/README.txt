HUDTWEAKS - PROMPT DISMISSAL FIX 1.0.1
======================================

Game: The Blood of Dawnwalker (PC)
Built for Steam build 25129649 / executable CL-257186.
Requires: HUDTweaks v2 and a working Dawnwalker-compatible UE4SS installation.

WHAT THIS FIXES
---------------
HUDTweaks was managing RenderOpacity on the complete [All] root set and on several
temporary prompt widgets. Dawnwalker uses that same RenderOpacity property to dismiss
some tutorial, interaction and quickslot prompts. Every HUDTweaks reassert cycle restored
the configured non-zero opacity, so prompts such as "press X to pick up the training
sword" could remain on screen indefinitely.

This replacement HUDTweaks.ini:
- leaves [All] opacity unset;
- leaves opacity unset on WBP_InputPrompt, WBP_SecondInputPrompt,
  WBP_InteractablePrompt, WBP_InteractablePrompt_AbilityVariant, and
  WBP_HUD_Quickslots_ChangePrompt;
- preserves all existing scale, offset, auto-fade and per-element customizations.

VORTEX INSTALLATION
-------------------
1. Close the game. Disable/remove the installed v1.0.0 mod in Vortex and deploy to
   remove its misplaced INI beside Dawnwalker.exe.
2. Import this v1.0.1 ZIP as a fresh installation, not just a redeploy of the old entry.
   Vortex must select Root (game folder), not ReShade Preset.
3. Enable and deploy. When Vortex reports a file conflict with HUDTweaks, make this fix load AFTER / WIN
   over HUDTweaks for HUDTweaks\Scripts\HUDTweaks.ini.
4. Keep the original HUDTweaks mod enabled because it supplies main.lua and enabled.txt.

The INI must deploy to this path relative to the game root:
  Dawnwalker/Binaries/Win64/ue4ss/Mods/HUDTweaks/Scripts/HUDTweaks.ini
There is exactly one INI in the archive. Data contains only a package-layout note.
Version 1.0.0 was misclassified as a ReShade preset, so redeploying that existing
installation cannot fix its destination. Do not manually alter Vortex hardlinks.

UNINSTALLATION
--------------
Disable/remove this fix in Vortex and deploy again. The original HUDTweaks.ini will win.

NOTES
-----
This mod does not touch the game installation directly and contains no packaged game assets.
Compatibility reference: Steam build 25129649 / executable CL-257186.
Compatibility with later game/HUDTweaks versions is not established.
The ZIP contains a full customized INI, not an automatic merge with your preferences.
Back up your INI and rebuild from it if you want to retain different HUD settings.
Build-time checks verify all six opacity edits and reproduce Vortex's old misrouting.
The installed Vortex extension routes this ZIP to the correct HUDTweaks Scripts path.
Actual deployment and live prompt dismissal still need a user-controlled in-game check.
