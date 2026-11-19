--@client
--[[
    SOLACE — Studio Theme, Typography & Procedural Vector Icons
    Cohesive dark desktop-3D application palette and StarfallEx font registry.
]]

local Theme = {}

-- Colors stored as {r, g, b, a} arrays so render.setRGBA can be called with zero allocations
Theme.C = {
    -- Surfaces (layered dark slate hierarchy)
    bgApp          = { 17, 19, 24, 248 },
    bgPanel        = { 22, 25, 31, 245 },
    bgPanelAlt     = { 27, 30, 38, 255 },
    bgHeader       = { 29, 33, 42, 255 },
    bgToolbar      = { 20, 23, 29, 250 },
    bgInput        = { 15, 17, 22, 255 },
    bgControl      = { 36, 40, 50, 255 },
    bgControlHover = { 46, 52, 65, 255 },
    bgControlPress = { 30, 34, 43, 255 },
    bgSelection    = { 43, 92, 176, 110 },
    bgSelectionRow = { 38, 79, 148, 95 },
    bgBadgePhase   = { 42, 46, 58, 220 },

    -- Borders & dividers
    border         = { 44, 49, 60, 255 },
    borderLight    = { 62, 69, 84, 255 },
    borderFocus    = { 66, 135, 245, 255 },
    splitter       = { 32, 36, 45, 255 },
    splitterHover  = { 66, 135, 245, 220 },

    -- Text hierarchy
    textPrimary    = { 232, 236, 244, 255 },
    textSecondary  = { 164, 172, 188, 255 },
    textMuted      = { 108, 116, 132, 255 },
    textDisabled   = { 80, 86, 100, 255 },

    -- Brand & semantic accents
    accent         = { 59, 130, 246, 255 },
    accentSoft     = { 59, 130, 246, 42 },
    accentBright   = { 96, 165, 250, 255 },
    success        = { 34, 197, 94, 255 },
    warning        = { 245, 158, 11, 255 },
    danger         = { 239, 68, 68, 255 },

    -- 3D Coordinate axes
    axisX          = { 239, 68, 68, 255 },
    axisY          = { 34, 197, 94, 255 },
    axisZ          = { 59, 130, 246, 255 },

    -- Viewport grid & overlays
    gridMinor      = { 110, 122, 145, 55 },
    gridMajor      = { 150, 165, 195, 115 },
    hudPill        = { 16, 18, 24, 215 },
    tooltipBg      = { 14, 16, 21, 245 },
}

Theme.Metrics = {
    pad = 8,
    padSm = 4,
    padLg = 12,
    headerH = 26,
    rowH = 22,
    controlH = 22,
    radius = 3,
}

Theme.Fonts = {}

function Theme.initFonts()
    if Theme._fontsReady then return end
    Theme._fontsReady = true

    -- Budget: 6 fonts total (StarfallEx sf_render_maxfonts default is 30)
    Theme.Fonts.Title    = render.createFont("Tahoma", 15, 700, true)
    Theme.Fonts.Header   = render.createFont("Tahoma", 13, 600, true)
    Theme.Fonts.Body     = render.createFont("Tahoma", 13, 400, true)
    Theme.Fonts.BodyBold = render.createFont("Tahoma", 13, 600, true)
    Theme.Fonts.Small    = render.createFont("Tahoma", 11, 500, true)
    Theme.Fonts.Mono     = render.createFont("DejaVu Sans Mono", 12, 400, true)
end

function Theme.setColor(c, alphaOverride)
    render.setRGBA(c[1], c[2], c[3], alphaOverride or c[4] or 255)
end

