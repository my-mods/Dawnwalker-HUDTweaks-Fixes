-- Import legacy HUD settings once. Keep advanced text separate from numeric menu values. MIT.
local directory = assert(debug.getinfo(1,'S').source:sub(2):match('^(.*[/\\])'))
local Store = dofile(directory .. 'SettingsStore.lua')
local schema = dofile(directory .. 'SettingsSchema.lua')
local fields = {
 {"General_enabled","general","enabled","bool"},
 {"General_startImmediately","general","startimmediately","bool"},
 {"debugLogging","general","debuglogging","bool"},
 {"General_dumpWidgets","general","dumpwidgets","bool"},
 {"General_dumpOnlyManaged","general","dumponlymanaged","bool"},
 {"General_dumpMaxDepth","general","dumpmaxdepth","number"},
 {"General_tweakMenus","general","tweakmenus","bool"},
 {"AutoFade_enabled","autofade","enabled","bool"},
 {"AutoFade_idleAfterSeconds","autofade","idleafterseconds","number"},
 {"AutoFade_idleOpacity","autofade","idleopacity","number"},
 {"AutoFade_fadeOutSeconds","autofade","fadeoutseconds","number"},
 {"AutoFade_fadeInSeconds","autofade","fadeinseconds","number"},
 {"AutoFade_peekSeconds","autofade","peekseconds","number"},
 {"AutoFade_showInCombat","autofade","showincombat","bool"},
 {"AutoFade_showWeaponDrawn","autofade","showweapondrawn","bool"},
 {"AutoFade_showWhenLockedOn","autofade","showwhenlockedon","bool"},
 {"AutoFade_showInFocusMode","autofade","showinfocusmode","bool"},
 {"AutoFade_showWhenAiming","autofade","showwhenaiming","bool"},
 {"AutoFade_shadowstepSeconds","autofade","shadowstepseconds","number"},
 {"AutoFade_showWhenAimingAfter","autofade","showwhenaimingafter","number"},
 {"AutoFade_showInFocusModeAfter","autofade","showinfocusmodeafter","number"},
 {"AutoFade_showWhenLockedOnAfter","autofade","showwhenlockedonafter","number"},
 {"AutoFade_showWeaponDrawnAfter","autofade","showweapondrawnafter","number"},
 {"AutoFade_showWhenHurt","autofade","showwhenhurt","bool"},
 {"AutoFade_showOnStatChange","autofade","showonstatchange","bool"},
 {"AutoFade_hurtBelow","autofade","hurtbelow","number"},
 {"AutoFade_hurtIncludesStamina","autofade","hurtincludesstamina","bool"},
 {"AutoFade_statChangeIncludesStamina","autofade","statchangeincludesstamina","bool"},
 {"AutoFade_statChangeBy","autofade","statchangeby","number"},
 {"All_opacity","all","opacity","number"},
 {"All_scale","all","scale","number"},
 {"HumanStats_opacity","humanstats","opacity","number"},
 {"HumanStats_scale","humanstats","scale","number"},
 {"HumanStats_offsetY","humanstats","offsety","number"},
 {"HumanStats_offsetX","humanstats","offsetx","number"},
 {"VampireStats_opacity","vampirestats","opacity","number"},
 {"VampireStats_scale","vampirestats","scale","number"},
 {"VampireStats_offsetY","vampirestats","offsety","number"},
 {"VampireStats_offsetX","vampirestats","offsetx","number"},
 {"OverdrinkBar_opacity","overdrinkbar","opacity","number"},
 {"OverdrinkBar_scale","overdrinkbar","scale","number"},
 {"OverdrinkBar_offsetY","overdrinkbar","offsety","number"},
 {"OverdrinkBar_offsetX","overdrinkbar","offsetx","number"},
 {"WBP_HUD_VampireMutation_opacity","wbp_hud_vampiremutation","opacity","number"},
 {"WBP_HUD_VampireMutation_scale","wbp_hud_vampiremutation","scale","number"},
 {"WBP_HUD_VampireMutation_offsetY","wbp_hud_vampiremutation","offsety","number"},
 {"WBP_HUD_VampireMutation_offsetX","wbp_hud_vampiremutation","offsetx","number"},
 {"WBP_HUD_XPBar_opacity","wbp_hud_xpbar","opacity","number"},
 {"WBP_HUD_XPBar_scale","wbp_hud_xpbar","scale","number"},
 {"WBP_HUD_XPBar_offsetY","wbp_hud_xpbar","offsety","number"},
 {"WBP_HUD_XPBar_offsetX","wbp_hud_xpbar","offsetx","number"},
 {"WBP_HUD_FocusCharge_Bar_opacity","wbp_hud_focuscharge_bar","opacity","number"},
 {"WBP_HUD_FocusCharge_Bar_scale","wbp_hud_focuscharge_bar","scale","number"},
 {"WBP_HUD_FocusCharge_Bar_offsetY","wbp_hud_focuscharge_bar","offsety","number"},
 {"WBP_HUD_FocusCharge_Bar_offsetX","wbp_hud_focuscharge_bar","offsetx","number"},
 {"WBP_HUD_SpecialAttackCooldown_opacity","wbp_hud_specialattackcooldown","opacity","number"},
 {"WBP_HUD_SpecialAttackCooldown_scale","wbp_hud_specialattackcooldown","scale","number"},
 {"WBP_HUD_SpecialAttackCooldown_offsetY","wbp_hud_specialattackcooldown","offsety","number"},
 {"WBP_HUD_SpecialAttackCooldown_offsetX","wbp_hud_specialattackcooldown","offsetx","number"},
 {"WBP_SkipButton_opacity","wbp_skipbutton","opacity","number"},
 {"WBP_SkipButton_scale","wbp_skipbutton","scale","number"},
 {"WBP_OpenFocusPrompt_opacity","wbp_openfocusprompt","opacity","number"},
 {"WBP_OpenFocusPrompt_force","wbp_openfocusprompt","force","bool"},
 {"WBP_OpenFocusPrompt_scale","wbp_openfocusprompt","scale","number"},
 {"WBP_OpenFocusPrompt_offsetY","wbp_openfocusprompt","offsety","number"},
 {"WBP_OpenFocusPrompt_offsetX","wbp_openfocusprompt","offsetx","number"},
 {"WBP_CombatTargetIndicator_opacity","wbp_combattargetindicator","opacity","number"},
 {"WBP_Combat_AttackWarning_opacity","wbp_combat_attackwarning","opacity","number"},
 {"WBP_Compass_opacity","wbp_compass","opacity","number"},
 {"WBP_Compass_scale","wbp_compass","scale","number"},
 {"WBP_Compass_offsetY","wbp_compass","offsety","number"},
 {"WBP_HUD_QuestInfo_opacity","wbp_hud_questinfo","opacity","number"},
 {"WBP_HudTimer_opacity","wbp_hudtimer","opacity","number"},
 {"WBP_HudTimer_scale","wbp_hudtimer","scale","number"},
 {"WBP_HudTimer_offsetY","wbp_hudtimer","offsety","number"},
 {"WBP_HudTimer_offsetX","wbp_hudtimer","offsetx","number"},
 {"WBP_NotificationPanel_scale","wbp_notificationpanel","scale","number"},
 {"WBP_NotificationPanel_offsetX","wbp_notificationpanel","offsetx","number"},
 {"WBP_NotificationPanel_opacity","wbp_notificationpanel","opacity","number"},
 {"WBP_HUD_Quickslots_opacity","wbp_hud_quickslots","opacity","number"},
 {"WBP_HUD_Quickslots_scale","wbp_hud_quickslots","scale","number"},
 {"WBP_HUD_Quickslots_offsetY","wbp_hud_quickslots","offsety","number"},
 {"WBP_HUD_Quickslots_offsetX","wbp_hud_quickslots","offsetx","number"},
 {"WBP_AA_Quickslots_opacity","wbp_aa_quickslots","opacity","number"},
 {"WBP_AA_Quickslots_scale","wbp_aa_quickslots","scale","number"},
 {"WBP_AA_Quickslots_offsetY","wbp_aa_quickslots","offsety","number"},
 {"WBP_AA_Quickslots_offsetX","wbp_aa_quickslots","offsetx","number"},
 {"QuickslotContainer_Overlay_2_CommonVisualAttachment_0_opacity","quickslotcontainer/overlay_2/commonvisualattachment_0","opacity","game"},
 {"QuickslotContainer_Overlay_2_CommonVisualAttachment_0_scale","quickslotcontainer/overlay_2/commonvisualattachment_0","scale","number"},
 {"QuickslotContainer_Overlay_2_CommonVisualAttachment_0_offsetX","quickslotcontainer/overlay_2/commonvisualattachment_0","offsetx","number"},
 {"QuickslotContainer_Overlay_2_CommonVisualAttachment_0_offsetY","quickslotcontainer/overlay_2/commonvisualattachment_0","offsety","number"},
 {"WBP_HUD_Quickslots_ChangePrompt_opacity","wbp_hud_quickslots_changeprompt","opacity","number"},
 {"WBP_HUD_Quickslots_ChangePrompt_scale","wbp_hud_quickslots_changeprompt","scale","number"},
 {"WBP_HUD_Quickslots_ChangePrompt_offsetX","wbp_hud_quickslots_changeprompt","offsetx","number"},
 {"WBP_HUD_Quickslots_ChangePrompt_offsetY","wbp_hud_quickslots_changeprompt","offsety","number"},
 {"WBP_HUD_Quickslots_ChangePrompt_reassert","wbp_hud_quickslots_changeprompt","reassert","bool"},
 {"WBP_BuffContainer_opacity","wbp_buffcontainer","opacity","number"},
 {"WBP_BuffContainer_scale","wbp_buffcontainer","scale","number"},
 {"WBP_ControlsLegend_opacity","wbp_controlslegend","opacity","number"},
 {"WBP_ControlsLegend_scale","wbp_controlslegend","scale","number"},
 {"WBP_ControlsLegend_offsetY","wbp_controlslegend","offsety","number"},
 {"WBP_ControlsLegend_offsetX","wbp_controlslegend","offsetx","number"},
 {"WBP_InputPrompt_opacity","wbp_inputprompt","opacity","game"},
 {"WBP_InputPrompt_scale","wbp_inputprompt","scale","number"},
 {"WBP_InputPrompt_offsetY","wbp_inputprompt","offsety","number"},
 {"WBP_SecondInputPrompt_opacity","wbp_secondinputprompt","opacity","game"},
 {"WBP_SecondInputPrompt_scale","wbp_secondinputprompt","scale","number"},
 {"WBP_SecondInputPrompt_offsetY","wbp_secondinputprompt","offsety","number"},
 {"WBP_SecondInputPrompt_offsetX","wbp_secondinputprompt","offsetx","number"},
 {"WBP_InteractablePrompt_opacity","wbp_interactableprompt","opacity","game"},
 {"WBP_InteractablePrompt_scale","wbp_interactableprompt","scale","number"},
 {"WBP_InteractablePrompt_AbilityVariant_opacity","wbp_interactableprompt_abilityvariant","opacity","game"},
 {"WBP_InteractablePrompt_AbilityVariant_scale","wbp_interactableprompt_abilityvariant","scale","number"},
 {"WBP_InteractablePrompt___opacity","wbp_interactableprompt/*","opacity","number"},
 {"WBP_InteractablePrompt___scale","wbp_interactableprompt/*","scale","number"},
 {"WBP_InteractablePrompt_AbilityVariant___opacity","wbp_interactableprompt_abilityvariant/*","opacity","number"},
 {"WBP_InteractablePrompt_AbilityVariant___scale","wbp_interactableprompt_abilityvariant/*","scale","number"},
 {"WBP_Dialogue_ChoiceBox_scale","wbp_dialogue_choicebox","scale","number"},
 {"WBP_Dialogue_ChoiceBox_opacity","wbp_dialogue_choicebox","opacity","game"},
 {"WBP_Dialogue_ChoiceBox___opacity","wbp_dialogue_choicebox/*","opacity","number"},
 {"WBP_Dialogue_ChoiceBox___scale","wbp_dialogue_choicebox/*","scale","number"},
 {"WBP_MediumTutorialPopup_opacity","wbp_mediumtutorialpopup","opacity","number"},
 {"WBP_MediumTutorialPopup_force","wbp_mediumtutorialpopup","force","bool"},
 {"WBP_GameplayDialogue_OverheadSubtitle_opacity","wbp_gameplaydialogue_overheadsubtitle","opacity","number"}
}
local M = {}
function M.path()
    local path=directory..'HUDTweaks.advanced.ini'
    local text,err,code=Store.read(path)
    if not text then
        if code~=2 then return nil,err end
        text,err,code=Store.read(directory..'HUDTweaks.ini')
        if not text and code==2 then text,err=Store.read(directory..'HUDTweaks.defaults.ini') end
        if not text then return nil,err end
        local ok,e=Store.create(path,text)
        if not ok and not Store.read(path) then return nil,e end
    end
    return path
end
function M.apply(ini)
    local values,err=Store.load(directory,schema,function()
        local result={}
        for _,f in ipairs(fields) do
            local v=ini[f[2]] and ini[f[2]][f[3]]
            if f[1]=='debugLogging' and v==nil then v=ini.general and ini.general.debuglogs end
            if type(v)=='boolean' then v=v and 1 or 0 end
            if v=='game' or v=='default' or v=='vanilla' then v=-1 end
            if v~=nil and type(v)~='number' then return nil,'Cannot migrate '..f[1] end
            result[f[1]]=v
        end
        return result
    end)
    if not values then return nil,err end
    for _,f in ipairs(fields) do
        local v=values[f[1]]
        if f[4]=='bool' then v=v==1 elseif f[3]=='opacity' and v==-1 then v='game' end
        ini[f[2]]=ini[f[2]] or {};ini[f[2]][f[3]]=v
    end
    return true
end
return M
