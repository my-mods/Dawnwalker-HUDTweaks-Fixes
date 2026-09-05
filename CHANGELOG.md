# Changes

## 1.1.2 — 2026-09-05

- Fix cross-type Vortex ownership collisions and repeated external-change warnings.
- Package Data/HUDTweaks/Scripts as dawnwalker-ue4ss, matching original HUDTweaks.
- Preserve runtime bytes and stable mod identity; document Vortex-managed repair.

## 1.1.1 — 2026-09-05

- Rename the mod to HUD Tweaks - Fixes to reflect the broader scope.
- Rename the repository to my-mods/Dawnwalker-HUDTweaks-Fixes, archive to
  HUDTweaks-Fixes.zip and manifest ID to HUDTweaksFixes.
- Update descriptions, Vortex metadata, packaging and migration documentation.
- Preserve repository history, prior releases and unchanged 1.1.0 runtime payloads.

## 1.1.0 — 2026-09-05

- Rebase on HUDTweaks v4, retaining its layout and visual defaults.
- Use opacity = game on the two HUD prompt lines; allow idle fading while injured.
- Port possession-safe player lookup with guarded collections and retry behavior.
- Add the patched v4 main.lua to the same stable ZIP; overlay now wins both Lua and INI.

## 1.0.4 — 2026-09-05

- Generate Vortex display name, version, and description in the release archive.
- Preserve the existing ZIP filename and runtime payloads. Reinstall/replace through Vortex to read metadata.

## 1.0.3 — 2026-09-05

- Rename the Data layout note to HUDTweaks-Prompt-Dismissal-Fix-PACKAGE-LAYOUT.txt.
- Exclude the old shared note from archives.
- Keep the stable ZIP filename and existing runtime behavior.

## 1.0.2 — 2026-09-05

- Use HUDTweaks-Prompt-Dismissal-Fix.zip, with no version suffix.
- Keep version numbers in metadata and release tags; update one Vortex mod entry.
- The installation paths and fixed INI are unchanged from 1.0.1.

## 1.0.1 — 2026-09-05

- Correct the archive destination to the full Dawnwalker game-root path.
- Prevent Vortex from treating this INI-only overlay as a ReShade preset.
- Include exactly one INI; keep Data at the root with a layout note only.

- Document fresh-import migration and Vortex-managed removal of the misplaced old INI.
- INI fix contents, other HUD settings, mod name, and internal mod ID remain unchanged.

## 1.0.0 — 2026-09-05

- Initial six-section opacity overlay.
- Known packaging defect: Vortex routes the INI beside the executable, not to HUDTweaks.