-- Crisp procedural vector icons drawn with StarfallEx render primitives
function Theme.drawIcon(name, x, y, size, c, alphaOverride)
    Theme.setColor(c or Theme.C.textSecondary, alphaOverride)
    local cx = x + size * 0.5
    local cy = y + size * 0.5
    local r = size * 0.36

    if name == "cursor" then
        -- Clean pointer arrow
        render.drawLine(x + 3, y + 2, x + 3, y + size - 3)
        render.drawLine(x + 3, y + 2, x + size - 3, cy + 1)
        render.drawLine(x + size - 3, cy + 1, cx + 1, cy + 2)
        render.drawLine(cx + 1, cy + 2, x + 3, y + size - 3)
    elseif name == "move" then
        -- 4-way arrows
        render.drawLine(cx, y + 2, cx, y + size - 2)
        render.drawLine(x + 2, cy, x + size - 2, cy)
        render.drawLine(cx - 2, y + 4, cx, y + 2)
        render.drawLine(cx + 2, y + 4, cx, y + 2)
        render.drawLine(cx - 2, y + size - 4, cx, y + size - 2)
        render.drawLine(cx + 2, y + size - 4, cx, y + size - 2)
        render.drawLine(x + 4, cy - 2, x + 2, cy)
        render.drawLine(x + 4, cy + 2, x + 2, cy)
        render.drawLine(x + size - 4, cy - 2, x + size - 2, cy)
        render.drawLine(x + size - 4, cy + 2, x + size - 2, cy)
    elseif name == "rotate" then
        render.drawCircle(cx, cy, r)
        render.drawLine(cx + r - 2, cy - 2, cx + r + 1, cy + 1)
    elseif name == "scale" then
        render.drawRectOutline(x + 2, y + 2, size - 4, size - 4, 1)
        render.drawRectFast(x + size - 6, y + 2, 4, 4)
        render.drawLine(cx - 2, cy + 2, x + size - 5, y + 5)
    elseif name == "pivot" then
        render.drawCircle(cx, cy, r * 0.7)
        render.drawLine(cx, y + 2, cx, y + size - 2)
        render.drawLine(x + 2, cy, x + size - 2, cy)
    elseif name == "grid" then
        local x0, y0 = x + 2, y + 2
        local s = size - 4
        render.drawRectOutline(x0, y0, s, s, 1)
        render.drawLine(x0 + s * 0.5, y0, x0 + s * 0.5, y0 + s)
        render.drawLine(x0, y0 + s * 0.5, x0 + s, y0 + s * 0.5)
    elseif name == "axes" then
        render.drawLine(x + 3, y + size - 3, x + 3, y + 3)
        render.drawLine(x + 3, y + size - 3, x + size - 3, y + size - 3)
        render.drawLine(x + 3, y + size - 3, cx + 3, cy - 3)
    elseif name == "cube" or name == "holo" then
        render.drawRectOutline(x + 3, y + 4, size - 7, size - 7, 1)
        render.drawLine(x + 3, y + 4, x + 6, y + 2)
        render.drawLine(x + size - 4, y + 4, x + size - 1, y + 2)
        render.drawLine(x + 6, y + 2, x + size - 1, y + 2)
        render.drawLine(x + size - 1, y + 2, x + size - 1, y + size - 5)
        render.drawLine(x + size - 4, y + size - 3, x + size - 1, y + size - 5)
    elseif name == "camera" then
        render.drawRectOutline(x + 2, y + 4, size - 7, size - 8, 1)
        render.drawLine(x + size - 5, cy - 2, x + size - 2, cy - 4)
        render.drawLine(x + size - 5, cy + 2, x + size - 2, cy + 4)
        render.drawLine(x + size - 2, cy - 4, x + size - 2, cy + 4)
    elseif name == "play" then
        render.drawLine(x + 4, y + 3, x + size - 3, cy)
        render.drawLine(x + size - 3, cy, x + 4, y + size - 3)
        render.drawLine(x + 4, y + 3, x + 4, y + size - 3)
    elseif name == "pause" then
        render.drawRectFast(x + 4, y + 3, 2, size - 6)
        render.drawRectFast(x + size - 6, y + 3, 2, size - 6)
    elseif name == "stop" then
        render.drawRectFast(x + 4, y + 4, size - 8, size - 8)
    elseif name == "undo" then
        render.drawLine(x + 3, cy, x + size - 3, cy)
        render.drawLine(x + 3, cy, x + 7, cy - 3)
        render.drawLine(x + 3, cy, x + 7, cy + 3)
    elseif name == "redo" then
        render.drawLine(x + 3, cy, x + size - 3, cy)
        render.drawLine(x + size - 3, cy, x + size - 7, cy - 3)
        render.drawLine(x + size - 3, cy, x + size - 7, cy + 3)
    elseif name == "save" then
        render.drawRectOutline(x + 3, y + 3, size - 6, size - 6, 1)
        render.drawRectFast(x + 5, y + 3, size - 10, 4)
        render.drawRectFast(x + 5, y + size - 7, size - 10, 4)
    elseif name == "export" then
        render.drawRectOutline(x + 3, y + 6, size - 6, size - 9, 1)
        render.drawLine(cx, y + 2, cx, cy + 1)
        render.drawLine(cx - 3, y + 5, cx, y + 2)
        render.drawLine(cx + 3, y + 5, cx, y + 2)
    elseif name == "search" then
        render.drawCircle(cx - 1, cy - 1, r * 0.72)
        render.drawLine(cx + 2, cy + 2, x + size - 3, y + size - 3)
    elseif name == "layers" or name == "scene" then
        render.drawRectOutline(x + 3, y + 3, size - 6, 4, 1)
        render.drawLine(x + 3, cy + 1, x + size - 3, cy + 1)
        render.drawLine(x + 3, y + size - 4, x + size - 3, y + size - 4)
    elseif name == "sparkle" or name == "burst" then
        render.drawLine(cx, y + 2, cx, y + size - 2)
        render.drawLine(x + 2, cy, x + size - 2, cy)
        render.drawLine(x + 4, y + 4, x + size - 4, y + size - 4)
        render.drawLine(x + size - 4, y + 4, x + 4, y + size - 4)
    elseif name == "stamp" then
        render.drawCircle(cx, cy, r)
        render.drawFilledCircle(cx, cy, 2)
    elseif name == "eye" then
        render.drawCircle(cx, cy, r * 0.75)
        render.drawFilledCircle(cx, cy, 2)
    elseif name == "reset" then
        render.drawRectOutline(x + 3, y + 3, size - 6, size - 6, 1)
        render.drawLine(x + 3, cy, x + size - 3, cy)
        render.drawLine(cx, y + 3, cx, y + size - 3)
    elseif name == "hide" then
        render.drawLine(x + 3, y + 3, x + size - 3, y + size - 3)
        render.drawLine(x + size - 3, y + 3, x + 3, y + size - 3)
    elseif name == "chevronDown" then
        render.drawLine(cx - 3, cy - 1, cx, cy + 2)
        render.drawLine(cx + 3, cy - 1, cx, cy + 2)
    elseif name == "chevronRight" then
        render.drawLine(cx - 1, cy - 3, cx + 2, cy)
        render.drawLine(cx - 1, cy + 3, cx + 2, cy)
    else
        render.drawRectOutline(x + 3, y + 3, size - 6, size - 6, 1)
    end
end

return Theme
