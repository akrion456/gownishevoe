--@name SOLACE — Visual Animation & Effects Studio
--@author SOLACE Team
--@shared

--@include core/constants.lua
--@include core/events.lua
--@include core/commands.lua
--@include core/math3d.lua
--@include scene/ir_schema.lua
--@include scene/scene_graph.lua
--@include scene/runtime_client.lua
--@include ui/theme.lua
--@include ui/ui_manager.lua
--@include ui/widgets.lua
--@include ui/layout.lua
--@include viewport/grid.lua
--@include viewport/camera.lua
--@include viewport/selection.lua
--@include ui/panels/toolbar.lua
--@include ui/panels/toolbox.lua
--@include ui/panels/explorer.lua
--@include ui/panels/properties.lua
--@include ui/panels/timeline.lua

local Constants  = require("core/constants.lua")
local Events     = require("core/events.lua")
local Commands   = require("core/commands.lua")
local SceneGraph = require("scene/scene_graph.lua")

if SERVER then
    -- Singleplayer / Sandbox-first: automatically attach owner HUD so the studio opens on spawn
    local function attachOwnerHud(ply)
        if isValid(ply) and ply == owner() then
            pcall(enableHud, ply, true)
        end
    end

    hook.add("ClientInitialized", "solace_sv_init_hud", function(ply)
        attachOwnerHud(ply)
    end)

    hook.add("StarfallUsed", "solace_sv_used_hud", function(activator, used)
        if used == chip() then
            attachOwnerHud(activator)
        end
    end)

    timer.simple(0.1, function()
        attachOwnerHud(owner())
    end)

    return
end

-- ============================================================================
-- CLIENT STUDIO BOOTSTRAP
-- ============================================================================

local Theme        = require("ui/theme.lua")
local UIManager    = require("ui/ui_manager.lua")
local Layout       = require("ui/layout.lua")
local SceneRuntime = require("scene/runtime_client.lua")
local ViewportGrid = require("viewport/grid.lua")
local Freecam      = require("viewport/camera.lua")
local Selection    = require("viewport/selection.lua")

local Toolbar      = require("ui/panels/toolbar.lua")
local Toolbox      = require("ui/panels/toolbox.lua")
local Explorer     = require("ui/panels/explorer.lua")
local Properties   = require("ui/panels/properties.lua")
local Timeline     = require("ui/panels/timeline.lua")

setupPermissionRequest({
    "render.hud",
    "render.calcview",
    "hologram.create",
    "material.load",
    "input",
    "input.enablecursor",
    "file.read",
    "file.write",
    "file.findInGame",
}, "SOLACE Studio requires HUD rendering, Freecam view control, cursor input, clientside holograms, and asset access.", true)

Theme.initFonts()

local events     = Events.new()
local commands   = Commands.new(events, 100)
local sceneGraph = SceneGraph.new(events)
local runtime    = SceneRuntime.new(sceneGraph, events)
local state      = Constants.createDefaultState()
local ui         = UIManager.new(state)
local layout     = Layout.new(state)
local camera     = Freecam.new(state)

local hudConnected = false
local lastFrameTime = timer.realtime()
local fpsSmooth = 60

local HIDDEN_HUD_ELEMENTS = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudCrosshair = true,
    CHudWeaponSelection = true,
    CHudDamageIndicator = true,
    CHudSuitPower = true,
    CHudHintDisplay = true,
    CHudZoom = true,
    CHudPoisonDamageIndicator = true,
    CHudSquadStatus = true,
}

local function syncCursor()
    if not hasPermission("input.enablecursor") then return end
    local wantCursor = hudConnected and state.studioOpen and (not state.viewportLooking)
    if input.getCursorVisible() ~= wantCursor then
        input.enableCursor(wantCursor)
    end
end

local function setStudioOpen(open)
    state.studioOpen = open
    if not open then
        state.viewportLooking = false
        ui.focusedInputId = nil
        ui.activeId = nil
    elseif not camera.initialized then
        camera:initFromPlayer()
    end
    syncCursor()
end

local function resolveOrigin()
    ViewportGrid.resolveOrigin(state)
    sceneGraph:setOrigin(state.grid.originPos)
end

