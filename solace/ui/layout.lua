--@client
--[[
    SOLACE — Resizable Dock Layout & Splitters
    Computes responsive 6-zone workspace geometry and handles interactive splitter dragging.
]]

local Constants = require("../core/constants.lua")
local Theme = require("./theme.lua")

local Layout = {}
Layout.__index = Layout

function Layout.new(state)
    local d = Constants.LAYOUT_DEFAULTS
    return setmetatable({
        state = state,
        toolbarH = d.toolbarHeight,
        leftW = d.leftWidth,
        rightW = d.rightWidth,
        bottomH = d.bottomHeight,
        explorerRatio = d.explorerRatio,
        rects = {
            toolbar = { x = 0, y = 0, w = 0, h = 0 },
            toolbox = { x = 0, y = 0, w = 0, h = 0 },
            viewport = { x = 0, y = 0, w = 0, h = 0 },
            explorer = { x = 0, y = 0, w = 0, h = 0 },
            properties = { x = 0, y = 0, w = 0, h = 0 },
            timeline = { x = 0, y = 0, w = 0, h = 0 },
        },
        _splitters = {},
    }, Layout)
end

function Layout:reset()
    local d = Constants.LAYOUT_DEFAULTS
    self.leftW = d.leftWidth
    self.rightW = d.rightWidth
    self.bottomH = d.bottomHeight
    self.explorerRatio = d.explorerRatio
end

function Layout:compute(scrW, scrH)
    local d = Constants.LAYOUT_DEFAULTS
    local sp = d.splitterSize
    local panels = self.state.panels

    local showLeft = panels.toolbox
    local showRight = panels.explorer or panels.properties
    local showBottom = panels.timeline

    local topY = self.toolbarH
    local availH = math.max(200, scrH - topY)

    -- Clamp bottom timeline height
    local activeBottomH = 0
    if showBottom then
        local maxB = math.min(d.maxBottomHeight, availH - d.minViewportHeight - sp)
        self.bottomH = math.clamp(self.bottomH, d.minBottomHeight, math.max(d.minBottomHeight, maxB))
        activeBottomH = self.bottomH
    end

    local middleH = availH - (showBottom and (activeBottomH + sp) or 0)

    -- Clamp left & right widths while preserving minimum center viewport width
    local activeLeftW = showLeft and math.clamp(self.leftW, d.minLeftWidth, d.maxLeftWidth) or 0
    local activeRightW = showRight and math.clamp(self.rightW, d.minRightWidth, d.maxRightWidth) or 0

    local neededNonViewport = (showLeft and (activeLeftW + sp) or 0) + (showRight and (activeRightW + sp) or 0)
    if scrW - neededNonViewport < d.minViewportWidth then
        local maxCombined = math.max(0, scrW - d.minViewportWidth - (showLeft and sp or 0) - (showRight and sp or 0))
        if showLeft and showRight then
            local ratio = activeLeftW / math.max(1, activeLeftW + activeRightW)
            activeLeftW = math.floor(maxCombined * ratio)
            activeRightW = maxCombined - activeLeftW
        elseif showLeft then
            activeLeftW = maxCombined
        elseif showRight then
            activeRightW = maxCombined
        end
    end

    self.leftW = showLeft and activeLeftW or self.leftW
    self.rightW = showRight and activeRightW or self.rightW

    local r = self.rects
    r.toolbar = { x = 0, y = 0, w = scrW, h = self.toolbarH }

    local curX = 0
    if showLeft then
        r.toolbox = { x = 0, y = topY, w = activeLeftW, h = middleH }
        curX = activeLeftW + sp
    else
        r.toolbox = { x = 0, y = 0, w = 0, h = 0 }
    end

    local vpW = scrW - curX - (showRight and (activeRightW + sp) or 0)
    r.viewport = { x = curX, y = topY, w = math.max(0, vpW), h = middleH }

    local rightX = curX + r.viewport.w + (showRight and sp or 0)
    if panels.explorer and panels.properties then
        local expH = math.floor((middleH - sp) * math.clamp(self.explorerRatio, d.minExplorerRatio, d.maxExplorerRatio))
        local propY = topY + expH + sp
        r.explorer = { x = rightX, y = topY, w = activeRightW, h = expH }
        r.properties = { x = rightX, y = propY, w = activeRightW, h = math.max(0, middleH - expH - sp) }
    elseif panels.explorer then
        r.explorer = { x = rightX, y = topY, w = activeRightW, h = middleH }
        r.properties = { x = 0, y = 0, w = 0, h = 0 }
    elseif panels.properties then
        r.explorer = { x = 0, y = 0, w = 0, h = 0 }
        r.properties = { x = rightX, y = topY, w = activeRightW, h = middleH }
    else
        r.explorer = { x = 0, y = 0, w = 0, h = 0 }
        r.properties = { x = 0, y = 0, w = 0, h = 0 }
    end

    if showBottom then
        r.timeline = { x = 0, y = topY + middleH + sp, w = scrW, h = activeBottomH }
    else
        r.timeline = { x = 0, y = 0, w = 0, h = 0 }
    end

    -- Build active splitter hitboxes
    self._splitters = {}
    if showLeft then
        self._splitters[#self._splitters + 1] = {
            id = "split_left",
            axis = "x",
            x = r.toolbox.w,
            y = topY,
            w = sp,
            h = middleH,
        }
    end
    if showRight then
        self._splitters[#self._splitters + 1] = {
            id = "split_right",
            axis = "x",
            x = r.viewport.x + r.viewport.w,
            y = topY,
            w = sp,
            h = middleH,
        }
    end
    if panels.explorer and panels.properties then
        self._splitters[#self._splitters + 1] = {
            id = "split_right_y",
            axis = "y",
            x = rightX,
            y = r.explorer.y + r.explorer.h,
            w = activeRightW,
            h = sp,
            parentTop = topY,
            parentH = middleH - sp,
        }
    end
    if showBottom then
        self._splitters[#self._splitters + 1] = {
            id = "split_bottom",
            axis = "y",
            x = 0,
            y = topY + middleH,
            w = scrW,
            h = sp,
        }
    end
