-- HereBeDragons is a data API for the World of Warcraft mapping system

local MAJOR, MINOR = "HereBeDragons-1.0", 1
assert(LibStub, MAJOR .. " requires LibStub")

local HereBeDragons = LibStub:NewLibrary(MAJOR, MINOR)
if not HereBeDragons then return end

HereBeDragons.eventFrame = HereBeDragons.eventFrame or CreateFrame("Frame")

HereBeDragons.mapData       = HereBeDragons.mapData or {}
HereBeDragons.mapToId       = HereBeDragons.mapToId or {}
HereBeDragons.idToMap       = HereBeDragons.idToMap or {}
HereBeDragons.mapLocalized  = HereBeDragons.mapLocalized or {}
HereBeDragons.microDungeons = HereBeDragons.microDungeons or {}
HereBeDragons.transforms    = HereBeDragons.transforms or {}

local PI2 = math.pi * 2

-- Override instance ids for phased content
local instanceIdOverrides = {
    -- Draenor
    [1152] = 1116, -- Horde Garrison 1
    [1153] = 1116, -- Horde Garrison 2
    [1154] = 1116, -- Horde Garrison 3
    [1158] = 1116, -- Alliance Garrison 1
    [1159] = 1116, -- Alliance Garrison 2
    [1160] = 1116, -- Alliance Garrison 3
    [1464] = 1116, -- Tanaan
    [1465] = 1116, -- Tanaan
}

-- GetDungeonMapInfo - flags
local DUNGEONMAP_MICRO_DUNGEON = 0x00000001

-- gather map info
local mapData = HereBeDragons.mapData -- table { width, height, left, top }
local mapToId, idToMap = HereBeDragons.mapToId, HereBeDragons.idToMap
local mapLocalized = HereBeDragons.mapLocalized
local microDungeons = HereBeDragons.microDungeons
local transforms = HereBeDragons.transforms
do
    local function processTransforms()
        for _, tID in ipairs(GetWorldMapTransforms()) do
            local terrainMapID, newTerrainMapID, _, _, transformMinY, transformMaxY, transformMinX, transformMaxX, offsetY, offsetX = GetWorldMapTransformInfo(tID)
            if offsetY ~= 0 or offsetX ~= 0 then
                local transform = {
                    instanceId = terrainMapID,
                    newInstanceId = newTerrainMapID,
                    minY = transformMinY,
                    maxY = transformMaxY,
                    minX = transformMinX,
                    maxX = transformMaxX,
                    offsetY = offsetY,
                    offsetX = offsetX
                }
                table.insert(transforms, transform)
            end
        end
    end

    local function applyMapTransforms(instanceId, left, right, top, bottom)
        for _, transformData in ipairs(transforms) do
            if transformData.instanceId == instanceId then
                if transformData.minX <= left and transformData.maxX >= right and transformData.minY <= top and transformData.maxY >= bottom then
                    instanceId = transformData.newInstanceId
                    left   = left   + transformData.offsetX
                    right  = right  + transformData.offsetX
                    top    = top    + transformData.offsetY
                    bottom = bottom + transformData.offsetY
                    break
                end
            end
        end
        return instanceId, left, right, top, bottom
    end

    -- gather the data of one zone (by mapId)
    local function processZone(id)
        if not id or mapData[id] then return end

        SetMapByID(id)
        local mapFile = GetMapInfo()
        local numFloors = GetNumDungeonMapLevels()
        idToMap[id] = mapFile

        if not mapToId[mapFile] then mapToId[mapFile] = id end
        mapLocalized[id] = GetMapNameByID(id)

        local instanceId = GetAreaMapInfo(id)
        local C = GetCurrentMapContinent()
        local Z, left, top, right, bottom = GetCurrentMapZone()
        if (left and top and right and bottom and (left ~= 0 or top ~= 0 or right ~= 0 or bottom ~= 0)) then
            instanceId, left, right, top, bottom = applyMapTransforms(instanceId, left, right, top, bottom)
            mapData[id] = { left - right, top - bottom, left, top }
        else
            mapData[id] = { 0, 0, 0, 0 }
        end

        mapData[id].instance = instanceId
        mapData[id].C = C or -100
        mapData[id].Z = Z or -100

        if numFloors == 0 and GetCurrentMapDungeonLevel() == 1 then
            numFloors = 1
            mapData[id].fakefloor = true
        end

        if DungeonUsesTerrainMap() then
            numFloors = numFloors - 1
        end

        mapData[id].floors = {}
        if numFloors > 0 then
            for f = 1, numFloors do
                SetDungeonMapLevel(f)
                local _, right, bottom, left, top = GetCurrentMapDungeonLevel()
                if left and top and right and bottom then
                    mapData[id].floors[f] = { left - right, top - bottom, left, top }
                    mapData[id].floors[f].instance = mapData[id].instance
                end
            end
        end
    end

    local function processMicroDungeons()
        for _, dID in ipairs(GetDungeonMaps()) do
            local floorIndex, minX, maxX, minY, maxY, terrainMapID, parentWorldMapID, flags = GetDungeonMapInfo(dID)

            -- check if microdungeon, and if this instance can have micro dungeons
            if bit.band(flags, DUNGEONMAP_MICRO_DUNGEON) == DUNGEONMAP_MICRO_DUNGEON then
                terrainMapID, maxX, minX, maxY, minY = applyMapTransforms(terrainMapID, maxX, minX, maxY, minY)
                if not microDungeons[terrainMapID] then
                    microDungeons[terrainMapID] = {}
                end
                microDungeons[terrainMapID][floorIndex] = { maxX - minX, maxY - minY, maxX, maxY }
                microDungeons[terrainMapID][floorIndex].instance = terrainMapID
            end
        end
    end

    local function gatherMapData()
        -- load transforms
        processTransforms()

        -- load the main zones
        -- these should be processed first so they take precedence in the mapFile lookup table
        local continents = {GetMapContinents()}
        for i = 1, #continents, 2 do
            processZone(continents[i])
            local zones = {GetMapZones((i + 1) / 2)}
            for z = 1, #zones, 2 do
                processZone(zones[z])
            end
        end

        -- process all other zones, this includes dungeons and more
        local areas = GetAreaMaps()
        for idx, zoneId in pairs(areas) do
            processZone(zoneId)
        end

        -- and finally, the microdungeons
        processMicroDungeons()
    end

    gatherMapData()
