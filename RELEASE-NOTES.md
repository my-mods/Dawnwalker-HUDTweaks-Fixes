# HUD Tweaks - Fixes 1.1.3

Reduce recurring HUD maintenance by using a 0.5-second auto-fade state-check delay
(previously 0.1 seconds) and a 5-second layout recheck (previously 2 seconds).
Fade animation speed, fade durations, prompt behavior, visual settings, and the
possession fix are unchanged. The Lua script is byte-identical to 1.1.2.

Activity detection may reveal the HUD a fraction of a second later. These changes
reduce how often work runs; each object search still has its existing cost.
No measured FPS or stutter improvement is claimed.

Original HUDTweaks v4 and a compatible UE4SS installation remain required.
Close the game, replace/reinstall the existing fixes entry from HUDTweaks-Fixes.zip
through Vortex as UE4SS (Lua mods), keep it after original HUDTweaks so it wins
HUDTweaks.ini and main.lua, deploy, then restart the game. Keep one fixes entry.

This is a full INI replacement, not an automatic merge. Back up custom preferences
and reapply them without overwriting the two new maintenance intervals.

Validation: exact INI diff and unchanged Lua, Lua 5.4 startup/loading/possession
regressions, actual ZIP contents/bytes, and installed Vortex installer planning.
Prerelease pending in-game validation of the slower checks: test combat entry,
lock-on, looting/dialogue prompts, damage, fades, and load/death transitions.
