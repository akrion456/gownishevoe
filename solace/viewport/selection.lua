--@client
--[[
    SOLACE — 3D Viewport Selection & Highlighting
    Performs cursor-to-world raycasting against runtime Scene IR bounds
    and draws clean Blender/Roblox-style OBB wireframes & corner brackets.
]]

local Constants = require("../core/constants.lua")
local Theme     = require("../ui/theme.lua")

local Selection = {
    hoveredId = nil,
}

local RAY_LEN = 16384

-- Reusable corner scratch vectors
local p0 = Vector(0, 0, 0)
local p1 = Vector(0, 0, 0)
local p2 = Vector(0, 0, 0)
local p3 = Vector(0, 0, 0)

local function drawCornerBrackets(pos, ang, sMin, sMax, col, alpha)
    local m = Matrix()
    m:translate(pos)
    m:rotate(ang)

    local x1, y1, z1 = sMin[1], sMin[2], sMin[3]
    local x2, y2, z2 = sMax[1], sMax[2], sMax[3]

    -- Expand slightly (0.5u) to prevent Z-fighting on flat box surfaces
    local pad = 0.5
    x1, y1, z1 = x1 - pad, y1 - pad, z1 - pad
    x2, y2, z2 = x2 + pad, y2 + pad, z2 + pad

    local dx = (x2 - x1) * 0.22
    local dy = (y2 - y1) * 0.22
    local dz = (z2 - z1) * 0.22

    Theme.setColor(col, alpha)

    local xs = { x1, x2 }
    local ys = { y1, y2 }
    local zs = { z1, z2 }

    for ix = 1, 2 do
        local cx = xs[ix]
        local sx = (ix == 1) and dx or -dx
        for iy = 1, 2 do
            local cy = ys[iy]
            local sy = (iy == 1) and dy or -dy
            for iz = 1, 2 do
                local cz = zs[iz]
                local sz = (iz == 1) and dz or -dz

                p0[1], p0[2], p0[3] = cx, cy, cz
                p1[1], p1[2], p1[3] = cx + sx, cy, cz
                p2[1], p2[2], p2[3] = cx, cy + sy, cz
                p3[1], p3[2], p3[3] = cx, cy, cz + sz

                local w0 = m * p0
                render.draw3DLine(w0, m * p1, true)
                render.draw3DLine(w0, m * p2, true)
                render.draw3DLine(w0, m * p3, true)
            end
        end
    end
end

function Selection.pickAtCursor(ui, state, camera, sceneGraph, runtime, vpRect)
    if not state.studioOpen or state.viewportLooking then
        Selection.hoveredId = nil
        return nil
    end
    if not ui:pointInRect(vpRect.x, vpRect.y, vpRect.w, vpRect.h) then
        Selection.hoveredId = nil
        return nil
    end

    local aimDir = trace.aimVector(camera.camAng, state.camera.fov, ui.mx, ui.my, ui.scrW, ui.scrH)
    local rayDelta = aimDir * RAY_LEN

    local bestId = nil
    local bestFrac = 2.0

    for id, entry in pairs(runtime:getEntries()) do
        local node = sceneGraph:getNode(id)
        if node and entry.visible and not node.locked then
            local kind = node.kind
            if kind == Constants.NODE_KINDS.MODEL
                or kind == Constants.NODE_KINDS.HOLOGRAM
                or kind == Constants.NODE_KINDS.SPRITE
            then
                local pos, ang, sMin, sMax = runtime:getNodeBounds(id)
                if pos then
                    local testAng = (kind == Constants.NODE_KINDS.SPRITE) and camera.camAng or ang
                    local _, _, frac = trace.intersectRayWithOBB(camera.camPos, rayDelta, pos, testAng, sMin, sMax)
                    if frac and frac < bestFrac then
                        bestFrac = frac
                        bestId = id
                    end
                end
            end
        end
    end

    Selection.hoveredId = bestId
    return bestId
end

function Selection.handleClick(ui, state, camera, sceneGraph, runtime, vpRect)
    if not state.studioOpen or state.viewportLooking then return end
    if ui.activeId ~= nil then return end
    if not ui.leftPressed then return end
    if not ui:pointInRect(vpRect.x, vpRect.y, vpRect.w, vpRect.h) then return end

    -- If a HUD widget inside the viewport (none in P2, future gizmos in P3) didn't capture the click:
    local hitId = Selection.pickAtCursor(ui, state, camera, sceneGraph, runtime, vpRect)
    local ctrl = hasPermission("input") and input.isControlDown() or false

    if hitId then
        if ctrl then
            sceneGraph:toggleSelectedId(hitId)
        else
            sceneGraph:setSelectedId(hitId)
        end
    else
        if not ctrl then
            sceneGraph:clearSelection()
        end
    end
end

function Selection.draw3D(state, camera, sceneGraph, runtime)
    if not state.studioOpen then return end

    local primaryId = sceneGraph:getSelectedId()
    local selectedIds = sceneGraph:getSelectedIds()

    -- Draw subtle hover box if cursor is over an unselected object
    local hovId = Selection.hoveredId
    if hovId and not sceneGraph:isSelected(hovId) then
        local node = sceneGraph:getNode(hovId)
        if node then
            local pos, ang, sMin, sMax = runtime:getNodeBounds(hovId)
            if pos then
                local testAng = (node.kind == Constants.NODE_KINDS.SPRITE) and camera.camAng or ang
                Theme.setColor(Theme.C.textPrimary, 95)
                render.draw3DWireframeBox(pos, testAng, sMin, sMax, true)
            end
        end
    end

    -- Draw selected object highlights
    for _, id in ipairs(selectedIds) do
        local node = sceneGraph:getNode(id)
        if node and id ~= sceneGraph:getRootId() then
            local pos, ang, sMin, sMax = runtime:getNodeBounds(id)
            if pos then
                local isPrimary = (id == primaryId)
                local col = isPrimary and Theme.C.accentBright or Theme.C.accent
                local testAng = (node.kind == Constants.NODE_KINDS.SPRITE) and camera.camAng or ang

                -- Subtle wireframe cage + crisp corner brackets
                Theme.setColor(col, isPrimary and 120 or 80)
                render.draw3DWireframeBox(pos, testAng, sMin, sMax, true)
                drawCornerBrackets(pos, testAng, sMin, sMax, col, isPrimary and 255 or 190)
            end
        end
    end
end

return Selection
