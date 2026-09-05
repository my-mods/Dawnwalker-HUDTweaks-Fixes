# HUDTweaks Prompt Dismissal Fix

Reproducible Vortex overlay for The Blood of Dawnwalker. It prevents HUDTweaks from
reasserting non-zero `RenderOpacity` on widgets whose opacity is controlled by the game.

## Download and install

Download the Vortex mod ZIP from
[Releases](https://github.com/my-mods/Dawnwalker-HUDTweaks-Prompt-Fix/releases).
GitHub's source-code ZIP is not an installable mod.

Requires HUDTweaks v2 and a Dawnwalker-compatible UE4SS installation. Prepared against
Steam build 25129649 / executable CL-257186; later-version compatibility is unverified.

1. Close the game. If v1.0.0 is installed, disable/remove that installed mod in Vortex
   and deploy so Vortex removes its misplaced `Dawnwalker/Binaries/Win64/HUDTweaks.ini`.
2. Import `HUDTweaks-Prompt-Dismissal-Fix-1.0.1-Vortex.zip` as a fresh installation.
   Redeploying the existing v1.0.0 installation cannot repair its stored layout.
3. Keep the original HUDTweaks mod enabled. The new overlay should use Vortex's
   **Root (game folder)** type, not ReShade Preset.
4. Enable this overlay and let it win the active `HUDTweaks/Scripts/HUDTweaks.ini`
   conflict, then deploy. Disable this overlay and redeploy to uninstall.

The only INI in the archive has this explicit game-root-relative destination:

```text
Dawnwalker/Binaries/Win64/ue4ss/Mods/HUDTweaks/Scripts/HUDTweaks.ini
```

Version 1.0.0 used `Data/HUDTweaks/Scripts/HUDTweaks.ini`. The installed Vortex
extension misclassified that INI-only layout as a ReShade preset and flattened it to
`HUDTweaks.ini` beside the executable. Version 1.0.1 selects the game-root installer.
Root-level `Data/` now contains only a layout note, never a second INI.

If using [Dawnwalker Controller Tweaks](https://github.com/my-mods/Dawnwalker-Controller-Tweaks),
that mod wins `main.lua`; this overlay wins `HUDTweaks.ini`. They address different files.

## Scope and limitations

The patch unsets opacity for `All` and five dynamic prompt sections, allowing the game
to dismiss them without HUDTweaks repeatedly restoring a nonzero opacity.
It does not disable tutorials or change game input bindings.

In-game validation remains pending; this release is a prerelease.

## Credits and issues

This is an unofficial compatibility overlay for HUDTweaks, not the original mod.
The upstream configuration belongs to its respective author; no new license is
granted to third-party content. Report issues with the game/HUDTweaks versions,
the affected prompt, and Vortex's INI conflict winner.
