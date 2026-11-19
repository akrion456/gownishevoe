--@client
--[[
    SOLACE — 3D Viewport Grid & Overlays
    Renders the world-space reference grid & axes in PostDrawOpaqueRenderables,
    plus the Viewport HUD frame, 3D orientation triad, telemetry bar, and RMB look capture.
]]

local Theme = require("../ui/theme.lua")

local ViewportGrid = {}

-- Reusable scratch vectors for zero-allocation 3D line drawing
local pA = Vector(0, 0, 0)
local pB = Vector(0, 0, 0)

local AXIS_VECS = {
    { label = "X", vec = Vector(1, 0, 0), color = Theme.C.axisX },
    { label = "Y", vec = Vector(0, 1, 0), color = Theme.C.axisY },
    { label = "Z", vec = Vector(0, 0, 1), color = Theme.C.axisZ },
}

local function setVec(v, x, y, z)
    v[1] = x
    v[2] = y
    v[3] = z
end

function ViewportGrid.resolveOrigin(state)
    local g = state.grid
    if g.originMode == "chip" and isValid(chip()) then
        local p = chip():getPos()
        g.originPos[1], g.originPos[2], g.originPos[3] = p[1], p[2], p[3]
    elseif g.originMode == "player" and isValid(player()) then
        local p = player():getPos()
        g.originPos[1], g.originPos[2], g.originPos[3] = p[1], p[2], p[3]
    else
        g.originPos[1], g.originPos[2], g.originPos[3] = 0, 0, 0
    end
end

function ViewportGrid.draw3D(state)
    if not state.studioOpen then return end
    local g = state.grid
    if not g.enabled and not g.showAxes then return end

    local ox = g.originPos[1]
    local oy = g.originPos[2]
    local oz = g.originPos[3] + (g.zOffset or 0.25)

    local spacing = g.spacing
    local n = g.halfExtents
    local majorEvery = math.max(1, g.majorEvery)
    local span = n * spacing

    if g.enabled then
        for i = -n, n do
            local isOriginLine = (i == 0)
            local isMajor = (i % majorEvery == 0)

            if not (isOriginLine and g.showAxes) then
                local c = isOriginLine and Theme.C.gridMajor
                    or (isMajor and Theme.C.gridMajor or Theme.C.gridMinor)
                render.setRGBA(c[1], c[2], c[3], c[4])

                local offset = i * spacing
                setVec(pA, ox - span, oy + offset, oz)
                setVec(pB, ox + span, oy + offset, oz)
                render.draw3DLine(pA, pB, true)

                setVec(pA, ox + offset, oy - span, oz)
                setVec(pB, ox + offset, oy + span, oz)
                render.draw3DLine(pA, pB, true)
            end
        end
    end

    if g.showAxes then
        local axisLen = math.max(spacing * 2, span)
        Theme.setColor(Theme.C.axisX, 230)
        setVec(pA, ox, oy, oz)
        setVec(pB, ox + axisLen, oy, oz)
        render.draw3DLine(pA, pB, true)
        Theme.setColor(Theme.C.axisX, 75)
        setVec(pB, ox - span, oy, oz)
        render.draw3DLine(pA, pB, true)

        Theme.setColor(Theme.C.axisY, 230)
        setVec(pA, ox, oy, oz)
        setVec(pB, ox, oy + axisLen, oz)
        render.draw3DLine(pA, pB, true)
        Theme.setColor(Theme.C.axisY, 75)
        setVec(pB, ox, oy - span, oz)
        render.draw3DLine(pA, pB, true)

        Theme.setColor(Theme.C.axisZ, 235)
        setVec(pA, ox, oy, oz)
        setVec(pB, ox, oy, oz + math.min(axisLen, spacing * 4))
        render.draw3DLine(pA, pB, true)
    end

    if g.showOriginMarker then
        local r = math.max(4, spacing * 0.14)
        Theme.setColor(Theme.C.warning, 220)
        setVec(pA, ox - r, oy - r, oz)
        setVec(pB, ox + r, oy + r, oz)
        render.draw3DLine(pA, pB, true)
        setVec(pA, ox - r, oy + r, oz)
        setVec(pB, ox + r, oy - r, oz)
        render.draw3DLine(pA, pB, true)
    end
end

