--@client
--[[
    SOLACE — Clientside Scene Runtime Adapter
    Converts pure Scene IR nodes into clientside StarfallEx visual objects
    (holograms, 3D sprites, bounds cache) without storing entity references in IR.
    All hologram creation/destruction is deferred to Think() so render hooks stay safe.
]]

local Constants = require("../core/constants.lua")
local Math3D    = require("../core/math3d.lua")
local IR        = require("./ir_schema.lua")

local SceneRuntime = {}
SceneRuntime.__index = SceneRuntime

local DEFAULT_MINS = Vector(-8, -8, -8)
local DEFAULT_MAXS = Vector(8, 8, 8)

function SceneRuntime.new(sceneGraph, events)
    local self = setmetatable({
        _scene = sceneGraph,
        _events = events,
        _entries = {},       -- [nodeId] = { kind, holo, material, matPath, worldPos, worldAng, worldScale, boundsMin, boundsMax, visible, errorMsg }
        _dirtyNodes = {},    -- [nodeId] = true
        _pendingRemove = {}, -- array of nodeIds
        _matCache = {},      -- [matPath] = LockedMaterial | false
        _lastError = nil,
    }, SceneRuntime)

    events:on("nodeAdded", "runtime_sync", function(node)
        self:markDirty(node.id)
    end)
    events:on("nodeUpdated", "runtime_sync", function(node)
        self:markSubtreeDirty(node.id)
    end)
    events:on("nodeRemoved", "runtime_sync", function(removedIds)
        for _, id in ipairs(removedIds) do
            self._dirtyNodes[id] = nil
            self._pendingRemove[#self._pendingRemove + 1] = id
        end
    end)

    -- Queue any pre-existing nodes
    for id in pairs(sceneGraph:getAllNodes()) do
        if id ~= sceneGraph:getRootId() then
            self._dirtyNodes[id] = true
        end
    end

    return self
end

function SceneRuntime:markDirty(nodeId)
    if nodeId and nodeId ~= self._scene:getRootId() then
        self._dirtyNodes[nodeId] = true
    end
end

function SceneRuntime:markSubtreeDirty(nodeId)
    local node = self._scene:getNode(nodeId)
    if not node then return end
    if node.id ~= self._scene:getRootId() then
        self._dirtyNodes[node.id] = true
    end
    for _, childId in ipairs(node.children) do
        self:markSubtreeDirty(childId)
    end
end

function SceneRuntime:getLastError()
    return self._lastError
end

function SceneRuntime:getEntries()
    return self._entries
end

function SceneRuntime:getEntry(nodeId)
    return self._entries[nodeId]
end

function SceneRuntime:_loadMaterialCached(matPath)
    if not matPath or matPath == "" then return nil end
    local cached = self._matCache[matPath]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    if not hasPermission("material.load") then
        return nil
    end
    local ok, mat = pcall(material.load, matPath)
    if ok and mat then
        self._matCache[matPath] = mat
        return mat
    end
    self._matCache[matPath] = false
    return nil
end

function SceneRuntime:_destroyEntry(id)
    local entry = self._entries[id]
    if not entry then return end
    if entry.holo and isValid(entry.holo) then
        pcall(function() entry.holo:remove() end)
    end
    self._entries[id] = nil
end

function SceneRuntime:_syncNode(node)
    local id = node.id
    local kind = node.kind
    local entry = self._entries[id]

    local wPos, wAng, wScale = Math3D.computeWorldTransform(self._scene, id)
    local vis = Math3D.isNodeHierarchyVisible(self._scene, id)

    if kind == Constants.NODE_KINDS.MODEL or kind == Constants.NODE_KINDS.HOLOGRAM then
        local modelPath = node.appearance.model or ""
        if modelPath == "" then return end

        if not entry then
            entry = { kind = kind }
            self._entries[id] = entry
        end

        entry.worldPos = wPos
        entry.worldAng = wAng
        entry.worldScale = wScale
        entry.visible = vis

        -- Create or recreate hologram if missing/invalid
        if not entry.holo or not isValid(entry.holo) then
            if not hasPermission("hologram.create") then
                entry.errorMsg = "Missing hologram.create permission"
                self._lastError = entry.errorMsg
                return
            end
            if not hologram.canSpawn() then
                entry.errorMsg = "Hologram limit/burst reached"
                self._lastError = entry.errorMsg
                return
            end
            if not game.modelExists(modelPath) then
                entry.errorMsg = "Model not found: " .. modelPath
                self._lastError = entry.errorMsg
                return
            end

            local ok, holo = pcall(hologram.create, wPos, wAng, modelPath, wScale)
            if not ok or not isValid(holo) then
                entry.errorMsg = "Failed to spawn hologram: " .. tostring(holo)
                self._lastError = entry.errorMsg
                return
            end

            entry.holo = holo
            entry.model = modelPath
            entry.errorMsg = nil
            entry.boundsMin = holo:obbMins() or DEFAULT_MINS
            entry.boundsMax = holo:obbMaxs() or DEFAULT_MAXS
        else
            if entry.model ~= modelPath and game.modelExists(modelPath) then
                pcall(function() entry.holo:setModel(modelPath) end)
                entry.model = modelPath
                entry.boundsMin = entry.holo:obbMins() or DEFAULT_MINS
                entry.boundsMax = entry.holo:obbMaxs() or DEFAULT_MAXS
            end
            entry.holo:setPos(wPos)
            entry.holo:setAngles(wAng)
            entry.holo:setScale(wScale)
        end

        local holo = entry.holo
        if isValid(holo) then
            holo:setNoDraw(not vis)
            holo:setColor(IR.toColor(node.appearance.color))
            if node.appearance.material and node.appearance.material ~= "" then
                holo:setMaterial(node.appearance.material)
            end
        end
    elseif kind == Constants.NODE_KINDS.SPRITE then
        if not entry then
            entry = { kind = kind }
            self._entries[id] = entry
        end
        entry.worldPos = wPos
        entry.worldAng = wAng
        entry.worldScale = wScale
        entry.visible = vis
        local spr = node.sprite or { width = 32, height = 32 }
        local hw = (spr.width or 32) * 0.5
        local hh = (spr.height or 32) * 0.5
        entry.boundsMin = Vector(-2, -hw, -hh)
        entry.boundsMax = Vector(2, hw, hh)
        local matPath = node.appearance.material or "sprites/light_glow02_add"
        if entry.matPath ~= matPath then
            entry.matPath = matPath
            entry.material = self:_loadMaterialCached(matPath)
        end
    elseif kind == Constants.NODE_KINDS.GROUP or kind == Constants.NODE_KINDS.FOLDER or kind == Constants.NODE_KINDS.CAMERA then
        if not entry then
            entry = { kind = kind }
            self._entries[id] = entry
        end
        entry.worldPos = wPos
        entry.worldAng = wAng
        entry.worldScale = wScale
        entry.visible = vis
        entry.boundsMin = DEFAULT_MINS
        entry.boundsMax = DEFAULT_MAXS
    end
end

-- Must ONLY be called outside render hooks (e.g. inside Think)
function SceneRuntime:flush()
    if #self._pendingRemove > 0 then
        for i = 1, #self._pendingRemove do
            self:_destroyEntry(self._pendingRemove[i])
        end
        self._pendingRemove = {}
    end

    if next(self._dirtyNodes) ~= nil then
        local batch = {}
        for id in pairs(self._dirtyNodes) do
            batch[#batch + 1] = id
        end
        self._dirtyNodes = {}

        for _, id in ipairs(batch) do
            local node = self._scene:getNode(id)
            if node then
                self:_syncNode(node)
            else
                self:_destroyEntry(id)
            end
        end
    end
end

-- Returns world transform + scaled bounds for raycasting, outlines & camera focus
function SceneRuntime:getNodeBounds(nodeId)
    local node = self._scene:getNode(nodeId)
    if not node then return nil end

    local entry = self._entries[nodeId]
    local pos, ang, scale
    if entry and entry.worldPos then
        pos, ang, scale = entry.worldPos, entry.worldAng, entry.worldScale
    else
        pos, ang, scale = Math3D.computeWorldTransform(self._scene, nodeId)
    end

    local rawMin = (entry and entry.boundsMin) or DEFAULT_MINS
    local rawMax = (entry and entry.boundsMax) or DEFAULT_MAXS
    local sMin, sMax = Math3D.getScaledBounds(rawMin, rawMax, scale)
    return pos, ang, sMin, sMax, scale, entry
end

-- Draw translucent 3D sprites in PostDrawTranslucentRenderables
function SceneRuntime:drawSprites(state)
    if not state.studioOpen then return end
    for id, entry in pairs(self._entries) do
        if entry.kind == Constants.NODE_KINDS.SPRITE and entry.visible then
            local node = self._scene:getNode(id)
            if node and entry.worldPos then
                local spr = node.sprite or { width = 32, height = 32 }
                local w = (spr.width or 32) * (entry.worldScale and entry.worldScale[1] or 1)
                local h = (spr.height or 32) * (entry.worldScale and entry.worldScale[2] or 1)
                local col = IR.toColor(node.appearance.color)

                if entry.material then
                    render.setMaterial(entry.material)
                    render.draw3DSprite(entry.worldPos, w, h, col)
                else
                    render.setMaterial(nil)
                    render.setColor(col)
                    render.draw3DSprite(entry.worldPos, w * 0.45, h * 0.45, col)
                end
            end
        end
    end
    render.setMaterial(nil)
end

function SceneRuntime:cleanup()
    for id in pairs(self._entries) do
        self:_destroyEntry(id)
    end
    self._entries = {}
    self._dirtyNodes = {}
    self._pendingRemove = {}
end

return SceneRuntime
