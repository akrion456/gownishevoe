--@client
--[[
    SOLACE — Reusable Studio UI Widgets
    All widgets render via Theme + StarfallEx fast 2D primitives and return direct interaction state.
]]

local Theme = require("./theme.lua")

local Widgets = {}

function Widgets.panelFrame(x, y, w, h, title, rightText)
    Theme.setColor(Theme.C.bgPanel)
    render.drawRectFast(x, y, w, h)

    Theme.setColor(Theme.C.border)
    render.drawRectOutline(x, y, w, h, 1)

    local hh = Theme.Metrics.headerH
    Theme.setColor(Theme.C.bgHeader)
    render.drawRectFast(x + 1, y + 1, w - 2, hh - 1)

    Theme.setColor(Theme.C.border)
    render.drawLine(x + 1, y + hh, x + w - 1, y + hh)

    render.setFont(Theme.Fonts.Header)
    Theme.setColor(Theme.C.textPrimary)
    render.drawSimpleText(x + 10, y + hh * 0.5, title, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)

    if rightText and rightText ~= "" then
        render.setFont(Theme.Fonts.Small)
        Theme.setColor(Theme.C.textMuted)
        render.drawSimpleText(x + w - 10, y + hh * 0.5, rightText, TEXT_ALIGN.RIGHT, TEXT_ALIGN.CENTER)
    end

    return x + 1, y + hh + 1, math.max(0, w - 2), math.max(0, h - hh - 2)
end

function Widgets.button(ui, id, x, y, w, h, label, opts)
    opts = opts or {}
    local disabled = opts.disabled == true
    local active = opts.active == true
    local hot, captured = ui:hitTest(id, x, y, w, h)

    if hot and opts.tooltip then
        ui:setTooltip(opts.tooltip)
    end

    local clicked = false
    if not disabled and hot and ui.leftPressed then
        ui:capture(id)
    end
    if not disabled and captured and ui.leftReleased and hot then
        clicked = true
    end

    -- Background
    if disabled then
        Theme.setColor(Theme.C.bgPanelAlt, 180)
    elseif active then
        Theme.setColor(Theme.C.accentSoft)
    elseif captured and hot then
        Theme.setColor(Theme.C.bgControlPress)
    elseif hot then
        Theme.setColor(Theme.C.bgControlHover)
    else
        Theme.setColor(opts.subtle and Theme.C.bgPanel or Theme.C.bgControl)
    end
    render.drawRectFast(x, y, w, h)

    -- Border
    if active then
        Theme.setColor(Theme.C.accent)
    elseif hot and not disabled then
        Theme.setColor(Theme.C.borderLight)
    else
        Theme.setColor(Theme.C.border, disabled and 120 or 255)
    end
    render.drawRectOutline(x, y, w, h, 1)

    local textColor = disabled and Theme.C.textDisabled
        or (active and Theme.C.accentBright or Theme.C.textPrimary)

    local cursorX = x + 8
    if opts.icon then
        local iconSize = math.min(14, h - 6)
        local ix = (label == nil or label == "") and (x + (w - iconSize) * 0.5) or cursorX
        local iy = y + (h - iconSize) * 0.5
        Theme.drawIcon(opts.icon, ix, iy, iconSize, textColor)
        cursorX = cursorX + iconSize + 6
    end

    if label and label ~= "" then
        render.setFont(opts.font or Theme.Fonts.Body)
        Theme.setColor(textColor)
        if opts.icon then
            render.drawSimpleText(cursorX, y + h * 0.5, label, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)
        else
            render.drawSimpleText(x + w * 0.5, y + h * 0.5, label, TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)
        end
    end

    if opts.badge and opts.badge ~= "" then
        render.setFont(Theme.Fonts.Small)
        local bw = 20
        local bh = 13
        local bx = x + w - bw - 3
        local by = y + 3
        Theme.setColor(Theme.C.bgBadgePhase)
        render.drawRectFast(bx, by, bw, bh)
        Theme.setColor(Theme.C.textMuted)
        render.drawSimpleText(bx + bw * 0.5, by + bh * 0.5, opts.badge, TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)
    end

    return clicked
end

