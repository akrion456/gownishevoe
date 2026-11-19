--@client
--[[
    SOLACE — Retained-Mode UI Manager
    Handles mouse state, drag capture, scissor clipping stack, keyboard text input,
    bind blocking, and floating tooltips.
]]

local Theme = require("./theme.lua")

local UIManager = {}
UIManager.__index = UIManager

-- Lookup table for printable key mapping (avoiding per-key allocations)
local KEY_CHAR_MAP = {}
local SHIFT_MAP = {
    ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
    ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")",
    ["-"] = "_", ["="] = "+", ["["] = "{", ["]"] = "}", ["\\"] = "|",
    [";"] = ":", ["'"] = "\"", [","] = "<", ["."] = ">", ["/"] = "?",
    ["`"] = "~",
}

local function buildKeyMap()
    local letters = {
        "A","B","C","D","E","F","G","H","I","J","K","L","M",
        "N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
    }
    for _, ch in ipairs(letters) do
        if KEY[ch] then KEY_CHAR_MAP[KEY[ch]] = string.lower(ch) end
    end
    for i = 0, 9 do
        local s = tostring(i)
        if KEY["KEY" .. s] then KEY_CHAR_MAP[KEY["KEY" .. s]] = s end
        if KEY[s] then KEY_CHAR_MAP[KEY[s]] = s end
        if KEY["PAD_" .. s] then KEY_CHAR_MAP[KEY["PAD_" .. s]] = s end
    end
    local extras = {
        SPACE = " ",
        MINUS = "-",
        EQUAL = "=",
        LBRACKET = "[",
        RBRACKET = "]",
        BACKSLASH = "\\",
        SEMICOLON = ";",
        APOSTROPHE = "'",
        COMMA = ",",
        PERIOD = ".",
        SLASH = "/",
        BACKQUOTE = "`",
        PAD_MINUS = "-",
        PAD_PLUS = "+",
        PAD_MULTIPLY = "*",
        PAD_DIVIDE = "/",
        PAD_DECIMAL = ".",
    }
    for k, v in pairs(extras) do
        if KEY[k] then KEY_CHAR_MAP[KEY[k]] = v end
    end
end

local BLOCKED_STUDIO_BINDS = {
    ["+forward"] = true,
    ["+back"] = true,
    ["+moveleft"] = true,
    ["+moveright"] = true,
    ["+jump"] = true,
    ["+duck"] = true,
    ["+speed"] = true,
    ["+walk"] = true,
    ["+attack"] = true,
    ["+attack2"] = true,
    ["+reload"] = true,
    ["+use"] = true,
    ["invnext"] = true,
    ["invprev"] = true,
    ["+menu"] = true,
    ["+menu_context"] = true,
}

function UIManager.new(state)
    buildKeyMap()
    return setmetatable({
        state = state,
        scrW = 1920,
        scrH = 1080,
        mx = 0,
        my = 0,
        prevMx = 0,
        prevMy = 0,
        dx = 0,
        dy = 0,
        leftDown = false,
        leftPressed = false,
        leftReleased = false,
        rightDown = false,
        rightPressed = false,
        rightReleased = false,
        wheelDelta = 0,

        activeId = nil,       -- ID currently captured by mouse drag
        hotId = nil,          -- ID currently hovered
        focusedInputId = nil, -- ID of active TextBox
        _inputState = {},     -- Per-TextBox transient cursor/value callbacks
        _tooltipText = nil,
        _tooltipTimer = 0,
        _lastHoverId = nil,
        _clipStack = {},
        _frameTime = 0,
    }, UIManager)
end

function UIManager:beginFrame(dt)
    self._frameTime = self._frameTime + dt
    self.scrW, self.scrH = render.getResolution()

    self.prevMx, self.prevMy = self.mx, self.my
    if hasPermission("input") then
        local cx, cy = input.getCursorPos()
        self.mx = cx or self.mx
        self.my = cy or self.my
    end
    self.dx = self.mx - self.prevMx
    self.dy = self.my - self.prevMy

    local lDown = hasPermission("input") and input.isMouseDown(MOUSE.LEFT) or false
    local rDown = hasPermission("input") and input.isMouseDown(MOUSE.RIGHT) or false

    self.leftPressed = lDown and not self.leftDown
    self.leftReleased = (not lDown) and self.leftDown
    self.leftDown = lDown

    self.rightPressed = rDown and not self.rightDown
    self.rightReleased = (not rDown) and self.rightDown
    self.rightDown = rDown

    if self.leftPressed then
        -- Clear text focus unless the clicked TextBox re-claims it during draw/update
        self._pendingClearFocus = true
    end

    self.hotId = nil
    self._tooltipText = nil
end

function UIManager:endFrame(dt)
    if self._pendingClearFocus then
        self.focusedInputId = nil
        self._pendingClearFocus = false
    end

    if self.leftReleased and self.activeId then
        self.activeId = nil
    end

    if self.hotId and self.hotId == self._lastHoverId and not self.activeId then
        self._tooltipTimer = self._tooltipTimer + dt
    else
        self._tooltipTimer = 0
        self._lastHoverId = self.hotId
    end

    self.wheelDelta = 0
