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
local mapData          = HereBeDragons.mapData -- table { width, height, left, top }

local currentPlayerUIMapID, currentPlayerUIMapType
