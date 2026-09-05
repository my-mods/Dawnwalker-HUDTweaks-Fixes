# HUDTweaks Prompt Dismissal Fix

Reproducible Vortex overlay for The Blood of Dawnwalker. It prevents HUDTweaks from
reasserting non-zero `RenderOpacity` on widgets whose opacity is controlled by the game.

## Download and install

Download the Vortex mod ZIP from
[Releases](https://github.com/my-mods/Dawnwalker-HUDTweaks-Prompt-Fix/releases).
GitHub's source-code ZIP is not an installable mod.

Requires HUDTweaks v2 and a Dawnwalker-compatible UE4SS installation. Prepared against
Steam build 25129649 / executable CL-257186; later-version compatibility is unverified.

1. Close the game and import the release ZIP into Vortex.
2. Keep the original HUDTweaks mod enabled.
3. Enable this overlay and let it win `HUDTweaks/Scripts/HUDTweaks.ini`.
4. Deploy through Vortex. Disable this overlay and redeploy to uninstall.

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