local function getTargetContainerParentId()
    local sel = sceneGraph:getSelectedNode()
    if sel and (sel.kind == Constants.NODE_KINDS.GROUP or sel.kind == Constants.NODE_KINDS.FOLDER) then
        return sel.id
    end
    return sceneGraph:getRootId()
end

local actions = {}
actions.hasSelection = false

function actions.toggleStudio(open)
    setStudioOpen(open)
end

function actions.resolveOrigin()
    resolveOrigin()
end

function actions.focusSelected()
    camera:focusNode(sceneGraph, runtime)
end

function actions.spawnQuickModel(name, modelPath)
    local posTbl, angTbl = camera:getSpawnTransform(state.spawnDistance)
    local parentId = getTargetContainerParentId()
    local node = sceneGraph:createModel(name, modelPath, posTbl, angTbl, parentId)
    sceneGraph:setSelectedId(node.id)
end

function actions.spawnSprite(name, matPath)
    local posTbl = camera:getSpawnTransform(state.spawnDistance)
    local parentId = getTargetContainerParentId()
    local node = sceneGraph:createSprite(name, matPath, posTbl, parentId)
    sceneGraph:setSelectedId(node.id)
end

function actions.spawnGroup()
    local posTbl = camera:getSpawnTransform(state.spawnDistance)
    local parentId = getTargetContainerParentId()
    local node = sceneGraph:createGroup("Group", posTbl, parentId)
    sceneGraph:setSelectedId(node.id)
end

function actions.spawnFolder()
    local parentId = getTargetContainerParentId()
    local node = sceneGraph:createFolder("Folder", parentId)
    sceneGraph:setSelectedId(node.id)
end

