--@shared
--[[
    SOLACE — Scene Graph
    Manages hierarchical IR nodes, multi-selection state, search queries, CRUD, and dirty tracking.
]]

local Constants = require("../core/constants.lua")
local IR = require("./ir_schema.lua")

local SceneGraph = {}
SceneGraph.__index = SceneGraph

local function sanitizeExportName(name)
    local clean = string.gsub(string.lower(name or "node"), "[^%w_]+", "_")
    clean = string.gsub(clean, "^_+", "")
    clean = string.gsub(clean, "_+$", "")
    if clean == "" or string.match(clean, "^%d") then
        clean = "obj_" .. clean
    end
    return clean
end

function SceneGraph.new(events)
    local self = setmetatable({
        _events = events,
        _project = IR.createProject({ name = "Untitled Scene" }),
        _selectedIds = {},
        _selectedMap = {},
        _primarySelectedId = nil,
        _dirty = false,
    }, SceneGraph)

    -- Create initial StudioCamera IR node
    local cam = self:addNode({
        name = "StudioCamera",
        kind = Constants.NODE_KINDS.CAMERA,
        parentId = self._project.rootId,
        description = "Primary editor & cinematic camera actor",
    })
    self:setSelectedId(cam.id)

    return self
end

function SceneGraph:getProject()
    return self._project
end

function SceneGraph:getRootId()
    return self._project.rootId
end

function SceneGraph:getNode(id)
    if not id then return nil end
    return self._project.nodes[id]
end

function SceneGraph:getAllNodes()
    return self._project.nodes
end

-- Selection API (supports both primary single selection and multi-selection)
function SceneGraph:getSelectedId()
    return self._primarySelectedId
end

function SceneGraph:getSelectedNode()
    return self._primarySelectedId and self._project.nodes[self._primarySelectedId] or nil
end

function SceneGraph:getSelectedIds()
    return self._selectedIds
end

function SceneGraph:isSelected(id)
    return id ~= nil and self._selectedMap[id] == true
end

function SceneGraph:clearSelection()
    if #self._selectedIds == 0 and self._primarySelectedId == nil then return end
    self._selectedIds = {}
    self._selectedMap = {}
    self._primarySelectedId = nil
    if self._events then
        self._events:emit("selectionChanged", nil, nil, self._selectedIds)
    end
end

function SceneGraph:setSelectedId(id)
    if id == nil then
        self:clearSelection()
        return
    end
    if not self._project.nodes[id] then return end
    if #self._selectedIds == 1 and self._primarySelectedId == id then return end

    self._selectedIds = { id }
    self._selectedMap = { [id] = true }
    self._primarySelectedId = id
    if self._events then
        self._events:emit("selectionChanged", id, self:getNode(id), self._selectedIds)
    end
end

