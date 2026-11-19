--@shared
--[[
    SOLACE — Visual Animation & Effects Studio
    Core Constants & Studio Configuration Defaults
]]

local Constants = {}

Constants.APP_NAME = "SOLACE"
Constants.APP_SUBTITLE = "Visual Animation & Effects Studio"
Constants.APP_TAGLINE = "Create. Animate. Visualize. Export."
Constants.VERSION = "0.2.0-phase2"
Constants.IR_SCHEMA_VERSION = 1

-- Node types supported by the Scene Intermediate Representation (IR)
Constants.NODE_KINDS = {
    ROOT = "root",
    FOLDER = "folder",
    GROUP = "group",
    MODEL = "model",
    HOLOGRAM = "hologram",
    RAGDOLL = "ragdoll",
    SPRITE = "sprite",
    PARTICLE = "particle",
    EFFECT = "effect",
    LIGHT = "light",
    DECAL = "decal",
    CAMERA = "camera",
}

-- Easing curve identifiers reserved in the IR for Phase 8+
Constants.EASING = {
    LINEAR = "linear",
    EASE_IN_QUAD = "inQuad",
    EASE_OUT_QUAD = "outQuad",
    EASE_IN_OUT_QUAD = "inOutQuad",
    EASE_IN_CUBIC = "inCubic",
    EASE_OUT_CUBIC = "outCubic",
    EASE_IN_OUT_CUBIC = "inOutCubic",
    STEP = "step",
}

-- Tool definitions (explicitly tagging implementation phase)
Constants.TOOLS = {
    { id = "select", label = "Select", icon = "cursor", phase = 2, ready = true,  hotkey = "Q", desc = "Select objects in 3D viewport (Click, Ctrl+Click multi-select, F: Focus)" },
    { id = "move",   label = "Move",   icon = "move",   phase = 3, ready = false, hotkey = "W", desc = "3D Translation Gizmo — Arriving in Phase 3" },
    { id = "rotate", label = "Rotate", icon = "rotate", phase = 3, ready = false, hotkey = "E", desc = "3D Rotation Gizmo — Arriving in Phase 3" },
    { id = "scale",  label = "Scale",  icon = "scale",  phase = 3, ready = false, hotkey = "R", desc = "3D Scale Gizmo — Arriving in Phase 3" },
    { id = "pivot",  label = "Pivot",  icon = "pivot",  phase = 5, ready = false, hotkey = "T", desc = "Custom Pivot Editor — Arriving in Phase 5" },
}

-- Toolbox categories (populated incrementally; full mounted scanner in Phase 6)
Constants.ASSET_CATEGORIES = {
    { id = "models",    label = "Models",    icon = "cube",    desc = "Mounted .mdl props & starter primitives (Full scanner in Phase 6)" },
    { id = "sprites",   label = "Sprites",   icon = "sparkle", desc = "Billboard 3D sprites (Full editor in Phase 7)" },
    { id = "materials", label = "Materials", icon = "layers",  desc = "Surface & model materials (Phase 6)" },
    { id = "decals",    label = "Decals",    icon = "stamp",   desc = "Surface decals & animated overlays (Phase 6/7)" },
    { id = "effects",   label = "Effects",   icon = "burst",   desc = "VFX presets, particles & shockwaves (Phase 10)" },
    { id = "holograms", label = "Holograms", icon = "holo",    desc = "Clientside hologram primitives & assemblies (Phase 5/7)" },
}

