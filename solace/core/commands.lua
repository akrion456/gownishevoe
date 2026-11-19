--@shared
--[[
    SOLACE — Undo / Redo Command History
    All scene mutations should go through reversible Command objects.
]]

local Commands = {}
Commands.__index = Commands

function Commands.new(events, maxHistory)
    return setmetatable({
        _events = events,
        _undoStack = {},
        _redoStack = {},
        _maxHistory = maxHistory or 100,
    }, Commands)
end

function Commands:execute(cmd)
    if not cmd or type(cmd.redo) ~= "function" or type(cmd.undo) ~= "function" then
        return false
    end

    cmd:redo()
    self._undoStack[#self._undoStack + 1] = cmd
    self._redoStack = {}

    if #self._undoStack > self._maxHistory then
        table.remove(self._undoStack, 1)
    end

    if self._events then
        self._events:emit("historyChanged", self)
    end
    return true
end

function Commands:canUndo()
    return #self._undoStack > 0
end

function Commands:canRedo()
    return #self._redoStack > 0
end

function Commands:getUndoLabel()
    local top = self._undoStack[#self._undoStack]
    return top and top.label or nil
end

function Commands:getRedoLabel()
    local top = self._redoStack[#self._redoStack]
    return top and top.label or nil
end

function Commands:undo()
    local idx = #self._undoStack
    if idx == 0 then return false end
    local cmd = self._undoStack[idx]
    self._undoStack[idx] = nil
    cmd:undo()
    self._redoStack[#self._redoStack + 1] = cmd
    if self._events then
        self._events:emit("historyChanged", self)
    end
    return true
end

function Commands:redo()
    local idx = #self._redoStack
    if idx == 0 then return false end
    local cmd = self._redoStack[idx]
    self._redoStack[idx] = nil
    cmd:redo()
    self._undoStack[#self._undoStack + 1] = cmd
    if self._events then
        self._events:emit("historyChanged", self)
    end
    return true
end

function Commands:clear()
    self._undoStack = {}
    self._redoStack = {}
    if self._events then
        self._events:emit("historyChanged", self)
    end
end

return Commands