function actions.deleteSelected()
    local ids = {}
    for _, id in ipairs(sceneGraph:getSelectedIds()) do
        if id ~= sceneGraph:getRootId() then
            ids[#ids + 1] = id
        end
    end
    for _, id in ipairs(ids) do
        sceneGraph:removeNode(id)
    end
end

timer.simple(0.05, function()
    resolveOrigin()
    camera:initFromPlayer()
    if hasPermission("render.hud") then
        hudConnected = true
        syncCursor()
    end
end)

hook.add("HUDConnected", "solace_hud_connected", function(ent, ply)
    if ply == player() then
        hudConnected = true
        if not camera.initialized then
            camera:initFromPlayer()
        end
        syncCursor()
    end
end)

hook.add("HUDDisconnected", "solace_hud_disconnected", function(ent, ply)
    if ply == player() then
        hudConnected = false
        state.viewportLooking = false
        ui.focusedInputId = nil
        ui.activeId = nil
        if hasPermission("input.enablecursor") then
            input.enableCursor(false)
        end
    end
end)

hook.add("HUDShouldDraw", "solace_hide_game_hud", function(name)
    if state.studioOpen and HIDDEN_HUD_ELEMENTS[name] then
        return false
    end
end)

hook.add("CalcView", "solace_freecam_view", function(origin, angles, fov, znear, zfar)
    if not state.studioOpen or not hudConnected then return end
    if not hasPermission("render.calcview") then return end
    return camera:calcView(origin, angles, fov, znear, zfar)
end)

hook.add("MouseMoved", "solace_freecam_look", function(dx, dy)
    if state.studioOpen and state.viewportLooking then
        camera:onMouseMoved(dx, dy)
    end
end)

hook.add("Think", "solace_runtime_flush", function()
    runtime:flush()
end)

hook.add("Removed", "solace_cleanup", function()
    runtime:cleanup()
    if hasPermission("input.enablecursor") then
        input.enableCursor(false)
    end
end)

hook.add("InputPressed", "solace_input_pressed", function(key)
    if key == KEY.F6 then
        setStudioOpen(not state.studioOpen)
        return
    end

    if not state.studioOpen then return end

    if ui:handleKeyPressed(key) then
        return
    end

    if key == KEY.G then
        state.grid.enabled = not state.grid.enabled
    elseif key == KEY.Q then
        state.activeTool = "select"
    elseif key == KEY.F then
        actions.focusSelected()
    elseif key == KEY.DELETE then
        actions.deleteSelected()
    elseif key == KEY.ESCAPE then
        sceneGraph:clearSelection()
    end
end)

hook.add("InputBindPressed", "solace_block_binds", function(bind)
    if ui:shouldBlockBind(bind) then
        return true
    end
end)

hook.add("MouseWheeled", "solace_mouse_wheel", function(delta)
    if not state.studioOpen then return end
    if state.viewportLooking then
        camera:onMouseWheelInViewport(delta)
    else
        ui:onMouseWheeled(delta)
    end
end)

hook.add("PostDrawOpaqueRenderables", "solace_viewport_3d", function(depth, skybox, skybox3d)
    if skybox or skybox3d then return end
    if not state.studioOpen then return end
    ViewportGrid.draw3D(state)
    Selection.draw3D(state, camera, sceneGraph, runtime)
end)

hook.add("PostDrawTranslucentRenderables", "solace_viewport_sprites", function(depth, skybox, skybox3d)
    if skybox or skybox3d then return end
    if not state.studioOpen then return end
    runtime:drawSprites(state)
end)

hook.add("HUDPaint", "solace_hud_paint", function()
    if not hasPermission("render.hud") then return end
    hudConnected = true

    local now = timer.realtime()
    local dt = math.clamp(now - lastFrameTime, 0.0001, 0.25)
    lastFrameTime = now
    local instFps = 1 / dt
    fpsSmooth = fpsSmooth * 0.92 + instFps * 0.08

    if not state.studioOpen then
        local scrW = render.getResolution()
        local label = "SOLACE Minimized  |  Press F6 to Open"
        render.setFont(Theme.Fonts.Small)
        local tw = render.getTextSize(label)
        local pw = tw + 18
        local px = scrW - pw - 14
        local py = 14
        Theme.setColor(Theme.C.hudPill)
        render.drawRectFast(px, py, pw, 24)
        Theme.setColor(Theme.C.borderLight)
        render.drawRectOutline(px, py, pw, 24, 1)
        Theme.setColor(Theme.C.textPrimary)
        render.drawSimpleText(px + 9, py + 12, label, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)
        return
    end

    syncCursor()
    ui:beginFrame(dt)
    layout:compute(ui.scrW, ui.scrH)

    local rects = layout.rects
    ViewportGrid.updateLookMode(state, ui, rects.viewport)
    camera:update(dt, ui, rects.viewport)

    local sel = sceneGraph:getSelectedNode()
    actions.hasSelection = (sel ~= nil and sel.id ~= sceneGraph:getRootId())

    -- Draw docked studio panels around the live center 3D viewport cutout
    Toolbar.draw(ui, state, layout, rects.toolbar, actions)
    Toolbox.draw(ui, state, rects.toolbox, actions)
    Explorer.draw(ui, state, sceneGraph, rects.explorer, actions)
    Properties.draw(ui, state, sceneGraph, runtime, camera, rects.properties, actions)
    Timeline.draw(ui, state, sceneGraph, rects.timeline)

    -- Draw viewport frame, 3D orientation triad & telemetry
    ViewportGrid.drawOverlay(state, ui, rects.viewport, fpsSmooth, camera, sceneGraph)

    -- Draw interactive panel splitters on top of panel borders
    layout:updateAndDrawSplitters(ui)

    -- Viewport raycast hover & click selection (only when no UI widget/splitter is hovered/active)
    if ui.hotId == nil and ui.activeId == nil then
        Selection.pickAtCursor(ui, state, camera, sceneGraph, runtime, rects.viewport)
        Selection.handleClick(ui, state, camera, sceneGraph, runtime, rects.viewport)
    else
        Selection.hoveredId = nil
    end

    -- Permission warning banner if cursor/input/calcview permissions were restricted
    if not hasPermission("input.enablecursor") or not hasPermission("input") or not hasPermission("render.calcview") then
        local msg = "SOLACE needs Cursor/Input/CalcView permissions: Press E (Use) on the Starfall chip to grant."
        render.setFont(Theme.Fonts.BodyBold)
        local mw = render.getTextSize(msg) + 24
        local mx = math.floor((ui.scrW - mw) * 0.5)
        local my = rects.toolbar.h + 12
        Theme.setColor(Theme.C.danger, 225)
        render.drawRectFast(mx, my, mw, 28)
        Theme.setColor(Theme.C.textPrimary)
        render.drawSimpleText(mx + mw * 0.5, my + 14, msg, TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER)
    end

    ui:drawTooltip()
    ui:endFrame(dt)
end)
