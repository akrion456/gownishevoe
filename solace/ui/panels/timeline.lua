--@client
--[[
    SOLACE — Bottom Timeline & Sequencer Panel
    Interactive zoomable time ruler, draggable playhead scrubber, FPS/duration controls,
    and Phase 8 track/keyframe workspace foundation.
]]

local Constants = require("../../core/constants.lua")
local Theme = require("../theme.lua")
local Widgets = require("../widgets.lua")

local Timeline = {}

local function cycleFps(current, dir)
    local opts = Constants.FPS_OPTIONS
    local idx = 2
    for i, v in ipairs(opts) do
        if v == current then idx = i break end
    end
    idx = ((idx - 1 + dir) % #opts) + 1
    return opts[idx]
end

local function formatTimecode(t)
    local mins = math.floor(t / 60)
    local secs = t - mins * 60
    return string.format("%02d:%05.2f", mins, secs)
end

function Timeline.draw(ui, state, sceneGraph, rect)
    if rect.w <= 0 or rect.h <= 0 then return end

    local tl = state.timeline
    local frameIdx = math.floor(tl.currentTime * tl.fps + 0.5)
    local totalFrames = math.floor(tl.duration * tl.fps + 0.5)
    local rightBadge = string.format("%s / %s  |  F %d / %d (%d FPS)",
        formatTimecode(tl.currentTime),
        formatTimecode(tl.duration),
        frameIdx,
        totalFrames,
        tl.fps
    )

    local bx, by, bw, bh = Widgets.panelFrame(rect.x, rect.y, rect.w, rect.h, "Timeline", rightBadge)
    if bw < 160 or bh < 60 then return end

    ui:pushClip(bx, by, bw, bh)

    -- Transport & ruler strip
    local stripH = 28
    local headerColW = math.min(230, math.floor(bw * 0.28))

    Theme.setColor(Theme.C.bgPanelAlt)
    render.drawRectFast(bx, by, bw, stripH)
    Theme.setColor(Theme.C.border)
    render.drawLine(bx, by + stripH - 1, bx + bw, by + stripH - 1)
    render.drawLine(bx + headerColW, by, bx + headerColW, by + bh)

    -- Left transport controls
    local tx = bx + 6
    local ty = by + 3
    local btnH = 22

    Widgets.button(ui, "tl_play", tx, ty, 26, btnH, nil, {
        icon = "play", disabled = true, tooltip = "Play Sequence — Arriving in Phase 8",
    })
    tx = tx + 29
    Widgets.button(ui, "tl_stop", tx, ty, 26, btnH, nil, {
        icon = "stop", disabled = true, tooltip = "Stop Sequence — Arriving in Phase 8",
    })
    tx = tx + 32

    if Widgets.button(ui, "tl_fps", tx, ty, 52, btnH, tostring(tl.fps) .. "fps", {
        tooltip = "Cycle Timeline Frame Rate (24 / 30 / 60 FPS)",
    }) then
        tl.fps = cycleFps(tl.fps, 1)
    end
    tx = tx + 56

    if Widgets.button(ui, "tl_dur_minus", tx, ty, 20, btnH, "-", {
        tooltip = "Decrease sequence duration (-5s)",
    }) then
        tl.duration = math.max(2, tl.duration - 5)
        tl.currentTime = math.min(tl.currentTime, tl.duration)
    end
    tx = tx + 21
    if Widgets.button(ui, "tl_dur_plus", tx, ty, 20, btnH, "+", {
        tooltip = "Increase sequence duration (+5s)",
    }) then
        tl.duration = math.min(120, tl.duration + 5)
    end
    tx = tx + 24

    if Widgets.button(ui, "tl_zoom_out", tx, ty, 20, btnH, "z-", {
        tooltip = "Zoom Out Timeline",
    }) then
        tl.zoom = math.clamp(tl.zoom * 0.8, 25, 320)
    end
    tx = tx + 21
    if Widgets.button(ui, "tl_zoom_in", tx, ty, 20, btnH, "z+", {
        tooltip = "Zoom In Timeline",
    }) then
        tl.zoom = math.clamp(tl.zoom * 1.25, 25, 320)
    end

    -- Right interactive Time Ruler
    local rulerX = bx + headerColW + 1
    local rulerW = math.max(40, bw - headerColW - 1)
    local rulerY = by
    local trackAreaY = by + stripH
    local trackAreaH = math.max(0, bh - stripH)

    -- Wheel zoom inside ruler/tracks
    if ui.wheelDelta ~= 0 and ui:pointInRect(rulerX, by, rulerW, bh) then
        local factor = ui.wheelDelta > 0 and 1.15 or 0.87
        tl.zoom = math.clamp(tl.zoom * factor, 25, 320)
    end

    -- Ruler scrubbing (click or drag anywhere on ruler)
    local rulerHot, rulerCap = ui:hitTest("tl_ruler", rulerX, rulerY, rulerW, stripH)
    if rulerHot then
        ui:setTooltip("Click or drag to scrub playhead (Mouse wheel to zoom)")
        if ui.leftPressed then
            ui:capture("tl_ruler")
        end
    end
    if rulerCap and ui.leftDown then
        local t = tl.scrollTime + (ui.mx - rulerX - 10) / tl.zoom
        tl.currentTime = math.clamp(t, 0, tl.duration)
    end

    ui:pushClip(rulerX, by, rulerW, bh)

    -- Ruler background & ticks
    Theme.setColor(Theme.C.bgInput)
    render.drawRectFast(rulerX, rulerY, rulerW, stripH - 1)

    local originPX = rulerX + 10 - tl.scrollTime * tl.zoom
    local durPX = originPX + tl.duration * tl.zoom

    -- Active sequence span highlight
    local spanX1 = math.max(rulerX, originPX)
    local spanX2 = math.min(rulerX + rulerW, durPX)
    if spanX2 > spanX1 then
        Theme.setColor(Theme.C.bgPanel, 220)
        render.drawRectFast(spanX1, trackAreaY, spanX2 - spanX1, trackAreaH)
    end

    local secStep = tl.zoom < 45 and 2 or 1
    local subDiv = tl.zoom >= 110 and 4 or 2

    render.setFont(Theme.Fonts.Small)
    for sec = 0, math.ceil(tl.duration) do
        local sx = originPX + sec * tl.zoom
        if sx >= rulerX - 20 and sx <= rulerX + rulerW + 20 then
            if sec % secStep == 0 then
                Theme.setColor(Theme.C.borderLight)
                render.drawLine(sx, rulerY + 12, sx, rulerY + stripH - 2)
                Theme.setColor(Theme.C.textSecondary)
                render.drawSimpleText(sx + 3, rulerY + 4, string.format("%ds", sec), TEXT_ALIGN.LEFT, TEXT_ALIGN.TOP)

                -- Vertical guide line into track body
                Theme.setColor(Theme.C.border, 120)
                render.drawLine(sx, trackAreaY, sx, trackAreaY + trackAreaH)
            else
                Theme.setColor(Theme.C.border)
                render.drawLine(sx, rulerY + 18, sx, rulerY + stripH - 2)
            end

            if sec < tl.duration then
                for sub = 1, subDiv - 1 do
                    local subX = sx + (sub / subDiv) * tl.zoom
                    Theme.setColor(Theme.C.border, 150)
                    render.drawLine(subX, rulerY + 21, subX, rulerY + stripH - 2)
                end
            end
        end
    end

    -- End-of-sequence marker
    if durPX >= rulerX and durPX <= rulerX + rulerW then
        Theme.setColor(Theme.C.warning, 160)
        render.drawLine(durPX, rulerY, durPX, by + bh)
    end

    -- Playhead scrubber line + handle
    local playX = math.floor(originPX + tl.currentTime * tl.zoom)
    if playX >= rulerX and playX <= rulerX + rulerW then
        Theme.setColor(Theme.C.accent)
        render.drawLine(playX, rulerY + 4, playX, by + bh)
        render.drawRectFast(playX - 5, rulerY + 3, 11, 10)
        Theme.setColor(Theme.C.textPrimary)
        render.drawRectOutline(playX - 5, rulerY + 3, 11, 10, 1)
    end

    -- Track rows preview (mirrors current IR nodes)
    local selId = sceneGraph:getSelectedId()
    local rows = sceneGraph:getFlatHierarchy("")
    local rowY = trackAreaY + 4
    local rowH = 22
    for _, item in ipairs(rows) do
        if item.node.id ~= sceneGraph:getRootId() and rowY + rowH <= by + bh - 4 then
            local isSel = (item.node.id == selId)
            if isSel then
                Theme.setColor(Theme.C.accentSoft, 80)
                render.drawRectFast(rulerX, rowY, rulerW, rowH)
            end
            Theme.setColor(Theme.C.border, 90)
            render.drawLine(rulerX, rowY + rowH, rulerX + rulerW, rowY + rowH)
            rowY = rowY + rowH
        end
    end

    if trackAreaH >= 48 then
        render.setFont(Theme.Fonts.Small)
        Theme.setColor(Theme.C.textMuted)
        render.drawSimpleText(
            rulerX + 12,
            by + bh - 14,
            "Keyframe tracks, interpolation & easing curves arrive in Phase 8 (Ruler scrubbing is live).",
            TEXT_ALIGN.LEFT,
            TEXT_ALIGN.CENTER
        )
    end

    ui:popClip()

    -- Left track label list (clipped to headerColW)
    ui:pushClip(bx, trackAreaY, headerColW, trackAreaH)
    local lRowY = trackAreaY + 4
    for _, item in ipairs(rows) do
        if item.node.id ~= sceneGraph:getRootId() and lRowY + rowH <= by + bh - 4 then
            local isSel = (item.node.id == selId)
            if isSel then
                Theme.setColor(Theme.C.bgSelectionRow)
                render.drawRectFast(bx + 2, lRowY, headerColW - 4, rowH)
            end
            render.setFont(Theme.Fonts.Body)
            Theme.setColor(isSel and Theme.C.textPrimary or Theme.C.textSecondary)
            render.drawSimpleText(bx + 10, lRowY + rowH * 0.5, item.node.name, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)

            render.setFont(Theme.Fonts.Small)
            Theme.setColor(Theme.C.textMuted)
            render.drawSimpleText(bx + headerColW - 8, lRowY + rowH * 0.5, "No tracks (P8)", TEXT_ALIGN.RIGHT, TEXT_ALIGN.CENTER)

            Theme.setColor(Theme.C.border, 90)
            render.drawLine(bx, lRowY + rowH, bx + headerColW, lRowY + rowH)
            lRowY = lRowY + rowH
        end
    end
    ui:popClip()

    ui:popClip()
end

return Timeline
