--@shared
--[[
    SOLACE — 3D Transform & Bounding Math Helpers
    Computes hierarchical world transforms from IR transforms (pos, ang, scale, pivot)
    and scaled bounding boxes for raycasting, selection outlines, and camera focus.
]]

local Math3D = {}

-- Compose local matrix: T(pos) * R(ang) * T(pivot) * S(scale) * T(-pivot)
function Math3D.composeLocalMatrix(t)
    local m = Matrix()
    local pos = t.pos
    local ang = t.ang
    local scale = t.scale
    local pivot = t.pivot

    m:translate(Vector(pos[1] or 0, pos[2] or 0, pos[3] or 0))
    m:rotate(Angle(ang[1] or 0, ang[2] or 0, ang[3] or 0))

    local px, py, pz = pivot[1] or 0, pivot[2] or 0, pivot[3] or 0
    local hasPivot = (px ~= 0 or py ~= 0 or pz ~= 0)
    if hasPivot then
        m:translate(Vector(px, py, pz))
    end

    local sx, sy, sz = scale[1] or 1, scale[2] or 1, scale[3] or 1
    if sx ~= 1 or sy ~= 1 or sz ~= 1 then
        m:scale(Vector(sx, sy, sz))
    end

    if hasPivot then
        m:translate(Vector(-px, -py, -pz))
    end

    return m
end

-- Walk parent chain to compute world transform of a Scene IR node.
-- Returns: worldPos (Vector), worldAng (Angle), worldScale (Vector)
function Math3D.computeWorldTransform(sceneGraph, nodeId)
    local chain = {}
    local cur = sceneGraph:getNode(nodeId)
    local rootId = sceneGraph:getRootId()
    local guard = 0

    while cur and cur.id ~= rootId and guard < 64 do
        chain[#chain + 1] = cur
        cur = cur.parentId and sceneGraph:getNode(cur.parentId) or nil
        guard = guard + 1
    end

    if #chain == 0 then
        return Vector(0, 0, 0), Angle(0, 0, 0), Vector(1, 1, 1)
    end

    local worldMat = Matrix()
    local sx, sy, sz = 1, 1, 1
    for i = #chain, 1, -1 do
        local n = chain[i]
        local t = n.transform
        -- Compose translation/rotation hierarchy without baking scale into rotation matrix
        local step = Matrix()
        step:translate(Vector(t.pos[1] or 0, t.pos[2] or 0, t.pos[3] or 0))
        step:rotate(Angle(t.ang[1] or 0, t.ang[2] or 0, t.ang[3] or 0))
        worldMat = worldMat * step

        local ns = t.scale
        sx = sx * (ns[1] or 1)
        sy = sy * (ns[2] or 1)
        sz = sz * (ns[3] or 1)
    end

    return worldMat:getTranslation(), worldMat:getAngles(), Vector(sx, sy, sz)
end

-- Compute hierarchical visibility (false if any ancestor is hidden)
function Math3D.isNodeHierarchyVisible(sceneGraph, nodeId)
    local cur = sceneGraph:getNode(nodeId)
    local rootId = sceneGraph:getRootId()
    local guard = 0
    while cur and guard < 64 do
        if cur.visible == false then return false end
        if cur.id == rootId then break end
        cur = cur.parentId and sceneGraph:getNode(cur.parentId) or nil
        guard = guard + 1
    end
    return true
end

-- Scale local OBB mins/maxs safely (preserving min <= max even for negative scales)
function Math3D.getScaledBounds(mins, maxs, scale)
    local sx, sy, sz = scale[1] or 1, scale[2] or 1, scale[3] or 1
    local x1, x2 = (mins[1] or -8) * sx, (maxs[1] or 8) * sx
    local y1, y2 = (mins[2] or -8) * sy, (maxs[2] or 8) * sy
    local z1, z2 = (mins[3] or -8) * sz, (maxs[3] or 8) * sz

    return Vector(math.min(x1, x2), math.min(y1, y2), math.min(z1, z2)),
           Vector(math.max(x1, x2), math.max(y1, y2), math.max(z1, z2))
end

-- World center & approximate bounding radius of an OBB
function Math3D.getOBBCenterAndRadius(pos, ang, sMin, sMax)
    local localCenter = (sMin + sMax) * 0.5
    local halfExt = (sMax - sMin) * 0.5
    local radius = math.max(8, halfExt:getLength())

    local m = Matrix()
    m:translate(pos)
    m:rotate(ang)
    m:translate(localCenter)
    return m:getTranslation(), radius
end

return Math3D