end

function UIManager:onMouseWheeled(delta)
    self.wheelDelta = self.wheelDelta + delta
end

function UIManager:pointInRect(x, y, w, h)
    return self.mx >= x and self.mx <= (x + w) and self.my >= y and self.my <= (y + h)
end

-- Respects active scissor clip stack so clipped scroll contents cannot be clicked outside parent
function UIManager:isMouseInClip()
    local top = self._clipStack[#self._clipStack]
    if not top then return true end
    return self.mx >= top[1] and self.mx <= top[3] and self.my >= top[2] and self.my <= top[4]
end

function UIManager:hitTest(id, x, y, w, h)
    if self.state.viewportLooking then return false, false end
    local inside = self:pointInRect(x, y, w, h) and self:isMouseInClip()
    local canHover = (self.activeId == nil or self.activeId == id)
    if inside and canHover then
        self.hotId = id
    end
    local isHot = (self.hotId == id)
    local isActive = (self.activeId == id)
    return isHot, isActive
end

function UIManager:capture(id)
    self.activeId = id
end

function UIManager:release(id)
    if self.activeId == id then
        self.activeId = nil
    end
end

function UIManager:setTooltip(text)
    if text and text ~= "" then
        self._tooltipText = text
    end
end

function UIManager:pushClip(x, y, w, h)
    local x1, y1, x2, y2 = x, y, x + math.max(0, w), y + math.max(0, h)
    local top = self._clipStack[#self._clipStack]
    if top then
        x1 = math.max(x1, top[1])
        y1 = math.max(y1, top[2])
        x2 = math.min(x2, top[3])
        y2 = math.min(y2, top[4])
    end
    self._clipStack[#self._clipStack + 1] = { x1, y1, x2, y2 }
    render.enableScissorRect(x1, y1, math.max(x1, x2), math.max(y1, y2))
end

function UIManager:popClip()
    local n = #self._clipStack
    if n == 0 then return end
    self._clipStack[n] = nil
    local top = self._clipStack[n - 1]
    if top then
        render.enableScissorRect(top[1], top[2], math.max(top[1], top[3]), math.max(top[2], top[4]))
    else
        render.disableScissorRect()
    end
end

function UIManager:registerTextInput(id, getter, setter, onSubmit)
    self._inputState[id] = {
        get = getter,
        set = setter,
        onSubmit = onSubmit,
    }
end

function UIManager:focusTextInput(id)
    self.focusedInputId = id
    self._pendingClearFocus = false
end

function UIManager:handleKeyPressed(key)
    if not self.focusedInputId then return false end
    local entry = self._inputState[self.focusedInputId]
    if not entry then
        self.focusedInputId = nil
        return false
    end

    if key == KEY.ESCAPE then
        self.focusedInputId = nil
        return true
    elseif key == KEY.ENTER or key == KEY.PAD_ENTER then
        if entry.onSubmit then entry.onSubmit(entry.get()) end
        self.focusedInputId = nil
        return true
    elseif key == KEY.BACKSPACE then
        local txt = entry.get() or ""
        if #txt > 0 then
            entry.set(string.sub(txt, 1, #txt - 1))
        end
        return true
    end

    local ch = KEY_CHAR_MAP[key]
    if ch then
        local shift = hasPermission("input") and input.isShiftDown() or false
        if shift then
            ch = SHIFT_MAP[ch] or string.upper(ch)
        end
        entry.set((entry.get() or "") .. ch)
        return true
    end

    return false
end

function UIManager:shouldBlockBind(bind)
    if not self.state.studioOpen then return false end
    if self.focusedInputId then return true end
    if self.state.viewportLooking then return false end
    return BLOCKED_STUDIO_BINDS[bind] == true
end

function UIManager:drawTooltip()
    if not self._tooltipText or self._tooltipTimer < 0.35 or self.activeId then return end

    render.setFont(Theme.Fonts.Small)
    local tw, th = render.getTextSize(self._tooltipText)
    local padX, padY = 8, 5
    local bw = tw + padX * 2
    local bh = th + padY * 2

    local tx = math.clamp(self.mx + 14, 6, self.scrW - bw - 6)
    local ty = math.clamp(self.my + 18, 6, self.scrH - bh - 6)

    Theme.setColor(Theme.C.tooltipBg)
    render.drawRectFast(tx, ty, bw, bh)
    Theme.setColor(Theme.C.borderLight)
    render.drawRectOutline(tx, ty, bw, bh, 1)
    Theme.setColor(Theme.C.textPrimary)
    render.drawSimpleText(tx + padX, ty + padY, self._tooltipText, TEXT_ALIGN.LEFT, TEXT_ALIGN.TOP)
end

return UIManager
