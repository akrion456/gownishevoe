--@client
--[[
    SOLACE — Top Studio Toolbar
    Contains active Phase 1/2 tools (Select, Focus, Quick Spawn, Grid/Axes/Stats, Panels)
    and clearly badged upcoming tools.
]]

local Constants = require("../../core/constants.lua")
local Theme = require("../theme.lua")
local Widgets = require("../widgets.lua")

local Toolbar = {}

function Toolbar.draw(ui, state, layout, rect, actions)
    local x, y, w, h = rect.x, rect.y, rect.w, rect.h
    if w < 100 or h <= 0 then return end

    Theme.setColor(Theme.C.bgToolbar)
    render.drawRectFast(x, y, w, h)
    Theme.setColor(Theme.C.border)
    render.drawLine(x, y + h - 1, x + w, y + h - 1)

    ui:pushClip(x, y, w, h)

    local cx = x + 10
    local btnH = 26
    local by = y + math.floor((h - btnH) * 0.5)

    -- Brand identity badge
    render.setFont(Theme.Fonts.Title)
    Theme.setColor(Theme.C.accentBright)
    render.drawSimpleText(cx, y + h * 0.5, Constants.APP_NAME, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)
    local nw = render.getTextSize(Constants.APP_NAME)
    cx = cx + nw + 8

    render.setFont(Theme.Fonts.Small)
    Theme.setColor(Theme.C.textMuted)
    render.drawSimpleText(cx, y + h * 0.5, "P2", TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)
    cx = cx + 22

    Theme.setColor(Theme.C.border)
    render.drawLine(cx, y + 7, cx, y + h - 7)
    cx = cx + 8

    -- Tool buttons
    for _, tool in ipairs(Constants.TOOLS) do
        local tw = tool.ready and 72 or 84
        if cx + tw > x + w - 260 then break end
        local clicked = Widgets.button(ui, "tb_tool_" .. tool.id, cx, by, tw, btnH, tool.label, {
            icon = tool.icon,
            active = tool.ready and (state.activeTool == tool.id),
            disabled = not tool.ready,
            badge = (not tool.ready) and ("P" .. tool.phase) or nil,
            tooltip = tool.desc,
        })
        if clicked and tool.ready then
            state.activeTool = tool.id
        end
        cx = cx + tw + 4
    end

    Theme.setColor(Theme.C.border)
    render.drawLine(cx + 2, y + 7, cx + 2, y + h - 7)
    cx = cx + 10

    -- Phase 2 Quick Actions: Focus Selected & Quick Spawn Cube
    if cx + 70 < x + w - 280 then
        if Widgets.button(ui, "tb_focus", cx, by, 68, btnH, "Focus", {
            icon = "camera",
            disabled = not actions.hasSelection,
            tooltip = "Focus Freecam on Selected Object (Hotkey: F)",
        }) then
            actions.focusSelected()
        end
        cx = cx + 72
    end

    if cx + 74 < x + w - 280 then
        if Widgets.button(ui, "tb_spawn_cube", cx, by, 72, btnH, "+Cube", {
            icon = "cube",
            tooltip = "Spawn Cube Hologram in front of Freecam",
        }) then
            actions.spawnQuickModel("Cube", "models/hunter/blocks/cube1x1x1.mdl")
        end
        cx = cx + 76
    end

    -- Viewport Toggles
    if cx + 66 < x + w - 280 then
        if Widgets.button(ui, "tb_grid", cx, by, 62, btnH, "Grid", {
            icon = "grid",
            active = state.grid.enabled,
            tooltip = "Toggle 3D Ground Grid (G)",
        }) then
            state.grid.enabled = not state.grid.enabled
        end
        cx = cx + 66
    end

    if cx + 66 < x + w - 280 then
        if Widgets.button(ui, "tb_axes", cx, by, 62, btnH, "Axes", {
            icon = "axes",
            active = state.grid.showAxes,
            tooltip = "Toggle 3D Origin Axes",
        }) then
            state.grid.showAxes = not state.grid.showAxes
        end
        cx = cx + 66
    end

    if cx + 68 < x + w - 280 then
        if Widgets.button(ui, "tb_stats", cx, by, 64, btnH, "Stats", {
            icon = "scene",
            active = state.grid.showTelemetry,
            tooltip = "Toggle Viewport Telemetry HUD",
        }) then
            state.grid.showTelemetry = not state.grid.showTelemetry
        end
        cx = cx + 68
    end

    -- Upcoming Transport / History / Project buttons
    local upcoming = {
        { id = "undo",   icon = "undo",   w = 30, tip = "Undo — Arriving in Phase 3" },
        { id = "redo",   icon = "redo",   w = 30, tip = "Redo — Arriving in Phase 3" },
        { id = "save",   icon = "save",   w = 56, label = "Save",   tip = "Save Project — Arriving in Phase 12" },
        { id = "export", icon = "export", w = 68, label = "Export", tip = "Export StarfallEx Lua — Arriving in Phase 13" },
    }
    if cx + 195 < x + w - 290 then
        Theme.setColor(Theme.C.border)
        render.drawLine(cx + 2, y + 7, cx + 2, y + h - 7)
        cx = cx + 10
        for _, item in ipairs(upcoming) do
            if cx + item.w > x + w - 290 then break end
            Widgets.button(ui, "tb_" .. item.id, cx, by, item.w, btnH, item.label, {
                icon = item.icon,
                disabled = true,
                tooltip = item.tip,
            })
            cx = cx + item.w + 4
        end
    end

    -- Right-aligned working panel toggles, Reset Layout & Hide Studio (F6)
    local rx = x + w - 10

    local hideW = 78
    rx = rx - hideW
    if Widgets.button(ui, "tb_hide", rx, by, hideW, btnH, "Hide F6", {
        icon = "hide",
        tooltip = "Minimize SOLACE Studio and restore gameplay camera/cursor (Press F6 to reopen)",
    }) then
        actions.toggleStudio(false)
    end
    rx = rx - 6

    local resetW = 54
    rx = rx - resetW
    if Widgets.button(ui, "tb_reset_layout", rx, by, resetW, btnH, "Reset", {
        icon = "reset",
        tooltip = "Reset all dock panel sizes to default",
    }) then
        layout:reset()
    end
    rx = rx - 8

    local panelDefs = {
        { key = "timeline",   label = "TL",   tip = "Toggle Timeline Panel" },
        { key = "properties", label = "Prop", tip = "Toggle Properties Panel" },
        { key = "explorer",   label = "Exp",  tip = "Toggle Explorer Panel" },
        { key = "toolbox",    label = "Box",  tip = "Toggle Toolbox Panel" },
    }
    for _, p in ipairs(panelDefs) do
        local pw = 40
        rx = rx - pw
        if rx > cx + 8 then
            if Widgets.button(ui, "tb_panel_" .. p.key, rx, by, pw, btnH, p.label, {
                active = state.panels[p.key],
                tooltip = p.tip,
            }) then
                state.panels[p.key] = not state.panels[p.key]
            end
        end
        rx = rx - 3
    end

    ui:popClip()
end

return Toolbar
