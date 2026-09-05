# HUDTweaks - Prompt Dismissal Fix v1.0.4

The ZIP now generates vortex_override_instructions.json from mod.manifest, so Vortex sets the display name, version, and description during installation. Runtime payloads and file destinations are unchanged.

Replace/reinstall the updated ZIP through Vortex using the existing mod entry, then deploy. Redeployment alone cannot read new archive metadata. This does not provide automatic update discovery or merge duplicate Vortex entries.

Archive filename: HUDTweaks-Prompt-Dismissal-Fix.zip

Validation: ZIP allowlist, manifest/attribute agreement, UTF-8 without BOM, installed Vortex attribute merge, and installer destination planning. Lua and INI hashes match the previous local release. 

No live Vortex installation/deployment or in-game test is performed for this packaging update. Confirm the displayed name, version, and description after reinstalling. Previous in-game acceptance checks remain applicable.

Requires HUDTweaks v2 and UE4SS. This fix wins Scripts/HUDTweaks.ini; Controller Tweaks wins Scripts/main.lua. Use Root (game folder). This is a full customized INI replacement: back up preferences and reapply your preferences if needed; preferences are not automatically merged. Prompt dismissal still needs an in-game acceptance check; this is a prerelease.

Verified local archive: 13648 bytes; SHA-256 `FC93BCBDF69171B6DBC6ED441BF74DB9AF55D4083E80FDFC825DEBC8CFC99185`.