end

function Layout:updateAndDrawSplitters(ui)
    local d = Constants.LAYOUT_DEFAULTS
    for _, s in ipairs(self._splitters) do
        local hot, captured = ui:hitTest(s.id, s.x - 1, s.y - 1, s.w + 2, s.h + 2)
        if hot then
            ui:setTooltip("Drag to resize panel")
        end
        if hot and ui.leftPressed then
            ui:capture(s.id)
        end

        if captured and ui.leftDown then
            if s.id == "split_left" then
                self.leftW = math.clamp(ui.mx, d.minLeftWidth, d.maxLeftWidth)
            elseif s.id == "split_right" then
                self.rightW = math.clamp(ui.scrW - ui.mx, d.minRightWidth, d.maxRightWidth)
            elseif s.id == "split_bottom" then
                self.bottomH = math.clamp(ui.scrH - ui.my, d.minBottomHeight, d.maxBottomHeight)
            elseif s.id == "split_right_y" then
                local frac = (ui.my - s.parentTop) / math.max(1, s.parentH)
                self.explorerRatio = math.clamp(frac, d.minExplorerRatio, d.maxExplorerRatio)
            end
        end

        Theme.setColor((hot or captured) and Theme.C.splitterHover or Theme.C.splitter)
        render.drawRectFast(s.x, s.y, s.w, s.h)

        -- Subtle grip indicator
        Theme.setColor((hot or captured) and Theme.C.textPrimary or Theme.C.borderLight)
        if s.axis == "x" then
            local cy = s.y + s.h * 0.5
            render.drawRectFast(s.x + 1, cy - 12, s.w - 2, 24)
        else
            local cx = s.x + s.w * 0.5
            render.drawRectFast(cx - 14, s.y + 1, 28, s.h - 2)
        end
    end
end

return Layout
