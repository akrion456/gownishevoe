--@shared
--[[
    SOLACE — Intermediate Representation (IR) Schema
    Pure, JSON-serializable scene data model decoupled from Starfall runtime entities.
    Designed from Phase 1 to support save/load, animations, VFX, and AI-friendly Lua export.
]]

local Constants = require("../core/constants.lua")

local IR = {}

local function vec3(x, y, z)
    return { x or 0, y or 0, z or 0 }
end

local function ang3(p, y, r)
    return { p or 0, y or 0, r or 0 }
end

local function rgba(r, g, b, a)
    return { r or 255, g or 255, b or 255, a or 255 }
end

function IR.cloneVec3(v)
    return { v[1] or 0, v[2] or 0, v[3] or 0 }
end

function IR.cloneColor(c)
    return { c[1] or 255, c[2] or 255, c[3] or 255, c[4] or 255 }
end

-- Runtime Starfall object conversions (used only by adapters/viewport, never stored in IR)
function IR.toVector(v)
    return Vector(v[1] or 0, v[2] or 0, v[3] or 0)
end

function IR.toAngle(a)
    return Angle(a[1] or 0, a[2] or 0, a[3] or 0)
end

function IR.toColor(c)
    return Color(c[1] or 255, c[2] or 255, c[3] or 255, c[4] or 255)
end

function IR.fromVector(v)
    return { v.x, v.y, v.z }
end

function IR.fromAngle(a)
    return { a.p, a.y, a.r }
end

function IR.fromColor(c)
    return { c.r, c.g, c.b, c.a }
end

function IR.createTransform(opts)
    opts = opts or {}
    return {
        pos   = opts.pos   and IR.cloneVec3(opts.pos)   or vec3(0, 0, 0),
        ang   = opts.ang   and IR.cloneVec3(opts.ang)   or ang3(0, 0, 0),
        scale = opts.scale and IR.cloneVec3(opts.scale) or vec3(1, 1, 1),
        pivot = opts.pivot and IR.cloneVec3(opts.pivot) or vec3(0, 0, 0),
    }
end

function IR.createAppearance(opts)
    opts = opts or {}
    return {
        model = opts.model or "",
        material = opts.material or "",
        submaterials = opts.submaterials or {},
        color = opts.color and IR.cloneColor(opts.color) or rgba(255, 255, 255, 255),
        renderMode = opts.renderMode or 0,
        renderFX = opts.renderFX or 0,
        skin = opts.skin or 0,
        bodygroups = opts.bodygroups or {},
        clips = opts.clips or {},
        suppressLighting = opts.suppressLighting or false,
    }
end

function IR.createKeyframe(time, value, easing)
    return {
        time = time or 0,
        value = value,
        easing = easing or Constants.EASING.LINEAR,
    }
end

function IR.createTrack(propertyPath)
    return {
        property = propertyPath,
        enabled = true,
        keyframes = {},
    }
end

function IR.createNode(opts)
    opts = opts or {}
    local kind = opts.kind or Constants.NODE_KINDS.MODEL

    local node = {
        id = opts.id or "",
        name = opts.name or "Node",
        exportName = opts.exportName or "",
        kind = kind,
        parentId = opts.parentId,       -- nil only on root
        children = opts.children or {}, -- ordered array of child node IDs
        visible = opts.visible ~= false,
        locked = opts.locked or false,
        expanded = opts.expanded ~= false,
        description = opts.description or "",
        tags = opts.tags or {},

        transform = IR.createTransform(opts.transform),
        appearance = IR.createAppearance(opts.appearance),

        physics = {
            enabled = false,
            frozen = true,
            mass = 50,
            gravity = true,
            material = "",
        },

        -- Specialized payload blocks (populated for sprite, light, effect, ragdoll, camera)
        sprite = nil,
        light = nil,
        effect = nil,
        bones = nil,
        camera = nil,

        -- Animation tracks keyed by property path (e.g. "transform.pos", "appearance.color")
        tracks = opts.tracks or {},
    }

    if kind == Constants.NODE_KINDS.CAMERA then
        node.camera = {
            fov = (opts.camera and opts.camera.fov) or 80,
            shakeAmplitude = 0,
            shakeFrequency = 0,
            shakeDuration = 0,
        }
    elseif kind == Constants.NODE_KINDS.SPRITE then
        node.sprite = {
            width = 32,
            height = 32,
            roll = 0,
            spawnTime = 0,
            lifetime = 0, -- 0 = persistent
            fadeIn = 0,
            fadeOut = 0,
            additive = false,
        }
    elseif kind == Constants.NODE_KINDS.LIGHT then
        node.light = {
            size = 256,
            brightness = 2,
            decay = 1000,
            projected = false,
            fov = 60,
        }
    end

    return node
end

function IR.createProject(opts)
    opts = opts or {}
    local rootId = "root"
    local rootNode = IR.createNode({
        id = rootId,
        name = opts.name or "Untitled Scene",
        kind = Constants.NODE_KINDS.ROOT,
        parentId = nil,
        expanded = true,
        description = "Root container for SOLACE scene hierarchy",
    })

    return {
        schemaVersion = Constants.IR_SCHEMA_VERSION,
        app = Constants.APP_NAME,
        name = opts.name or "Untitled Scene",
        author = opts.author or "",
        createdAt = opts.createdAt or os.time(),
        modifiedAt = opts.modifiedAt or os.time(),
        nextId = 1,
        timeline = {
            fps = 30,
            duration = 10.0,
        },
        origin = { 0, 0, 0 },
        rootId = rootId,
        nodes = {
            [rootId] = rootNode,
        },
        presets = {},
    }
end

return IR
