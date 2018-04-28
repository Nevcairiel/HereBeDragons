-- HereBeDragons is a data API for the World of Warcraft mapping system

-- HereBeDragons-2.0 is not supported on WoW 7.x or earlier
if select(4, GetBuildInfo()) < 80000 then
	return
end

local MAJOR, MINOR = "HereBeDragons-2.0", 1
assert(LibStub, MAJOR .. " requires LibStub")

local HereBeDragons, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not HereBeDragons then return end

local CBH = LibStub("CallbackHandler-1.0")

HereBeDragons.eventFrame       = HereBeDragons.eventFrame or CreateFrame("Frame")

HereBeDragons.mapData          = HereBeDragons.mapData or {}
HereBeDragons.callbacks        = CBH:New(HereBeDragons, nil, nil, false)

-- Data Constants
local COSMIC_MAP_ID = 946

-- Lua upvalues
local PI2 = math.pi * 2
local atan2 = math.atan2
local pairs, ipairs = pairs, ipairs
local type = type
local band = bit.band

-- WoW API upvalues
local UnitPosition = UnitPosition
local C_Map = C_Map

-- data table upvalues
local mapData          = HereBeDragons.mapData -- table { width, height, left, top, .instance, .name, .mapType }

local currentPlayerUIMapID, currentPlayerUIMapType

-- Override instance ids for phased content
local instanceIDOverrides = {
    -- Draenor
    [1152] = 1116, -- Horde Garrison 1
    [1330] = 1116, -- Horde Garrison 2
    [1153] = 1116, -- Horde Garrison 3
    [1154] = 1116, -- Horde Garrison 4 (unused)
    [1158] = 1116, -- Alliance Garrison 1
    [1331] = 1116, -- Alliance Garrison 2
    [1159] = 1116, -- Alliance Garrison 3
    [1160] = 1116, -- Alliance Garrison 4 (unused)
    [1191] = 1116, -- Ashran PvP Zone
    [1203] = 1116, -- Frostfire Finale Scenario
    [1207] = 1116, -- Talador Finale Scenario
    [1277] = 1116, -- Defense of Karabor Scenario (SMV)
    [1402] = 1116, -- Gorgrond Finale Scenario
    [1464] = 1116, -- Tanaan
    [1465] = 1116, -- Tanaan
    -- Legion
    [1478] = 1220, -- Temple of Elune Scenario (Val'Sharah)
    [1495] = 1220, -- Protection Paladin Artifact Scenario (Stormheim)
    [1498] = 1220, -- Havoc Demon Hunter Artifact Scenario (Suramar)
    [1502] = 1220, -- Dalaran Underbelly
    [1533] = 0,    -- Karazhan Artifact Scenario
    [1612] = 1220, -- Feral Druid Artifact Scenario (Suramar)
    [1626] = 1220, -- Suramar Withered Scenario
    [1662] = 1220, -- Suramar Invasion Scenario
}

-- gather map info, but only if this isn't an upgrade (or the upgrade version forces a re-map)
if not oldversion or oldversion < 1 then
    -- wipe old data, if required, otherwise the upgrade path isn't triggered
    if oldversion then
        wipe(mapData)
    end

    -- gather the data of one map (by UIMapID)
    local function processMap(id, data)
        if not id or mapData[id] then return end

        mapData[id] = {0, 0, 0, 0, instance = -1, name = data.name, mapType = data.mapType}
    end

    local function processMapChildrenRecursive(id)
        local children = C_Map.GetMapChildrenInfo(id)
        if children and #children > 0 then
            for i = 1, #children do
                local id = children[i].mapID
                if id and not mapData[id] then
                    processMap(id, children[i])
                    processMapChildrenRecursive(id)
                end
            end
        end
    end

    local function fixupZones()
        local cosmic = C_Map.GetMapInfo(COSMIC_MAP_ID)
        mapData[COSMIC_MAP_ID] = {0, 0, 0, 0}
        mapData[COSMIC_MAP_ID].instance = -1
        mapData[COSMIC_MAP_ID].name = cosmic.name
        mapData[COSMIC_MAP_ID].mapType = cosmic.mapType
    end

    local function gatherMapData()
        processMapChildrenRecursive(COSMIC_MAP_ID)

        fixupZones()
    end

    gatherMapData()
end

local StartUpdateTimer
local function UpdateCurrentPosition()
    -- retrieve current zone
    local uiMapID = C_Map.GetBestMapForUnit("player")

    if uiMapID ~= currentPlayerUIMapID then
        -- update upvalues and signal callback
        currentPlayerUIMapID, currentPlayerUIMapType = uiMapID, mapData[uiMapID] and mapData[uiMapID].mapType or 0
        HereBeDragons.callbacks:Fire("PlayerZoneChanged", currentPlayerUIMapID, currentPlayerUIMapType)
    end

    -- start a timer to update in micro dungeons since multi-level micro dungeons do not reliably fire events
    if currentPlayerUIMapType == Enum.UIMapType.Micro then
        StartUpdateTimer()
    end
end

-- upgradeable timer callback, don't want to keep calling the old function if the library is upgraded
HereBeDragons.UpdateCurrentPosition = UpdateCurrentPosition
local function UpdateTimerCallback()
    -- signal that the timer ran
    HereBeDragons.updateTimerActive = nil

    -- run update now
    HereBeDragons.UpdateCurrentPosition()
end

function StartUpdateTimer()
    if not HereBeDragons.updateTimerActive then
        -- prevent running multiple timers
        HereBeDragons.updateTimerActive = true

        -- and queue an update
        C_Timer.After(1, UpdateTimerCallback)
    end
end

local function OnEvent(frame, event, ...)
    UpdateCurrentPosition()
end

HereBeDragons.eventFrame:SetScript("OnEvent", OnEvent)
HereBeDragons.eventFrame:UnregisterAllEvents()
HereBeDragons.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
HereBeDragons.eventFrame:RegisterEvent("ZONE_CHANGED")
HereBeDragons.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
HereBeDragons.eventFrame:RegisterEvent("NEW_WMO_CHUNK")
HereBeDragons.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- if we're loading after entering the world (ie. on demand), update position now
if IsLoggedIn() then
    UpdateCurrentPosition()
end