function Widgets.stepper(ui, id, x, y, w, h, label, valueText, tooltip)
    local labelW = math.floor(w * 0.48)
    local ctrlX = x + labelW
    local ctrlW = w - labelW
    local btnW = 20

    render.setFont(Theme.Fonts.Body)
    Theme.setColor(Theme.C.textSecondary)
    render.drawSimpleText(x, y + h * 0.5, label, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)

    if tooltip and ui:pointInRect(x, y, labelW, h) and ui:isMouseInClip() then
        ui:setTooltip(tooltip)
    end

    local prevClicked = Widgets.button(ui, id .. "_prev", ctrlX, y, btnW, h, "<", { tooltip = tooltip })
    local nextClicked = Widgets.button(ui, id .. "_next", ctrlX + ctrlW - btnW, y, btnW, h, ">", { tooltip = tooltip })

    local midX = ctrlX + btnW
    local midW = math.max(0, ctrlW - btnW * 2)
    Theme.setColor(Theme.C.bgInput)
    render.drawRectFast(midX, y, midW, h)
    Theme.setColor(Theme.C.border)
    render.drawRectOutline(midX, y, midW, h, 1)

    render.setFont(Theme.Fonts.Mono)
    Theme.setColor(Theme.C.textPrimary)
    render.drawSimpleText(midX + midW * 0.5, y + h * 0.5, tostring(valueText), TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)

    return prevClicked, nextClicked
end

function Widgets.slider(ui, id, x, y, w, h, label, value, minVal, maxVal, step, fmt, tooltip)
    local labelW = math.floor(w * 0.48)
    local trackX = x + labelW
    local trackW = math.max(40, w - labelW)

    render.setFont(Theme.Fonts.Body)
    Theme.setColor(Theme.C.textSecondary)
    render.drawSimpleText(x, y + h * 0.5, label, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)

    local hot, captured = ui:hitTest(id, trackX, y, trackW, h)
    if (hot or (ui:pointInRect(x, y, labelW, h) and ui:isMouseInClip())) and tooltip then
        ui:setTooltip(tooltip)
    end

    local newVal = value
    local changed = false
    if hot and ui.leftPressed then
        ui:capture(id)
    end
    if captured and ui.leftDown then
        local frac = math.clamp((ui.mx - trackX) / trackW, 0, 1)
        local raw = minVal + (maxVal - minVal) * frac
        if step and step > 0 then
            raw = math.round(raw / step) * step
        end
        raw = math.clamp(raw, minVal, maxVal)
        if math.abs(raw - value) > 1e-6 then
            newVal = raw
            changed = true
        end
    end

    -- Track background
    Theme.setColor(Theme.C.bgInput)
    render.drawRectFast(trackX, y, trackW, h)

    local frac = math.clamp((newVal - minVal) / math.max(1e-6, maxVal - minVal), 0, 1)
    local fillW = math.floor((trackW - 2) * frac)
    Theme.setColor(captured and Theme.C.accent or (hot and Theme.C.bgSelection or Theme.C.accentSoft), captured and 140 or 180)
    render.drawRectFast(trackX + 1, y + 1, fillW, h - 2)

    Theme.setColor((hot or captured) and Theme.C.borderFocus or Theme.C.border)
    render.drawRectOutline(trackX, y, trackW, h, 1)

    render.setFont(Theme.Fonts.Mono)
    Theme.setColor(Theme.C.textPrimary)
    render.drawSimpleText(trackX + trackW * 0.5, y + h * 0.5, string.format(fmt or "%.0f", newVal), TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)

    return newVal, changed
end

