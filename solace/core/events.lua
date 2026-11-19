--@shared
--[[
    SOLACE — Event Bus
    Decoupled pub/sub messaging between Scene IR, UI Panels, and Viewport.
]]

local Events = {}
Events.__index = Events

function Events.new()
    return setmetatable({
        _listeners = {},
    }, Events)
end

function Events:on(eventName, id, fn)
    local bucket = self._listeners[eventName]
    if not bucket then
        bucket = {}
        self._listeners[eventName] = bucket
    end
    bucket[id] = fn
end

function Events:off(eventName, id)
    local bucket = self._listeners[eventName]
    if bucket then
        bucket[id] = nil
    end
end

function Events:emit(eventName, ...)
    local bucket = self._listeners[eventName]
    if not bucket then return end
    for _, fn in pairs(bucket) do
        fn(...)
    end
end

return Events
