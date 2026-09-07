-- HUDTweaks - The Blood of Dawnwalker (Dawnwalker / Dogwood, UE 5.5)
-- Move, resize, recolour and fade individual HUD elements, and fade the whole HUD out while
-- nothing is happening. Every value it uses lives in HUDTweaks.ini next to this file - the reload
-- key re-reads that file and re-applies it, so tuning never needs a UE4SS script reload and never
-- needs a game restart.
--
-- HOW THIS GAME'S HUD IS PUT TOGETHER, AND WHY THAT SHAPES THE MOD:
--   Dawnwalker builds its HUD the tidy way: ONE widget, WBP_GameHUD_C, holds the lot, and every
--   part of the HUD is a named child inside it - Crosshair, HumanStats, VampireStats, WBP_Compass,
--   WBP_HUD_QuestInfo, WBP_HUD_Quickslots, WBP_NotificationPanel, and so on down to about sixty
--   named widgets. That widget is itself a child of WBP_UIFrontend_C, which also holds the pause
--   menu, the settings screen and the dialogue UI.
--   So a section here is a name out of that tree, [WBP_GameHUD] is the whole HUD at once, and the
--   auto-fade below has a single widget to fade rather than a moving population of them.
--   A handful of things do live OUTSIDE the HUD widget, created and destroyed while you play -
--   compass pins, toast notifications, combat target indicators, interaction prompts - so `roots`
--   is still a list, and the layers that catch a widget the moment it is born still earn their
--   keep. They are just no longer the whole story.
--
--   The game also has a HUD-visibility system of its own: NamedToggleableContainer groups inside
--   WBP_GameHUD (StatContainer, CompassContainer, QuestContainer, ...) that it shows and hides by
--   gameplay tag, driven by HUDVisibilityPreset assets - HVP_Combat, HVP_Dialogue, HVP_DrinkBlood.
--   This mod does not touch that system. It works on the render transform and render opacity,
--   which multiply with whatever the game decides, so the two never fight.
--
-- HOW IT MOVES THINGS, AND WHY IT DOES IT THAT WAY:
--   A UMG widget has two completely separate ways to end up somewhere on screen.
--     1. LAYOUT - anchors, offsets and alignment on its slot. This is what the UI designer set up,
--        and it is what makes the HUD behave at every aspect ratio and every UI scale setting.
--        Editing it means re-doing that design work per element, and getting it wrong shows up as
--        a HUD that is fine at 1920x1080 and broken at ultrawide.
--     2. RENDER TRANSFORM - a translate/scale/rotate applied to the finished widget on its way to
--        the screen. It changes nothing about the layout, it is one struct per widget, and putting
--        the vanilla numbers back is exact.
--   This mod uses the render transform, so the HUD keeps its own anchoring and its own scaling
--   rules and we only nudge the result. A side effect worth knowing: the offsets you type are in
--   the widget's own space, so they are multiplied by the game's UI scale on the way to the
--   screen. That is usually what you want - an offset that looks right at one UI scale setting
--   still looks right at another.
--
-- WHAT IT CAN CHANGE, PER ELEMENT:
--   offsetX / offsetY   where it sits          -> RenderTransform.Translation
--   scale / scaleX/Y    how big it is          -> RenderTransform.Scale
--   opacity             how visible it is      -> RenderOpacity
--   brightness          how bright it is       -> ColorAndOpacity (the widget's own tint, scaled)
--   angle, pivotX/Y     rotation and its pivot -> RenderTransform.Angle, RenderTransformPivot
--   visible/visibility  hide it outright       -> SetVisibility
--
-- PUSHING IT TO SLATE (this is the part that is easy to get wrong):
--   UWidget keeps RenderTransform as a plain struct, and Slate keeps its own copy. Writing the
--   struct does NOT reach Slate - the widget only hands it over inside UWidget::UpdateRenderTransform().
--   Nothing exposes that directly, but every one of the render transform setters calls it, and
--   SetRenderTransformAngle takes a plain float rather than a struct. So: write translation and
--   scale into the struct, then call SetRenderTransformAngle once, and the whole transform lands.
--   RenderOpacity has the same problem and no such trick, which is what SetRenderOpacity is for.
--
--   Everything on screen here is either stock UMG or a DogwoodUI widget - DWW_Text, DWW_StatBar,
--   StatBarBase, NamedToggleableContainer, CommonVisualAttachment - and every one of them derives
--   from UMG's UWidget/UPanelWidget, so all of the above applies unchanged.
--   NamedToggleableContainer is the one to know about: it is the game's own show/hide group, and
--   it is what HVP_Combat and friends switch. Put your values on the widget INSIDE it, or on the
--   HUD root, rather than on the container, and the two multiply instead of fighting.
--
-- KEEPING IT APPLIED, cheapest layer first:
--   1. CLASS DEFAULTS. Before anything is created we write your values onto the class default
--      object and onto the class widget-tree template. Every instance the game makes from then on
--      is BORN tweaked - no hook has to beat the first paint, and a loot marker you never walked
--      near is already right. This is the layer that matters most in this game, because widgets
--      come and go by the dozen.
--   2. NotifyOnNewObject per root class, so an instance made before the bake - or one the game
--      recycles out of a pool - is fixed the moment it is allocated.
--   3. A full pass on triggers only (script load, begin play, the reload key, a few follow-ups):
--      find every live root, walk its tree, snapshot, apply. This is also what feeds dumpWidgets.
--   4. A timer that re-checks ONLY the widgets we actually wrote to, and only the fields we wrote
--      on them. When one has died it sweeps the live instances of its class rather than walking
--      everything again - see ReassertManaged.
--   What we never do is walk every widget on a timer.
--
-- We never compute a new value from the live value, always from the vanilla snapshot taken the
-- first time we saw the widget. That is what stops values compounding across reloads.

-- UE4SS reports this script's own path here, which is how we find the ini next to it.
-- Do NOT declare a local named "debug" in this file or that stops working.
local SCRIPT_SOURCE = debug.getinfo(1, "S").source

-- /!!!!!\ NOTHING BELOW IS A SETTING - EDIT HUDTweaks.ini INSTEAD /!!!!!\

local INI_NAME   = "HUDTweaks.ini"
local MOD_FOLDER = "HUDTweaks"

-- The player pawn's BeginPlay. The HUD is built around here, and a level transition comes back
-- through here with a fresh WBP_GameHUD, so everything we were holding is stale.
local BEGIN_PLAY = "/Game/_Dawnwalker/Player/BP_PlayerCharacter.BP_PlayerCharacter_C:ReceiveBeginPlay"

-- The player pawn itself, which the auto-fade reads its state off. Named by the NATIVE class
-- because that is what the blueprint derives from and FindAllOf matches derived classes; the
-- blueprint is /Game/_Dawnwalker/Player/BP_PlayerCharacter.BP_PlayerCharacter_C.
local PLAYER_CLASS = "DawnwalkerPlayerCharacter"

-- The in-game HUD. The first entry is the one that matters - WBP_GameHUD_C holds the whole HUD -
-- and everything after it is a widget the game creates and destroys OUTSIDE that tree while you
-- play. Full class paths: the path is what NotifyOnNewObject and the class-default bake need, and
-- the short name is taken off the end of it for FindAllOf.
local DEFAULT_ROOTS = {
	-- THE HUD. One widget, ~60 named children, everything from the crosshair to the compass.
	"/Game/_Dawnwalker/UI/_Unified/HUD/WBP_GameHUD.WBP_GameHUD_C",

	-- compass pins - one per marker, dozens alive at once, constantly created and destroyed
	"/Game/_Dawnwalker/UI/_Unified/HUD/Compass/WBP_Compass_Mappin.WBP_Compass_Mappin_C",
	"/Game/_Dawnwalker/UI/_Unified/HUD/Compass/WBP_CompassHeading.WBP_CompassHeading_C",

	-- toast notifications - one widget per toast, gone again in seconds
	"/Game/_Dawnwalker/UI/_Unified/HUD/Notifications/WBP_NotificationPanel_Toast_Entry.WBP_NotificationPanel_Toast_Entry_C",

	-- combat furniture that lives on the enemy rather than in the HUD
	"/Game/_Dawnwalker/UI/_Unified/Combat/WBP_CombatTargetIndicator.WBP_CombatTargetIndicator_C",
	"/Game/_Dawnwalker/UI/_Unified/Combat/WBP_CombatCharacterBar.WBP_CombatCharacterBar_C",
	"/Game/_Dawnwalker/UI/Combat/WBP_Combat_AttackWarning.WBP_Combat_AttackWarning_C",
	"/Game/_Dawnwalker/UI/_Unified/HUD/CombatNotifications/WBP_CombatNotifications.WBP_CombatNotifications_C",

	-- interaction and ability prompts
	"/Game/_Dawnwalker/UI/_Unified/Gameplay/Interaction/WBP_InteractablePrompt.WBP_InteractablePrompt_C",
	"/Game/_Dawnwalker/UI/_Unified/Gameplay/AbilityActivationPrompt/WBP_InteractablePrompt_AbilityVariant.WBP_InteractablePrompt_AbilityVariant_C",
	"/Game/_Dawnwalker/UI/_Unified/Gameplay/DIS/WBP_DIS_Prompt_New.WBP_DIS_Prompt_New_C",

	-- looting, reading, investigation
	"/Game/_Dawnwalker/UI/_Unified/HUD/LootPanel/WBP_HUD_LootingPanel.WBP_HUD_LootingPanel_C",
	"/Game/_Dawnwalker/UI/_Unified/HUD/Readable/WBP_HUD_Readable.WBP_HUD_Readable_C",
	"/Game/_Dawnwalker/UI/_Unified/Gameplay/Investigation/WBP_BOIPOIWidget.WBP_BOIPOIWidget_C",
	"/Game/_Dawnwalker/Player/HUD/Interactables/WBP_FocusRevelaedMarker.WBP_FocusRevelaedMarker_C",

	-- subtitles over an NPC's head, and the tutorial card
	"/Game/_Dawnwalker/UI/_Unified/HUD/GameplayDialogue/WBP_GameplayDialogue_OverheadSubtitle.WBP_GameplayDialogue_OverheadSubtitle_C",
	"/Game/_Dawnwalker/UI/_Unified/Tutorial/WBP_MediumTutorialPopup.WBP_MediumTutorialPopup_C",
	"/Game/_Dawnwalker/UI/_Unified/Gameplay/QuestLevelSequenceOverlay/WBP_QuestLevelSequenceOverlay.WBP_QuestLevelSequenceOverlay_C",
}

-- The full-screen menus: the hub tabs, the map, the pause screen, settings, dialogue, loading.
-- Unlike the HUD list these are OPTIONAL - tweakMenus in the ini turns the lot off in one switch -
-- and unlike some games these are given as blueprint paths, because Dawnwalker keeps its hub
-- screens loaded rather than streaming each one in as it opens. That matters: a blueprint path
-- can be BAKED (see PatchClassDefaults), so a menu here gets the same treatment the HUD does
-- instead of relying on a sweep to notice it.
--
-- The /Script/ entries at the end are the native parents, for screens that were not loaded when
-- this list was written. They cannot be baked - a blueprint subclass copies its parent's defaults
-- when it is compiled, not at runtime - but FindAllOf and NotifyOnNewObject both match derived
-- classes, so naming the parent still reaches the blueprint. Press the scan key with a screen
-- open to see what it actually resolves to, and move the path up here if you want the bake.
local DEFAULT_MENU_ROOTS = {
	-- the hub tabs
	"/Game/_Dawnwalker/UI/_Unified/GameHub/Journal/WBP_Hub_Journal.WBP_Hub_Journal_C",
	"/Game/_Dawnwalker/UI/_Unified/GameHub/Map/WBP_Map.WBP_Map_C",
	"/Game/_Dawnwalker/UI/_Unified/GameHub/Inventory/WBP_Hub_NewInventory.WBP_Hub_NewInventory_C",
	"/Game/_Dawnwalker/UI/_Unified/GameHub/CharacterDevelopment/WBP_Hub_CharacterDevelopment.WBP_Hub_CharacterDevelopment_C",
	"/Game/_Dawnwalker/UI/_Unified/GameHub/ActiveAbilities/WBP_Hub_ActiveAbilities.WBP_Hub_ActiveAbilities_C",
	"/Game/_Dawnwalker/UI/_Unified/GameHub/Crafting/WBP_Hub_Crafting.WBP_Hub_Crafting_C",
	"/Game/_Dawnwalker/UI/_Unified/GameHub/Court/WBP_Hub_Court.WBP_Hub_Court_C",
	"/Game/_Dawnwalker/UI/_Unified/GameHub/Glossary/WBP_Hub_Glossary.WBP_Hub_Glossary_C",
	-- pause, settings, dialogue, loading
	"/Game/_Dawnwalker/UI/_Unified/PauseMenu/WBP_PauseMenu.WBP_PauseMenu_C",
	"/Game/_Dawnwalker/UI/_Unified/Settings/WBP_Settings.WBP_Settings_C",
	"/Game/_Dawnwalker/UI/_Unified/Dialogues/WBP_Dialogue.WBP_Dialogue_C",
	"/Game/_Dawnwalker/UI/_Unified/LoadingScreen/WBP_LoadingScreen.WBP_LoadingScreen_C",
	-- native parents, for anything the list above misses
	"/Script/DogwoodUI.DWHUBWidgetBase",              -- the hub frame the tabs sit in
	"/Script/DogwoodUI.MapWidget",
	"/Script/DogwoodUI.MainMenuBase",
	"/Script/DogwoodUI.TitleScreen",
	"/Script/DogwoodUI.CreditsWindowBase",
	"/Script/DogwoodUI.SaveWindowBase",
	"/Script/DogwoodUI.ComicViewerWidget",
	"/Script/DogwoodUI.CinematicDialogueWidget",
}

-- Sections that configure the mod rather than name a HUD element. Leaving [AutoFade] out of this
-- would make it a widget section that matches nothing, reported as a typo, and silently ignored.
local RESERVED = { general = true, all = true, autofade = true }

-- Widgets whose being on screen counts as "something is happening". These are the ones this game
-- puts up in response to you - a prompt, a loot list, a toast, a line of dialogue - rather than as
-- permanent furniture, so one of them being alive and visible is a good enough signal on its own.
-- It is a list in the ini rather than a probe each because this is the part most likely to need a
-- name this file does not know yet.
local DEFAULT_FADE_WATCH = {
	"WBP_InteractablePrompt_C",
	"WBP_InteractablePrompt_AbilityVariant_C",
	"WBP_DIS_Prompt_New_C",
	"WBP_HUD_LootingPanel_C",
	"WBP_HUD_Readable_C",
	"WBP_NotificationPanel_Toast_Entry_C",
	"WBP_MediumTutorialPopup_C",
	"WBP_Dialogue_C",
}

-- brightness multiplies the element's own colour, so it has no natural ceiling - but a tint of
-- 200 looks exactly like a tint of 10, and a typo should not be silently obeyed.
local BRIGHTNESS_MAX = 10.0

-- ESlateVisibility. Collapsed also gives up its layout space, Hidden keeps the space empty.
-- For a HUD element inside a canvas the two look identical, so "visible = false" uses Collapsed.
local VIS_BY_NAME = {
	visible = 0, collapsed = 1, hidden = 2, hittestinvisible = 3, selfhittestinvisible = 4,
	-- friendlier spellings for the same five
	shown = 0, gone = 1, invisible = 2, nohit = 3, passthrough = 4,
}
local VIS_NAME = {
	[0] = "Visible", [1] = "Collapsed", [2] = "Hidden",
	[3] = "HitTestInvisible", [4] = "SelfHitTestInvisible",
}

-- ##############################
-- State
-- ##############################

local S        = {}   -- resolved settings, rebuilt from the ini on every load / reload
local ini      = {}   -- [section][key] = value, both lowercased
local iniCased = {}   -- [loweredSection] = section exactly as it was written in the file
local iniPath  = nil

local vanilla    = {}  -- [fullName] = entry, the snapshot taken the first time we saw the widget
local written    = {}  -- [fullName] = entry, only the widgets we actually changed
local discovered = {}  -- this pass, in tree order, which is what the dump prints
local managed    = {}  -- this pass, the entries some ini section claims

local applyGeneration = 0
local boundKeys       = {}
local beginPlayHooked = false

local suspended       = false  -- the toggle key: everything restored, nothing re-applied
local pivotWarned     = false  -- SetRenderTransformPivot takes a struct; say so once if it fails

-- Auto-fade state. Up here with the rest of it rather than next to the code that drives it,
-- because RestoreAll runs long before that code is defined and still has to be able to let go.
local fadeLevel       = 1.0    -- what the HUD is holding right now
local fadeWant        = 1.0    -- what it is easing towards
local fadeLastTime    = nil    -- when the level last moved, so the ease is measured in seconds
local fadeNextProbe   = nil    -- when the probes are next due; they run slower than the ease
local fadeApplied     = nil    -- what we last wrote, so an unchanged level writes nothing at all
local fadeIdleSince   = nil    -- when the last engaged signal went quiet
local fadePeekUntil   = 0      -- the peek key holds the HUD up until this
local fadeTicks       = 0
local nestedWarned    = {}     -- sections already reported as claiming a widget inside itself
local fadeReported    = false  -- the one-time "here is what I can and cannot read" line
local fadeNamed       = false  -- the one-time "here is what I am holding down" line
local fadeLastWhy     = nil    -- last set of reasons, so a change is logged and a repeat is not
local fadeFirstTick   = nil    -- when the fade first ran with a player, for the stuck-check
local fadeStuckReported = false
local fadeUpSince     = nil    -- when the current unbroken run of "something is happening" began
local fadeHoldReported = false -- one-shot per stuck episode, re-armed the moment it goes quiet
local fadePlayer      = nil    -- cached player pawn
local fadeCombatSub   = nil    -- cached combat subsystem
local lastHealth, lastStamina = nil, nil
local probeSince      = {}     -- [probe key] = when it last went true, for the per-signal delay
local fadeStatStart, fadeStatN, fadeStatMax = nil, 0, 0   -- one fade's step count and worst gap, for the log
local fadeStatCost    = 0      -- seconds spent INSIDE our own steps during that fade, to tell our cost from UE4SS's latency
local fadeStatProbe   = 0      -- ...of which, inside the probes
local fadeStatPush    = 0      -- ...of which, inside PushFade
local fadeEaseChains  = 0      -- ease chains currently running (they exit on their own when the fade settles)
local fadeStepVia     = "timer" -- which driver ran the last ease step: timer / frame / hook
local fadeHookLast    = nil    -- when the frameHook last stepped the fade
local fadeHooked      = {}     -- [frameHook path] = true once registered, so each is registered once
local tintWarned      = false  -- SetColorAndOpacity has the same problem; same treatment
local tintCall        = 0      -- which way of handing a colour back to Slate this build accepts

-- ##############################
-- Logging / small helpers
-- ##############################

local function Log(fmt, ...)
	if select("#", ...) > 0 then
		print(string.format("[HUDTweaks] " .. fmt .. "\n", ...))
	else
		print("[HUDTweaks] " .. tostring(fmt) .. "\n")
	end
end

local function Debug(fmt, ...)
	if S.debugLogging then Log(fmt, ...) end
end

-- One shared game-thread dispatcher; checkpoints never retain borrowed structs.
local Work = {forced = {}, fading = {}, queue = {}, keyed = {}, active = {}, token = 0, due = nil,
    frame = nil, units = 0, started = 0, current = nil, clock = nil, attempts = 0,
    stats = {slices = 0, maxMs = 0, maxUnits = 0, coalesced = 0}}
local Pump, Arm
-- UE4SS binds native APIs to the Lua states it creates. Plain Lua coroutines
-- only plan work; the registered game-thread callback executes native calls.
local function HostPcall(fn, ...)
    if Work.current ~= coroutine.running() then return pcall(fn, ...) end
    return coroutine.yield({call = fn, args = table.pack(...)})
end
local function HostFunction(fn)
    if type(fn) ~= 'function' then return fn end
    return function(...)
        local result = table.pack(HostPcall(fn, ...))
        if not result[1] then error(result[2], 0) end
        return table.unpack(result, 2, result.n)
    end
end
Log = HostFunction(Log)
Work.host = {
    StaticFindObject = HostFunction(StaticFindObject),
    RegisterHook = HostFunction(RegisterHook),
    RegisterKeyBind = HostFunction(RegisterKeyBind),
    NotifyOnNewObject = HostFunction(NotifyOnNewObject),
    ExecuteInGameThreadWithDelay = HostFunction(ExecuteInGameThreadWithDelay),
    ExecuteInGameThread = HostFunction(ExecuteInGameThread),
    ExecuteWithDelay = HostFunction(ExecuteWithDelay),
}
local function BudgetStep()
    if Work.current ~= coroutine.running() then return end
    while Work.units >= 128 or os.clock() - Work.started >= 0.001 do coroutine.yield() end
    Work.units = Work.units + 1
end
local function Defer(ms, fn, urgent, key, persistent)
    local old = key ~= nil and Work.keyed[key] or nil
    if old and (old.generation == false or old.generation == applyGeneration) then
        Work.stats.coalesced = Work.stats.coalesced + 1
        return
    end
    local job = {fn = fn, due = os.clock() + math.max(ms, 0) / 1000,
        generation = (not persistent) and applyGeneration, lane = urgent and 1 or 2, key = key}
    Work.queue[#Work.queue + 1] = job
    if key ~= nil then Work.keyed[key] = job end
    Arm(ms)
end
Arm = function(ms)
    local due = os.clock() + math.max(ms, 1) / 1000
    if Work.due and Work.due <= due then return end
    Work.token = Work.token + 1
    local token = Work.token
    Work.due = due
    local run = function()
        if token ~= Work.token then return end
        Work.due = nil
        Pump()
    end
    if type(Work.host.ExecuteInGameThreadWithDelay) == 'function' then
        Work.host.ExecuteInGameThreadWithDelay(math.max(ms, 1), run)
    elseif type(Work.host.ExecuteInGameThread) == 'function' and type(Work.host.ExecuteWithDelay) == 'function' then
        Work.host.ExecuteWithDelay(math.max(ms, 1), function() Work.host.ExecuteInGameThread(run) end)
    else
        Work.due = nil
        if not Work.warned then Log('HUD scheduling requires game-thread callbacks.'); Work.warned = true end
    end
end
local function FrameNumber()
    if Work.clock == nil then
        if Work.attempts >= 3 then return nil end
        Work.attempts = Work.attempts + 1
        local ok, lib = pcall(Work.host.StaticFindObject, '/Script/Engine.Default__KismetSystemLibrary')
        if ok then Work.clock = lib end
    end
    local ok, frame = pcall(function()
        if Work.clock and Work.clock:IsValid() then return Work.clock:GetFrameCount() end
    end)
    if ok and type(frame) == 'number' then return frame end
    Work.clock = nil
    return nil
end
Pump = function()
    local frame = FrameNumber()
    if frame == nil then
        if Work.attempts < 3 then Arm(250)
        elseif not Work.warned then
            Log('HUD updates paused: frame counter unavailable; check UE4SS compatibility.')
            Work.warned = true
        end
        return
    end
    -- Timer expiry is not proof of a new frame: share the budget across all wakes.
    if frame == Work.frame then Arm(16); return end
    Work.frame, Work.units, Work.started = frame, 0, os.clock()
    local now = os.clock()
    for lane = 1, 2 do
        local job = Work.active[lane]
        if job and job.generation ~= false and job.generation ~= applyGeneration then
            if job.key ~= nil and Work.keyed[job.key] == job then Work.keyed[job.key] = nil end
            Work.active[lane] = nil
        end
        while Work.units < 128 and os.clock() - Work.started < 0.001 do
            job = Work.active[lane]
            if not job then
                for i = #Work.queue, 1, -1 do
                    local candidate = Work.queue[i]
                    if candidate.generation ~= false and candidate.generation ~= applyGeneration then
                        if candidate.key ~= nil and Work.keyed[candidate.key] == candidate then Work.keyed[candidate.key] = nil end
                        table.remove(Work.queue, i)
                    end
                end
                for i, candidate in ipairs(Work.queue) do
                    if candidate.lane == lane and candidate.due <= now then
                        job = table.remove(Work.queue, i)
                        job.thread = coroutine.create(job.fn)
                        Work.active[lane] = job
                        break
                    end
                end
            end
            if not job then break end
            Work.units = Work.units + 1
            Work.current = job.thread
            local reply = job.reply
            job.reply = nil
            local ok, err
            if reply then ok, err = coroutine.resume(job.thread, table.unpack(reply, 1, reply.n))
            else ok, err = coroutine.resume(job.thread) end
            Work.current = nil
            if not ok or coroutine.status(job.thread) == 'dead' then
                if job.key ~= nil and Work.keyed[job.key] == job then Work.keyed[job.key] = nil end
                Work.active[lane] = nil
                if not ok then Log('HUD job stopped: %s', tostring(err)) end
            elseif type(err) == 'table' and type(err.call) == 'function' then
                -- Run one atomic operation here, never in the job's Lua state.
                -- Replies contain scalars, owned Lua tables or UObject references;
                -- borrowed property structs stay inside the atomic operation.
                job.reply = table.pack(pcall(err.call, table.unpack(err.args, 1, err.args.n)))
            else break end
        end
    end
    Work.stats.slices = Work.stats.slices + 1
    Work.stats.maxMs = math.max(Work.stats.maxMs, (os.clock() - Work.started) * 1000)
    Work.stats.maxUnits = math.max(Work.stats.maxUnits, Work.units)
    local delay = (Work.active[1] or Work.active[2]) and 1 or nil
    for _, job in ipairs(Work.queue) do
        local remaining = math.max(1, math.ceil((job.due - os.clock()) * 1000))
        delay = delay and math.min(delay, remaining) or remaining
    end
    if delay then Arm(delay) end
end

local function RetireWork()
    applyGeneration = applyGeneration + 1
    for _, job in pairs(Work.active) do
        if job.thread == Work.current then job.generation = applyGeneration end
    end
    if Work.clock == nil then Work.attempts = 0; Work.warned = false end
end

-- Construction-driven index. No global object-array searches, including empty watches.
-- Captured objects are checked later, after construction, on the game thread.
local ObjectIndex = {classes = {}, entries = {}, hooks = {}, pending = {}, attempts = {}, owner = nil, world = nil}
local function SameOwner(a, b)
    return a == b or (a:IsValid() and b:IsValid() and a:GetAddress() == b:GetAddress())
end
local function CurrentEntry(entry)
    local ok, live = HostPcall(function()
        return entry.obj:IsValid()
            and (not entry.world or not ObjectIndex.world or SameOwner(entry.world, ObjectIndex.world))
            and (not entry.owner or not ObjectIndex.owner or SameOwner(entry.owner, ObjectIndex.owner))
    end)
    return ok and live
end
local function IndexedWorld(obj)
    for _ = 1, 8 do
        if not obj or not obj:IsValid() then return nil end
        if obj:GetClass():GetFName():ToString() == 'World' then return obj end
        obj = obj:GetOuter()
    end
end
function ObjectIndex.add(obj)
    BudgetStep()
    local ok, names, world, owner = HostPcall(function()
        if not obj or not obj:IsValid() then return nil end
        local full = obj:GetFullName()
        if string.find(full, 'Default__', 1, true) then return nil end
        local chain, cls, isWidget = {}, obj:GetClass(), false
        for _ = 1, 32 do
            if not cls or not cls:IsValid() then break end
            local name = cls:GetFName():ToString()
            chain[#chain + 1] = name
            if name == 'UserWidget' then isWidget = true end
            cls = cls:GetSuperStruct()
        end
        local hasWorld, w = HostPcall(IndexedWorld, obj)
        if not hasWorld then w = nil end
        local player
        if isWidget then
            local hasOwner, candidate = HostPcall(function() return obj:GetOwningPlayer() end)
            if hasOwner and candidate and candidate:IsValid() then player = candidate end
        end
        return chain, w, player
    end)
    if not ok or not names then return end
    local entry = {obj = obj, world = world, owner = owner, names = names}
    if not CurrentEntry(entry) then return end
    ObjectIndex.entries[obj] = entry
    for _, name in ipairs(names) do
        local list = ObjectIndex.classes[name]
        if not list then list = {}; ObjectIndex.classes[name] = list end
        list[obj] = entry
    end
    if ObjectIndex.widget then
        for _, name in ipairs(names) do
            if name == 'UserWidget' then ObjectIndex.widget(obj, names); break end
        end
    end
end
function ObjectIndex.capture(obj)
    ObjectIndex.pending[obj] = true
    Defer(0, function()
        while next(ObjectIndex.pending) do
            BudgetStep()
            local object = next(ObjectIndex.pending)
            ObjectIndex.pending[object] = nil
            ObjectIndex.add(object)
        end
    end, false, 'object-index', true)
end
function ObjectIndex.get(name)
    local result, list = {}, ObjectIndex.classes[name]
    if not list then return result end
    for obj, entry in pairs(list) do
        BudgetStep()
        if CurrentEntry(entry) then result[#result + 1] = obj else list[obj] = nil end
    end
    return result
end
function ObjectIndex.prune(replay)
    for obj, entry in pairs(ObjectIndex.entries) do
        BudgetStep()
        if not CurrentEntry(entry) then
            ObjectIndex.entries[obj] = nil
            for _, name in ipairs(entry.names) do ObjectIndex.classes[name][obj] = nil end
        elseif replay and ObjectIndex.widget then
            ObjectIndex.widget(obj, entry.names)
        end
    end
end
function ObjectIndex.context(controller)
    local ok, localPlayer = HostPcall(function() return controller:IsValid() and controller:IsLocalController() end)
    if not ok or not localPlayer then return end
    ObjectIndex.attempts = {}
    ObjectIndex.owner = controller
    local found, world = HostPcall(IndexedWorld, controller)
    ObjectIndex.world = found and world or nil
    ObjectIndex.capture(controller)
    local valid, pawn = HostPcall(function() if controller:IsValid() then return controller.Pawn end end)
    if valid and pawn then ObjectIndex.capture(pawn) end
end
function ObjectIndex.start()
    for _, path in ipairs({'/Script/UMG.UserWidget', '/Script/Engine.PlayerController',
        '/Script/Engine.WorldSubsystem', '/Script/Engine.GameInstanceSubsystem'}) do
        if not ObjectIndex.hooks[path] and (ObjectIndex.attempts[path] or 0) < 3 then
            ObjectIndex.attempts[path] = (ObjectIndex.attempts[path] or 0) + 1
            ObjectIndex.hooks[path] = pcall(Work.host.NotifyOnNewObject, path, ObjectIndex.capture)
            if not ObjectIndex.hooks[path] and ObjectIndex.attempts[path] == 3 then
                Log('HUD discovery unavailable for %s; check UE4SS compatibility.', path)
            end
        end
    end
end
-- All existing lookups now use the index, including player/subsystem recovery.
local FindAllOf = ObjectIndex.get

local function Trim(s)
	if s == nil then return "" end
	return (string.gsub(string.gsub(s, "^%s+", ""), "%s+$", ""))
end

-- Every one of these is the body of a pcall a few lines further down. Lua 5.4 allocates a fresh
-- closure for every inline function() ... end, and these run once or more per widget per pass, so
-- they are written once here and handed their object as an argument instead.
local function _get(obj)       return obj:get() end
_get = HostFunction(_get)
local function _isValid(obj)   return obj:IsValid() end
_isValid = HostFunction(_isValid)
local function _fullName(obj)  if not obj or not obj:IsValid() then return nil end; return obj:GetFullName() end
_fullName = HostFunction(_fullName)
local function _shortName(obj) if not obj or not obj:IsValid() then return nil end; return obj:GetFName():ToString() end
_shortName = HostFunction(_shortName)
local function _className(obj) if not obj or not obj:IsValid() then return nil end; return obj:GetClass():GetFName():ToString() end
_className = HostFunction(_className)
local function _setOpacity(obj, value) if not obj or not obj:IsValid() then return nil end; return obj:SetRenderOpacity(value) end
_setOpacity = HostFunction(_setOpacity)

-- UE4SS hands most numbers back plain, but wrapped values need :get()
local function ToNumber(value)
	local t = type(value)
	if t == "number" then return value end
	if t == "userdata" then
		local ok, res = pcall(_get, value)
		if ok and type(res) == "number" then return res end
	end
	return tonumber(value)
end

local function Num(value, default)
	local n = ToNumber(value)
	if n == nil then return default end
	return n
end

local function Differs(a, b)
	if a == nil or b == nil then return a ~= b end
	return math.abs(a - b) > 0.0005
end

local function IsValidObject(obj)
	if obj == nil then return false end
	local ok, valid = pcall(_isValid, obj)
	return ok and valid == true
end

local function SafeName(obj)
	if obj == nil then return "<nil>" end
	local ok, name = pcall(_fullName, obj)
	if not ok then return "<nil>" end
	return name
end

-- The designer's name for the widget - "AmmoBG", "DotCrosshair" - which is what the ini sections use.
local function SafeShortName(obj)
	if obj == nil then return "<nil>" end
	local ok, name = pcall(_shortName, obj)
	if not ok then return "<nil>" end
	return name
end

local function SafeClassName(obj)
	if obj == nil then return "<nil>" end
	local ok, name = pcall(_className, obj)
	if not ok then return "<nil>" end
	return name
end

-- FindAllOf hands back the class default object alongside the live widgets. A CDO is not on
-- screen and writing to it through the normal path would be writing a default by accident, so
-- every caller that walks live widgets filters it out here.
local function IsDefaultObject(obj)
	return string.find(SafeName(obj), "Default__", 1, true) ~= nil
end

-- ##############################
-- The .ini
-- ##############################

-- UE4SS reports the script path as "@E:\...\Scripts\main.lua". Strip the marker, keep the folder.
local function IniCandidates()
	local list   = {}
	local source = SCRIPT_SOURCE or ""
	if string.sub(source, 1, 1) == "@" then source = string.sub(source, 2) end

	local dir = string.match(source, "^(.*)[/\\][^/\\]*$")
	if dir ~= nil and dir ~= "" then
		list[#list + 1] = dir .. "\\" .. INI_NAME
		list[#list + 1] = dir .. "/" .. INI_NAME
	end

	-- The game's working directory is Binaries/Win64, so this reaches the same file another way.
	list[#list + 1] = "ue4ss/Mods/" .. MOD_FOLDER .. "/Scripts/" .. INI_NAME
	list[#list + 1] = INI_NAME
	return list
end

local function ParseValue(raw)
	local value = Trim(raw)
	local lower = string.lower(value)

	if lower == "true"  or lower == "yes" or lower == "on"     then return true end
	if lower == "false" or lower == "no"  or lower == "off"    then return false end
	-- blank / "default" means "leave the game's own value alone"
	if lower == "" or lower == "default" or lower == "vanilla" then return nil end

	local number = tonumber(value)
	if number ~= nil then return number end
	return value
end

local function LoadIni()
	ini      = {}
	iniCased = {}
	iniPath  = nil

	local file = nil
	for _, candidate in ipairs(IniCandidates()) do
	    BudgetStep()
		local handle = io.open(candidate, "r")
		if handle ~= nil then
			file    = handle
			iniPath = candidate
			break
		end
	end

	if file == nil then
		Log("WARNING: %s not found - the HUD will be left exactly as the game draws it", INI_NAME)
		Log("  looked in: %s", table.concat(IniCandidates(), " | "))
		return false
	end

	local section = "general"
	ini[section]  = {}

	-- A line ending in \ continues onto the next one, so a long list - roots, above all - can be
	-- written down the page instead of as one unreadable line. The pieces are joined before
	-- anything else looks at them, so a continued line behaves exactly like the single line it
	-- would otherwise have been.
	local pending  = nil
	local lineNo   = 0
	local rejected = {}

	local ok = pcall(function()
		for line in file:lines() do
		    BudgetStep()
			lineNo = lineNo + 1
			local text = Trim(line)

			if pending ~= nil then
				text    = pending .. " " .. text
				pending = nil
			end

			local continued = string.match(text, "^(.*)\\$")
			if continued ~= nil then
				pending = Trim(continued)
				text    = ""
			end

			local first = string.sub(text, 1, 1)
			if text ~= "" and first ~= ";" and first ~= "#" then
				-- A section header may be followed by a comment - "[AmmoBG]  ; the background
				-- plate" - so the header is matched WITHOUT anchoring to the end of the line and
				-- whatever follows has to be a comment for the line to count as one. Anchoring
				-- here is the kind of bug that costs an evening: the line silently stops being a
				-- header, every key under it lands in whichever section came before, and the file
				-- looks completely correct while doing something else entirely.
				local header, rest = string.match(text, "^%[(.-)%]%s*(.*)$")
				local restFirst    = (rest ~= nil) and string.sub(rest, 1, 1) or nil

				if header ~= nil and (rest == "" or restFirst == ";" or restFirst == "#") then
					section      = string.lower(Trim(header))
					ini[section] = ini[section] or {}
					-- Keep the original spelling: a section name doubles as a widget name, and the
					-- dump prints it back at you, so it should read the way you wrote it.
					iniCased[section] = Trim(header)
				else
					local key, value = string.match(text, "^([^=]+)=(.*)$")
					if key ~= nil then
						value = string.gsub(value, "%s*[;#].*$", "") -- trailing inline comment
						ini[section][string.lower(Trim(key))] = ParseValue(value)
					else
						-- Not a header, not a key = value, not a comment. Silently skipping this
						-- is how a typo turns into "the mod does nothing and says nothing".
						rejected[#rejected + 1] = string.format("line %d: %s", lineNo, text)
					end
				end
			end
		end
	end)

	pcall(function() file:close() end)

	if not ok then
		Log("ERROR: %s could not be parsed - the HUD is left untouched", tostring(iniPath))
		ini = {}
		return false
	end

	if #rejected > 0 then
		Log("WARNING: %d line(s) in %s were not understood and had NO effect. A section header " ..
		    "must be [Name], and anything after it on the line must start with ; or #:",
		    #rejected, INI_NAME)
		for _, entry in ipairs(rejected) do Log("    %s", entry) end
	end

	return true
end

local function Raw(section, key)
	local bucket = ini[string.lower(section)]
	if bucket == nil then return nil end
	return bucket[string.lower(key)]
end

local function GetBool(section, key, default)
	local value = Raw(section, key)
	if type(value) == "boolean" then return value end
	if type(value) == "number"  then return value ~= 0 end
	return default
end

local function GetNum(section, key, default)
	local value = Raw(section, key)
	if type(value) == "number" then return value end
	return default
end

local function GetStr(section, key, default)
	local value = Raw(section, key)
	if type(value) == "string" then return value end
	return default
end

local function GetList(section, key, default)
	local value = GetStr(section, key, nil)
	if value == nil then return default end

	local list = {}
	for item in string.gmatch(value, "[^,]+") do
	    BudgetStep()
		item = Trim(item)
		if item ~= "" then list[#list + 1] = item end
	end
	if #list == 0 then return default end
	return list
end

local function GetNumberList(section, key, default)
	local raw = GetStr(section, key, nil)
	if raw == nil then
		-- a single number is a perfectly good one-entry list
		local single = GetNum(section, key, nil)
		if single ~= nil then return { single } end
		return default
	end

	local list = {}
	for item in string.gmatch(raw, "[^,]+") do
	    BudgetStep()
		local number = tonumber(Trim(item))
		if number ~= nil then list[#list + 1] = number end
	end
	if #list == 0 then return default end
	return list
end

-- ##############################
-- Root widget classes
-- ##############################

-- One entry per root: the short class name FindAllOf wants, and - when the ini gave a full path -
-- the object path Work.host.NotifyOnNewObject and the class-default bake want. An entry that is only a
-- short name still works for finding and tweaking live widgets; it just cannot be baked or
-- notified on, because there is no path to look the class up by.
local rootSpecs = {}
local specByKey = {}   -- [lowered class name] = the spec, for asking "is that root a menu?"

local function BuildRootSpecs()
	rootSpecs = {}
	specByKey = {}
	local seen = {}

	local function add(raw, isMenu)
		local entry = Trim(raw)
		if entry == "" then return end

		local path, class = nil, entry
		if string.sub(entry, 1, 1) == "/" then
			path  = entry
			class = string.match(entry, "([^/.]+)$") or entry
		end

		-- A blueprint class is always Name_C, and both "WBP_GameHUD" and "WBP_GameHUD_C" are
		-- meant to name it, so the _C is normalised on. A NATIVE class - /Script/DogwoodUI.MapWidget,
		-- which is how the menu list reaches a screen it has no path for - has no _C and must not
		-- get one.
		local native = path ~= nil and string.sub(path, 1, 8) == "/Script/"
		if not native then
			class = string.gsub(class, "_C$", "") .. "_C"
		end

		local key = string.lower(class)
		if not seen[key] then
			seen[key] = true
			local spec = {
				class = class, path = path, key = key, native = native, menu = isMenu == true,
			}
			rootSpecs[#rootSpecs + 1] = spec
			specByKey[key] = spec
		end
	end

	for _, raw in ipairs(S.roots or {}) do add(raw, false) end
	if S.tweakMenus then
		for _, raw in ipairs(S.menuRoots or {}) do add(raw, true) end
	end
end

local function ResolveSettings()
	S = {}
	-- Said again after a reload: the file may have fixed the section, or introduced another.
	nestedWarned = {}

	S.enabled          = GetBool("General", "enabled", true)
	S.startImmediately = GetBool("General", "startImmediately", true)
	S.debugLogging        = GetBool("General", "debugLogging", GetBool("General", "debugLogs", false))
	S.reloadKeyName    = GetStr ("General", "reloadKey", "F7")
	S.toggleKeyName    = GetStr ("General", "toggleKey", "F8")
	S.scanKeyName      = GetStr ("General", "scanKey", "F9")
	S.dumpWidgets      = GetBool("General", "dumpWidgets", false)
	S.dumpOnlyManaged  = GetBool("General", "dumpOnlyManaged", false)

	-- The widget classes we start a tree walk from. Unlike a one-root HUD this is the whole list
	-- of things on screen, and each class can have any number of live instances at once.
	S.roots            = GetList("General", "roots", DEFAULT_ROOTS)
	-- extraRoots ADDS to the list instead of replacing it, so one more widget class does not
	-- mean restating all eighteen defaults in the ini. Same format: full class paths.
	for _, raw in ipairs(GetList("General", "extraRoots", {})) do
	    BudgetStep()
		S.roots[#S.roots + 1] = raw
	end
	-- The menus, kept as their own list so that turning them off is one switch rather than an
	-- edit to the roots list, and so [All] can be read as "the HUD" or "the whole UI" on purpose.
	S.tweakMenus       = GetBool("General", "tweakMenus", true)
	S.menuRoots        = GetList("General", "menuRoots", DEFAULT_MENU_ROOTS)

	-- How far down the tree to look. Measured against the real HUD: a quick-access slot button is
	-- already eight levels down inside its own nested user widget, and the input-key images inside
	-- a prompt are deeper still. 24 reaches every leaf with room to spare.
	S.maxDepth         = math.floor(GetNum("General", "maxDepth", 24))

	-- Depth is the wrong knob for keeping the log readable - cutting the dump short is fine,
	-- cutting the WALK short means sections silently match nothing. So they are separate.
	-- 0 = print everything the walk found.
	S.dumpMaxDepth     = math.floor(GetNum("General", "dumpMaxDepth", 10))

	-- A ceiling on the walk itself, so a deep maxDepth can never turn into a runaway pass.
	S.maxWidgets       = math.floor(GetNum("General", "maxWidgets", 4000))

	-- Elements that get the [All] values without needing a section of their own.
	S.elementSet = {}
	for _, name in ipairs(GetList("General", "elements", {})) do
	    BudgetStep()
		S.elementSet[string.lower(Trim(name))] = true
	end

	-- The master switch for catching widgets as they are created: the class-default bake and the
	-- Work.host.NotifyOnNewObject callbacks. false leaves both off and relies on triggers alone, which in
	-- this game means prompts and loot markers will often show up untweaked.
	S.hookNewWidgets   = GetBool("General", "hookNewWidgets", true)
	S.bakeDefaults     = GetBool("General", "bakeClassDefaults", true)
	-- A widget is allocated before its tree is filled in, so the Work.host.NotifyOnNewObject callback fixes
	-- what it can straight away and then comes back a few times.
	S.newObjectFollowUps = GetNumberList("General", "newObjectFollowUpSeconds", { 0, 0.05, 0.25 })

	-- Functions the GAME uses to write a value you also want to own. We put ours back straight
	-- after each one returns, which is the only way to hold a value the game rewrites every frame
	-- and is still cheaper than any timer: it fires once per write, never in between.
	S.reassertAfter   = GetList("General", "reassertAfter", {})
	-- Log how long the first few per-instance tweaks take, so the cost is measured and not asserted.
	S.instanceTimings = math.floor(GetNum("General", "instanceTimings", 5))
	-- Dead instances are dropped after this many writes. Prompts and markers come and go
	-- constantly and each one is a new object with a new name, so something has to bound the
	-- snapshot table.
	S.purgeEvery      = math.floor(GetNum("General", "purgeEveryInstances", 200))

	-- Widgets to blink on and off so you can see which one is which. Names or wildcards, same
	-- matching as a section header. Blank = nothing blinks.
	S.identify   = GetList("General", "identify", {})
	-- trace = names: every write to a matching widget is logged with who wrote, what the game
	-- had put there, what we set, and whether one of its animations is running. For the one
	-- element you are fighting the game over.
	S.trace = {}
	for _, name in ipairs(GetList("General", "trace", {})) do
	    BudgetStep()
		S.trace[#S.trace + 1] = string.lower(Trim(name))
	end
	S.identifyMs = math.floor(GetNum("General", "identifyBlinkSeconds", 0.4) * 1000)

	S.reassert   = GetBool("General", "reassert", true)
	S.reassertMs = math.floor(GetNum("General", "reassertSeconds", 2.0) * 1000)
	-- Fast loop for sections with force = true (something the game keeps re-writing).
	S.forceReassertMs = math.floor(GetNum("General", "forceReassertSeconds", 0.05) * 1000)
	S.followUps  = GetNumberList("General", "followUpSeconds", { 2, 6, 15 })
	-- Periodic FindAllOf sweep of every root class. 0 = off, which is the default: the bake and
	-- Work.host.NotifyOnNewObject already catch new widgets, and a sweep is the one expensive thing here.
	S.sweepMs    = math.floor(GetNum("General", "sweepSeconds", 0) * 1000)
	-- The menus need one of their own - see MenuSweepHeartbeat for why it is on when the general
	-- sweep is off.
	S.menuSweepMs = math.floor(GetNum("General", "menuSweepSeconds", 2.0) * 1000)

	-- ---- auto-fade ---------------------------------------------------------------------------
	-- Its own section, because it is its own feature: none of it applies unless [AutoFade]
	-- enabled = true, and with it off not one line of the code below ever runs.
	S.autoFade       = GetBool("AutoFade", "enabled", false)
	S.idleAfter      = math.max(0.0, GetNum("AutoFade", "idleAfterSeconds", 4.0))
	S.idleOpacity    = math.max(0.0, math.min(1.0, GetNum("AutoFade", "idleOpacity", 0.0)))
	S.fadeOutSeconds = math.max(0.0, GetNum("AutoFade", "fadeOutSeconds", 0.8))
	S.fadeInSeconds  = math.max(0.0, GetNum("AutoFade", "fadeInSeconds", 0.15))
	-- Ten times a second by default. Everything a check does is a handful of property reads on
	-- objects it already holds, so this is cheap - but it is the only thing in this mod that runs
	-- on a clock while you play, so it is a number you can see and change.
	S.autoFadeMs     = math.floor(GetNum("AutoFade", "checkSeconds", 0.1) * 1000)
	-- How often the fade MOVES, which is a different question from how often it looks. Ten times
	-- a second is plenty for noticing that you drew a weapon and nowhere near enough to draw a
	-- fade: at that rate an 0.8s fade is eight visible bands. Floored at 8ms so a typo cannot
	-- turn this into a spin.
	S.fadeStepMs     = math.max(8, math.floor(GetNum("AutoFade", "fadeStepSeconds", 0.016) * 1000))
	-- How the ease is driven while the fade is moving. Measured on this build: both UE4SS timers
	-- and Work.host.ExecuteInGameThread deliver a step about every 100ms whatever is asked for, so neither
	-- can make a fade smooth. frameHook is the one route that is not a UE4SS timer: a post-hook
	-- on an engine function that runs every frame on the game thread, stepping the ease from
	-- there. Off by default; the cadence line in the log says what each option achieves.
	-- Independent ease chains stepping the same fade while it moves. 1..8.
	S.fadeChains       = math.max(1, math.min(8, math.floor(GetNum("AutoFade", "fadeChains", 2))))
	S.fadeFrameHooks   = GetList("AutoFade", "frameHook", {})
	S.gameThreadTimers = GetBool("General", "gameThreadTimers", true)
	-- Not 1.0: a stat bar that regenerates sits a hair under full for a long time, and a strict
	-- "< 1.0" would hold the HUD up through all of it.
	S.hurtBelow      = GetNum("AutoFade", "hurtBelow", 0.995)
	-- How far health or stamina has to move to count as something happening. Small enough to
	-- catch a hit, large enough that continuous stamina regeneration is not "something happening"
	-- every tick forever - which is the difference between a HUD that fades and one that never
	-- does.
	S.statChangeBy   = math.max(0.0005, GetNum("AutoFade", "statChangeBy", 0.02))
	-- Whether stamina counts for the two vitals probes. Off: only health does.
	S.hurtStamina       = GetBool("AutoFade", "hurtIncludesStamina", false)
	S.statChangeStamina = GetBool("AutoFade", "statChangeIncludesStamina", false)
	S.peekKeyName    = GetStr("AutoFade", "peekKey", "")
	S.peekSeconds    = math.max(0.0, GetNum("AutoFade", "peekSeconds", 4.0))

	S.showInCombat     = GetBool("AutoFade", "showInCombat", true)
	S.showWeaponDrawn  = GetBool("AutoFade", "showWeaponDrawn", true)
	S.showWhenLockedOn = GetBool("AutoFade", "showWhenLockedOn", true)
	S.showInFocusMode  = GetBool("AutoFade", "showInFocusMode", true)
	S.showWhenAiming   = GetBool("AutoFade", "showWhenAiming", true)
	-- How long after a shadowstep fires it still counts as "executing, not aiming".
	S.stepSeconds      = math.max(0.0, GetNum("AutoFade", "shadowstepSeconds", 1.5))

	-- Per-signal delay: "<key>After = seconds" means the signal has to stay true that long before
	-- it counts. 0 (the default) is instant. showInCombat is left instant on purpose.
	S.probeAfter = {}
	local probeKeys = { "showInCombat", "showWeaponDrawn", "showWhenLockedOn", "showInFocusMode",
	                    "showWhenAiming", "showWhenHurt", "showOnStatChange" }
	for _, key in ipairs(probeKeys) do
	    BudgetStep()
		S.probeAfter[key] = math.max(0.0, GetNum("AutoFade", key .. "After", 0.0))
	end
	S.showWhenHurt     = GetBool("AutoFade", "showWhenHurt", true)
	S.showOnStatChange = GetBool("AutoFade", "showOnStatChange", true)

	S.fadeWatch = GetList("AutoFade", "showWhenVisible", DEFAULT_FADE_WATCH)
	-- Empty = fade each top-level widget, the whole HUD in one write. Non-empty = fade exactly
	-- these named pieces instead, which is what makes "everything except the compass" possible.
	S.fadeElements = {}
	for _, name in ipairs(GetList("AutoFade", "fadeElements", {})) do
	    BudgetStep()
		S.fadeElements[#S.fadeElements + 1] = string.lower(Trim(name))
	end
	S.fadeExclude = {}
	for _, name in ipairs(GetList("AutoFade", "exclude", {})) do
	    BudgetStep()
		S.fadeExclude[#S.fadeExclude + 1] = string.lower(Trim(name))
	end

	-- Does [All] actually say anything? It only reaches widgets on its own when it does, because
	-- claiming every top-level widget for an empty section would put the whole UI in the re-check
	-- loop to write values identical to the ones already there.
	S.allActive = false
	local allSection = ini["all"]
	if allSection ~= nil then
		for _ in pairs(allSection) do
		    BudgetStep()
			S.allActive = true
			break
		end
	end

	BuildRootSpecs()
end

-- ##############################
-- Reading and writing a widget
-- ##############################

local function ReadVisibility(widget)
	local value = nil
	pcall(function() value = ToNumber(widget:GetVisibility()) end)
	if value == nil then
		pcall(function() value = ToNumber(widget.Visibility) end)
	end
	return value
end
ReadVisibility = HostFunction(ReadVisibility)

-- The tint a widget multiplies itself by, and the thing brightness acts on. A UUserWidget
-- applies ColorAndOpacity to its whole subtree and a UImage applies it to its brush, which
-- between them is every top-level HUD element and every picture inside one - so scaling this one
-- colour dims or lifts an element, icons and text included, without touching its opacity.
--
-- Only the FLinearColor form is read. A text block keeps an FSlateColor here instead: the same
-- colour one level down, behind a rule saying whether that colour is used at all rather than the
-- style's. Text inside an element is already tinted by the element's own colour, so forcing that
-- rule would win nothing and could throw a style away. nil means this widget has no tint, and
-- every colour key is then a no-op on it.
local function ReadTint(widget)
	local r, g, b, a
	pcall(function()
		local colour = widget.ColorAndOpacity
		r, g, b, a = Num(colour.R, nil), Num(colour.G, nil), Num(colour.B, nil), Num(colour.A, nil)
	end)
	if r == nil or g == nil or b == nil then return nil end
	return r, g, b, a or 1.0
end
ReadTint = HostFunction(ReadTint)

-- Everything we are ever going to touch, in one flat table. Taken once per widget, before we
-- write anything, and never taken again - that is the whole compounding defence.
local function ReadState(widget)
    BudgetStep()
	if not IsValidObject(widget) then return {} end
	local st = { tx = 0.0, ty = 0.0, sx = 1.0, sy = 1.0, angle = 0.0, px = 0.5, py = 0.5 }

	pcall(function()
		st.tx    = Num(widget.RenderTransform.Translation.X, 0.0)
		st.ty    = Num(widget.RenderTransform.Translation.Y, 0.0)
		st.sx    = Num(widget.RenderTransform.Scale.X, 1.0)
		st.sy    = Num(widget.RenderTransform.Scale.Y, 1.0)
		st.angle = Num(widget.RenderTransform.Angle, 0.0)
	end)

	pcall(function()
		st.px = Num(widget.RenderTransformPivot.X, 0.5)
		st.py = Num(widget.RenderTransformPivot.Y, 0.5)
	end)

	pcall(function() st.opacity = Num(widget:GetRenderOpacity(), nil) end)
	if st.opacity == nil then
		pcall(function() st.opacity = Num(widget.RenderOpacity, nil) end)
	end

	st.cr, st.cg, st.cb, st.ca = ReadTint(widget)

	st.vis = ReadVisibility(widget)
	return st
end
ReadState = HostFunction(ReadState)

local function WriteTintChannels(widget, r, g, b)
	return pcall(function()
		local colour = widget.ColorAndOpacity
		colour.R, colour.G, colour.B = r, g, b
	end)
end

local function TintHolds(widget, r, g, b)
	local liveR, liveG, liveB = ReadTint(widget)
	return liveR ~= nil and not Differs(liveR, r)
	       and not Differs(liveG, g) and not Differs(liveB, b)
end

-- The channel writes above reach only UMG, exactly like the render transform - the Slate side of
-- a tint moves through SetColorAndOpacity, and that setter takes a struct rather than the plain
-- float SetRenderTransformAngle takes, so there is no free trick this time. Two ways to get a
-- struct into it, and which one this UE4SS build accepts is worked out once and then remembered:
-- hand back the very struct we just read out of the property (a build that cannot construct one
-- from a Lua table can still pass on one it already owns), or build it from a table.
--
-- Both of those calls ASSIGN their argument to the property on their way to Slate. So a call that
-- goes through holding a struct UE4SS did not actually fill in would quietly replace the three
-- channels we just wrote with whatever was in it - which is why a strategy only counts as working
-- if the colour still reads back correct afterwards, and why the channels are written again
-- before the next attempt. Once one is known to work the read-back is skipped.
--
-- If neither call can be made the property write still stands, and that is not the loss it would
-- be in another game: it lands on the next rebuild, and here the HUD is rebuilt constantly - and
-- on a class default there is no Slate widget to push to at all, so the write is the entire job.
-- Said once, like pivot, and not again.
local function PushTint(widget, r, g, b, a)
	if not WriteTintChannels(widget, r, g, b) then return false end

	if tintCall ~= 2 then
		if pcall(function() widget:SetColorAndOpacity(widget.ColorAndOpacity) end)
		   and (tintCall == 1 or TintHolds(widget, r, g, b)) then
			tintCall = 1
			return true
		end
		WriteTintChannels(widget, r, g, b)
	end

	if tintCall ~= 1 then
		if pcall(function() widget:SetColorAndOpacity({ R = r, G = g, B = b, A = a or 1.0 }) end)
		   and (tintCall == 2 or TintHolds(widget, r, g, b)) then
			tintCall = 2
			return true
		end
		WriteTintChannels(widget, r, g, b)
	end

	if not tintWarned then
		tintWarned = true
		Log("NOTE: brightness could not be pushed to Slate directly - it applies to every widget " ..
		    "created from now on, and to what is already on screen the next time it is rebuilt.")
	end
	-- Not "true" out of politeness: this is what decides whether WriteState reports a change, and
	-- on a class default - where there is no Slate side and the property IS the result - the
	-- read-back is a real answer rather than a consolation prize.
	return TintHolds(widget, r, g, b)
end

-- What this widget's RenderOpacity should actually be: what the ini asked for, times the
-- auto-fade's current level whenever the fade is holding one.
--
-- Two things about that second half are deliberate. The fade MULTIPLIES rather than replaces, so
-- "[All] opacity = 0.8" plus a fade to 0.3 lands on 0.24 and your value still means what it says.
-- And when the file set no opacity at all it multiplies the widget's VANILLA value, which is what
-- lets the fade work on a HUD nobody has configured.
--
-- entry.fade is nil whenever the HUD is fully up, so at rest this returns exactly what it returned
-- before the fade existed, and the whole feature writes nothing.
local function EffectiveOpacity(entry, target)
	local want = target.opacity
	if entry == nil or entry.fade == nil then return want end

	if want == nil then
		want = (entry.snapshot ~= nil) and entry.snapshot.opacity or nil
		if want == nil then want = 1.0 end
	end
	return math.max(0.0, math.min(1.0, want * entry.fade))
end

-- Writes `target` onto the widget and returns the list of fields that actually moved. Nothing is
-- written when it already holds the value we want, so the re-assert timer is free in the normal
-- case where nothing has reset us.
local function WriteState(entry, target, why)
    BudgetStep()
	if entry.key and vanilla[entry.key] == entry and target == entry.target then
		Work.forced[entry.key] = entry.force and entry or nil
		Work.fading[entry.key] = entry.fadeAllowed and entry or nil
	end
	local widget = entry.obj
	if not IsValidObject(widget) or target == nil then return nil end

	-- Still the object this entry was made for? A cached reference can outlive its widget:
	-- UE4SS's IsValid passes for an object-array slot the engine has since reused for something
	-- else, and writing RenderOpacity at that offset into whatever lives there now is an access
	-- violation with no log line in front of it (18:31 today: GameThread, UE4SS -> Lua -> a
	-- property access on 0x80000003). The full name is the identity the entry was created with;
	-- on a mismatch the entry is marked dead and the re-check sweeps its class as usual.
	if entry.key ~= nil and SafeName(widget) ~= entry.key then
		entry.obj = nil
		return nil
	end

	local changed   = {}
	local transform = false

	-- trace: what the game had put on this widget before we touched it. Read only for a traced
	-- entry, so the hot path pays nothing for the feature.
	local before = nil
	if entry.trace then
		pcall(function()
			before = string.format("offset=(%.0f, %.0f) scale=(%.2f, %.2f) opacity=%.2f",
				Num(widget.RenderTransform.Translation.X, 0), Num(widget.RenderTransform.Translation.Y, 0),
				Num(widget.RenderTransform.Scale.X, 1), Num(widget.RenderTransform.Scale.Y, 1),
				Num(widget:GetRenderOpacity(), 1))
		end)
	end

	pcall(function()
		if Differs(Num(widget.RenderTransform.Translation.X, nil), target.tx) then
			widget.RenderTransform.Translation.X = target.tx
			changed[#changed + 1] = "offsetX"
			transform = true
		end
		if Differs(Num(widget.RenderTransform.Translation.Y, nil), target.ty) then
			widget.RenderTransform.Translation.Y = target.ty
			changed[#changed + 1] = "offsetY"
			transform = true
		end
		if Differs(Num(widget.RenderTransform.Scale.X, nil), target.sx) then
			widget.RenderTransform.Scale.X = target.sx
			changed[#changed + 1] = "scaleX"
			transform = true
		end
		if Differs(Num(widget.RenderTransform.Scale.Y, nil), target.sy) then
			widget.RenderTransform.Scale.Y = target.sy
			changed[#changed + 1] = "scaleY"
			transform = true
		end
		if Differs(Num(widget.RenderTransform.Angle, nil), target.angle) then
			changed[#changed + 1] = "angle"
			transform = true
		end
	end)

	-- The struct writes above only reached UMG. UWidget::UpdateRenderTransform is what hands the
	-- transform to Slate, and every render transform setter calls it - so one call to the only
	-- setter that takes a plain float pushes the translation and the scale as well.
	if transform then
		pcall(function() widget:SetRenderTransformAngle(target.angle) end)
	end

	local pivotX, pivotY = nil, nil
	pcall(function()
		pivotX = Num(widget.RenderTransformPivot.X, nil)
		pivotY = Num(widget.RenderTransformPivot.Y, nil)
	end)
	if Differs(pivotX, target.px) or Differs(pivotY, target.py) then
		pcall(function()
			widget.RenderTransformPivot.X = target.px
			widget.RenderTransformPivot.Y = target.py
		end)
		-- The Slate side of the pivot only moves through the setter, and that one takes a struct
		-- rather than the plain floats every other setter here takes. If UE4SS cannot build the
		-- struct for us the property write above still stands, and UMG picks it up the next time
		-- the widget synchronises - which a rebuild does anyway. Worth saying out loud once,
		-- because it is the difference between "pivotX takes effect now" and "on the next rebuild".
		if not pcall(function() widget:SetRenderTransformPivot({ X = target.px, Y = target.py }) end)
		   and not pivotWarned then
			pivotWarned = true
			Log("NOTE: pivotX/pivotY could not be pushed to Slate directly - they will apply the " ..
			    "next time that widget is rebuilt. Everything else applies immediately.")
		end
		changed[#changed + 1] = "pivot"
	end

	-- force = true: always push opacity/visibility. Some widgets re-show themselves from their own
	-- animations and layout passes; a "only if different" write loses that fight for a frame and
	-- the element flickers back. The cheap path still skips when the live value already matches.
	local force = entry.force == true

	local wantOpacity = EffectiveOpacity(entry, target)

	-- revealAfter: the fallback for a widget whose transform the game keeps rewriting - the
	-- quickslot change prompt animates its own position on every weapon draw and we cannot
	-- write faster than an animation. So when the game has just moved it (`transform` is true:
	-- we found it away from where we put it), hold it at opacity 0 for revealAfter seconds
	-- while the force heartbeat keeps putting it back, and only then let it show. Misplaced
	-- and invisible beats misplaced and visible. Needs an opacity in the section to come back
	-- to; without one there would be nothing to write on the way out of the hold.
	local clock = nil
	if entry.reveal ~= nil then
		pcall(function() clock = os.clock() end)
		if clock ~= nil then
			if transform then entry.hideUntil = clock + entry.reveal end
			if entry.hideUntil ~= nil and clock < entry.hideUntil and wantOpacity ~= nil then
				wantOpacity = 0.0
			end
		end
	end

	if wantOpacity ~= nil then
		local live = nil
		pcall(function() live = Num(widget:GetRenderOpacity(), nil) end)
		if live == nil then pcall(function() live = Num(widget.RenderOpacity, nil) end) end
		if force or Differs(live, wantOpacity) then
			if pcall(function() widget:SetRenderOpacity(wantOpacity) end) then
				changed[#changed + 1] = "opacity"
			end
		end
	end

	-- target.cr is nil unless a brightness key asked for one AND the widget had a colour to
	-- scale, so this is skipped outright on everything else.
	if target.cr ~= nil then
		local liveR, liveG, liveB = ReadTint(widget)
		if force or Differs(liveR, target.cr) or Differs(liveG, target.cg)
		   or Differs(liveB, target.cb) then
			if PushTint(widget, target.cr, target.cg, target.cb, target.ca) then
				changed[#changed + 1] = "brightness"
			end
		end
	end

	if target.vis ~= nil then
		local liveVis = ReadVisibility(widget)
		if force or liveVis ~= target.vis then
			if pcall(function() widget:SetVisibility(target.vis) end) then
				changed[#changed + 1] = "visibility"
			end
		end
	end

	-- The trace line. Only when something was written, or when a hook fired - a 50ms force
	-- tick that found nothing to do is not worth a line each.
	if entry.trace and (#changed > 0 or why == "hook") then
		local anim = nil
		pcall(function() anim = widget:IsAnyAnimationPlaying() end)
		local hidden = (entry.hideUntil ~= nil and clock ~= nil and clock < entry.hideUntil)
		Log("TRACE %s via %s | game had %s | %s%s | want offset=(%.0f, %.0f) opacity=%s | parent=%s animating=%s",
		    entry.name or "?", why or "?", before or "?",
		    (#changed > 0) and ("wrote " .. table.concat(changed, ", ")) or "nothing to write",
		    hidden and " [held invisible until placed]" or "",
		    target.tx or 0, target.ty or 0, tostring(target.opacity),
		    entry.parent or "?", tostring(anim))
	end

	return changed
end
WriteState = HostFunction(WriteState)

-- ##############################
-- Walking the widget tree
-- ##############################

-- Two ways down, and a widget only ever has one of them: a user widget owns a WidgetTree, and a
-- panel widget owns children. Both calls throw on the wrong kind of widget, hence the pcalls.
--
-- A caught throw is not free and a whole HUD of them is most of a pass, so which of the two a
-- class turns out to be is remembered the first time we find out, and the other probe is skipped
-- from then on. Only the two POSITIVE answers are ever remembered: a user widget whose WidgetTree
-- is not populated yet legitimately probes as neither, and that is exactly the state the follow-up
-- passes exist to catch - remembering it would hide a whole subtree until the reload key. Keyed on
-- the CLASS address, never on an instance's: class objects of loaded blueprints are not recycled
-- the way instances are.
local function _treeRoot(widget)   if not widget or not widget:IsValid() then return nil end; return widget.WidgetTree.RootWidget end
_treeRoot = HostFunction(_treeRoot)
local function _childCount(widget) if not widget or not widget:IsValid() then return nil end; return widget:GetChildrenCount() end
_childCount = HostFunction(_childCount)
local function _childAt(widget, i) if not widget or not widget:IsValid() then return nil end; return widget:GetChildAt(i) end
_childAt = HostFunction(_childAt)
local function _classAddress(obj)  if not obj or not obj:IsValid() then return nil end; return obj:GetClass():GetAddress() end
_classAddress = HostFunction(_classAddress)

local widgetKind = {}   -- [class address] = "user" | "panel". Positives only, never "leaf".

local function ChildrenOf(widget)
	local list = {}

	local addr = nil
	local addrOk, address = pcall(_classAddress, widget)
	if addrOk then addr = address end

	local kind = nil
	if addr ~= nil then kind = widgetKind[addr] end

	if kind ~= "panel" then
		local ok, root = pcall(_treeRoot, widget)
		if ok and IsValidObject(root) then
			if addr ~= nil then widgetKind[addr] = "user" end
			list[1] = root
			return list
		end
	end

	if kind ~= "user" then
		local count = 0
		local ok, value = pcall(_childCount, widget)
		if ok then
			if addr ~= nil then widgetKind[addr] = "panel" end
			count = Num(value, 0)
		end
		for i = 0, count - 1 do
		    BudgetStep()
			if not IsValidObject(widget) then return list end
			local childOk, child = pcall(_childAt, widget, i)
			if childOk and IsValidObject(child) then list[#list + 1] = child end
		end
	end

	return list
end

-- One entry per widget, created the first time we ever see it and kept from then on. Keyed on the
-- full object name.
-- One segment of a widget's ancestor path: its lowered name, with the object number a root
-- carries ("WBP_GameHUD_C_2147478239") taken off so the root reads as its blueprint name.
local function PathSeg(name)
	return (string.gsub(string.lower(name or ""), "_c_%d+$", ""))
end

local function Visit(widget, parentName, depth, seen, rootKey, parentPath)
    BudgetStep()
	if not IsValidObject(widget) then return nil end
	local key = SafeName(widget)
	if seen[key] then return nil end
	seen[key] = true

	local entry = vanilla[key]
	if entry == nil then
		entry = {
			key      = key,
			name     = SafeShortName(widget),
			class    = SafeClassName(widget),
			snapshot = ReadState(widget),
		}
		vanilla[key] = entry
	end

	entry.obj     = widget
	entry.parent  = parentName
	-- Every ancestor's name, root first, "/"-joined and lowered. This is what a section header
	-- like [QuickslotContainer/Overlay_2/CommonVisualAttachment_0] is matched against: generic
	-- names repeat all over these trees, and one parent is often not enough to tell them apart.
	entry.ppath   = parentPath or ""
	entry.depth   = depth
	-- Which root class this widget came in under. When it dies we sweep that one class rather
	-- than walking every root again - see ReassertManaged.
	entry.rootKey = rootKey
	-- Only the top-level widget answers to the root's name. Letting a child answer to it would
	-- make [WBP_GameHUD] claim every widget in the HUD at once, which is not what it reads as -
	-- and with sixty of them, would be a spectacular way to shrink the HUD to nothing.
	entry.rootSpec = (depth == 0) and rootKey or nil

	discovered[#discovered + 1] = entry
	return entry
end

-- Nothing validates the widget here: both callers already did. ChildrenOf only ever returns
-- children that passed IsValidObject, and CollectWidgets checks each root before it starts.
local function WalkWidget(widget, parentName, depth, seen, rootKey, parentPath)
    BudgetStep()
	if not IsValidObject(widget) then return end
	if depth > S.maxDepth then return end
	if #discovered >= S.maxWidgets then return end

	local entry = Visit(widget, parentName, depth, seen, rootKey, parentPath)
	if entry == nil then return end

	local path = entry.ppath
	path = (path == "" and "" or (path .. "/")) .. PathSeg(entry.name)
	for _, child in ipairs(ChildrenOf(widget)) do
	    BudgetStep()
		WalkWidget(child, entry.name, depth + 1, seen, rootKey, path)
	end
end

-- FindAllOf walks the whole object array and hands back the same widgets every time, so what it
-- found is kept and only looked for again when one of them stops being valid - which is exactly
-- when that part of the HUD has been rebuilt. With two dozen root classes that matters: a pass
-- that re-searched every class would be two dozen full object-array walks.
--
-- An EMPTY result is cached too, but only for the current generation. Half of these classes have
-- nothing on screen at any given moment (no loot marker nearby, no notification up), and without
-- this every one of them would be re-searched on every follow-up pass for the rest of the session.
local rootCache = {}   -- [lowered class name] = { generation = n, list = { widget, ... } }

local function RememberRoot(widget)
    -- Roots are indexed once by construction notifications.
end

local function RootsOfClass(className)
    return ObjectIndex.get(className)
end

local function CollectWidgets()
	discovered = {}
	local seen, roots = {}, 0

	for _, spec in ipairs(rootSpecs) do

	    BudgetStep()
		for _, obj in ipairs(RootsOfClass(spec.class)) do
		    BudgetStep()
			roots = roots + 1
			WalkWidget(obj, "", 0, seen, spec.key)
		end
	end

	if #discovered >= S.maxWidgets then
		Log("WARNING: stopped at maxWidgets = %d - some of the HUD was not looked at. Raise " ..
		    "maxWidgets, or trim the roots list so the walk does not spend its budget on UI you " ..
		    "are not tweaking.", S.maxWidgets)
	end

	return roots
end

-- ##############################
-- Matching ini sections to widgets
-- ##############################

-- Every Lua pattern character except * gets escaped, so a section name is taken literally and *
-- is the one wildcard - [WBP_HUD_*] or [*Container].
local function EscapePattern(text)
	return (string.gsub(text, "([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1"))
end

-- An entry's name and class never change once it exists, so the lowered forms every section is
-- matched against are worked out once and kept on the entry rather than rebuilt for every section
-- on every pass.
local function LoweredFields(entry)
	local name = entry.lname
	if name == nil then
		name         = string.lower(entry.name or "")
		entry.lname  = name
		entry.lclass = string.lower(entry.class or "")
		entry.lblue  = string.gsub(entry.lclass, "_c$", "")
		-- A top-level widget is named after its class plus the object number the engine handed it
		-- - "WBP_GameHUD_C_2147478239" - so the root of every widget also answers to the blueprint
		-- name. That is what makes [WBP_GameHUD] mean "the whole HUD".
		entry.lroot  = string.match(name, "^(.-)_c_%d+$")
	end

	-- The name this widget was FOUND by, which for a natively-named menu is not the name it has.
	-- menuRoots asks for /Script/DogwoodUI.MapWidget and gets back a blueprint called WBP_Map_C,
	-- and there is no way for anyone to write [WBP_Map] in this file without having gone looking
	-- for it first. So a top-level widget also answers to the root that matched it, and
	-- [MapWidget] means the map whatever the blueprint underneath happens to be called.
	-- Not cached with the rest: an entry can be created by the per-instance path before the walk
	-- has ever seen it as a root, so this has to follow the field rather than the first read.
	if entry.lspecSrc ~= entry.rootSpec then
		entry.lspecSrc  = entry.rootSpec
		entry.lspec     = entry.rootSpec
		entry.lspecblue = entry.rootSpec ~= nil
		                  and string.gsub(entry.rootSpec, "_c$", "") or nil
	end

	return name, entry.lclass, entry.lblue, entry.lroot, entry.lspec, entry.lspecblue
end

local function SectionMatches(entry, want)
	-- "parent/name": this name, but only where its PARENT matches too. Widget trees here reuse
	-- generic names everywhere - CommonVisualAttachment_0 exists twenty times over, once as the
	-- wrapper around the quickslot change prompt directly under the HUD and again inside the
	-- boss bar, the compass, every compass pin, every settings slider. A plain [name] section
	-- claims the lot; [WBP_GameHUD/CommonVisualAttachment_0] claims the one. The parent half
	-- takes the same forms a section does (blueprint name, wildcard), and a root's parent-name
	-- carries the engine's object number, so its blueprint name answers as well.
	local parentWant, childWant = string.match(want, "^(.-)/([^/]+)$")
	if parentWant ~= nil and parentWant ~= "" then
		if not SectionMatches(entry, childWant) then return false end

		-- As many ancestors as the header names, nearest last, compared from the end against
		-- the entry's own chain. [Overlay_2/X] needs one to agree; [A/Overlay_2/X] needs two.
		-- One level turned out not to be enough for exactly the case this was built for -
		-- Overlay_2/CommonVisualAttachment_0 exists under the quickslot container, the compass
		-- and a vertical box - so the header can go as far up as it needs to.
		local path = entry.ppath
		if path == nil then path = PathSeg(entry.parent) end   -- an entry with no chain: parent only
		local have = {}
		for seg in string.gmatch(path, "[^/]+") do have[#have + 1] = seg end
		local wants = {}
		for seg in string.gmatch(parentWant, "[^/]+") do wants[#wants + 1] = seg end
		if #wants > #have then return false end

		for i = 0, #wants - 1 do

		    BudgetStep()
			local h = have[#have - i]
			local w = (string.gsub(wants[#wants - i], "_c$", ""))   -- WBP_GameHUD_C == WBP_GameHUD
			if string.find(w, "*", 1, true) ~= nil then
				local pattern = "^" .. string.gsub(EscapePattern(w), "%*", ".*") .. "$"
				if string.match(h, pattern) == nil then return false end
			elseif h ~= w then
				return false
			end
		end
		return true
	end

	local name, class, blueprint, rootName, spec, specBlue = LoweredFields(entry)

	if string.find(want, "*", 1, true) ~= nil then
		local pattern = "^" .. string.gsub(EscapePattern(want), "%*", ".*") .. "$"
		return string.match(name, pattern) ~= nil
			or string.match(blueprint, pattern) ~= nil
			or (rootName ~= nil and string.match(rootName, pattern) ~= nil)
			or (specBlue ~= nil and string.match(specBlue, pattern) ~= nil)
	end

	return name == want or class == want or blueprint == want
		or spec == want or specBlue == want
end

-- Sorted, so that when two sections claim the same widget the order they are applied in is the
-- same every time rather than whatever pairs() felt like today.
local function ConfiguredSections()
	local list = {}
	for lowered, cased in pairs(iniCased) do
	    BudgetStep()
		if not RESERVED[lowered] then list[#list + 1] = cased end
	end
	table.sort(list, function(a, b) return string.lower(a) < string.lower(b) end)
	return list
end

-- Which top-level widgets the auto-fade is allowed to hold down. Menus never are - a screen you
-- opened on purpose is not idle - and anything named in the ini's exclude list is left alone, so
-- "fade everything except the subtitles" is one line.
--
-- Answered here, where an entry is being matched against sections anyway, rather than in the fade
-- tick: the tick runs ten times a second and has no business matching strings.
local function FadeAllowed(entry, rootKey, isTop)
	if not S.autoFade then return false end

	local spec = specByKey[rootKey or ""]
	-- Never a menu, in either mode below. A screen you opened on purpose is not idle.
	if spec ~= nil and spec.menu then return false end

	for _, want in ipairs(S.fadeExclude or {}) do

	    BudgetStep()
		if SectionMatches(entry, want) then return false end
	end

	-- PIECES MODE. The fade holds exactly the widgets named in fadeElements, wherever they sit in
	-- the tree, instead of holding each top-level widget.
	--
	-- This mode exists because of one hard fact about UMG: opacity MULTIPLIES down the tree. The
	-- default below fades WBP_GameHUD, and everything inside it goes with it - there is no way to
	-- keep the compass up by "excluding" it, because zero times anything is still zero. A child
	-- cannot be rescued from its parent. The only way to keep one piece of the HUD visible is to
	-- stop fading the parent and fade its siblings individually instead, which is what this is.
	-- It costs one write per named piece rather than one for the whole HUD, which at ten ticks a
	-- second and only while actually fading is not a cost worth avoiding.
	if #(S.fadeElements or {}) > 0 then
		for _, want in ipairs(S.fadeElements) do
		    BudgetStep()
			if SectionMatches(entry, want) then return true end
		end
		return false
	end

	-- DEFAULT MODE: the top-level widgets, which is the whole HUD in a single write. A widget we
	-- cannot place under any root this file lists is refused - "I do not know what this is" has
	-- never been a good reason to hide something.
	if not isTop or spec == nil then return false end
	return true
end

local function ApplyKeys(section, target, van)
	local n

	n = GetNum(section, "offsetX", nil)    ; if n ~= nil then target.tx = n end
	n = GetNum(section, "offsetY", nil)    ; if n ~= nil then target.ty = n end
	n = GetNum(section, "offsetXAdd", nil) ; if n ~= nil then target.tx = target.tx + n end
	n = GetNum(section, "offsetYAdd", nil) ; if n ~= nil then target.ty = target.ty + n end

	n = GetNum(section, "scale", nil)      ; if n ~= nil then target.sx, target.sy = n, n end
	n = GetNum(section, "scaleX", nil)     ; if n ~= nil then target.sx = n end
	n = GetNum(section, "scaleY", nil)     ; if n ~= nil then target.sy = n end
	n = GetNum(section, "scaleMul", nil)
	if n ~= nil then
		target.sx = target.sx * n
		target.sy = target.sy * n
	end
	n = GetNum(section, "scaleXMul", nil)  ; if n ~= nil then target.sx = target.sx * n end
	n = GetNum(section, "scaleYMul", nil)  ; if n ~= nil then target.sy = target.sy * n end

	n = GetNum(section, "angle", nil)      ; if n ~= nil then target.angle = n end
	n = GetNum(section, "pivotX", nil)     ; if n ~= nil then target.px = n end
	n = GetNum(section, "pivotY", nil)     ; if n ~= nil then target.py = n end

	n = GetNum(section, "opacity", nil)    ; if n ~= nil then target.opacity = n end
	-- opacity = game: this widget's opacity is the GAME's to drive, whatever [All] said. Needed
	-- for the elements the game shows and hides by opacity - the quickslot change prompt, the
	-- focus radial - where any absolute value from this file, including [All]'s, drags a hidden
	-- widget back on screen. A blank value cannot express this: blank is "no override", and
	-- [All] has already set one by the time the section is read.
	if string.lower(Trim(GetStr(section, "opacity", "") or "")) == "game" then
		target.opacity = nil
	end
	n = GetNum(section, "opacityMul", nil)
	if n ~= nil then
		-- Nothing set an opacity yet, so multiply the game's own value.
		local base = target.opacity
		if base == nil then base = van.opacity end
		if base ~= nil then target.opacity = base * n end
	end

	-- brightness scales the element's OWN colour, so 1.0 is vanilla whatever that colour happens
	-- to be and there is no palette anyone has to know about. Below 1 darkens and always shows.
	-- Above 1 multiplies the tint, which lifts everything the element draws that is not already
	-- full white - a grey plate or a dark icon brightens, a pure white pixel has nowhere left to
	-- go. Alpha is deliberately left alone: fading is what opacity is for, and putting both
	-- behind one key would make brightness = 0 mean two different things at once.
	-- Computed from the vanilla colour, like everything else here, so an element's own section
	-- replaces the value [All] gave it rather than compounding with it.
	n = GetNum(section, "brightness", nil)
	if n ~= nil and van.cr ~= nil then
		n = math.max(0.0, math.min(BRIGHTNESS_MAX, n))
		target.cr, target.cg, target.cb = van.cr * n, van.cg * n, van.cb * n
		target.ca = van.ca
	end

	-- visible = false hides it. visible = true puts the game's own visibility back rather than
	-- forcing Visible, because most HUD elements ship as SelfHitTestInvisible and forcing them
	-- Visible would let them start swallowing mouse clicks.
	local show = GetBool(section, "visible", nil)
	if show == false then
		target.vis = VIS_BY_NAME.collapsed
		-- Also kill opacity unless the section set one itself - some elements are re-shown by
		-- animations that only touch RenderOpacity, not Visibility.
		if GetNum(section, "opacity", nil) == nil and target._opacitySet ~= true then
			target.opacity = 0.0
		end
	end
	if show == true  then target.vis = van.vis end

	local named = GetStr(section, "visibility", nil)
	if named ~= nil then
		local value = VIS_BY_NAME[string.lower(Trim(named))]
		if value ~= nil then
			target.vis = value
		else
			Log("WARNING: [%s] visibility = %s is not one of: %s", section, named,
			    "visible, collapsed, hidden, hitTestInvisible, selfHitTestInvisible")
		end
	end

	if GetNum(section, "opacity", nil) ~= nil then target._opacitySet = true end

	if target.opacity ~= nil then
		target.opacity = math.max(0.0, math.min(1.0, target.opacity))
	end
end

-- [All] first, then the widget's own sections in name order. Always starts from the vanilla
-- snapshot, so nothing here can compound however many times it runs.
local function BuildTarget(entry, sections)
	local van = entry.snapshot
	-- opacity and vis start as nil, and stay nil unless a key in the file asks for them. They are
	-- the two things the game drives itself on a lot of widgets - the crosshair appears only while
	-- you aim, an input hint fades in and out with the prompt - and a target seeded from the
	-- snapshot would pin them to whatever state the widget happened to be in the first time we saw
	-- it, which is how a scaled crosshair ends up permanently invisible. A transform is ours to
	-- own; visibility is not, unless you say so.
	local target = {
		tx = van.tx or 0.0, ty = van.ty or 0.0,
		sx = van.sx or 1.0, sy = van.sy or 1.0,
		angle = van.angle or 0.0,
		px = van.px or 0.5, py = van.py or 0.5,
		opacity = nil, vis = nil,
		-- The tint stays unset for the same reason, plus one of its own: an element with no
		-- ColorAndOpacity has no vanilla colour to scale, and inventing white for it would paint
		-- a tint onto something that never had one.
		cr = nil, cg = nil, cb = nil, ca = nil,
	}

	local order = { "All" }
	for _, section in ipairs(sections) do order[#order + 1] = section end

	local live     = true
	local reassert = S.reassert
	local force    = false
	local reveal   = nil
	for _, section in ipairs(order) do
	    BudgetStep()
		if GetBool(section, "enabled", true) == false then live = false end
		reassert = GetBool(section, "reassert", reassert)
		if GetBool(section, "force", false) then force = true end
		-- revealAfter = seconds: when the game moves this widget, hold it invisible that long
		-- while we put it back, then show it. Implies force, since the re-show is on that clock.
		local n = GetNum(section, "revealAfter", nil)
		if n ~= nil then reveal = math.max(0.0, n); force = true end
		ApplyKeys(section, target, van)
	end

	entry.reassert = reassert
	entry.force    = force
	entry.reveal   = reveal
	entry.trace    = false
	for _, want in ipairs(S.trace or {}) do
	    BudgetStep()
		if SectionMatches(entry, want) then entry.trace = true end
	end
	if not live then return nil end
	target._opacitySet = nil
	return target
end

-- Returns the sections that matched nothing, which is the list worth printing: a typo in a
-- section name is otherwise completely silent.
local function ResolveTargets()
	managed = {}
	local sections = ConfiguredSections()
	local hits     = {}

	local blinking = {}

	-- [depth] = what the widget at that depth on the CURRENT branch claims. Valid only for depths
	-- shallower than the entry being looked at, which is all it is ever read for.
	local pathSections = {}

	-- Lowered out here, not in the loop: the two inner loops below run once per section for every
	-- widget the walk found, which is thousands of identical string.lower calls per pass.
	local wantIdentify, wantSections = {}, {}
	for i, want in ipairs(S.identify) do wantIdentify[i] = string.lower(want) end
	for i, section in ipairs(sections) do wantSections[i] = string.lower(section) end

	for _, entry in ipairs(discovered) do

	    BudgetStep()
		entry.identify = false
		for _, want in ipairs(wantIdentify) do
		    BudgetStep()
			if SectionMatches(entry, want) then
				entry.identify = true
				blinking[#blinking + 1] = entry.name
			end
		end

		local claims = nil
		for i, section in ipairs(sections) do
		    BudgetStep()
			if SectionMatches(entry, wantSections[i]) then
				claims = claims or {}
				claims[#claims + 1] = section
				hits[section] = (hits[section] or 0) + 1
			end
		end

		-- Named in [General] elements, or being blinked: takes the [All] values and nothing
		-- else. A blinked widget still needs a target so that restoring it puts back the exact
		-- opacity it had before we started flashing it.
		if claims == nil and (entry.identify or S.elementSet[(LoweredFields(entry))]) then
			claims = {}
		end

		-- [All] on its own reaches every TOP-LEVEL widget - one per thing on screen - and nothing
		-- below them. That is the only depth at which it can mean what people expect it to mean:
		-- render transforms and render opacity both compound down the tree, so "[All] scale = 0.8"
		-- applied to every widget would shrink a four-deep element to 0.41 and a ten-deep one to
		-- 0.11, and "[All] opacity = 0.8" would fade them to nothing. Applied to the roots it is
		-- exactly "the whole UI, once".
		if claims == nil and S.allActive and (entry.depth or 0) == 0 then
			claims = {}
		end

		-- The auto-fade can only fade widgets it is holding, and this file may configure nothing
		-- at all. So while the fade is on, every top-level HUD widget is claimed the same way
		-- [All] claims one: it takes [All]'s values and nothing else. That costs nothing while the
		-- HUD is up, because a target with no opacity in it is a target nobody writes.
		local canFade = FadeAllowed(entry, entry.rootKey, (entry.depth or 0) == 0)
		if claims == nil and canFade then claims = {} end

		if claims ~= nil then
			-- Does this section already own something further up this widget's own branch?
			--
			-- It is a real and quiet trap. Widget trees here reuse a name at two levels - the HUD
			-- has an XPBar (WBP_HUD_XPBar_C) whose bar is also called XPBar (DWW_StatBar_C) - and
			-- a section matches by name, so [XPBar] claims both. Transforms and opacity MULTIPLY
			-- down the tree, so an offset written to both lands on the inner one twice: it walks
			-- away from the icons and arrows sitting beside it, at exactly the offset you asked
			-- for, and nothing about "my bar came apart" points at the section that caused it.
			--
			-- `discovered` is in tree order, depth first, so the entry at any shallower depth in
			-- pathSections is this widget's ancestor on the current branch. That makes the check
			-- a couple of table lookups rather than a walk back up the tree.
			local depth = entry.depth or 0
			for _, section in ipairs(claims) do
			    BudgetStep()
				for above = 0, depth - 1 do
				    BudgetStep()
					local owner = pathSections[above]
					if owner ~= nil and owner.sections[section] then
						local key = section .. "|" .. (owner.name or "?") .. "|" .. (entry.name or "?")
						if not nestedWarned[key] then
							nestedWarned[key] = true
							Log("WARNING: [%s] matches %s (%s) AND %s (%s) inside it. Transforms " ..
							    "and opacity multiply down the tree, so every value in that " ..
							    "section is applied TWICE to the inner one - it will drift away " ..
							    "from whatever sits beside it by exactly the offset you set.",
							    section, owner.name or "?", owner.class or "?",
							    entry.name or "?", entry.class or "?")
							Log("  Name one of them by its class instead: [%s] for the outer, " ..
							    "[%s] for the inner.",
							    string.gsub(owner.class or "?", "_C$", ""),
							    string.gsub(entry.class or "?", "_C$", ""))
						end
					end
				end
			end

			local mine = {}
			for _, section in ipairs(claims) do mine[section] = true end
			pathSections[depth] = { sections = mine, name = entry.name, class = entry.class }

			entry.sections    = claims
			entry.target      = BuildTarget(entry, claims)
			entry.fadeAllowed = canFade
			managed[#managed + 1] = entry
		else
			-- Nothing claims this one, so it cannot be an ancestor anybody has to worry about -
			-- but it still has to clear the slot, or a widget on a previous branch would be
			-- mistaken for this one's ancestor.
			pathSections[entry.depth or 0] = nil
			entry.sections    = nil
			entry.target      = nil
			entry.fadeAllowed = false
		end
	end

	if #blinking > 0 then
		Log("IDENTIFY: blinking %s - watch the screen, then clear identify in %s",
		    table.concat(blinking, ", "), INI_NAME)
	elseif #S.identify > 0 then
		Log("IDENTIFY: nothing matched %s", table.concat(S.identify, ", "))
	end

	local missing = {}
	for _, section in ipairs(sections) do
	    BudgetStep()
		if hits[section] == nil then missing[#missing + 1] = section end
	end
	return missing
end

-- ##############################
-- Per-instance widgets
-- ##############################

-- Every root class in this game behaves the way an enemy health bar does in a game with one HUD:
-- instances are created and destroyed while you play, and there can be several at once. So the
-- per-instance path is not a special case here, it is the main one.
--
-- [classKey] = { generation, byName = table | false, rootOnly = bool }
-- byName == false means "nothing in this class is configured", which is the free path.
-- The cache is keyed by widget name, and exactly one widget in an instance does not have a usable
-- one: the root. It is created at runtime, so its name carries a unique object number -
-- WBP_Compass_Mappin_C_2147466210 - and no two instances share it. Everything below it belongs to
-- the blueprint's widget tree and keeps its stable designer name, so the root alone needs a key
-- that means "whatever this instance is called".
local ROOT_KEY = "<root>"   -- angle brackets cannot appear in a widget name, so this cannot clash

-- Widgets the game creates at runtime rather than laying out in the editor - a compass pin per
-- marker, a toast per notification, the entries a list builds for its rows - are named with the
-- engine's object number on the end: WBP_Compass_Mappin_C_2147466210. That number is different on
-- every instance, so caching by the raw name would mean the cache never hit twice and a wildcard
-- section could never reach those widgets on more than the one instance it was built from.
-- Designer names carry small suffixes of their own - Overlay_162, Border_174, PanelSlot_2 - and
-- those are stable and must be kept, so only a long run of digits (engine object numbers are in
-- the billions) is treated as an instance number.
local function NameKey(name)
	local lowered = string.lower(name or "")
	return (string.gsub(lowered, "_%d%d%d%d%d%d%d+$", ""))
end

local instanceCache  = {}
local instanceWrites = 0
local instanceTimed  = 0

-- Sections the instance path owns this generation. The full pass would otherwise report them as
-- unmatched when nothing of that class happens to be on screen while it runs.
local instanceClaimed = { generation = -1, names = {} }

local function ClaimedSections()
	if instanceClaimed.generation ~= applyGeneration then
		instanceClaimed = { generation = applyGeneration, names = {} }
	end
	return instanceClaimed.names
end

local function Now()
	local t = nil
	pcall(function() t = os.clock() end)
	return t
end

-- Flat list of every widget under `root`, root included. Deliberately separate from the full
-- pass: it must not touch `discovered`, and it is walking tens of widgets rather than thousands.
-- Same as WalkWidget: the callers hand this an object they have already validated, and every
-- child comes out of ChildrenOf, which validated it.
local function CollectSubtree(root, list, seen, depth, parentName, parentPath)
    BudgetStep()
	if not IsValidObject(root) then return end
	if depth > S.maxDepth then return end
	local key = SafeName(root)
	if seen[key] then return end
	seen[key] = true

	local item = {
		obj = root, key = key, name = SafeShortName(root), class = SafeClassName(root),
		-- The parent's name and the whole ancestor path, so a "parent/name" section matches on
		-- this path as well as on the full walk. Same format as Visit builds.
		parent = parentName,
		ppath  = parentPath or "",
	}
	list[#list + 1] = item

	local path = (item.ppath == "" and "" or (item.ppath .. "/")) .. PathSeg(item.name)
	for _, child in ipairs(ChildrenOf(root)) do
	    BudgetStep()
		CollectSubtree(child, list, seen, depth + 1, item.name, path)
	end
end

-- Built once per class per reload, from the first instance we are handed. Every instance of a
-- class comes from the same blueprint, so the vanilla values are the same on all of them and one
-- snapshot answers for the lot - which is also what stops the snapshot table growing per prompt.
local function BuildInstanceCache(root, classKey, specKey)
	local list, sections = {}, ConfiguredSections()
	CollectSubtree(root, list, {}, 0)

	-- The first item CollectSubtree produces is the root, and it is the one that answers to the
	-- name this widget was found by - see LoweredFields.
	if list[1] ~= nil then list[1].rootSpec = specKey end

	local byName, count = {}, 0
	local rootFullName  = SafeName(root)
	local nonRoot, opacityWanted = false, false

	-- Work.host.NotifyOnNewObject hands us the widget the instant it is allocated, which is BEFORE its
	-- WidgetTree has been filled in - so the walk above can legitimately come back with nothing
	-- but the root. Caching that as the answer for the whole class would be a lie that lasts
	-- until the next trigger: every later instance would be told there is nothing inside it to
	-- tweak. So a one-item walk builds a cache that is used now and thrown away, and the
	-- follow-up calls a moment later build the real one.
	local incomplete = #list <= 1
	local cacheGen   = incomplete and -1 or applyGeneration

	for _, item in ipairs(list) do

	    BudgetStep()
		local claims = nil
		for _, section in ipairs(sections) do
		    BudgetStep()
			if SectionMatches(item, string.lower(section)) then
				claims = claims or {}
				claims[#claims + 1] = section
			end
		end

		-- Same rule as the full pass: [All] claims the top-level widget and nothing under it.
		local isTop   = item.key == rootFullName
		local canFade = FadeAllowed(item, specKey, isTop)
		if claims == nil and S.allActive and isTop then
			claims = {}
		end
		if claims == nil and canFade then claims = {} end

		if claims ~= nil then
			local entry = { name = item.name, class = item.class, snapshot = ReadState(item.obj) }
			local target = BuildTarget(entry, claims)
			if target ~= nil then
				-- Keyed by name AND ancestor path, not name alone. Every instance of a class has
				-- the same tree, so the path is as stable as the name - and it is what stops a
				-- generic name at two places in one tree (CommonVisualAttachment_0 wraps the
				-- quickslot change prompt AND sits inside the compass) sharing a single target.
				local lowered = ROOT_KEY
				if item.key ~= rootFullName then
					lowered = NameKey(item.name) .. "|" .. (item.ppath or "")
				end
				byName[lowered] = {
					target   = target,
					snapshot = entry.snapshot,
					force    = entry.force == true,
					reassert = entry.reassert,
					reveal   = entry.reveal,
					trace    = entry.trace == true,
					-- Worked out once per class here, so the per-instance path never has to match
					-- a section name again to know whether the fade owns this widget.
					fade     = canFade,
				}
				count = count + 1
				if lowered ~= ROOT_KEY then nonRoot = true end
				if target.opacity ~= nil and Differs(target.opacity, entry.snapshot.opacity) then
					opacityWanted = true
				end

				local claimed = ClaimedSections()
				for _, section in ipairs(claims) do claimed[section] = true end
			end
		end
	end

	if count == 0 then
		-- Completely normal: the default roots list covers the whole HUD and most people configure
		-- three or four things in it. Not worth a warning, only a debug line.
		if not incomplete then
			Debug("%s is live but nothing in %s configures it - its hook is a no-op",
			      classKey, INI_NAME)
		end
		instanceCache[classKey] = { generation = cacheGen, byName = false }
		return instanceCache[classKey]
	end

	-- Widgets that drive their own RenderOpacity every tick - the crosshair fading in as you aim,
	-- a scene marker fading by distance - will overwrite anything we write. Say so rather than let
	-- it look broken. reassertAfter in the ini is the way to win those.
	if opacityWanted then
		Debug("opacity on %s may not stick if that widget animates its own fade - if it does not " ..
		      "hold, use reassertAfter, or use scale/offsets instead.", classKey)
	end

	if not incomplete then
		Debug("%s - %d widget(s) configured%s", classKey, count,
		      nonRoot and "" or ", root only (no subtree walk needed)")
	end

	instanceCache[classKey] = {
		generation = cacheGen,
		byName     = byName,
		-- An incomplete walk must not claim "the root is all there is" - that is what rootOnly
		-- means, and it would stop the next call from ever looking inside.
		rootOnly   = (not nonRoot) and not incomplete,
	}
	return instanceCache[classKey]
end

-- Runs once per widget that appears. Everything expensive has already been done by the time a
-- second instance of that class gets here.
local function TweakInstance(root, specKey)
    BudgetStep()
	if not S.enabled or suspended then return end
	if not IsValidObject(root) or IsDefaultObject(root) then return end

	local classKey = string.lower(SafeClassName(root))
	local cache    = instanceCache[classKey]

	if cache == nil or cache.generation ~= applyGeneration then
		local started = Now()
		cache = BuildInstanceCache(root, classKey, specKey)
		local finished = Now()
		if started ~= nil and finished ~= nil and S.instanceTimings > 0 then
			Debug("first %s took %.2f ms to work out", classKey, (finished - started) * 1000)
		end
	end

	if cache.byName == false then return end   -- the free path

	local started = (instanceTimed < S.instanceTimings) and Now() or nil

	-- rootOnly is the normal case - "[WBP_Compass_Mappin] scale = 0.8" and nothing else - and we
	-- already hold the only object we need, so there is no walk at all.
	local items = nil
	if cache.rootOnly then
		items = { {
			obj = root, key = SafeName(root),
			name = SafeShortName(root), class = SafeClassName(root),
		} }
	else
		items = {}
		CollectSubtree(root, items, {}, 0)
	end

	local wrote, rootFullName = 0, SafeName(root)
	for _, item in ipairs(items) do
	    BudgetStep()
		local lookup = ROOT_KEY
		if item.key ~= rootFullName then
			lookup = NameKey(item.name) .. "|" .. (item.ppath or "")
		end

		local want = cache.byName[lookup]
		if want ~= nil and IsValidObject(item.obj) then
			local entry = vanilla[item.key]
			if entry == nil then
				-- item.class, not classKey: an entry created here can be met again by the full
				-- pass, which reuses it rather than re-reading the widget, so it has to carry the
				-- widget's OWN class or every section matched by class would miss it from then on.
				entry = {
					key = item.key, name = item.name, class = item.class,
					parent   = item.parent,
					ppath    = item.ppath,
					rootSpec = (item.key == rootFullName) and specKey or nil,
					snapshot = want.snapshot,   -- shared per class, see BuildInstanceCache
					-- These die and are replaced constantly. When one goes we sweep its class
					-- rather than treat it as "the HUD was rebuilt".
					instance = true,
					-- The root we were found by, not our own class: those differ for a menu, and
					-- the re-check sweeps by root, so storing the class would leave a dead menu
					-- widget asking for a sweep of a root that does not exist.
					rootKey  = specKey or classKey,
					reassert = want.reassert ~= false,
					force    = want.force == true,
				}
				vanilla[item.key] = entry
			end
			entry.obj    = item.obj
			entry.target = want.target
			entry.force  = want.force == true
			entry.reveal = want.reveal
			entry.trace  = want.trace == true
			entry.fadeAllowed = want.fade == true

			local changed = WriteState(entry, want.target)
			if changed ~= nil and #changed > 0 then wrote = wrote + 1 end
			written[item.key] = entry
			instanceWrites = instanceWrites + 1
		end
	end

	RememberRoot(root)

	local finished = Now()
	if started ~= nil and finished ~= nil then
		instanceTimed = instanceTimed + 1
		Debug("%s tweaked (%d widget(s), %d changed) in %.2f ms",
		      classKey, #items, wrote, (finished - started) * 1000)
	end
end

-- The hook catches everything created from now on; this catches what is already on screen, so
-- pressing reload does something immediately. `wanted` is an optional function(spec) that narrows
-- it: the re-check uses it to sweep the one class whose widget just died, and the menu heartbeat
-- uses it to sweep only the screens.
local function SweepInstances(wanted)
	if not S.enabled or suspended then return 0 end

	local found = 0
	for _, spec in ipairs(rootSpecs) do
	    BudgetStep()
		if wanted == nil or wanted(spec) then
			local ok, list = pcall(FindAllOf, spec.class)
			if ok and list ~= nil then
				for _, obj in pairs(list) do
				    BudgetStep()
					if IsValidObject(obj) and not IsDefaultObject(obj) then
						found = found + 1
						pcall(TweakInstance, obj, spec.key)
					end
				end
			end
		end
	end
	return found
end

-- ##############################
-- Applying
-- ##############################

local function DescribeState(st)
	if st == nil then return "?" end
	local text = string.format("offset=(%.0f, %.0f) scale=(%.2f, %.2f) opacity=%.2f vis=%s",
		st.tx or 0, st.ty or 0, st.sx or 1, st.sy or 1, st.opacity or 1,
		VIS_NAME[st.vis] or tostring(st.vis))
	-- Printed only for the widgets that actually have a tint, so the line does not carry a
	-- meaningless colour on every box and panel that has none - and its absence is the answer to
	-- "why does brightness do nothing on this one".
	if st.cr ~= nil then
		text = text .. string.format(" colour=(%.2f, %.2f, %.2f)", st.cr, st.cg or 0, st.cb or 0)
	end
	return text
end

local function DumpWidgets()
	Log("---- HUD widgets (%d found, dumpWidgets = true in %s) ----", #discovered, INI_NAME)
	Log("Use a widget's NAME as an ini section, e.g. [%s]",
	    (discovered[1] ~= nil) and discovered[1].name or "AmmoBG")

	local hidden = 0
	for _, entry in ipairs(discovered) do
	    BudgetStep()
		local tooDeep = (S.dumpMaxDepth > 0) and ((entry.depth or 0) > S.dumpMaxDepth)
		                and entry.target == nil
		if tooDeep then hidden = hidden + 1 end

		if (not tooDeep) and ((not S.dumpOnlyManaged) or entry.target ~= nil) then
			local indent = string.rep("  ", entry.depth or 0)
			local claim  = ""
			if entry.sections ~= nil and #entry.sections > 0 then
				claim = "   <- [" .. table.concat(entry.sections, "] [") .. "]"
			elseif entry.target ~= nil then
				claim = "   <- [All]"
			end

			-- The numbers printed are the VANILLA snapshot, which is what you tune against. When
			-- the widget is not currently holding them the live values follow, so the dump answers
			-- "did my value actually land on this thing" without any guesswork.
			local live = IsValidObject(entry.obj) and ReadState(entry.obj) or nil
			if live ~= nil then
				local van = entry.snapshot or {}
				if Differs(live.tx, van.tx) or Differs(live.ty, van.ty)
				   or Differs(live.sx, van.sx) or Differs(live.sy, van.sy)
				   or Differs(live.opacity, van.opacity) or live.vis ~= van.vis
				   or Differs(live.cr, van.cr) or Differs(live.cg, van.cg)
				   or Differs(live.cb, van.cb) then
					claim = claim .. "   now: " .. DescribeState(live)
				end
			end

			Log("  %s%-40s %-30s %s%s", indent,
			    entry.name or "?", entry.class or "?", DescribeState(entry.snapshot), claim)
		end
	end

	-- Hidden here means "not printed", never "not found" - a section still matches these.
	if hidden > 0 then
		Log("  ... %d more below depth %d, not printed. They are still matchable - raise " ..
		    "dumpMaxDepth to see them.", hidden, S.dumpMaxDepth)
	end
	Log("---- end of widget list ----")
end

-- The full pass: find the widgets, snapshot anything new, work out what each one should look
-- like, and write it. Runs on a trigger only - never on a timer.
function ApplyAll(verbose)
	if not S.enabled or suspended then return 0 end

	local roots = CollectWidgets()
	if roots == 0 then
		Debug("nothing on screen yet (looked for %d root class(es))", #rootSpecs)
		return 0
	end

	local missing = ResolveTargets()

	local touched = 0
	for _, entry in ipairs(managed) do
	    BudgetStep()
		local changed = WriteState(entry, entry.target)
		if changed ~= nil and #changed > 0 then
			touched = touched + 1
			written[entry.key] = entry
			if verbose then
				Log("  %s: %s", entry.name, table.concat(changed, ", "))
			end
		elseif entry.target ~= nil then
			-- Already correct, but still ours to defend if something resets it later.
			written[entry.key] = entry
		end
	end

	-- A section for a widget class that is simply not on screen right now - a loot marker, a
	-- notification - is not a typo, and reporting it as one sends people looking for a mistake
	-- that is not there. Anything the instance path has ever built a target for is excused.
	local claimed, unmatched = ClaimedSections(), {}
	local rootNames = {}
	for _, spec in ipairs(rootSpecs) do
	    BudgetStep()
		rootNames[spec.key] = true
		rootNames[string.gsub(spec.key, "_c$", "")] = true
	end

	for _, section in ipairs(missing) do

	    BudgetStep()
		if not claimed[section] and not rootNames[string.lower(section)] then
			unmatched[#unmatched + 1] = section
		end
	end

	if verbose then
		Log("%d live root widget(s), %d widget(s) walked, %d configured, %d changed",
		    roots, #discovered, #managed, touched)
		if #unmatched > 0 then
			-- Either a typo, or simply nothing of that kind on screen at this moment - a loot
			-- marker with no loot nearby, a notification that is not up. The bake still applies
			-- to those, so this is worth reading but is not necessarily a problem.
			Log("  nothing on screen matched: %s", table.concat(unmatched, ", "))
		end
		if S.dumpWidgets then DumpWidgets() end
	end

	return touched
end

local function RestoreAll()
	local restored = 0

	-- The fade lets go first. A restore has to put the vanilla value back, not the vanilla value
	-- times whatever the fade happened to be holding at the moment the key was pressed.
	fadeLevel, fadeApplied, fadeIdleSince = 1.0, nil, nil

	for _, entry in pairs(written) do

	    BudgetStep()
		entry.fade = nil
		if IsValidObject(entry.obj) then
			local changed = WriteState(entry, entry.snapshot)
			if changed ~= nil and #changed > 0 then restored = restored + 1 end
		end
	end
	written = {}
	Work.forced, Work.fading = {}, {}
	if restored > 0 then Debug("restored %d widget(s) to vanilla", restored) end
	return restored
end

-- Widgets die constantly here. Drop the dead ones so the tables do not grow all session, but keep
-- the snapshots for anything still alive.
local function PurgeDead()
	local dropped = 0
	for key, entry in pairs(vanilla) do
	    BudgetStep()
		if not IsValidObject(entry.obj) then
			vanilla[key] = nil
			written[key] = nil
			Work.forced[key], Work.fading[key] = nil, nil
			dropped = dropped + 1
		end
	end
	if dropped > 0 then Debug("dropped %d widget(s) that no longer exist", dropped) end
end

-- The cheap layer. Walks only the widgets we wrote to, re-reads only the fields we wrote on them,
-- and searches for nothing.
--
-- When one has died we do NOT run a full pass. In this game a dead widget is the normal case - a
-- prompt went away, a notification finished - and a full pass would mean re-searching two dozen
-- classes and re-walking every tree. Instead its class is swept: FindAllOf for that one class and
-- the cheap per-instance tweak on whatever is live. Anything genuinely new was already caught by
-- the class-default bake and Work.host.NotifyOnNewObject before it ever painted.
local function ReassertManaged()
	if not S.enabled or suspended then return 0 end

	local fixed, sweep = 0, nil
	for key, entry in pairs(written) do
	    BudgetStep()
		if not IsValidObject(entry.obj) then
			written[key] = nil
			vanilla[key] = nil
			Work.forced[key], Work.fading[key] = nil, nil
			if entry.rootKey ~= nil then
				sweep = sweep or {}
				sweep[entry.rootKey] = true
			end
		elseif entry.identify then
			-- The blink owns this one's opacity. Re-asserting it here would just fight the flash.
		elseif entry.reassert ~= false and entry.target ~= nil then
			local changed = WriteState(entry, entry.target, "recheck")
			if changed ~= nil and #changed > 0 then
				fixed = fixed + 1
				Debug("re-applied %s (%s)", entry.name, table.concat(changed, ", "))
			end
		end
	end

	if sweep ~= nil then
		for classKey, _ in pairs(sweep) do
		    BudgetStep()
			Debug("%s widget(s) gone - sweeping the live ones", classKey)
			pcall(SweepInstances, function(spec) return spec.key == classKey end)
		end
	end

	return fixed
end

-- ##############################
-- Auto-fade: the HUD up while something is happening, out of the way while nothing is
-- ##############################

-- The idea is small. Ten times a second, ask a handful of questions about what the player is
-- doing. If any of them says yes, the HUD is up. If none has said yes for idleAfterSeconds, it
-- eases down to idleOpacity. Everything else here is about making that honest and cheap.
--
-- WHY IT IS BUILT OUT OF SEPARATE PROBES. Each question is a small function returning true, false,
-- or NIL for "I could not tell" - the class was not there, the property was not there, the call
-- threw. A probe that cannot answer is never counted as a no. It is named in the log, once, and
-- then ignored. The alternative is a mod that leaves your HUD faded through a boss fight because
-- one property got renamed in a patch, and says nothing about why.
--
-- WHY IT MULTIPLIES RATHER THAN SETS. The fade is a factor on top of whatever the ini already
-- asked for - see EffectiveOpacity - so it composes with [All] opacity, with a per-element
-- opacity, and with the game's own HUDVisibilityPreset switching, instead of overwriting any of
-- them.
--
-- WHY IT LETS GO AT THE TOP. At full brightness entry.fade is cleared rather than parked at 1.0,
-- so a HUD that is up is a HUD this feature is not writing to at all. It holds a value only while
-- it is actually holding the HUD down.
--
-- WHAT IT DELIBERATELY DOES NOT DO. It never touches Visibility, so nothing changes layout and
-- nothing stops taking input: a faded HUD is still there, just invisible. It never touches menus.
-- And it never touches the class defaults, because a fade level is a thing about right now and
-- baking it into every widget the game will ever make is the opposite of that.

local function FirstLiveOf(className)
	local ok, list = pcall(FindAllOf, className)
	if not ok or list == nil then return nil end
	for _, obj in pairs(list) do
	    BudgetStep()
		if IsValidObject(obj) and not IsDefaultObject(obj) then return obj end
	end
	return nil
end

-- The player pawn: an instance of the player character class that a controller is possessing.
--
-- Both halves of that matter. FindAllOf matches derived classes, so asking for
-- DawnwalkerPlayerCharacter finds BP_PlayerCharacter_C - and does NOT find whatever the main menu
-- map's own MainMenuPlayerController is possessing, which an earlier version of this happily took
-- for the player and then sat there deciding the title screen was idle. And a cutscene level
-- sequence keeps a second, entirely valid BP_PlayerCharacter around as a template (it is in the
-- object dump under CS004_wakeUp_part2_LS), so among the candidates the possessed one is the real
-- one and there is no fallback to "whichever turned up first" - a template is not gameplay either.
--
-- Deliberately a question about CLASS and POSSESSION, not "can I read CombatComponent off it".
-- Whether those component reads work is exactly what the probes below are testing and are allowed
-- to fail at, one by one, with a line in the log. Gating the whole feature on the same lookup
-- would mean one broken property switches off the auto-fade entirely and silently - a single point
-- of failure in the one place that must not have one.
--
-- nil means "not in gameplay" - the main menu, a loading screen, the moment after a level load and
-- before possession - and AutoFadeStep treats that as a reason to let go rather than as the
-- quietest kind of idle it has ever seen.
-- Local compatibility backport: revalidate possession even while an old pawn is
-- a valid UObject. No controller input, compass hooks, or additional timers.
local compatibilityController = nil
local compatibilityLookupWarning = nil
local function PlayerPawn()
    local function controls(candidate, pawn)
        if not IsValidObject(candidate) or not IsValidObject(pawn) then return false end
        local ok, result = HostPcall(function()
            if not IsValidObject(candidate) or not IsValidObject(pawn) then return false end
            local name = pawn:GetFullName()
            return not IsDefaultObject(candidate) and not IsDefaultObject(pawn)
                and candidate:IsLocalController() == true
                and IsValidObject(candidate.Pawn)
                and type(name) == "string" and name ~= ""
                and candidate.Pawn:GetFullName() == name
        end)
        return ok and result == true
    end
    if controls(compatibilityController, fadePlayer) then return fadePlayer end
    fadePlayer, compatibilityController = nil, nil

    local function find(className)
        local ok, objects = pcall(FindAllOf, className)
        if ok and objects == nil then return {} end
        if not ok or type(objects) ~= "table" then
            local reason = className .. ": " .. (ok and type(objects) or "lookup failed")
            if compatibilityLookupWarning ~= reason then
                Log("COMPAT: player lookup unavailable (%s); retrying on next probe", reason)
                compatibilityLookupWarning = reason
            end
            return nil
        end
        return objects
    end
    local pawns = find(PLAYER_CLASS)
    if pawns == nil then return nil end
    local controllers = find("PlayerController")
    if controllers == nil then return nil end
    compatibilityLookupWarning = nil
    for _, pawn in pairs(pawns) do
        BudgetStep()
        for _, candidate in pairs(controllers) do
            BudgetStep()
            if controls(candidate, pawn) then
                fadePlayer, compatibilityController = pawn, candidate
                return fadePlayer
            end
        end
    end
    return nil
end

-- The player's components are plain object properties on the pawn - CombatComponent,
-- CombatFocusComponent, ShadowstepComponent - so there is no searching to do once we have it.
local function PlayerPart(field)
	local pawn = PlayerPawn()
	if pawn == nil then return nil end

	local part = nil
	HostPcall(function() if not IsValidObject(pawn) then return end; part = pawn[field] end)
	if IsValidObject(part) then return part end
	return nil
end

-- Health and stamina as 0..1. Both live on CombatComponentBase as a function call, which is one
-- call each and saves walking an attribute set to find the same number.
--
-- The sanity check is not decoration. "Percentage" is an ambiguous word and the pinning failure it
-- causes is total: if either of these comes back on a 0..100 scale, or comes back 0 because the
-- call did not really work, then `hp < hurtBelow` is true forever, the HUD counts as never idle,
-- and the whole feature silently does nothing. So a value above 1 is read as a 0..100 percentage
-- and scaled, and a value of 0 or below is refused as untrustworthy rather than believed.
--
-- Refusing 0 does mean losing this signal at exactly 0 health. That is a moment when the death
-- screen is up and the HUD being visible is not in question, so it is the cheap half of the trade.
local function Vital(value)
	local n = ToNumber(value)
	if n == nil then return nil end
	if n > 1.001 then n = n / 100.0 end
	if n <= 0.0 or n > 1.001 then return nil end
	return n
end

local function PlayerVitals(withStamina)
	local combat = PlayerPart("CombatComponent")
	if combat == nil then return nil, nil end

	local hp, sp = nil, nil
	HostPcall(function() if not IsValidObject(combat) then return end; hp = Vital(combat:GetHealthPercentage()) end)
	-- Stamina is opt-in per probe, and off by default, because of what spends it: a sprint, a
	-- dodge, a shadowstep. Outside combat those are the most ordinary things a player does, and
	-- every one of them dropped the bar 2% and brought the whole HUD back for the refill. That
	-- was the "shadowstep un-fades the HUD" report, and it took the debug line to see it - it
	-- looked like an aim signal from the outside.
	if withStamina then
		HostPcall(function() if not IsValidObject(combat) then return end; sp = Vital(combat:GetStaminaPercentage()) end)
	end
	return hp, sp
end

-- ESlateVisibility values that mean the thing is actually on screen. Collapsed and Hidden are not
-- here on purpose: half the widgets in the watch list are permanent children that the game
-- collapses when they have nothing to say.
local FADE_SHOWN_VIS = { [0] = true, [3] = true, [4] = true }

-- Is this widget actually on screen?
--
-- IsVisible() first, because it asks SLATE what it did with the widget rather than reading the
-- UMG property and hoping: a widget can carry a perfectly innocent SelfHitTestInvisible and still
-- never have been built.
--
-- And when nothing can be read, the answer is NO. That is the second time this file has had to
-- learn the same lesson and it is worth writing down: "I could not tell" must never resolve to
-- "yes" here. The costs are not symmetric. A wrong yes is total - one permanently-alive widget in
-- the watch list holds the HUD up forever, the fade never runs once, and the whole mod looks like
-- it did not load - while a wrong no just means the HUD fades a moment early on a prompt that was
-- up. Three widgets pinned it exactly this way in testing: WBP_InteractablePrompt_AbilityVariant,
-- WBP_HUD_Readable and WBP_NotificationPanel_Toast_Entry all exist all the time.
local function WidgetIsShown(obj)
	local visible = nil
	pcall(function() visible = obj:IsVisible() end)
	if visible ~= nil then
		if visible ~= true then return false end
	else
		local vis = ReadVisibility(obj)
		if vis == nil or not FADE_SHOWN_VIS[vis] then return false end
	end

	local opacity = nil
	pcall(function() opacity = Num(obj:GetRenderOpacity(), nil) end)
	if opacity == nil then return true end

	-- Careful here. This mod may be fading that very widget, and one WE have faded to nothing must
	-- not read back as "not on screen": that is a feedback loop in which the fade quietly stops
	-- the thing that would have cancelled it. So when the live value is too low to count, go and
	-- ask whether we are the reason, and if we are, judge it on the opacity it had before we
	-- touched it. The lookup is only paid for a widget that already reads as faded.
	if opacity <= 0.01 then
		local ours = written[SafeName(obj)]
		if ours ~= nil and ours.fade ~= nil and ours.snapshot ~= nil then
			opacity = ours.snapshot.opacity
		end
	end

	return opacity == nil or opacity > 0.01
end
WidgetIsShown = HostFunction(WidgetIsShown)

local function AnyShown(className)
    for _, obj in ipairs(ObjectIndex.get(className)) do
        BudgetStep()
        BudgetStep()
        if IsValidObject(obj) and not IsDefaultObject(obj) and WidgetIsShown(obj) then return true end
    end
    return false
end

-- Each probe returns true (something is happening), false (nothing is), or nil (could not tell).
-- `key` is the ini switch, `what` is what the log calls it.
local FADE_PROBES = {
	{
		key = "showInCombat", what = "in combat",
		run = function()
			if not IsValidObject(fadeCombatSub) or IsDefaultObject(fadeCombatSub) then
				fadeCombatSub = FirstLiveOf("CombatSubsystem")
			end
			if fadeCombatSub == nil then return nil end

			local value = nil
			HostPcall(function() if not IsValidObject(fadeCombatSub) then return end; value = fadeCombatSub.bIsInCombat end)
			if value == nil then HostPcall(function() if not IsValidObject(fadeCombatSub) then return end; value = fadeCombatSub:GetIsInCombat() end) end
			if value == nil then return nil end
			return value == true
		end,
	},
	{
		key = "showWeaponDrawn", what = "weapon drawn",
		run = function()
			local combat = PlayerPart("CombatComponent")
			if combat == nil then return nil end

			-- ECombatModeType: 0 = None, then Fistfight, HandToHand, Sword, VampireHandToHand,
			-- VampireSword. Anything but None means the player is standing in a fighting stance,
			-- which is the earliest honest signal that combat is about to matter - it comes up
			-- before the combat subsystem does.
			local mode = nil
			HostPcall(function() if not IsValidObject(combat) then return end; mode = ToNumber(combat.CurrentCombatMode) end)
			if mode == nil then return nil end
			return mode ~= 0
		end,
	},
	{
		key = "showWhenLockedOn", what = "locked on to a target",
		run = function()
			local combat = PlayerPart("CombatComponent")
			if combat == nil then return nil end

			local locked = nil
			HostPcall(function() if not IsValidObject(combat) then return end; locked = combat:IsHardLocked() end)
			if locked ~= nil then return locked == true end

			-- Soft lock: there is a target even if it is not a hard lock.
			local target = nil
			HostPcall(function() if not IsValidObject(combat) then return end; target = combat.CurrentLockTarget end)
			if target == nil then return nil end
			return IsValidObject(target)
		end,
	},
	{
		key = "showInFocusMode", what = "in focus mode",
		run = function()
			local pawn = PlayerPawn()
			if pawn == nil then return nil end

			-- Planning the abilities and executing the plan are two different states, and both of
			-- them are very much "something is happening".
			local planning = nil
			HostPcall(function() if not IsValidObject(pawn) then return end; planning = pawn.bIsInFocusMode end)

			local executing = nil
			local focus = PlayerPart("CombatFocusComponent")
			if focus ~= nil then HostPcall(function() if not IsValidObject(focus) then return end; executing = focus:IsExecuting() end) end

			if planning == nil and executing == nil then return nil end
			return planning == true or executing == true
		end,
	},
	{
		key = "showWhenAiming", what = "aiming a shadowstep",
		run = function()
			local shadowstep = PlayerPart("ShadowstepComponent")
			if shadowstep == nil then return nil end

			local aiming = nil
			HostPcall(function() if not IsValidObject(shadowstep) then return end; aiming = shadowstep:GetAimingEnabled() end)
			if aiming == nil then return nil end
			if aiming ~= true then return false end

			-- Aiming with LT and firing a shadowstep with RT both light GetAimingEnabled, and
			-- only the first is "the player is lining something up" - the second is a one-second
			-- teleport that should not drag a faded HUD back on screen outside combat (in combat
			-- showInCombat holds it regardless). The step has its own state machine
			-- (GetShadowstepState: Idle / StartMontage / Transition / TeleportTransition /
			-- EndMontage / BlendOut) but the dump gives no numeric values for it, so this asks
			-- the value-free question instead: has a step actually fired in the last moment? If
			-- it has, this is an execution, not an aim. Unreadable = trust the aim, as before.
			local fired = nil
			HostPcall(function() if not IsValidObject(shadowstep) then return end; fired = shadowstep:HasBeenTriggeredRecently(S.stepSeconds) end)
			if fired == true then return false end
			return true
		end,
	},
	{
		key = "showWhenHurt", what = "health or stamina not full",
		run = function()
			local hp, sp = PlayerVitals(S.hurtStamina)
			if hp == nil and sp == nil then return nil end
			return (hp ~= nil and hp < S.hurtBelow) or (sp ~= nil and sp < S.hurtBelow)
		end,
	},
	{
		key = "showOnStatChange", what = "health or stamina just moved",
		run = function()
			local hp, sp = PlayerVitals(S.statChangeStamina)
			if hp == nil and sp == nil then return nil end

			-- True only on the tick a value MEANINGFULLY moved. The threshold is the whole point
			-- and it is not Differs's hair-width 0.0005: stamina regenerates continuously, so a
			-- "did it change at all" test is true on every single tick while it refills and the
			-- HUD never fades. statChangeBy is what makes this "something happened to you" rather
			-- than "a float moved".
			local function moved(now, before)
				if now == nil or before == nil then return false end
				return math.abs(now - before) >= S.statChangeBy
			end

			local changed = moved(hp, lastHealth) or moved(sp, lastStamina)
			if lastHealth == nil and lastStamina == nil then changed = false end
			lastHealth, lastStamina = hp, sp
			return changed
		end,
	},
}

-- Returns: engaged, the reasons it is, and the probes that could not answer.
local function ProbeEngaged(now)
	local engaged, reasons, unknown = false, {}, {}

	for _, probe in ipairs(FADE_PROBES) do

	    BudgetStep()
		if S[probe.key] then
			local ok, value = pcall(probe.run)
			if not ok then value = nil end

			if value == nil then
				unknown[#unknown + 1] = probe.key
				probeSince[probe.key] = nil
			elseif value then
				-- A signal can be asked to stay true for a while before it counts. This is the
				-- answer to a shadowstep: it trips the aim / focus probes for well under a second,
				-- and nothing in the game's API says "this was a teleport, not an aim" reliably
				-- enough to lean on. So instead of naming the blip, outlast it: LT held or focus
				-- mode entered on purpose is still there a second later; a step is not.
				local since = probeSince[probe.key] or now
				probeSince[probe.key] = since
				if (now - since) >= (S.probeAfter[probe.key] or 0) then
					engaged = true
					reasons[#reasons + 1] = probe.what
				end
			else
				probeSince[probe.key] = nil
			end
		end
	end

	for _, class in ipairs(S.fadeWatch or {}) do

	    BudgetStep()
		local shown = AnyShown(class)
		if shown == nil then
			unknown[#unknown + 1] = class
		elseif shown then
			engaged = true
			reasons[#reasons + 1] = class
		end
	end

	return engaged, reasons, unknown
end

-- Said once per reload. The alternative is a feature that quietly does nothing and a player with
-- no way to find out why - and since every one of these signals is a guess about a game that can
-- be patched under us, "could not read" is the single most useful line this mod prints.
local function ReportProbes(unknown)
	if fadeReported then return end
	fadeReported = true

	local on = {}
	for _, probe in ipairs(FADE_PROBES) do
	    BudgetStep()
		if S[probe.key] then on[#on + 1] = probe.key end
	end

	Log("AUTO-FADE: idle for %.1fs -> opacity %.2f over %.1fs, back to full in %.2fs.",
	    S.idleAfter, S.idleOpacity, S.fadeOutSeconds, S.fadeInSeconds)
	Log("  watching: %s", (#on > 0) and table.concat(on, ", ") or "(no player-state signals)")
	if #(S.fadeWatch or {}) > 0 then
		Log("  and these being on screen: %s", table.concat(S.fadeWatch, ", "))
	end
	if #unknown > 0 then
		Log("  COULD NOT READ: %s. Those signals are OFF - everything else still works. If the " ..
		    "game has renamed something, the scan key lists what is really on screen.",
		    table.concat(unknown, ", "))
	end
end

-- The fade's own write: the effective opacity and nothing else. Two property accesses per widget
-- instead of WriteState's dozen.
local function WriteFadeOpacity(entry)
    BudgetStep()
	local target = entry.target
	if target == nil then return false end
	local want = EffectiveOpacity(entry, target)
	if want == nil then return false end

	local widget = entry.obj
	if not IsValidObject(widget) then return false end
	-- Same identity check as WriteState, for the same reason. This is the hot path (every ease
	-- step, every held widget), and one GetFullName per write is what it costs to never write
	-- into a reused object slot.
	if entry.key ~= nil and SafeName(widget) ~= entry.key then
		entry.obj = nil
		return false
	end
	local live = nil
	pcall(function() live = Num(widget:GetRenderOpacity(), nil) end)
	if not Differs(live, want) then return false end

	local ok = pcall(function() widget:SetRenderOpacity(want) end)
	if ok and entry.trace then
		Log("TRACE %s via fade | opacity %.2f -> %.2f", entry.name or "?", live or -1, want)
	end
	return ok
end
WriteFadeOpacity = HostFunction(WriteFadeOpacity)

-- Writes the current level onto the widgets the fade owns. Nothing is written when the level has
-- not moved, so a HUD that is fully up, or fully faded and sitting there, costs one float compare
-- per tick and no widget work at all.
local function PushFade()
	if not Differs(fadeLevel, fadeApplied) then return end

	local holding    = fadeLevel < 0.9995
	local wasHolding = (fadeApplied ~= nil) and (fadeApplied < 0.9995)
	fadeApplied = fadeLevel

	-- Already fully up and still fully up: there is nothing for this feature to do or undo.
	if not holding and not wasHolding then return end

	-- Named once, the first time the fade actually holds something. Without this the only way to
	-- answer "what did it just hide?" is to guess from a widget count, which is not an answer.
	if holding and not fadeNamed then
		fadeNamed = true
		local names = {}
		for _, entry in pairs(Work.fading) do
		    BudgetStep()
			if entry.fadeAllowed then names[#names + 1] = entry.name or "?" end
		end
		table.sort(names)
		Log("AUTO-FADE: holding %d widget(s): %s", #names,
		    (#names > 0) and table.concat(names, ", ") or "(nothing)")
	end

	local touched = 0
	for _, entry in pairs(Work.fading) do
	    BudgetStep()
		-- A widget whose opacity could not be read has no base to fade FROM and, worse, nothing
		-- to put back afterwards. Better never to touch it than to fade it and get stuck.
		local base = entry.target ~= nil
		             and (entry.target.opacity ~= nil
		                  or (entry.snapshot ~= nil and entry.snapshot.opacity ~= nil))

		if entry.fadeAllowed and base and not entry.identify and IsValidObject(entry.obj) then
			-- Note the 1.0 rather than nil on the way back up. EffectiveOpacity returns nil for an
			-- entry whose section set no opacity of its own - which is most of them, since the
			-- fade claims widgets nobody configured - so clearing the field first would mean no
			-- write at all and a widget left sitting at whatever it had faded to. Write at
			-- exactly 1.0, which is the base value, and only then let go.
			--
			-- The base is the SNAPSHOT, on purpose, and an attempt to do better is worth recording
			-- so it is not tried again the same way. Re-reading the live opacity at the start of
			-- each hold - so that a widget the game had set to 0 (the closed focus radial) would
			-- be held at 0 and put back at 0 - looked right and pinned the whole HUD: the first
			-- hold fires two seconds after begin play, while the game is still bringing its own
			-- HUD in, and a live value read then is a transient that becomes permanent the moment
			-- we write it back. See NOTES.md §5c. The radial is handled in the ini instead.
			entry.fade = holding and fadeLevel or 1.0
			-- Opacity only. WriteState reads the whole transform and pivot as well, seven
			-- property reads a widget that the fade has no use for - the re-check owns those.
			-- At forty-odd widgets a step, that is the difference between a step that costs a
			-- frame and one that does not.
			WriteFadeOpacity(entry)
			if not holding then entry.fade = nil end
			touched = touched + 1
		end
	end

	if not holding then
		Debug("HUD back to full - the fade has let go of %d widget(s)", touched)
	end
end

local function AutoFadeStep(withProbes)
	if not S.enabled or suspended or not S.autoFade then return end

	local now = Now() or 0

	-- No player character means no gameplay: the main menu, a loading screen, the gap between
	-- levels. Nothing there is idle in any sense this feature is entitled to act on - every
	-- gameplay probe returns "could not tell", which would otherwise add up to "nothing is
	-- happening" and fade whatever we happened to be holding. So the fade lets go and waits.
	if PlayerPawn() == nil then
		if fadeLevel < 1.0 or fadeApplied ~= nil then
			fadeLevel = 1.0
			PushFade()
		end
		-- fadeWant as well as fadeLevel, and not only for tidiness: the heartbeat picks its
		-- interval by comparing the two, so leaving a stale want of 0 here would have it ticking
		-- at animation speed for as long as the main menu is open, moving nothing.
		fadeWant      = 1.0
		fadeLastTime  = nil
		fadeIdleSince = nil
		return
	end

	-- The probes are the expensive half - a handful of property reads plus a widget search each -
	-- and they do not need to run at animation speed. So they keep their own clock, and between
	-- them all this function does is move a float and write it, which is exactly the part that
	-- has to happen often enough for a fade to look like one.
	-- The probes run ONLY from the probe chain (withProbes), never from an ease step. They are
	-- the expensive half by a mile - measured at ~140ms a call, which is the whole reason a fade
	-- used to get four steps - and an ease step that has to wait for them cannot be smooth.
	if withProbes ~= false and (fadeNextProbe == nil or now >= fadeNextProbe) then
		fadeNextProbe = now + (S.autoFadeMs / 1000)

		local probeT0 = Now() or 0
		local engaged, reasons, unknown = ProbeEngaged(now)
		fadeStatProbe = fadeStatProbe + ((Now() or 0) - probeT0)

		if now < fadePeekUntil then
			engaged = true
			reasons[#reasons + 1] = "peek key"
		end

		-- We only get here with a player, so the report always describes a loaded game rather
		-- than the title screen - which is the only place the probe results mean anything.
		fadeTicks = fadeTicks + 1
		if not fadeReported then ReportProbes(unknown) end

		-- Diagnostics, and they exist because of the failure this feature actually has. It is not
		-- "fades when it should not"; it is "never fades at all", because one signal is stuck on -
		-- and from the outside that is indistinguishable from the mod being broken or not loaded.
		-- Nothing in the log said which signal, so working it out meant guessing. Now it says.
		local why = table.concat(reasons, ", ")
		if why ~= fadeLastWhy then
			fadeLastWhy = why
			Debug("HUD held up by: %s", (why ~= "") and why or "(nothing - the fade can start)")
		end

		-- The stuck-check below only ever fired for a fade that had NEVER held anything, which
		-- misses the report this was actually written for: a fade that worked all the way to the
		-- first fight and then never ran again. `fadeNamed` is true by then, so the one line that
		-- would have named the culprit was gated off for the rest of the session and the log had
		-- nothing in it to send. This one is per EPISODE - any unbroken run of "something is
		-- happening" that outlasts the idle timer by a clear margin says so, once, and re-arms as
		-- soon as the HUD goes quiet again.
		if fadeUpSince ~= nil and not fadeHoldReported
		   and (now - fadeUpSince) > (S.idleAfter + 15.0) then
			fadeHoldReported = true
			Log("AUTO-FADE: held up without a break for %.0fs by: %s", now - fadeUpSince,
			    (why ~= "") and why or "(nothing this tick)")
			Log("  If that does not match what you are doing, switch it off in [AutoFade] and " ..
			    "press %s. showWhenHurt is the usual one: it means \"health or stamina is not " ..
			    "full\", and health does not refill on its own, so one scratch pins the HUD for " ..
			    "good. hurtBelow = 0.35 makes it \"badly hurt\" instead.",
			    string.upper(Trim(S.reloadKeyName or "F7")))
		end

		if fadeFirstTick == nil then fadeFirstTick = now end
		if not fadeStuckReported and not fadeNamed
		   and (now - fadeFirstTick) > (S.idleAfter + 15.0) then
			fadeStuckReported = true
			Log("AUTO-FADE: %.0fs in and the HUD has not faded once, so something is reporting " ..
			    "activity the whole time. Held up right now by: %s",
			    now - fadeFirstTick,
			    (why ~= "") and why or "(nothing this tick - so it is intermittent, not stuck)")
			Log("  If one of those does not match what you were actually doing, switch it off in " ..
			    "[AutoFade] and press %s. debugLogging = true prints this every time it changes.",
			    string.upper(Trim(S.reloadKeyName or "F7")))
		end

		if engaged then
			if fadeIdleSince ~= nil and fadeLevel < 1.0 then
				Debug("HUD up again (%s)", table.concat(reasons, ", "))
			end
			fadeIdleSince = nil
			if fadeUpSince == nil then fadeUpSince = now end
		elseif fadeIdleSince == nil then
			fadeIdleSince = now
			-- The hold is over, so the next one is worth reporting again. This is what makes the
			-- check above an EPISODE detector rather than a once-per-session one.
			fadeUpSince        = nil
			fadeHoldReported   = false
		end
	end

	local idle = (fadeIdleSince ~= nil) and ((now - fadeIdleSince) >= S.idleAfter)
	fadeWant = idle and S.idleOpacity or 1.0

	-- Measured in seconds elapsed, not in ticks. The heartbeat below deliberately changes its own
	-- interval depending on whether anything is moving, and Work.host.ExecuteWithDelay was never exact to
	-- begin with, so "how long since we last moved" is the only basis on which fadeOutSeconds
	-- means what it says. The clamp is for the frame after a hitch or a loading screen: a two
	-- second gap must not teleport the fade, it must just take a big step and carry on.
	local elapsed = (fadeLastTime ~= nil) and (now - fadeLastTime) or 0.0
	fadeLastTime = now
	local rawElapsed = elapsed
	if elapsed > 0.25 then elapsed = 0.25 end

	-- Was anything moving before this step? That is what the cadence report below counts.
	local wasMoving = Differs(fadeLevel, fadeWant)

	-- The rate is over the whole 0..1 range rather than over the distance actually being
	-- travelled, so fadeOutSeconds means the same thing whatever idleOpacity is set to - a fade to
	-- 0.5 takes half as long as a fade to 0, which is what a constant speed looks like.
	local overSeconds = (fadeWant < fadeLevel) and S.fadeOutSeconds or S.fadeInSeconds
	local step        = (overSeconds > 0) and (elapsed / overSeconds) or 1.0

	if math.abs(fadeWant - fadeLevel) <= step then
		fadeLevel = fadeWant
	elseif fadeWant > fadeLevel then
		fadeLevel = fadeLevel + step
	else
		fadeLevel = fadeLevel - step
	end

	-- One line per fade saying how smooth it actually was: how many steps it took and the worst
	-- gap between two of them. "Smooth" is a claim about this number, not about the requested
	-- fadeStepSeconds, and until this line existed the two were being confused.
	if wasMoving then
		if fadeStatStart == nil then
			fadeStatStart, fadeStatN, fadeStatMax = now, 0, 0
			fadeStatCost, fadeStatProbe, fadeStatPush = 0, 0, 0
		else
			fadeStatN = fadeStatN + 1
			if rawElapsed > fadeStatMax then fadeStatMax = rawElapsed end
		end
		if not Differs(fadeLevel, fadeWant) then
			local took = now - fadeStatStart
			-- "our cost" is the time spent inside these steps; the rest of each gap is UE4SS
			-- taking its time to call us back. Which of the two is big decides what to fix.
			Debug("fade to %.2f: %d steps over %.2fs (avg gap %.0fms, worst %.0fms, our cost " ..
			      "%.1fms/step of which probes %.1fms push %.1fms, driver=%s, chains=%d)",
			      fadeLevel, fadeStatN, took,
			      (fadeStatN > 0) and (took / fadeStatN * 1000) or 0, fadeStatMax * 1000,
			      (fadeStatN > 0) and (fadeStatCost / fadeStatN * 1000) or 0,
			      (fadeStatN > 0) and (fadeStatProbe / fadeStatN * 1000) or 0,
			      (fadeStatN > 0) and (fadeStatPush / fadeStatN * 1000) or 0,
			      fadeStepVia, S.fadeChains or 1)
			fadeStatStart = nil
		end
	end

	local pushT0 = Now() or 0
	PushFade()
	fadeStatPush = fadeStatPush + ((Now() or 0) - pushT0)
end

-- The peek key: hold the HUD up for a few seconds without turning anything off. This is the
-- answer to "where was my quest marker" on a HUD that is faded to nothing.
local function PeekHUD()
	if not S.autoFade then
		Log("PEEK: the auto-fade is off, so the HUD is already up ([AutoFade] enabled in %s)",
		    INI_NAME)
		return
	end
	fadePeekUntil = (Now() or 0) + S.peekSeconds
	Debug("peek - holding the HUD up for %.1fs", S.peekSeconds)
end

-- A trigger means the HUD has just been found again, so the fade starts from "up" rather than
-- from a level it was holding for widgets that may no longer exist.
--
-- It PUTS BACK what it was holding rather than just forgetting that it was holding it, and that
-- distinction is the whole function. Forgetting is how a HUD ends up stuck faded: entry.fade goes
-- to nil, EffectiveOpacity goes back to returning nil for an entry whose section set no opacity of
-- its own - which is most of them - and so nothing ever writes that widget again. The next tick
-- would not save us either: PushFade sees a level of 1.0 that was already 1.0 and correctly
-- decides it has nothing to do. Note the same write-at-1.0-then-clear order PushFade uses, for
-- exactly the same reason.
--
-- Two triggers reach this while the HUD is genuinely faded - the scan key, and begin play on a
-- level change - and neither of them restores first, which is why this cannot be left to the
-- restore path.
local function ResetFade()
	for _, entry in pairs(written) do
	    BudgetStep()
		if entry.fade ~= nil then
			entry.fade = 1.0
			if entry.target ~= nil and IsValidObject(entry.obj) then
				pcall(WriteState, entry, entry.target)
			end
			entry.fade = nil
		end
	end

	fadeLevel, fadeApplied    = 1.0, nil
	fadeWant                  = 1.0
	fadeLastTime, fadeNextProbe = nil, nil
	fadeIdleSince             = nil
	fadeNamed                 = false
	fadeLastWhy               = nil
	fadeFirstTick             = nil
	fadeStuckReported         = false
	fadeUpSince               = nil
	fadeHoldReported          = false
	fadePeekUntil, fadeTicks  = 0, 0
	lastHealth, lastStamina   = nil, nil
	probeSince                = {}
	fadeStatStart, fadeStatN, fadeStatMax = nil, 0, 0
	fadeStatCost, fadeStatProbe, fadeStatPush = 0, 0, 0
	fadeEaseChains            = 0
	fadePlayer, fadeCombatSub = nil, nil
end

-- Two speeds, and the gap between them is the whole point. While the fade is moving it runs at
-- fadeStepSeconds, because that is what makes the result look like a fade rather than a slideshow.
-- While it is settled - which is nearly all of the time, at either end - it drops back to
-- checkSeconds, because the only thing left to do is ask the probes and they are the expensive
-- half. Running the probes at 60Hz to get a smooth fade would be paying for the wrong thing.
-- One ease step, timed. Every driver goes through this so the cadence line can say how much of
-- each gap was spent inside our own code.
local function StepFade(withProbes)
	local t0 = Now() or 0
	pcall(AutoFadeStep, withProbes)
	fadeStatCost = fadeStatCost + ((Now() or 0) - t0)
end

-- Two kinds of chain, because the two jobs cost a hundredfold apart.
--
-- The PROBE chain runs at checkSeconds for as long as the mod is on. It asks the probes - the
-- ~140ms half - and moves the ease one step while it is at it. When it finds the fade moving
-- and no ease chain running, it starts the ease chains.
--
-- An EASE chain runs at fadeStepSeconds, steps the ease WITHOUT the probes (an opacity write per
-- held widget, a few ms), and exits by itself the moment the fade has settled. fadeChains of
-- them run side by side, started a little apart, and interleave.
local EaseChain

EaseChain = function(generation)
	Defer(S.fadeStepMs, function()
		-- This callback only updates cached widgets on the game thread.
		if generation ~= applyGeneration or not Differs(fadeLevel, fadeWant) then
			fadeEaseChains = math.max(0, fadeEaseChains - 1)
			return
		end
		fadeStepVia = "ease"
		StepFade(false)
		EaseChain(generation)
	end, true)
end

local function StartEaseChains(generation)
	if fadeEaseChains > 0 then return end
	for i = 1, (S.fadeChains or 1) do
	    BudgetStep()
		fadeEaseChains = fadeEaseChains + 1
		if i == 1 then
			EaseChain(generation)
		else
			Defer((i - 1) * 20, function()
				if generation ~= applyGeneration then
					fadeEaseChains = math.max(0, fadeEaseChains - 1)
					return
				end
				EaseChain(generation)
			end)
		end
	end
end

local function AutoFadeHeartbeat(generation)
	if not S.autoFade or S.autoFadeMs <= 0 then return end

	Defer(S.autoFadeMs, function()
		if generation ~= applyGeneration then return end
		fadeStepVia = "probe"
		StepFade(true)
		if Differs(fadeLevel, fadeWant) then StartEaseChains(generation) end
		AutoFadeHeartbeat(generation)
	end, true)
end

-- frameHook: step the ease from a post-hook on an engine function that runs once per frame on
-- the game thread. Registered once per path; F7 picks up a changed path. The timer heartbeat
-- keeps running underneath - it is what asks the probes - and the ease is measured in elapsed
-- seconds, so being stepped from two places changes nothing but the smoothness. The 4ms floor
-- is a guard against a function that turns out to run several times a frame.
local function HookFadeFrame()
	for _, raw in ipairs(S.fadeFrameHooks or {}) do
	    BudgetStep()
		local path = Trim(raw)
		if path ~= "" and not fadeHooked[path] then
			-- Several candidates can be listed; whichever of them really runs every frame ends
			-- up driving the ease, and the shared 4ms floor means two that both fire do not
			-- double the work. The cadence line names the one that stepped last.
			--
			-- A blueprint class is not loaded when the mod starts - the HUD arrives seconds
			-- later - and Work.host.RegisterHook on a function of an unloaded class fails. So the class is
			-- looked up first, and a missing one is skipped quietly; this runs again on every
			-- apply trigger (begin play, the follow-ups, F7) until it succeeds.
			local classPath = string.match(path, "^(.-):[^:]+$")
			local cls = nil
			if classPath ~= nil then pcall(function() cls = Work.host.StaticFindObject(classPath) end) end
			if classPath ~= nil and not IsValidObject(cls) then
				Debug("frameHook: %s is not loaded yet - will try again on the next trigger", classPath)
				goto continue
			end
			local short = string.match(path, "([^./]+)$") or path
			local ok = pcall(function()
				Work.host.RegisterHook(path, function() end, function()
					if not Differs(fadeLevel, fadeWant) then return end
					local now = Now() or 0
					if fadeHookLast ~= nil and (now - fadeHookLast) < 0.004 then return end
					fadeHookLast = now
					fadeStepVia  = "hook:" .. short
					Defer(0, function() StepFade(false) end, true, "fade-frame")
				end)
			end)
			if ok then
				fadeHooked[path] = true
				Log("AUTO-FADE: stepping the fade from %s - the next 'fade to' line in the log " ..
				    "says whether it actually runs every frame", path)
			else
				Log("AUTO-FADE: could not hook %s for frameHook - not a function on that class, " ..
				    "or already hooked by a previous script instance", path)
			end
		end
		::continue::
	end
end

-- ##############################
-- When we apply
-- ##############################

-- No per-frame tick anywhere in this mod. The full pass runs on a trigger: script load, begin
-- play, the reload key, plus a couple of follow-ups because parts of the HUD are created lazily.
-- Between triggers all that runs is ReassertManaged.
--
-- The heartbeat is a self-rescheduling Work.host.ExecuteWithDelay rather than a tick hook so that it is
-- paced in real time and so that it does not share a hook with another mod. The generation guard
-- is what stops them piling up: every trigger bumps applyGeneration, so the previous chain
-- retires on its next wake-up.
local function Heartbeat(generation)
	if S.reassertMs <= 0 then return end
	Defer(S.reassertMs, function()
		if generation ~= applyGeneration then return end
		pcall(ReassertManaged)
		Defer(0, function() ObjectIndex.prune(false) end, false, "index-cleanup")

		-- Amortised, and driven by the thing that actually grows: every prompt and marker is a new
		-- object with a new name, so without this the snapshot table would climb all session.
		if S.purgeEvery > 0 and instanceWrites >= S.purgeEvery then
			instanceWrites = 0
			PurgeDead()
		end

		Heartbeat(generation)
	end)
end

-- Tight loop for force = true entries only. Walks only the forced set and does not tree-walk.
local function ForceHeartbeat(generation)
	if S.forceReassertMs <= 0 then return end
	Defer(S.forceReassertMs, function()
		if generation ~= applyGeneration then return end
		if S.enabled and not suspended then
			for _, entry in pairs(Work.forced) do
			    BudgetStep()
				if entry.force and entry.target ~= nil and IsValidObject(entry.obj) then
					pcall(WriteState, entry, entry.target, "force")
				end
			end
		end
		ForceHeartbeat(generation)
	end, true)
end

-- Off by default. Only worth turning on if you have added a root class by short name, which
-- cannot be baked or notified on, so nothing else would ever notice its instances appearing.
local function SweepHeartbeat(generation)
	if S.sweepMs <= 0 then return end
	Defer(S.sweepMs, function()
		if generation ~= applyGeneration then return end
		if S.enabled and not suspended then pcall(SweepInstances) end
		SweepHeartbeat(generation)
	end)
end

-- The menus get a sweep of their own, and unlike the one above it is ON by default. Two reasons.
-- They cannot be baked, so the class-default layer that carries the HUD does nothing for them;
-- and they are named by a native parent class, so whether the new-instance watch sees them at all
-- depends on that watch matching derived classes. A screen you open and read for a minute can
-- afford to be found by a scan a moment later, and this way it is found either way. It only ever
-- looks at the menu classes, and only while tweakMenus is on.
local function MenuSweepHeartbeat(generation)
	if S.menuSweepMs <= 0 or not S.tweakMenus then return end

	local anyMenu = false
	for _, spec in ipairs(rootSpecs) do
	    BudgetStep()
		if spec.menu then
			anyMenu = true
			break
		end
	end
	if not anyMenu then return end

	Defer(S.menuSweepMs, function()
		if generation ~= applyGeneration then return end
		if S.enabled and not suspended then
			pcall(SweepInstances, function(spec) return spec.menu end)
		end
		MenuSweepHeartbeat(generation)
	end)
end

-- Same self-rescheduling shape as the heartbeat, same generation guard, so a reload retires the
-- old chain instead of leaving two of them flashing out of phase.
local blinkOn = false

local function IdentifyBlink(generation)
	if S.identifyMs <= 0 or #S.identify == 0 then return end
	Defer(S.identifyMs, function()
		if generation ~= applyGeneration then return end

		blinkOn = not blinkOn
		local opacity = blinkOn and 1.0 or 0.0
		for _, entry in pairs(written) do
		    BudgetStep()
			if entry.identify and IsValidObject(entry.obj) then
				pcall(_setOpacity, entry.obj, opacity)
			end
		end

		IdentifyBlink(generation)
	end)
end

local function ApplySequence(reason)
    Defer(0, function()
        Debug('apply (%s)', reason)
        ResetFade()
        PatchClassDefaults()
        HookFadeFrame()
        ObjectIndex.start()
        -- A full pass is reserved for explicit configuration/diagnostic requests.
        -- Normal startup/load relies on the indexed per-instance updates.
        if reason == 'reload key' or reason == 'toggle key' or reason == 'scan key' then
            ApplyAll(true)
        else
            -- Resume indexed instances whose jobs were retired during loading.
            ObjectIndex.prune(true)
        end
        -- Only retry class readiness. Construction events own per-instance updates;
        -- there are no full-tree replay passes at 2, 6 and 15 seconds.
        for _, seconds in ipairs(S.followUps) do
            BudgetStep()
            if seconds > 0 then
                Defer(math.floor(seconds * 1000), function()
                    ObjectIndex.start()
                    PatchClassDefaults()
                    HookFadeFrame()
                end, false, 'class-readiness-' .. seconds)
            end
        end
        local generation = applyGeneration
        if Work.heartbeatGeneration == generation then return end
        Work.heartbeatGeneration = generation
        Heartbeat(generation)
        ForceHeartbeat(generation)
        SweepHeartbeat(generation)
        MenuSweepHeartbeat(generation)
        IdentifyBlink(generation)
        AutoFadeHeartbeat(generation)
    end, false, 'apply')
end

-- ##############################
-- Reload / toggle: re-read the ini and re-apply. No UE4SS script reload needed.
-- ##############################

function Reload()
	RetireWork()
	Log("================ Reload ================")

	-- 1. put every value we wrote back to what it was, so nothing compounds
	pcall(RestoreAll)

	-- 2. drop handles to widgets that have since died
	PurgeDead()

	-- 3. re-read the file
	if LoadIni() then Log("Loaded %s", iniPath) end
	ResolveSettings()
	suspended = false

	-- Unbake and re-bake: the file may have changed the values, or dropped the section entirely.
	pcall(RestoreClassDefaults)

	-- 4. re-apply, and pick up a reloadKey / roots change made in the file
	BindKeys()
	HookNewObjects()
	HookReassertAfter()
	HookFadeFrame()
	ApplySequence("reload key")

	Log("Reload complete")
end

local function Toggle()
	RetireWork()
	suspended = not suspended
	if suspended then
		pcall(RestoreAll)
		pcall(RestoreClassDefaults)
		Log("HUD tweaks OFF - the HUD is back to how the game ships it")
	else
		Log("HUD tweaks ON")
		ApplySequence("toggle key")
	end
end

-- ##############################
-- Finding UI this file does not know about
-- ##############################

-- Every screen in this game is a blueprint that is only loaded while it is open, so there is no
-- object dump - taken in gameplay or anywhere else - that lists all of them at once. This is the
-- way round that: open the screen you want, press the scan key, and get the class path of every
-- user widget currently alive, ready to paste into roots.
--
-- FindAllOf matches derived classes, so asking for UserWidget asks for all of them at once.
local function ScanLiveWidgets()
	local ok, found = pcall(FindAllOf, "UserWidget")
	if not ok or found == nil then
		Log("SCAN: could not enumerate widgets - FindAllOf(\"UserWidget\") failed")
		return
	end

	-- One line per CLASS, not per instance: a screen with forty item buttons on it should not
	-- print forty times, and the class path is the thing you came here for.
	local byClass, order = {}, {}
	local total = 0
	for _, obj in pairs(found) do
	    BudgetStep()
		if IsValidObject(obj) and not IsDefaultObject(obj) then
			total = total + 1
			local class = SafeClassName(obj)
			local seen  = byClass[class]
			if seen == nil then
				-- "WidgetBlueprintGeneratedClass /Game/.../UI_Pause.UI_Pause_C" - keep the path.
				local path = "?"
				HostPcall(function() if not IsValidObject(obj) then return end; path = obj:GetClass():GetFullName() end)
				path = string.match(path, "([^%s]+)$") or path

				seen = { count = 0, path = path, sample = obj }
				byClass[class] = seen
				order[#order + 1] = class
			end
			seen.count = seen.count + 1
		end
	end

	table.sort(order, function(a, b) return string.lower(a) < string.lower(b) end)

	-- Which of these can this file already reach? Asked of the widgets we have actually walked,
	-- not of the roots list, because a menu named by its native parent turns up here under the
	-- blueprint's name - MapWidget in menuRoots, WBP_Map_C on screen - and comparing
	-- against the roots list would report it as unreached when it is nothing of the kind.
	local reached = {}
	for _, entry in pairs(vanilla) do
	    BudgetStep()
		if entry.class ~= nil then reached[string.lower(entry.class)] = true end
	end

	Log("---- live user widgets (%d instance(s), %d class(es)) ----", total, #order)
	Log("\"reached\" = this mod has walked one and a section can name it. For anything else, paste")
	Log("its path into roots (HUD) or menuRoots (screens) and press the reload key.")
	for _, class in ipairs(order) do
	    BudgetStep()
		local info = byClass[class]
		Log("  %-44s x%-3d %s%s", class, info.count, info.path,
		    reached[string.lower(class)] and "   <- reached" or "")
	end
	Log("---- end of scan ----")
end

function BindKeys()
	local function bind(name, action, label)
		name = string.upper(Trim(name or ""))
		if name == "" or boundKeys[name] then return end

		local key = nil
		HostPcall(function() key = Key[name] end)
		if key == nil then
			Log("WARNING: '%s' is not a key name UE4SS knows", name)
			return
		end

		if pcall(function() Work.host.RegisterKeyBind(key, function() Defer(0, action) end) end) then
			boundKeys[name] = true
			Log("%s bound to %s", label, name)
		end
	end

	bind(S.reloadKeyName, Reload, "Reload")
	bind(S.toggleKeyName, Toggle, "On/off toggle")
	bind(S.peekKeyName, PeekHUD, "HUD peek")
	-- A fresh pass first, so a screen opened since the last trigger is walked before it is listed
	-- and "reached" means what it says.
	bind(S.scanKeyName, function()
		ApplySequence("scan key")
		ScanLiveWidgets()
	end, "Widget scan")
end

-- ##############################
-- Class defaults
-- ##############################

-- Hooks and sweeps can only reach a widget that already exists, and in this game that is a losing
-- race: prompts, notifications and loot markers are created and shown in the same frame, and half
-- of them are gone again before any timer we could set would fire. The fix is to stop chasing
-- instances and write the value one level up, onto the objects every new instance is built from.
-- That catches every widget there will ever be, and it costs nothing per widget - no timer, no
-- scan, no per-instance work at all.
--
-- Two objects hold those defaults, and which one a value needs depends on where it lives:
--   * the widget itself - transform, opacity, visibility - lives on the class default object, so
--     [WBP_Compass_Mappin] scale = 0.8 goes there and every new pin is constructed at 0.8.
--   * anything NAMED INSIDE it - [Crosshair], [HumanStats] - lives on the class WidgetTree
--     template, because an instance's tree is duplicated from that template.
--
-- Work.host.NotifyOnNewObject stays: a widget the game pools and reuses keeps its object, so it is past the
-- point where a default applies, and only a write on the live widget puts it back.
local classDefaults     = {}   -- [fullName] = { obj, snapshot } - what the blueprint shipped
local classDefaultsDone = {}   -- [classPath] = true once that class has been baked

local function PatchDefaultObject(obj, name, class, isRoot)
    BudgetStep()
	if not IsValidObject(obj) then return false end

	local item, claims = { name = name, class = class }, nil
	for _, section in ipairs(ConfiguredSections()) do
	    BudgetStep()
		if SectionMatches(item, string.lower(section)) then
			claims = claims or {}
			claims[#claims + 1] = section
		end
	end
	-- The class default object stands in for the widget itself, so it is the one object here that
	-- [All] claims - the same rule as a live top-level widget.
	if claims == nil and S.allActive and isRoot then claims = {} end
	if claims == nil then return false end

	-- Snapshot once and keep it. A second pass has to build its target from what the blueprint
	-- shipped, not from the values we wrote last time, or scaleMul-style keys compound.
	local key      = SafeName(obj)
	local held     = classDefaults[key]
	local snapshot = held ~= nil and held.snapshot or ReadState(obj)
	classDefaults[key] = { obj = obj, snapshot = snapshot }

	local entry  = { key = key, name = name, class = class, snapshot = snapshot, obj = obj }
	local target = BuildTarget(entry, claims)
	if target == nil then return false end

	-- A class default has no Slate widget behind it, so the setters have nothing to push to and
	-- the property writes are the whole job. WriteState calls them anyway and they are harmless.
	local changed = WriteState(entry, target)
	if changed ~= nil and #changed > 0 then
		Log("DEFAULT: %s (%s) - every %s created from now on starts this way",
		    name, table.concat(changed, ", "), class)
	end
	return true
end

-- Put the class defaults back the way the blueprint shipped them. Instances already alive are
-- RestoreAll's job; this is only about the ones not created yet.
function RestoreClassDefaults()
	for _, held in pairs(classDefaults) do
	    BudgetStep()
		if IsValidObject(held.obj) then
			pcall(WriteState, { obj = held.obj }, held.snapshot)
		end
	end
	classDefaults     = {}
	classDefaultsDone = {}
end

-- Cheap and idempotent: once a class is baked it is skipped, and until its blueprint is loaded
-- there is nothing to find, so this is safe to call from every trigger.
function PatchClassDefaults()
	if not S.enabled or suspended or not S.hookNewWidgets or not S.bakeDefaults then return end

	for _, spec in ipairs(rootSpecs) do

	    BudgetStep()
		-- Native classes are skipped: a blueprint subclass copies its parent's defaults when it is
		-- compiled, so writing to the parent's CDO now reaches nothing, and a native class has no
		-- widget-tree template to patch either. Menus are covered by the new-instance watch.
		local classPath = (not spec.native) and spec.path or nil
		if classPath ~= nil and not classDefaultsDone[classPath] then
			local cls = nil
			pcall(function() cls = Work.host.StaticFindObject(classPath) end)

			if IsValidObject(cls) then
				classDefaultsDone[classPath] = true

				-- the widget itself
				local cdoPath = string.gsub(classPath, "%.([^.]+)$", ".Default__%1")
				local cdo = nil
				pcall(function() cdo = Work.host.StaticFindObject(cdoPath) end)
				if IsValidObject(cdo) then
					PatchDefaultObject(cdo, SafeShortName(cdo), spec.class, true)
				else
					Debug("no CDO at %s - only the widgets inside %s can be defaulted",
					      cdoPath, spec.class)
				end

				-- and everything named inside it. ChildrenOf starts at
				-- <object>.WidgetTree.RootWidget, and on a generated class that is the template
				-- tree - the same walk as an instance, one object earlier in its life.
				local items = {}
				CollectSubtree(cls, items, {}, 0)
				for _, item in ipairs(items) do
				    BudgetStep()
					if item.obj ~= cls then
						PatchDefaultObject(item.obj, item.name, item.class)
					end
				end
			else
				Debug("%s is not loaded yet - will bake its defaults on the next trigger", classPath)
			end
		end
	end
end

-- ##############################
-- Hooks
-- ##############################

-- Work.host.NotifyOnNewObject fires the moment an instance is allocated, which is earlier than any UFunction
-- hook could be and - unlike Construct - exists for every one of these classes whether or not the
-- blueprint happens to implement an event. That is why this mod hooks allocation rather than
-- Construct: most of this game's HUD widgets are native C++ classes with no Construct to hook.
--
-- A widget is allocated before its tree is filled in, so the callback fixes what it can now and
-- comes back a couple of times. Each retry is the cheap per-instance path, not a full pass.
local newObjectHooked = {}

function HookNewObjects()
    ObjectIndex.start()
    ObjectIndex.widget = function(obj, names)
        if not S.hookNewWidgets or not S.enabled or suspended then return end
        local chosen
        for _, spec in ipairs(rootSpecs) do
            BudgetStep()
            for _, name in ipairs(names) do
                BudgetStep()
                if spec.class == name then chosen = spec.key; break end
            end
            if chosen then break end
        end
        if not chosen then return end
        -- One readiness chain per instance; the upstream zero-delay retry is redundant.
        Defer(0, function()
            if not IsValidObject(obj) then return end
            TweakInstance(obj, chosen)
            for _, seconds in ipairs(S.newObjectFollowUps or {}) do
                BudgetStep()
                if seconds > 0 then
                    Defer(math.floor(seconds * 1000), function()
                        if IsValidObject(obj) then TweakInstance(obj, chosen) end
                    end, false, {obj, seconds})
                end
            end
        end, false, obj)
    end
end

-- "Widget:Function" is not enough here because these widgets live in a dozen different folders,
-- so a reassertAfter entry must be a full path: /Script/Weapons.CrosshairWidget:ShowCrosshair
local function HookPath(spec)
	local target, fn = string.match(spec, "^(.-):([^:]+)$")
	if target == nil or fn == nil then return nil end
	return Trim(target) .. ":" .. Trim(fn)
end

-- ##############################
-- Writing back after the game
-- ##############################

-- Some values are not ours to keep. A widget that lerps its own RenderOpacity towards a target
-- every frame will have thrown away anything we wrote by the next frame, no matter how often we
-- re-assert it, and no class default survives it either: the game recomputes the value, it does
-- not read it.
--
-- The way to win that is to stop guessing when to write and let the game tell us. A post-hook on
-- the function that writes the value fires once per write, immediately after it, so ours lands
-- last by construction. Nothing polls, nothing runs on a frame the game did not already work on.
--
-- Only worth it for values the game actually fights over. Scale, offsets and visible = false
-- normally stick on their own and need none of this.
local userWidgetClass = nil   -- /Script/UMG.UserWidget, looked up once, for the test below

local function ReassertWidget(widget)
	if not S.enabled or suspended or not IsValidObject(widget) then return end

	-- Only what we already hold. The pass that walks the HUD is what puts an entry here, so
	-- before it has run there is nothing to write back - and it will run.
	local entry = written[SafeName(widget)]
	if entry ~= nil and entry.target ~= nil then
		entry.obj = widget
		pcall(WriteState, entry, entry.target, "hook")
		-- The event we hooked often STARTS something - the quickslot change prompt plays a
		-- slide-in on the weapon-draw event - and an animation that begins after our write
		-- overwrites it on its next frame. So write again a few times over the next half second;
		-- one widget, four cheap writes, and the last one lands after any short animation.
		local generation = applyGeneration
		for _, ms in ipairs({ 80, 200, 400, 700 }) do
		    BudgetStep()
			Defer(ms, function()
				if generation ~= applyGeneration then return end
				if IsValidObject(entry.obj) and entry.target ~= nil then
					pcall(WriteState, entry, entry.target, "hook+" .. ms)
				end
			end)
		end
		return
	end

	-- A user widget that is not ours - some toast or compass pin finishing its own animation,
	-- via the UserWidget:OnAnimationFinished hook - is nobody's business here. Only a NON-widget
	-- context falls through to the broad path below: a NamedToggleableContainer (a panel, not a
	-- user widget) or the HUD subsystem. A real class test, not a property probe - UE4SS hands
	-- back nil rather than throwing for a property a class does not have, so "does it have a
	-- WidgetTree" would have called the subsystem a user widget and quietly switched the preset
	-- hooks off. If the class cannot be found the broad path is skipped, which is the safe side.
	if userWidgetClass == nil then
		pcall(function() userWidgetClass = Work.host.StaticFindObject("/Script/UMG.UserWidget") end)
	end
	local isUserWidget = true
	if IsValidObject(userWidgetClass) then
		local ok, res = HostPcall(function() if not IsValidObject(widget) then return end; return widget:IsA(userWidgetClass) end)
		isUserWidget = (not ok) or (res == true)
	end
	if isUserWidget then return end

	-- Not a widget we hold, so this hook is on something that rewrites MANY widgets at once -
	-- HUDManagerSubsystem:PushHUDPreset / PopHUDPreset, or NamedToggleableContainer:SetShown.
	-- That is what happens when focus mode or a brief lock-on flips the HUD preset: the game
	-- re-shows a prompt we hold at opacity 0 and re-lays-out the quickslot change prompt, and
	-- until now the only thing putting them back was the 2s re-check, which is exactly the gap
	-- that was visible. So re-assert everything we hold, right now and once more a moment later
	-- for anything the game settles on the following frame. ReassertManaged touches only
	-- `written` and only the fields we wrote, so this is cheap enough to hang off a hook.
	Defer(0, ReassertManaged, false, "preset-reassert")
	Defer(120, ReassertManaged, false, "preset-reassert-followup")
end

local reassertAfterHooked = {}

function HookReassertAfter()
	for _, spec in ipairs(S.reassertAfter or {}) do
	    BudgetStep()
		local path = HookPath(spec)
		if path == nil then
			Log("WARNING: reassertAfter entry '%s' is not a full path in the form " ..
			    "/Script/Module.Class:Function", spec)
		elseif not reassertAfterHooked[path] then
			local ok = pcall(function()
				Work.host.RegisterHook(path, function() end, function(context)
					local ok, widget = pcall(function() return context:get() end)
					if ok then Defer(0, function() ReassertWidget(widget) end, true, widget) end
				end)
			end)

			reassertAfterHooked[path] = ok
			if ok then
				Log("Hooked %s - our value goes back on right after the game writes its own", path)
			else
				Log("NOTE: could not hook %s (reassertAfter) - it is already hooked, or the name " ..
				    "is not a function on that class", path)
			end
		end
	end
end

-- ##############################
-- Boot
-- ##############################

if LoadIni() then Log("Loaded %s", iniPath) end
ResolveSettings()

local menuCount = 0
for _, spec in ipairs(rootSpecs) do
    BudgetStep()
	if spec.menu then menuCount = menuCount + 1 end
end

Log("================ HUDTweaks - The Blood of Dawnwalker ================")
Log("  enabled=%s  roots=%d class(es) (%d HUD, %d menu)  maxDepth=%d",
    tostring(S.enabled), #rootSpecs, #rootSpecs - menuCount, menuCount, S.maxDepth)
Log("  bakeClassDefaults=%s  reCheck=%.1fs  dumpWidgets=%s  [All] active=%s",
    tostring(S.bakeDefaults), S.reassertMs / 1000, tostring(S.dumpWidgets), tostring(S.allActive))
Log("  %s = reload   %s = on/off   %s = list every live widget (open a screen first)",
    string.upper(Trim(S.reloadKeyName or "?")), string.upper(Trim(S.toggleKeyName or "?")),
    string.upper(Trim(S.scanKeyName or "?")))
if S.autoFade then
	Log("  autoFade=on: HUD fades to %.2f after %.1fs idle%s. The full list of what counts as " ..
	    "\"not idle\" is printed once the game is loaded.",
	    S.idleOpacity, S.idleAfter,
	    (Trim(S.peekKeyName or "") ~= "")
	        and (", " .. string.upper(Trim(S.peekKeyName)) .. " to peek") or "")
else
	Log("  autoFade=off. Turn it on with [AutoFade] enabled = true in %s.", INI_NAME)
end

ObjectIndex.start()
Defer(0, function()
BindKeys()
HookNewObjects()
HookReassertAfter()
HookFadeFrame()

Work.host.RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(context)
	RetireWork()
	local ok, controller = pcall(function() return context:get() end)
	if ok then Defer(0, function() ObjectIndex.context(controller) end, true, nil, true) end
	Debug("client restart")

	if not beginPlayHooked then
		beginPlayHooked = pcall(function()
			Work.host.RegisterHook(BEGIN_PLAY, function()
				-- The HUD is built around here. A level transition comes back through here too,
				-- with a brand new set of widgets, so everything we held is stale.
				RetireWork()
				Defer(2000, function() PurgeDead(); ApplySequence("begin play") end, false, "load-apply")
			end)
		end)
		if beginPlayHooked then
			Log("Hooked %s", BEGIN_PLAY)
		else
			Log("NOTE: could not hook %s - it is already hooked, usually because a UE4SS script " ..
			    "reload cannot re-register a hook the previous instance owned. The %.1fs re-check " ..
			    "and the reload key still work.", BEGIN_PLAY, S.reassertMs / 1000)
		end
	end

	Defer(4000, function() ApplySequence("client restart") end, false, "load-apply")
end)

-- Hot reload support: with this on we try right away instead of waiting for a level load.
if S.startImmediately then
	ApplySequence("script load")
	-- Retry the bake a few times - blueprints may not be loaded on the first script tick, and a
	-- class that is not loaded yet has no defaults to write.
	for _, ms in ipairs({ 50, 100, 250, 500, 1000, 2000, 4000 }) do
	    BudgetStep()
		Defer(ms, function() pcall(PatchClassDefaults) end)
	end
end
end)