local function drawOrientationTriad(cx, cy, radius, ang)
    Theme.setColor(Theme.C.hudPill)
    render.drawFilledCircle(cx, cy, radius + 12)
    Theme.setColor(Theme.C.borderLight)
    render.drawCircle(cx, cy, radius + 12)

    local fwd = ang:getForward()
    local right = ang:getRight()
    local up = ang:getUp()

    local items = {}
    for i = 1, 3 do
        local a = AXIS_VECS[i]
        items[i] = {
            label = a.label,
            color = a.color,
            sx = a.vec:dot(right),
            sy = -a.vec:dot(up),
            depth = a.vec:dot(fwd),
        }
    end
    table.sort(items, function(a, b) return a.depth < b.depth end)

    render.setFont(Theme.Fonts.Small)
    for _, item in ipairs(items) do
        local ex = cx + item.sx * radius
        local ey = cy + item.sy * radius
        local alpha = item.depth < -0.15 and 120 or 255
        Theme.setColor(item.color, alpha)
        render.drawLine(cx, cy, ex, ey)
        render.drawFilledCircle(ex, ey, 7)
        Theme.setColor(Theme.C.textPrimary, alpha)
        render.drawSimpleText(ex, ey, item.label, TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)
    end
end

function ViewportGrid.updateLookMode(state, ui, vpRect)
    if not state.studioOpen then
        state.viewportLooking = false
        return
    end

    local inViewport = ui:pointInRect(vpRect.x, vpRect.y, vpRect.w, vpRect.h)
    if ui.rightPressed and inViewport and not ui.activeId and not ui.focusedInputId then
        state.viewportLooking = true
        if hasPermission("input.enablecursor") then
            input.enableCursor(false)
        end
    elseif state.viewportLooking and not ui.rightDown then
        state.viewportLooking = false
        if hasPermission("input.enablecursor") then
            input.enableCursor(true)
        end
    end
end

function ViewportGrid.drawOverlay(state, ui, vpRect, fpsSmooth, camera, sceneGraph)
    local x, y, w, h = vpRect.x, vpRect.y, vpRect.w, vpRect.h
    if w < 40 or h < 40 then return end

    ui:pushClip(x, y, w, h)

    Theme.setColor(state.viewportLooking and Theme.C.accent or Theme.C.border)
    render.drawRectOutline(x, y, w, h, 1)

    -- Top-left Freecam / Selection hint pill
    local pillX = x + 10
    local pillY = y + 10
    local modeStr = state.viewportLooking
        and string.format("FREECAM  |  Speed: %d u/s (Shift: x%.1f)  |  Release RMB for cursor", state.camera.speed, state.camera.boostMult)
        or "Freecam: Hold RMB + WASD/Space/Ctrl  |  Click: Select  |  F: Focus  |  Del: Delete"
    render.setFont(Theme.Fonts.Small)
    local tw = render.getTextSize(modeStr)
    local pw = math.min(w - 110, tw + 18)
    Theme.setColor(Theme.C.hudPill)
    render.drawRectFast(pillX, pillY, pw, 22)
    Theme.setColor(state.viewportLooking and Theme.C.accent or Theme.C.border)
    render.drawRectOutline(pillX, pillY, pw, 22, 1)
    Theme.setColor(state.viewportLooking and Theme.C.accentBright or Theme.C.textSecondary)
    render.drawSimpleText(pillX + 9, pillY + 11, modeStr, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)

    -- Top-right 3D Orientation Triad synced with Freecam angle
    if state.grid.showOrientationGizmo and w > 180 and h > 140 then
        local triadAng = (camera and camera.initialized) and camera.camAng or eyeAngles()
        drawOrientationTriad(x + w - 42, y + 42, 22, triadAng)
    end

    -- Bottom-left live telemetry & selection readout
    if state.grid.showTelemetry then
        local cpuMs = cpuAverage() * 1000
        local maxMs = cpuMax() * 1000
        local ramMb = ramUsed() / 1024
        local holos = hologram.hologramsLeft()
        local selCount = #sceneGraph:getSelectedIds()
        local selNode = sceneGraph:getSelectedNode()
        local selText = selCount == 0 and "None"
            or (selCount == 1 and (selNode and selNode.name or "?") or (selCount .. " objects"))

        local statsStr = string.format(
            "FPS: %d  |  CPU: %.2f/%.1fms  |  RAM: %.1fMB  |  Holos: %d  |  Cam: %d u/s FOV %d  |  Sel: %s",
            math.round(fpsSmooth),
            cpuMs,
            maxMs,
            ramMb,
            holos,
            state.camera.speed,
            state.camera.fov,
            selText
        )
        render.setFont(Theme.Fonts.Mono)
        local sw = render.getTextSize(statsStr)
        local bx = x + 10
        local by = y + h - 30
        local bw = math.min(w - 20, sw + 16)
        Theme.setColor(Theme.C.hudPill)
        render.drawRectFast(bx, by, bw, 20)
        Theme.setColor(Theme.C.border)
        render.drawRectOutline(bx, by, bw, 20, 1)

        local cpuWarn = (cpuMs / math.max(0.001, maxMs)) > 0.7
        Theme.setColor(cpuWarn and Theme.C.warning or Theme.C.textSecondary)
        render.drawSimpleText(bx + 8, by + 10, statsStr, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)
    end

    ui:popClip()
end

return ViewportGrid