function Widgets.textBox(ui, id, x, y, w, h, getter, setter, placeholder, tooltip)
    ui:registerTextInput(id, getter, setter)
    local val = getter() or ""
    local focused = (ui.focusedInputId == id)
    local clearW = (#val > 0) and 20 or 0
    local hot, _ = ui:hitTest(id, x, y, w - clearW, h)

    if hot and tooltip then
        ui:setTooltip(tooltip)
    end
    if hot and ui.leftPressed then
        ui:focusTextInput(id)
    end

    Theme.setColor(Theme.C.bgInput)
    render.drawRectFast(x, y, w, h)
    Theme.setColor(focused and Theme.C.borderFocus or (hot and Theme.C.borderLight or Theme.C.border))
    render.drawRectOutline(x, y, w, h, 1)

    Theme.drawIcon("search", x + 6, y + (h - 12) * 0.5, 12, focused and Theme.C.accentBright or Theme.C.textMuted)

    ui:pushClip(x + 22, y + 1, math.max(0, w - 26 - clearW), h - 2)
    render.setFont(Theme.Fonts.Body)
    if #val > 0 then
        Theme.setColor(Theme.C.textPrimary)
        render.drawSimpleText(x + 24, y + h * 0.5, val, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)
        if focused and (math.floor(ui._frameTime * 2) % 2 == 0) then
            local tw = render.getTextSize(val)
            Theme.setColor(Theme.C.accentBright)
            render.drawLine(x + 25 + tw, y + 4, x + 25 + tw, y + h - 4)
        end
    else
        Theme.setColor(Theme.C.textMuted)
        render.drawSimpleText(x + 24, y + h * 0.5, placeholder or "Search...", TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)
        if focused and (math.floor(ui._frameTime * 2) % 2 == 0) then
            Theme.setColor(Theme.C.accentBright)
            render.drawLine(x + 25, y + 4, x + 25, y + h - 4)
        end
    end
    ui:popClip()

    if clearW > 0 then
        if Widgets.button(ui, id .. "_clr", x + w - clearW, y, clearW, h, "x", { subtle = true, tooltip = "Clear search" }) then
            setter("")
        end
    end
end

function Widgets.sectionHeader(ui, id, x, y, w, h, title, isOpen)
    local hot, captured = ui:hitTest(id, x, y, w, h)
    local toggled = false
    if hot and ui.leftPressed then ui:capture(id) end
    if captured and ui.leftReleased and hot then toggled = true end

    Theme.setColor(hot and Theme.C.bgControlHover or Theme.C.bgHeader)
    render.drawRectFast(x, y, w, h)
    Theme.setColor(Theme.C.border)
    render.drawLine(x, y + h - 1, x + w, y + h - 1)

    Theme.drawIcon(isOpen and "chevronDown" or "chevronRight", x + 6, y + (h - 12) * 0.5, 12, Theme.C.textSecondary)

    render.setFont(Theme.Fonts.BodyBold)
    Theme.setColor(Theme.C.textPrimary)
    render.drawSimpleText(x + 22, y + h * 0.5, title, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)

    if toggled then
        return not isOpen
    end
    return isOpen
end

function Widgets.keyValueRow(x, y, w, h, keyText, valText, valColor)
    render.setFont(Theme.Fonts.Body)
    Theme.setColor(Theme.C.textSecondary)
    render.drawSimpleText(x, y + h * 0.5, keyText, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)

    render.setFont(Theme.Fonts.Mono)
    Theme.setColor(valColor or Theme.C.textPrimary)
    render.drawSimpleText(x + w, y + h * 0.5, tostring(valText), TEXT_ALIGN.RIGHT, TEXT_ALIGN.CENTER)
end

function Widgets.phaseNotice(x, y, w, title, bodyLines, phaseBadge)
    local lineH = 15
    local h = 34 + #bodyLines * lineH
    Theme.setColor(Theme.C.bgPanelAlt)
    render.drawRectFast(x, y, w, h)
    Theme.setColor(Theme.C.border)
    render.drawRectOutline(x, y, w, h, 1)

    render.setFont(Theme.Fonts.BodyBold)
    Theme.setColor(Theme.C.textPrimary)
    render.drawSimpleText(x + 10, y + 13, title, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)

    if phaseBadge then
        render.setFont(Theme.Fonts.Small)
        Theme.setColor(Theme.C.accentBright)
        render.drawSimpleText(x + w - 10, y + 13, phaseBadge, TEXT_ALIGN.RIGHT, TEXT_ALIGN.CENTER)
    end

    render.setFont(Theme.Fonts.Small)
    Theme.setColor(Theme.C.textMuted)
    for i, line in ipairs(bodyLines) do
        render.drawSimpleText(x + 10, y + 26 + (i - 1) * lineH, line, TEXT_ALIGN.LEFT, TEXT_ALIGN.TOP)
    end
    return h
end

return Widgets
