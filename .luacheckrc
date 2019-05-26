std = "lua51"
max_line_length = false
exclude_files = {
    ".luacheckrc"
}

ignore = {
    "11./HBD_.*", -- Setting an undefined (HBD Constants) global variable
    "211/_.*", -- Unused local variable starting with _
    "212", -- Unused argument
    "542", -- empty if branch
}

globals = {
    "WorldMapFrame",
}

read_globals = {
    "bit",
    "floor", "ceil",
    "wipe",

    -- Third Party addon functions
    "GetMinimapShape",
    "LibStub",

    -- API functions
    "C_Map",
    "C_Timer",
    "CreateFrame",
    "GetBuildInfo",
    "GetCVar",
    "GetPlayerFacing",
    "IsLoggedIn",
    "UnitPosition",

    -- FrameXML functions
    "CreateFramePool",
    "CreateFromMixins",
    "CreateVector2D",
    "FramePool_HideAndClearAnchors",
    "Mixin",

    -- FrameXML Frames
    "Minimap",
    "UIParent",

    -- FrameXML Misc
    "MapCanvasDataProviderMixin",
    "MapCanvasPinMixin",

    -- Constants
    "Enum",
}