-- Curated starter models commonly mounted in Garry's Mod / HL2 (validated via game.modelExists at runtime)
Constants.STARTER_MODELS = {
    { name = "Cube (1x1)",      model = "models/hunter/blocks/cube1x1x1.mdl" },
    { name = "Cube (0.5)",      model = "models/hunter/blocks/cube05x05x05.mdl" },
    { name = "Sphere",          model = "models/hunter/misc/sphere075x075.mdl" },
    { name = "Cylinder",        model = "models/hunter/tubes/tube1x1x1.mdl" },
    { name = "Plate (2x2)",     model = "models/hunter/plates/plate2x2.mdl" },
    { name = "Oil Barrel",      model = "models/props_c17/oildrum001.mdl" },
    { name = "Wooden Crate",    model = "models/props_junk/wood_crate001a.mdl" },
    { name = "Chair",           model = "models/props_c17/furniturechair001a.mdl" },
    { name = "Traffic Cone",    model = "models/props_junk/trafficcone001a.mdl" },
    { name = "Sawblade",        model = "models/props_junk/sawblade001a.mdl" },
    { name = "Combine Soldier", model = "models/player/combine_soldier.mdl" },
    { name = "Dr. Kleiner",     model = "models/player/kleiner.mdl" },
    { name = "G-Man",           model = "models/player/gman_high.mdl" },
}

Constants.STARTER_SPRITES = {
    { name = "Glow Sprite",  material = "sprites/light_glow02_add" },
    { name = "Flare Sprite", material = "sprites/glow04_noz" },
    { name = "Phys Ring",    material = "sprites/physg_glow1" },
}

-- Grid defaults (Hammer units)
Constants.GRID_SPACING_OPTIONS = { 16, 32, 64, 128 }
Constants.ORIGIN_MODES = { "chip", "player", "world" }

-- Timeline defaults
Constants.FPS_OPTIONS = { 24, 30, 60 }

-- Camera defaults
Constants.CAMERA_DEFAULTS = {
    speed = 450,
    minSpeed = 40,
    maxSpeed = 3000,
    boostMult = 3.0,
    sensitivity = 0.16,
    fov = 80,
    smoothing = 16.0,
    focusPadding = 1.45,
}

-- Default dock layout sizes (pixels) & bounds
Constants.LAYOUT_DEFAULTS = {
    toolbarHeight = 40,
    leftWidth = 256,
    rightWidth = 300,
    bottomHeight = 192,
    explorerRatio = 0.46,

    minLeftWidth = 180,
    maxLeftWidth = 420,
    minRightWidth = 220,
    maxRightWidth = 480,
    minBottomHeight = 132,
    maxBottomHeight = 420,
    minExplorerRatio = 0.22,
    maxExplorerRatio = 0.78,
    minViewportWidth = 320,
    minViewportHeight = 200,
    splitterSize = 5,
}

-- Default runtime state factory
function Constants.createDefaultState()
    return {
        studioOpen = true,
        viewportLooking = false,
        activeTool = "select",
        activeToolboxCategory = "models",
        toolboxSearch = "",
        explorerSearch = "",
        customModelPath = "models/props_c17/oildrum001.mdl",
        spawnDistance = 140,

        -- Freecam settings
        camera = {
            speed = Constants.CAMERA_DEFAULTS.speed,
            boostMult = Constants.CAMERA_DEFAULTS.boostMult,
            sensitivity = Constants.CAMERA_DEFAULTS.sensitivity,
            fov = Constants.CAMERA_DEFAULTS.fov,
            smoothing = Constants.CAMERA_DEFAULTS.smoothing,
        },

        -- Viewport & grid settings
        grid = {
            enabled = true,
            showAxes = true,
            showOriginMarker = true,
            showTelemetry = true,
            showOrientationGizmo = true,
            spacing = 32,
            halfExtents = 10,
            majorEvery = 4,
            originMode = "chip",
            originPos = { 0, 0, 0 },
            zOffset = 0.25,
        },

        -- Timeline state
        timeline = {
            currentTime = 0.0,
            duration = 10.0,
            fps = 30,
            zoom = 80,
            scrollTime = 0.0,
            playing = false,
            loop = true,
        },

        -- Panel visibility toggles
        panels = {
            toolbox = true,
            explorer = true,
            properties = true,
            timeline = true,
        },

        -- Property section collapse state
        sections = {
            selection = true,
            camera = true,
            grid = true,
            origin = false,
            quotas = false,
        },
    }
end

return Constants
