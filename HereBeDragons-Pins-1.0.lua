-- HereBeDragons-Pins is a library to show pins/icons on the world map and minimap

local MAJOR, MINOR = "HereBeDragons-Pins-1.0", 1
assert(LibStub, MAJOR .. " requires LibStub")

local pins, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not pins then return end

local HBD = LibStub("HereBeDragons-1.0")

--- Add a icon to the minimap (x/y world coordinate version)
-- Note: This API does not let you specify a floor, as floors are map-specific, not instance/world wide. Use the Map/Floor API to specify a floor.
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param instanceID Instance ID of the map to add the icon to
-- @param x X position in world coordinates
-- @param y Y position in world coordinates
-- @param floatOnEdge flag if the icon should float on the edge of the minimap when going out of range, or hide immediately (default false)
function pins:AddMinimapIconWorld(ref, icon, instanceID, x, y, floatOnEdge)

end

--- Add a icon to the minimap (mapid/floor coordinate version)
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param mapID Map ID of the map to place the icon on
-- @param mapFloor Floor to place the icon on (or nil for all floors)
-- @param x X position in local/point coordinates (0-1), relative to the zone
-- @param y Y position in local/point coordinates (0-1), relative to the zone
-- @param floatOnEdge flag if the icon should float on the edge of the minimap when going out of range, or hide immediately (default false)
function pins:AddMinimapIconMF(ref, icon, mapID, mapFloor, x, y, floatOnEdge)

end

--- Remove a minimap icon
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
function pins:RemoveMinimapIcon(ref, icon)

end

--- Remove all minimap icons belonging to your addon (as tracked by "ref")
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
function pins:RemoveAllMinimapIcons(ref)

end
