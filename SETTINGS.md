# Settings

Install [Mod Setting Menu 1.0.5 or later](https://www.nexusmods.com/thebloodofdawnwalker/mods/271) and UE4SS through Vortex. Start the game once, then open Main Menu > Mod Settings > All Mods. Select this mod, change settings and press Apply. **Fully close and restart the game after Apply.** Restore discards unapplied changes; Reset selects this mod’s defaults.

The stable menu ID is `oOCamilleOo_HUDTweaksFixes`. The mod generates `settings.ini` beside `mod_settings.ini` in its UE4SS mod folder. This generated file is the authoritative settings store and is not shipped in the ZIP. Existing supported preferences are imported on first use; legacy files are left intact and are no longer synchronized. Back up `settings.ini` before removing/reinstalling the mod or moving its folder. Restore that backup into the same runtime folder before launching. Do not restore an old INI over it.

Missing, duplicate or invalid settings stop configuration loading and are reported in `Dawnwalker/Binaries/Win64/ue4ss/UE4SS.log`. Preserve the file before correcting it. If a menu save fails, preserve its temporary/backup files and follow the menu’s recovery instructions. Settings are never polled. `debugLogging` controls additional diagnostic logging; it defaults to Off.

| Group | Setting | Choices or range |
| --- | --- | --- |
| General | enabled | Off, On |
| General | startImmediately | Off, On |
| General | debugLogging | Off, On |
| General | dumpWidgets | Off, On |
| General | dumpOnlyManaged | Off, On |
| General | dumpMaxDepth | 0 to 64 |
| General | tweakMenus | Off, On |
| AutoFade | enabled | Off, On |
| AutoFade | idleAfterSeconds | 0 to 120 |
| AutoFade | idleOpacity | 0 to 1 |
| AutoFade | fadeOutSeconds | 0 to 120 |
| AutoFade | fadeInSeconds | 0 to 120 |
| AutoFade | peekSeconds | 0 to 120 |
| AutoFade | showInCombat | Off, On |
| AutoFade | showWeaponDrawn | Off, On |
| AutoFade | showWhenLockedOn | Off, On |
| AutoFade | showInFocusMode | Off, On |
| AutoFade | showWhenAiming | Off, On |
| AutoFade | shadowstepSeconds | 0 to 120 |
| AutoFade | showWhenAimingAfter | 0 to 120 |
| AutoFade | showInFocusModeAfter | 0 to 120 |
| AutoFade | showWhenLockedOnAfter | 0 to 120 |
| AutoFade | showWeaponDrawnAfter | 0 to 120 |
| AutoFade | showWhenHurt | Off, On |
| AutoFade | showOnStatChange | Off, On |
| AutoFade | hurtBelow | 0 to 1 |
| AutoFade | hurtIncludesStamina | Off, On |
| AutoFade | statChangeIncludesStamina | Off, On |
| AutoFade | statChangeBy | 0 to 1 |
| HUD: All | opacity | -1 to 1 |
| HUD: All | scale | 0 to 5 |
| HUD: HumanStats | opacity | -1 to 1 |
| HUD: HumanStats | scale | 0 to 5 |
| HUD: HumanStats | offsetY | -10000 to 10000 |
| HUD: HumanStats | offsetX | -10000 to 10000 |
| HUD: VampireStats | opacity | -1 to 1 |
| HUD: VampireStats | scale | 0 to 5 |
| HUD: VampireStats | offsetY | -10000 to 10000 |
| HUD: VampireStats | offsetX | -10000 to 10000 |
| HUD: OverdrinkBar | opacity | -1 to 1 |
| HUD: OverdrinkBar | scale | 0 to 5 |
| HUD: OverdrinkBar | offsetY | -10000 to 10000 |
| HUD: OverdrinkBar | offsetX | -10000 to 10000 |
| HUD: WBP_HUD_VampireMutation | opacity | -1 to 1 |
| HUD: WBP_HUD_VampireMutation | scale | 0 to 5 |
| HUD: WBP_HUD_VampireMutation | offsetY | -10000 to 10000 |
| HUD: WBP_HUD_VampireMutation | offsetX | -10000 to 10000 |
| HUD: WBP_HUD_XPBar | opacity | -1 to 1 |
| HUD: WBP_HUD_XPBar | scale | 0 to 5 |
| HUD: WBP_HUD_XPBar | offsetY | -10000 to 10000 |
| HUD: WBP_HUD_XPBar | offsetX | -10000 to 10000 |
| HUD: WBP_HUD_FocusCharge_Bar | opacity | -1 to 1 |
| HUD: WBP_HUD_FocusCharge_Bar | scale | 0 to 5 |
| HUD: WBP_HUD_FocusCharge_Bar | offsetY | -10000 to 10000 |
| HUD: WBP_HUD_FocusCharge_Bar | offsetX | -10000 to 10000 |
| HUD: WBP_HUD_SpecialAttackCooldown | opacity | -1 to 1 |
| HUD: WBP_HUD_SpecialAttackCooldown | scale | 0 to 5 |
| HUD: WBP_HUD_SpecialAttackCooldown | offsetY | -10000 to 10000 |
| HUD: WBP_HUD_SpecialAttackCooldown | offsetX | -10000 to 10000 |
| HUD: WBP_SkipButton | opacity | -1 to 1 |
| HUD: WBP_SkipButton | scale | 0 to 5 |
| HUD: WBP_OpenFocusPrompt | opacity | -1 to 1 |
| HUD: WBP_OpenFocusPrompt | force | Off, On |
| HUD: WBP_OpenFocusPrompt | scale | 0 to 5 |
| HUD: WBP_OpenFocusPrompt | offsetY | -10000 to 10000 |
| HUD: WBP_OpenFocusPrompt | offsetX | -10000 to 10000 |
| HUD: WBP_CombatTargetIndicator | opacity | -1 to 1 |
| HUD: WBP_Combat_AttackWarning | opacity | -1 to 1 |
| HUD: WBP_Compass | opacity | -1 to 1 |
| HUD: WBP_Compass | scale | 0 to 5 |
| HUD: WBP_Compass | offsetY | -10000 to 10000 |
| HUD: WBP_HUD_QuestInfo | opacity | -1 to 1 |
| HUD: WBP_HudTimer | opacity | -1 to 1 |
| HUD: WBP_HudTimer | scale | 0 to 5 |
| HUD: WBP_HudTimer | offsetY | -10000 to 10000 |
| HUD: WBP_HudTimer | offsetX | -10000 to 10000 |
| HUD: WBP_NotificationPanel | scale | 0 to 5 |
| HUD: WBP_NotificationPanel | offsetX | -10000 to 10000 |
| HUD: WBP_NotificationPanel | opacity | -1 to 1 |
| HUD: WBP_HUD_Quickslots | opacity | -1 to 1 |
| HUD: WBP_HUD_Quickslots | scale | 0 to 5 |
| HUD: WBP_HUD_Quickslots | offsetY | -10000 to 10000 |
| HUD: WBP_HUD_Quickslots | offsetX | -10000 to 10000 |
| HUD: WBP_AA_Quickslots | opacity | -1 to 1 |
| HUD: WBP_AA_Quickslots | scale | 0 to 5 |
| HUD: WBP_AA_Quickslots | offsetY | -10000 to 10000 |
| HUD: WBP_AA_Quickslots | offsetX | -10000 to 10000 |
| HUD: QuickslotContainer/Overlay_2/CommonVisualAttachment_0 | opacity | -1 to 1 |
| HUD: QuickslotContainer/Overlay_2/CommonVisualAttachment_0 | scale | 0 to 5 |
| HUD: QuickslotContainer/Overlay_2/CommonVisualAttachment_0 | offsetX | -10000 to 10000 |
| HUD: QuickslotContainer/Overlay_2/CommonVisualAttachment_0 | offsetY | -10000 to 10000 |
| HUD: WBP_HUD_Quickslots_ChangePrompt | opacity | -1 to 1 |
| HUD: WBP_HUD_Quickslots_ChangePrompt | scale | 0 to 5 |
| HUD: WBP_HUD_Quickslots_ChangePrompt | offsetX | -10000 to 10000 |
| HUD: WBP_HUD_Quickslots_ChangePrompt | offsetY | -10000 to 10000 |
| HUD: WBP_HUD_Quickslots_ChangePrompt | reassert | Off, On |
| HUD: WBP_BuffContainer | opacity | -1 to 1 |
| HUD: WBP_BuffContainer | scale | 0 to 5 |
| HUD: WBP_ControlsLegend | opacity | -1 to 1 |
| HUD: WBP_ControlsLegend | scale | 0 to 5 |
| HUD: WBP_ControlsLegend | offsetY | -10000 to 10000 |
| HUD: WBP_ControlsLegend | offsetX | -10000 to 10000 |
| HUD: WBP_InputPrompt | opacity | -1 to 1 |
| HUD: WBP_InputPrompt | scale | 0 to 5 |
| HUD: WBP_InputPrompt | offsetY | -10000 to 10000 |
| HUD: WBP_SecondInputPrompt | opacity | -1 to 1 |
| HUD: WBP_SecondInputPrompt | scale | 0 to 5 |
| HUD: WBP_SecondInputPrompt | offsetY | -10000 to 10000 |
| HUD: WBP_SecondInputPrompt | offsetX | -10000 to 10000 |
| HUD: WBP_InteractablePrompt | opacity | -1 to 1 |
| HUD: WBP_InteractablePrompt | scale | 0 to 5 |
| HUD: WBP_InteractablePrompt_AbilityVariant | opacity | -1 to 1 |
| HUD: WBP_InteractablePrompt_AbilityVariant | scale | 0 to 5 |
| HUD: WBP_InteractablePrompt/* | opacity | -1 to 1 |
| HUD: WBP_InteractablePrompt/* | scale | 0 to 5 |
| HUD: WBP_InteractablePrompt_AbilityVariant/* | opacity | -1 to 1 |
| HUD: WBP_InteractablePrompt_AbilityVariant/* | scale | 0 to 5 |
| HUD: WBP_Dialogue_ChoiceBox | scale | 0 to 5 |
| HUD: WBP_Dialogue_ChoiceBox | opacity | -1 to 1 |
| HUD: WBP_Dialogue_ChoiceBox/* | opacity | -1 to 1 |
| HUD: WBP_Dialogue_ChoiceBox/* | scale | 0 to 5 |
| HUD: WBP_MediumTutorialPopup | opacity | -1 to 1 |
| HUD: WBP_MediumTutorialPopup | force | Off, On |
| HUD: WBP_GameplayDialogue_OverheadSubtitle | opacity | -1 to 1 |

HUD Tweaks also creates `Scripts/HUDTweaks.advanced.ini` on first use, copying the existing HUDTweaks INI or shipped defaults. This preserves advanced class paths, wildcard selectors, text lists and key bindings that the numeric menu cannot represent. Numeric settings in that snapshot are superseded by the menu. Back up this file alongside `settings.ini`. Existing HUDTweaks.ini files remain unchanged. Threading and scheduler controls are fixed implementation settings and are not exposed in the menu.

Console commands are not used to change settings.

Conditional rows and groups show relevant controls as you edit. Hidden options keep their saved values; hiding an option does not reset it. The interface uses toggles, labeled choices and sliders; the numeric representation in settings.ini is an implementation detail.