function SceneGraph:toggleSelectedId(id)
    if not id or not self._project.nodes[id] then return end
    if self._selectedMap[id] then
        self._selectedMap[id] = nil
        for i = #self._selectedIds, 1, -1 do
            if self._selectedIds[i] == id then
                table.remove(self._selectedIds, i)
                break
            end
        end
        if self._primarySelectedId == id then
            self._primarySelectedId = self._selectedIds[#self._selectedIds]
        end
    else
        self._selectedMap[id] = true
        self._selectedIds[#self._selectedIds + 1] = id
        self._primarySelectedId = id
    end

    if self._events then
        self._events:emit("selectionChanged", self._primarySelectedId, self:getSelectedNode(), self._selectedIds)
    end
end

function SceneGraph:isDirty()
    return self._dirty
end

function SceneGraph:markDirty()
    self._dirty = true
    self._project.modifiedAt = os.time()
    if self._events then
        self._events:emit("sceneDirty", self._project)
    end
end

function SceneGraph:generateId(prefix)
    local idx = self._project.nextId
    self._project.nextId = idx + 1
    return string.format("%s_%04d", prefix or "node", idx)
end

function SceneGraph:addNode(opts)
    opts = opts or {}
    local parentId = opts.parentId or self._project.rootId
    local parent = self._project.nodes[parentId]
    if not parent then
        parentId = self._project.rootId
        parent = self._project.nodes[parentId]
    end

    local id = opts.id
    if not id or id == "" or self._project.nodes[id] then
        id = self:generateId(opts.kind or "node")
    end

    local node = IR.createNode(opts)
    node.id = id
    node.parentId = parentId
    if node.exportName == "" then
        node.exportName = sanitizeExportName(node.name) .. "_" .. string.sub(id, -4)
    end

    self._project.nodes[id] = node
    parent.children[#parent.children + 1] = id

    self:markDirty()
    if self._events then
        self._events:emit("nodeAdded", node)
    end
    return node
end

function SceneGraph:createModel(name, modelPath, posTbl, angTbl, parentId)
    return self:addNode({
        name = name or "Model",
        kind = Constants.NODE_KINDS.MODEL,
        parentId = parentId or self._project.rootId,
        transform = {
            pos = posTbl or { 0, 0, 0 },
            ang = angTbl or { 0, 0, 0 },
            scale = { 1, 1, 1 },
            pivot = { 0, 0, 0 },
        },
        appearance = {
            model = modelPath,
        },
    })
end

function SceneGraph:createGroup(name, posTbl, parentId)
    return self:addNode({
        name = name or "Group",
        kind = Constants.NODE_KINDS.GROUP,
        parentId = parentId or self._project.rootId,
        transform = {
            pos = posTbl or { 0, 0, 0 },
        },
    })
end

function SceneGraph:createFolder(name, parentId)
    return self:addNode({
        name = name or "Folder",
        kind = Constants.NODE_KINDS.FOLDER,
        parentId = parentId or self._project.rootId,
    })
end

function SceneGraph:createSprite(name, materialPath, posTbl, parentId)
    return self:addNode({
        name = name or "Sprite",
        kind = Constants.NODE_KINDS.SPRITE,
        parentId = parentId or self._project.rootId,
        transform = {
            pos = posTbl or { 0, 0, 0 },
        },
        appearance = {
            material = materialPath or "sprites/light_glow02_add",
        },
    })
end

function SceneGraph:removeNode(id)
    if not id or id == self._project.rootId then return false end
    local node = self._project.nodes[id]
    if not node then return false end

    -- Gather entire subtree IDs post-order
    local removedIds = {}
    local function collect(nid)
        local n = self._project.nodes[nid]
        if not n then return end
        for i = 1, #n.children do
            collect(n.children[i])
        end
        removedIds[#removedIds + 1] = nid
    end
    collect(id)

    -- Detach from parent's children array
    local parent = node.parentId and self._project.nodes[node.parentId]
    if parent then
        for i = #parent.children, 1, -1 do
            if parent.children[i] == id then
                table.remove(parent.children, i)
                break
            end
        end
    end

    local selChanged = false
    for _, rid in ipairs(removedIds) do
        self._project.nodes[rid] = nil
        if self._selectedMap[rid] then
            self._selectedMap[rid] = nil
            selChanged = true
        end
    end

    if selChanged then
        for i = #self._selectedIds, 1, -1 do
            if not self._selectedMap[self._selectedIds[i]] then
                table.remove(self._selectedIds, i)
            end
        end
        if not self._selectedMap[self._primarySelectedId] then
            self._primarySelectedId = self._selectedIds[#self._selectedIds]
        end
    end

    self:markDirty()
    if self._events then
        self._events:emit("nodeRemoved", removedIds)
        if selChanged then
            self._events:emit("selectionChanged", self._primarySelectedId, self:getSelectedNode(), self._selectedIds)
        end
    end
    return true
end

function SceneGraph:renameNode(id, newName)
    local node = self:getNode(id)
    if not node or not newName then return false end
    local trimmed = string.trim(newName)
    if trimmed == "" then return false end
    node.name = trimmed
    if id == self._project.rootId then
        self._project.name = trimmed
    else
        node.exportName = sanitizeExportName(trimmed) .. "_" .. string.sub(id, -4)
    end
    self:markDirty()
    if self._events then
        self._events:emit("nodeUpdated", node)
    end
    return true
end

function SceneGraph:toggleNodeVisible(id)
    if not id or id == self._project.rootId then return false end
    local node = self:getNode(id)
    if not node then return false end
    node.visible = not node.visible
    self:markDirty()
    if self._events then
        self._events:emit("nodeUpdated", node)
    end
    return true
end

function SceneGraph:notifyNodeUpdated(id)
    local node = self:getNode(id)
    if not node then return end
    self:markDirty()
    if self._events then
        self._events:emit("nodeUpdated", node)
    end
end

function SceneGraph:getNodeCount()
    local count = 0
    for id in pairs(self._project.nodes) do
        if id ~= self._project.rootId then
            count = count + 1
        end
    end
    return count
end

-- Flattened depth-first list for Explorer rendering (respects expanded state & optional search filter)
function SceneGraph:getFlatHierarchy(searchQuery)
    local out = {}
    local q = searchQuery and string.lower(string.trim(searchQuery)) or ""
    local hasQuery = q ~= ""

    local function matches(node)
        if not hasQuery then return true end
        return string.find(string.lower(node.name), q, 1, true) ~= nil
            or string.find(string.lower(node.kind), q, 1, true) ~= nil
    end

    local function subtreeMatches(node)
        if matches(node) then return true end
        for _, childId in ipairs(node.children) do
            local child = self._project.nodes[childId]
            if child and subtreeMatches(child) then
                return true
            end
        end
        return false
    end

    local function walk(nodeId, depth)
        local node = self._project.nodes[nodeId]
        if not node then return end
        if hasQuery and not subtreeMatches(node) then return end

        out[#out + 1] = {
            node = node,
            depth = depth,
            hasChildren = #node.children > 0,
        }

        if node.expanded or hasQuery then
            for _, childId in ipairs(node.children) do
                walk(childId, depth + 1)
            end
        end
    end

    walk(self._project.rootId, 0)
    return out
end

function SceneGraph:setOrigin(vecTbl)
    self._project.origin = IR.cloneVec3(vecTbl)
    self:markDirty()
end

function SceneGraph:setProjectName(name)
    self:renameNode(self._project.rootId, name)
end

return SceneGraph
