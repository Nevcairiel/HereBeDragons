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
    "C_Minimap",
    "C_Timer",
    "CreateFrame",
    "GetBuildInfo",
    "GetCVar",
    "GetPlayerFacing",
    "IsLoggedIn",
    "UnitPosition",

    -- FrameXML functions
    "CreateFramePool",
    "CreateUnsecuredRegionPoolInstance",
    "CreateFromMixins",
    "CreateVector2D",
    "Lerp",
    "Mixin",

    -- FrameXML Frames
    "Minimap",
    "UIParent",

    -- FrameXML Misc
    "MapCanvasDataProviderMixin",
    "MapCanvasPinMixin",

    -- Constants
    "Enum",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
    "WOW_PROJECT_WRATH_CLASSIC",
    "WOW_PROJECT_CATACLYSM_CLASSIC",
    "WOW_PROJECT_MISTS_CLASSIC"
}
