--@client
--[[
    SOLACE — 3D Freecam Controller
    Provides smooth Blender/Unreal-style 3D navigation via CalcView + MouseMoved.
    Restores default player camera completely whenever SOLACE is closed.
]]

local Constants = require("../core/constants.lua")
local Math3D    = require("../core/math3d.lua")

local Freecam = {}
Freecam.__index = Freecam

function Freecam.new(state)
    return setmetatable({
        state = state,
        initialized = false,
        camPos = Vector(0, 0, 100),
        camAng = Angle(15, 0, 0),
        targetPos = Vector(0, 0, 100),
        targetAng = Angle(15, 0, 0),
    }, Freecam)
end

function Freecam:initFromPlayer()
    local pos = eyePos()
    local ang = eyeAngles()
    -- Offset slightly up & back so user sees the studio origin/chip cleanly
    local initPos = pos + Vector(0, 0, 16)
    self.camPos = initPos:clone()
    self.targetPos = initPos:clone()
    self.camAng = Angle(ang[1], ang[2], 0)
    self.targetAng = Angle(ang[1], ang[2], 0)
    self.initialized = true
end

function Freecam:resetToPlayer()
    self:initFromPlayer()
end

function Freecam:onMouseMoved(dx, dy)
    if not self.state.studioOpen or not self.state.viewportLooking then return end
    local sens = self.state.camera.sensitivity
    self.targetAng[2] = math.normalizeAngle(self.targetAng[2] - dx * sens)
    self.targetAng[1] = math.clamp(self.targetAng[1] + dy * sens, -89.0, 89.0)
    self.targetAng[3] = 0
end

function Freecam:onMouseWheelInViewport(delta)
    if not self.state.studioOpen then return end
    local c = self.state.camera
    local factor = delta > 0 and 1.15 or (1 / 1.15)
    c.speed = math.clamp(math.round(c.speed * factor), Constants.CAMERA_DEFAULTS.minSpeed, Constants.CAMERA_DEFAULTS.maxSpeed)
end

function Freecam:focusNode(sceneGraph, runtime, nodeId)
    if not self.initialized then self:initFromPlayer() end
    local targetId = nodeId or sceneGraph:getSelectedId()
    if not targetId or targetId == sceneGraph:getRootId() then return false end

    local node = sceneGraph:getNode(targetId)
    if not node then return false end

    local pos, ang, sMin, sMax = runtime:getNodeBounds(targetId)
    if not pos then return false end

    local center, radius = Math3D.getOBBCenterAndRadius(pos, ang, sMin, sMax)
    local halfFovRad = math.rad(math.clamp(self.state.camera.fov, 30, 120) * 0.5)
    local dist = math.max(55, (radius / math.max(0.15, math.tan(halfFovRad))) * Constants.CAMERA_DEFAULTS.focusPadding)

    local fwd = self.targetAng:getForward()
    self.targetPos = center - fwd * dist
    return true
end

function Freecam:getSpawnTransform(distance)
    if not self.initialized then self:initFromPlayer() end
    local d = distance or self.state.spawnDistance or 140
    local p = self.camPos + self.camAng:getForward() * d
    return { math.round(p[1], 2), math.round(p[2], 2), math.round(p[3], 2) },
           { 0, math.round(self.camAng[2], 1), 0 }
end

function Freecam:update(dt, ui, vpRect)
    if not self.initialized then
        self:initFromPlayer()
    end

    if not self.state.studioOpen then return end
    if not hasPermission("input") then return end

    -- Adjust speed with mouse wheel when cursor is inside the viewport (or while RMB-looking)
    if ui.wheelDelta ~= 0 and (self.state.viewportLooking or ui:pointInRect(vpRect.x, vpRect.y, vpRect.w, vpRect.h)) then
        self:onMouseWheelInViewport(ui.wheelDelta)
    end

    -- Keyboard movement (disabled while typing into any TextBox)
    if not ui.focusedInputId then
        local fwd = 0
        local right = 0
        local up = 0

        if input.isKeyDown(KEY.W) then fwd = fwd + 1 end
        if input.isKeyDown(KEY.S) then fwd = fwd - 1 end
        if input.isKeyDown(KEY.D) then right = right + 1 end
        if input.isKeyDown(KEY.A) then right = right - 1 end
        if input.isKeyDown(KEY.SPACE) then up = up + 1 end
        if input.isKeyDown(KEY.LCONTROL) or input.isKeyDown(KEY.RCONTROL) then up = up - 1 end

        if fwd ~= 0 or right ~= 0 or up ~= 0 then
            local moveDir = self.targetAng:getForward() * fwd
                + self.targetAng:getRight() * right
                + Vector(0, 0, up)

            local len = moveDir:getLength()
            if len > 0.001 then
                moveDir = moveDir / len
                local spd = self.state.camera.speed
                if input.isShiftDown() then
                    spd = spd * self.state.camera.boostMult
                end
                self.targetPos = self.targetPos + moveDir * (spd * dt)
            end
        end
    end

    -- Smooth exponential interpolation (frame-rate independent)
    local smooth = self.state.camera.smoothing
    if smooth >= 40 then
        self.camPos = self.targetPos:clone()
        self.camAng = self.targetAng:clone()
    else
        local t = 1 - math.exp(-smooth * dt)
        self.camPos = math.lerpVector(t, self.camPos, self.targetPos)
        self.camAng = math.lerpAngle(t, self.camAng, self.targetAng)
        self.camAng[3] = 0
    end
end

function Freecam:calcView(origin, angles, fov, znear, zfar)
    if not self.state.studioOpen then return nil end
    if not self.initialized then
        self:initFromPlayer()
    end
    return {
        origin = self.camPos,
        angles = self.camAng,
        fov = self.state.camera.fov,
        drawviewer = true,
    }
end

return Freecam
