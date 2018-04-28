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

    -- gather the data of one map (by uiMapID)
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

-- Transform a set of coordinates based on the defined map transformations
local function applyCoordinateTransforms(x, y, instanceID)
    --[[for _, transformData in ipairs(transforms) do
        if transformData.instanceID == instanceID then
            if transformData.minX <= x and transformData.maxX >= x and transformData.minY <= y and transformData.maxY >= y then
                instanceID = transformData.newInstanceID
                x = x + transformData.offsetX
                y = y + transformData.offsetY
                break
            end
        end
    end]]
    if instanceIDOverrides[instanceID] then
        instanceID = instanceIDOverrides[instanceID]
    end
    return x, y, instanceID
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

--- Return the localized zone name for a given uiMapID
-- @param uiMapID uiMapID of the zone
function HereBeDragons:GetLocalizedMap(uiMapID)
    return mapData[uiMapID] and mapData[uiMapID].name or nil
end

--- Get the size of the zone
-- @param uiMapID uiMapID of the zone
-- @return width, height of the zone, in yards
function HereBeDragons:GetZoneSize(uiMapID)
    local data = mapData[uiMapID]
    if not data then return 0, 0 end

    return data[1], data[2]
end

--- Get a list of all map IDs
-- @return array-style table with all known/valid map IDs
function HereBeDragons:GetAllMapIDs()
    local t = {}
    for id in pairs(mapData) do
        table.insert(t, id)
    end
    return t
end

--- Convert local/point coordinates to world coordinates in yards
-- @param x X position in 0-1 point coordinates
-- @param y Y position in 0-1 point coordinates
-- @param zone uiMapID of the zone
function HereBeDragons:GetWorldCoordinatesFromZone(x, y, zone)
    local data = mapData[zone]
    if not data or data[0] == 0 or data[1] == 0 then return nil, nil, nil end
    if not x or not y then return nil, nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = left - width * x, top - height * y

    return x, y, data.instance
end

--- Convert world coordinates to local/point zone coordinates
-- @param x Global X position
-- @param y Global Y position
-- @param zone uiMapID of the zone
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
function HereBeDragons:GetZoneCoordinatesFromWorld(x, y, zone, allowOutOfBounds)
    local data = mapData[zone]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil end
    if not x or not y then return nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    -- verify the coordinates fall into the zone
    if not allowOutOfBounds and (x < 0 or x > 1 or y < 0 or y > 1) then return nil, nil end

    return x, y
end

--- Translate zone coordinates from one zone to another
-- @param x X position in 0-1 point coordinates, relative to the origin zone
-- @param y Y position in 0-1 point coordinates, relative to the origin zone
-- @param oZone Origin Zone, uiMapID
-- @param dZone Destination Zone, uiMapID
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
function HereBeDragons:TranslateZoneCoordinates(x, y, oZone, dZone, allowOutOfBounds)
    local xCoord, yCoord, instance = self:GetWorldCoordinatesFromZone(x, y, oZone)
    if not xCoord then return nil, nil end

    local data = mapData[dZone]
    if not data or data.instance ~= instance then return nil, nil end

    return self:GetZoneCoordinatesFromWorld(xCoord, yCoord, dZone, allowOutOfBounds)
end

--- Return the distance from an origin position to a destination position in the same instance/continent.
-- @param instanceID instance ID
-- @param oX origin X
-- @param oY origin Y
-- @param dX destination X
-- @param dY destination Y
-- @return distance, deltaX, deltaY
function HereBeDragons:GetWorldDistance(instanceID, oX, oY, dX, dY)
    if not oX or not oY or not dX or not dY then return nil, nil, nil end
    local deltaX, deltaY = dX - oX, dY - oY
    return (deltaX * deltaX + deltaY * deltaY)^0.5, deltaX, deltaY
end

--- Return the distance between two points on the same continent
-- @param oZone origin zone uiMapID
-- @param oX origin X, in local zone/point coordinates
-- @param oY origin Y, in local zone/point coordinates
-- @param dZone destination zone uiMapID
-- @param dX destination X, in local zone/point coordinates
-- @param dY destination Y, in local zone/point coordinates
-- @return distance, deltaX, deltaY in yards
function HereBeDragons:GetZoneDistance(oZone, oX, oY, dZone, dX, dY)
    local oX, oY, oInstance = self:GetWorldCoordinatesFromZone(oX, oY, oZone)
    if not oX then return nil, nil, nil end

    -- translate dX, dY to the origin zone
    local dX, dY, dInstance = self:GetWorldCoordinatesFromZone(dX, dY, dZone)
    if not dX then return nil, nil, nil end

    if oInstance ~= dInstance then return nil, nil, nil end

    return self:GetWorldDistance(oInstance, oX, oY, dX, dY)
end

--- Return the angle and distance from an origin position to a destination position in the same instance/continent.
-- @param instanceID instance ID
-- @param oX origin X
-- @param oY origin Y
-- @param dX destination X
-- @param dY destination Y
-- @return angle, distance where angle is in radians and distance in yards
function HereBeDragons:GetWorldVector(instanceID, oX, oY, dX, dY)
    local distance, deltaX, deltaY = self:GetWorldDistance(instanceID, oX, oY, dX, dY)
    if not distance then return nil, nil end

    -- calculate the angle from deltaY and deltaX
    local angle = atan2(-deltaX, deltaY)

    -- normalize the angle
    if angle > 0 then
        angle = PI2 - angle
    else
        angle = -angle
    end

    return angle, distance
end

--- Get the current world position of the specified unit
-- The position is transformed to the current continent, if applicable
-- NOTE: The same restrictions as for the UnitPosition() API apply,
-- which means a very limited set of unit ids will actually work.
-- @param unitId Unit Id
-- @return x, y, instanceID
function HereBeDragons:GetUnitWorldPosition(unitId)
    -- get the current position
    local y, x, z, instanceID = UnitPosition(unitId)
    if not x or not y then return nil, nil, instanceIDOverrides[instanceID] or instanceID end

    -- return transformed coordinates
    return applyCoordinateTransforms(x, y, instanceID)
end

--- Get the current world position of the player
-- The position is transformed to the current continent, if applicable
-- @return x, y, instanceID
function HereBeDragons:GetPlayerWorldPosition()
    -- get the current position
    local y, x, z, instanceID = UnitPosition("player")
    if not x or not y then return nil, nil, instanceIDOverrides[instanceID] or instanceID end

    -- return transformed coordinates
    return applyCoordinateTransforms(x, y, instanceID)
end

--- Get the current zone and level of the player
-- The returned mapFile can represent a micro dungeon, if the player currently is inside one.
-- @return uiMapID, mapType
function HereBeDragons:GetPlayerZone()
    return currentPlayerUIMapID, currentPlayerUIMapType
end

--- Get the current position of the player on a zone level
-- The returned values are local point coordinates, 0-1. The mapFile can represent a micro dungeon.
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
-- @return x, y, uiMapID, mapType
function HereBeDragons:GetPlayerZonePosition(allowOutOfBounds)
    if not currentPlayerUIMapID then return nil, nil, nil, nil end
    local x, y, instanceID = self:GetPlayerWorldPosition()
    if not x or not y then return nil, nil, nil, nil end

    x, y = self:GetZoneCoordinatesFromWorld(x, y, currentPlayerUIMapID, allowOutOfBounds)
    if x and y then
        return x, y, currentPlayerUIMapID, currentPlayerUIMapType
    end
    return nil, nil, nil, nil
end
