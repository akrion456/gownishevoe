--@client
--[[
    SOLACE — Right-Bottom Properties Panel
    Live scrollable inspector for Selected Object metadata/transforms, Freecam Camera settings,
    Viewport Grid/Origin settings, and StarfallEx runtime quotas.
]]

local Constants = require("../../core/constants.lua")
local Theme = require("../theme.lua")
local Widgets = require("../widgets.lua")

local Properties = {
    _scrollY = 0,
    _contentH = 0,
}

local function cycleOption(options, current, dir)
    local idx = 1
    for i, v in ipairs(options) do
        if v == current then idx = i break end
    end
    idx = ((idx - 1 + dir) % #options) + 1
    return options[idx]
end

local function fmtVec3(v, dec)
    local f = "%." .. (dec or 1) .. "f, %." .. (dec or 1) .. "f, %." .. (dec or 1) .. "f"
    return string.format(f, v[1] or 0, v[2] or 0, v[3] or 0)
end

function Properties.draw(ui, state, sceneGraph, runtime, camera, rect, actions)
    if rect.w <= 0 or rect.h <= 0 then return end

    local sel = sceneGraph:getSelectedNode()
    local selCount = #sceneGraph:getSelectedIds()
    local rightLabel = selCount > 1 and (selCount .. " selected") or (sel and sel.name or "No Selection")
    local bx, by, bw, bh = Widgets.panelFrame(rect.x, rect.y, rect.w, rect.h, "Properties", rightLabel)
    if bw < 20 or bh < 40 then return end

    if ui.wheelDelta ~= 0 and ui:pointInRect(bx, by, bw, bh) then
        Properties._scrollY = Properties._scrollY - ui.wheelDelta * 28
    end
    local maxScroll = math.max(0, Properties._contentH - bh)
    Properties._scrollY = math.clamp(Properties._scrollY, 0, maxScroll)

    ui:pushClip(bx, by, bw, bh)

    local pad = Theme.Metrics.pad
    local rowH = Theme.Metrics.controlH
    local innerW = bw - pad * 2 - (maxScroll > 0 and 8 or 0)
    local curY = by + pad - Properties._scrollY
    local startY = curY

    -- 1. Selected Object
    state.sections.selection = Widgets.sectionHeader(ui, "sec_selection", bx, curY, bw, 22, "Selection", state.sections.selection)
    curY = curY + 26
    if state.sections.selection then
        if sel then
            local isRoot = (sel.id == sceneGraph:getRootId())

            if not isRoot then
                Widgets.textBox(
                    ui,
                    "prop_node_name_" .. sel.id,
                    bx + pad,
                    curY,
                    innerW,
                    22,
                    function() return sel.name end,
                    function(v) sceneGraph:renameNode(sel.id, v) end,
                    "Object name...",
                    "Rename selected object"
                )
                curY = curY + 26
            end

            Widgets.keyValueRow(bx + pad, curY, innerW, 18, "Kind", sel.kind, Theme.C.accentBright)
            curY = curY + 19
            Widgets.keyValueRow(bx + pad, curY, innerW, 18, "IR ID", sel.id, Theme.C.textMuted)
            curY = curY + 19

            if sel.appearance.model and sel.appearance.model ~= "" then
                local shortMdl = string.getFileFromFilename(sel.appearance.model) or sel.appearance.model
                Widgets.keyValueRow(bx + pad, curY, innerW, 18, "Model", shortMdl, Theme.C.textSecondary)
                curY = curY + 19
            elseif sel.appearance.material and sel.appearance.material ~= "" then
                Widgets.keyValueRow(bx + pad, curY, innerW, 18, "Material", sel.appearance.material, Theme.C.textSecondary)
                curY = curY + 19
            end

            if not isRoot then
                Widgets.keyValueRow(bx + pad, curY, innerW, 18, "Position", fmtVec3(sel.transform.pos, 1))
                curY = curY + 19
                Widgets.keyValueRow(bx + pad, curY, innerW, 18, "Rotation", fmtVec3(sel.transform.ang, 1))
                curY = curY + 19
                Widgets.keyValueRow(bx + pad, curY, innerW, 18, "Scale", fmtVec3(sel.transform.scale, 2))
                curY = curY + 22

                local entry = runtime:getEntry(sel.id)
                if entry and entry.errorMsg then
                    Widgets.keyValueRow(bx + pad, curY, innerW, 18, "Runtime", entry.errorMsg, Theme.C.danger)
                    curY = curY + 20
                end

                local thirdW = math.floor((innerW - 8) / 3)
                if Widgets.button(ui, "prop_vis", bx + pad, curY, thirdW, rowH, sel.visible and "Visible" or "Hidden", {
                    active = sel.visible,
                    tooltip = "Toggle object visibility",
                }) then
                    sceneGraph:toggleNodeVisible(sel.id)
                end
                if Widgets.button(ui, "prop_focus", bx + pad + thirdW + 4, curY, thirdW, rowH, "Focus", {
                    tooltip = "Move Freecam to frame this object (F)",
                }) then
                    actions.focusSelected()
                end
                if Widgets.button(ui, "prop_del", bx + pad + (thirdW + 4) * 2, curY, innerW - (thirdW + 4) * 2, rowH, "Delete", {
                    tooltip = "Delete selected object(s) (Del)",
                }) then
                    actions.deleteSelected()
                end
                curY = curY + rowH + 6
            end

            local nh = Widgets.phaseNotice(
                bx + pad, curY, innerW,
                "Interactive Transform Gizmos",
                { "Move / Rotate / Scale editing & numeric", "transform boxes arrive in Phase 3 & 4." },
                "Phase 3-4"
            )
            curY = curY + nh + 8
        else
            Widgets.keyValueRow(bx + pad, curY, innerW, 18, "Selection", "None (Click object in viewport)", Theme.C.textMuted)
            curY = curY + 24
        end
    end

    -- 2. Freecam Camera (live)
    state.sections.camera = Widgets.sectionHeader(ui, "sec_camera", bx, curY, bw, 22, "Freecam Camera", state.sections.camera)
    curY = curY + 26
    if state.sections.camera then
        local c = state.camera
        local spd, spdChanged = Widgets.slider(
            ui, "prop_cam_spd", bx + pad, curY, innerW, rowH,
            "Move Speed", c.speed, Constants.CAMERA_DEFAULTS.minSpeed, Constants.CAMERA_DEFAULTS.maxSpeed, 10, "%.0f u/s",
            "Freecam base movement speed (Mouse wheel in viewport adjusts this)"
        )
        if spdChanged then c.speed = spd end
        curY = curY + rowH + 4

        local bst, bstChanged = Widgets.slider(
            ui, "prop_cam_bst", bx + pad, curY, innerW, rowH,
            "Shift Boost", c.boostMult, 1.5, 6.0, 0.25, "x%.2f",
            "Speed multiplier while holding Shift"
        )
        if bstChanged then c.boostMult = bst end
        curY = curY + rowH + 4

        local sens, sensChanged = Widgets.slider(
            ui, "prop_cam_sens", bx + pad, curY, innerW, rowH,
            "Mouse Sens", c.sensitivity, 0.04, 0.50, 0.01, "%.2f",
            "Mouse look sensitivity while holding Right Mouse Button"
        )
        if sensChanged then c.sensitivity = sens end
        curY = curY + rowH + 4

        local fov, fovChanged = Widgets.slider(
            ui, "prop_cam_fov", bx + pad, curY, innerW, rowH,
            "Field of View", c.fov, 45, 115, 1, "%.0f deg",
            "Viewport camera vertical field of view"
        )
        if fovChanged then c.fov = fov end
        curY = curY + rowH + 4

        local sm, smChanged = Widgets.slider(
            ui, "prop_cam_sm", bx + pad, curY, innerW, rowH,
            "Smoothing", c.smoothing, 4, 40, 1, "%.0f",
            "Camera motion damping (40 = crisp / instant)"
        )
        if smChanged then c.smoothing = sm end
        curY = curY + rowH + 4

        if Widgets.button(ui, "prop_cam_reset", bx + pad, curY, innerW, rowH, "Snap Camera to Player", {
            icon = "camera",
            tooltip = "Move Freecam back to your player's eye position",
        }) then
            camera:resetToPlayer()
        end
        curY = curY + rowH + 8
    end

    -- 3. Viewport Grid (live)
    state.sections.grid = Widgets.sectionHeader(ui, "sec_grid", bx, curY, bw, 22, "Viewport Grid", state.sections.grid)
    curY = curY + 26
    if state.sections.grid then
        local g = state.grid

        if Widgets.button(ui, "prop_grid_en", bx + pad, curY, innerW, rowH,
            "Ground Grid: " .. (g.enabled and "Visible" or "Hidden"),
            { active = g.enabled, icon = "grid", tooltip = "Toggle 3D reference grid (Hotkey: G)" }
        ) then
            g.enabled = not g.enabled
        end
        curY = curY + rowH + 4

        local prevSp, nextSp = Widgets.stepper(
            ui, "prop_grid_sp", bx + pad, curY, innerW, rowH,
            "Cell Spacing", tostring(g.spacing) .. " u",
            "Grid cell size in Hammer units"
        )
        if prevSp then g.spacing = cycleOption(Constants.GRID_SPACING_OPTIONS, g.spacing, -1) end
        if nextSp then g.spacing = cycleOption(Constants.GRID_SPACING_OPTIONS, g.spacing, 1) end
        curY = curY + rowH + 4

        local newExt, extChanged = Widgets.slider(
            ui, "prop_grid_ext", bx + pad, curY, innerW, rowH,
            "Grid Radius", g.halfExtents, 4, 24, 1, "%.0f cells",
            "Number of grid cells from origin in each direction"
        )
        if extChanged then g.halfExtents = newExt end
        curY = curY + rowH + 8
    end

    -- 4. Studio Origin & HUD
    state.sections.origin = Widgets.sectionHeader(ui, "sec_origin", bx, curY, bw, 22, "Studio Origin & HUD", state.sections.origin)
    curY = curY + 26
    if state.sections.origin then
        local g = state.grid
        local prevOr, nextOr = Widgets.stepper(
            ui, "prop_origin_mode", bx + pad, curY, innerW, rowH,
            "Origin Anchor", string.upper(g.originMode),
            "Center studio grid on Chip, Player, or World (0,0,0)"
        )
        if prevOr then
            g.originMode = cycleOption(Constants.ORIGIN_MODES, g.originMode, -1)
            actions.resolveOrigin()
        end
        if nextOr then
            g.originMode = cycleOption(Constants.ORIGIN_MODES, g.originMode, 1)
            actions.resolveOrigin()
        end
        curY = curY + rowH + 4

        local halfW = math.floor((innerW - 4) * 0.5)
        if Widgets.button(ui, "prop_triad", bx + pad, curY, halfW, rowH, "3D Triad", {
            active = g.showOrientationGizmo,
            tooltip = "Toggle top-right 3D axis orientation widget",
        }) then
            g.showOrientationGizmo = not g.showOrientationGizmo
        end
        if Widgets.button(ui, "prop_telem", bx + pad + halfW + 4, curY, innerW - halfW - 4, rowH, "Telemetry", {
            active = g.showTelemetry,
            tooltip = "Toggle bottom-left performance telemetry pill",
        }) then
            g.showTelemetry = not g.showTelemetry
        end
        curY = curY + rowH + 8
    end

    -- 5. StarfallEx Quotas & Permissions
    state.sections.quotas = Widgets.sectionHeader(ui, "sec_quotas", bx, curY, bw, 22, "StarfallEx Runtime", state.sections.quotas)
    curY = curY + 26
    if state.sections.quotas then
        local cpuMs = cpuAverage() * 1000
        local maxMs = cpuMax() * 1000
        Widgets.keyValueRow(bx + pad, curY, innerW, 18, "CPU Avg / Cap", string.format("%.2f / %.1f ms", cpuMs, maxMs))
        curY = curY + 19
        Widgets.keyValueRow(bx + pad, curY, innerW, 18, "RAM Used", string.format("%.1f MB", ramUsed() / 1024))
        curY = curY + 19
        Widgets.keyValueRow(bx + pad, curY, innerW, 18, "Holograms Left", tostring(hologram.hologramsLeft()))
        curY = curY + 19
        Widgets.keyValueRow(bx + pad, curY, innerW, 18, "render.calcview", hasPermission("render.calcview") and "OK" or "Denied",
            hasPermission("render.calcview") and Theme.C.success or Theme.C.danger)
        curY = curY + 19
        Widgets.keyValueRow(bx + pad, curY, innerW, 18, "hologram.create", hasPermission("hologram.create") and "OK" or "Pending",
            hasPermission("hologram.create") and Theme.C.success or Theme.C.warning)
        curY = curY + 24
    end

    Properties._contentH = (curY - startY) + pad

    if maxScroll > 0 then
        local barW = 4
        local barX = bx + bw - barW - 2
        local trackH = bh - 4
        local thumbH = math.max(24, math.floor(trackH * (bh / Properties._contentH)))
        local thumbY = by + 2 + math.floor((trackH - thumbH) * (Properties._scrollY / maxScroll))
        Theme.setColor(Theme.C.bgInput)
        render.drawRectFast(barX, by + 2, barW, trackH)
        Theme.setColor(Theme.C.borderLight)
        render.drawRectFast(barX, thumbY, barW, thumbH)
    end

    ui:popClip()
end

return Properties