end

-- Transform a set of coordinates based on the defined map transformations
local function applyCoordinateTransforms(x, y, instanceId)
    for _, transformData in ipairs(transforms) do
        if transformData.instanceId == instanceId then
            if transformData.minX <= x and transformData.maxX >= x and transformData.minY <= y and transformData.maxY >= y then
                instanceId = transformData.newInstanceId
                x = x + transformData.offsetX
                y = y + transformData.offsetY
                break
            end
        end
    end
    if instanceIdOverrides[instanceId] then
        instanceId = instanceIdOverrides[instanceId]
    end
    return x, y, instanceId
end

-- get the data table for a map and its level (floor)
local function getMapDataTable(mapId, level)
    if not mapId or mapId == WORLDMAP_COSMIC_ID then return nil end
    if type(mapId) == "string" then
        mapId = mapToId[mapId]
    end
    local data = mapData[mapId]
    if not data then return nil end

    if (level == nil or level == 0) and data.fakefloor then
        level = 1
    end

    if level and level > 0 then
        if data.floors[level] then
            return data.floors[level]
        elseif microDungeons[data.instance][level] then
            return microDungeons[data.instance][level]
        end
    else
        return data
    end
end
HereBeDragons.getMapDataTable = getMapDataTable

--- Return the localized zone name for a given mapId or mapFile
-- @param mapId numeric mapId or mapFile
function HereBeDragons:GetLocalizedMap(mapId)
    if mapId == WORLDMAP_COSMIC_ID then return WORLD_MAP end
    if type(mapId) == "string" then
        mapId = mapToId[mapId]
    end
    assert(mapLocalized[mapId])
    return mapLocalized[mapId]
end

--- Return the map id to a mapFile
-- @param mapFile Map File
function HereBeDragons:GetMapIdFromFile(mapFile)
    assert(mapToId[mapFile])
    return mapToId[mapFile]
end

--- Return the mapFile to a map id
-- @param mapId Map Id
function HereBeDragons:GetMapFileFromId(mapId)
    return idToMap[mapId]
end

--- Get the size of the zone
-- @param mapId Map Id or MapFile of the zone
-- @param level Optional map level
-- @return width, height of the zone, in yards
function HereBeDragons:GetZoneSize(mapId, level)
    local data = getMapDataTable(mapId, level)
    if not data then return 0, 0 end

    return data[1], data[2]
end

--- Convert local/point coordinates to world coordinates in yards
-- @param x X position on 0-1 point coordinates
-- @param y Y position in 0-1 point coordinates
-- @param zone MapId or MapFile of the zone
-- @param level Optional level of the zone
-- @param transform Apply map transforms
function HereBeDragons:GetWorldCoordinatesFromZone(x, y, zone, level, transform)
    local data = getMapDataTable(zone, level)
    if not data then return 0, 0 end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = left - width * x, top - height * y

    return x, y, data.instance
end

--- Convert world coordinates to local/point zone coordinates
-- @param x Global X position
-- @param y Global Y position
-- @param zone MapId or MapFile of the zone
-- @param level Optiona level of the zone
function HereBeDragons:GetZoneCoordinatesFromWorld(x, y, zone, level)
    local data = getMapDataTable(zone, level)
    if not data then return 0, 0 end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    -- verify the coordinates fall into the zone
    if x < 0 or x > 1 or y < 0 or y > 1 then return 0, 0 end

    return x, y
end

--- Return the distance from an origin position to a destination position in the same instance/continent.
-- @param instanceId instance id
-- @param oX origin X
-- @param oY origin Y
-- @param dX destination X
-- @param dY destination Y
-- @return distance, deltaX, deltaY
function HereBeDragons:GetWorldDistance(instanceId, oX, oY, dX, dY)
    local deltaX, deltaY = dX - oX, dY - oY
    return (deltaX * deltaX + deltaY * deltaY)^0.5, deltaX, deltaY
end

--- Return the angle and distance from an origin position to a destination position in the same instance/continent.
-- @param instanceId instance id
-- @param oX origin X
-- @param oY origin Y
-- @param dX destination X
-- @param dY destination Y
-- @return angle, distance where angle is in radians and distance in yards
function HereBeDragons:GetWorldVector(instanceId, oX, oY, dX, dY)
    local distance, deltaX, deltaY = self:GetWorldDistance(instanceId, oX, oY, dX, dY)

    -- calculate the angle from deltaY and deltaX
    local angle = math.atan2(deltaX, -deltaY)

    -- normalize the angle
    if angle > 0 then
        angle = PI2 - angle
    else
        angle = -angle
    end

    return angle, distance
end

--- Get the current world position of the player
-- The position is transformed to the current continent, if applicable
-- @return x, y, instanceId
function HereBeDragons:GetPlayerWorldPosition()
    -- get the current position
    local y, x, z, instanceId = UnitPosition("player")

    -- return transformed coordinates
    return applyCoordinateTransforms(x, y, instanceId)
end
