--@client
--[[
    SOLACE — Left Toolbox / Object Creator & Asset Browser
    Phase 2: Spawn mounted starter & custom .mdl models, sprites, groups, and folders.
    Phase 6: Expands with full incremental file.findInGame asset scanner.
]]

local Constants = require("../../core/constants.lua")
local Theme = require("../theme.lua")
local Widgets = require("../widgets.lua")

local Toolbox = {
    _scrollY = 0,
    _contentH = 0,
    _modelExistsCache = {},
}

local function checkModelMounted(path)
    if not path or path == "" then return false end
    local cached = Toolbox._modelExistsCache[path]
    if cached ~= nil then return cached end
    local ok = game.modelExists(path)
    Toolbox._modelExistsCache[path] = ok
    return ok
end

function Toolbox.draw(ui, state, rect, actions)
    if rect.w <= 0 or rect.h <= 0 then return end

    local bx, by, bw, bh = Widgets.panelFrame(rect.x, rect.y, rect.w, rect.h, "Toolbox", "Create")
    if bw < 20 or bh < 40 then return end

    -- Scroll body with wheel when mouse inside Toolbox
    if ui.wheelDelta ~= 0 and ui:pointInRect(bx, by, bw, bh) then
        Toolbox._scrollY = Toolbox._scrollY - ui.wheelDelta * 26
    end
    local maxScroll = math.max(0, Toolbox._contentH - bh)
    Toolbox._scrollY = math.clamp(Toolbox._scrollY, 0, maxScroll)

    ui:pushClip(bx, by, bw, bh)

    local pad = Theme.Metrics.pad
    local innerW = bw - pad * 2 - (maxScroll > 0 and 6 or 0)
    local curY = by + pad - Toolbox._scrollY
    local startY = curY

    -- Search input
    Widgets.textBox(
        ui,
        "toolbox_search",
        bx + pad,
        curY,
        innerW,
        24,
        function() return state.toolboxSearch end,
        function(v) state.toolboxSearch = v end,
        "Filter assets...",
        "Filter available models and sprites"
    )
    curY = curY + 30

    -- Category buttons (2 columns)
    local cols = innerW >= 200 and 2 or 1
    local gap = 4
    local cellW = math.floor((innerW - gap * (cols - 1)) / cols)
    local cellH = 24
    local activeCatInfo = Constants.ASSET_CATEGORIES[1]

    for i, cat in ipairs(Constants.ASSET_CATEGORIES) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = bx + pad + col * (cellW + gap)
        local cy = curY + row * (cellH + gap)
        local isSelected = (state.activeToolboxCategory == cat.id)
        if isSelected then activeCatInfo = cat end

        if Widgets.button(ui, "tbx_cat_" .. cat.id, cx, cy, cellW, cellH, cat.label, {
            icon = cat.icon,
            active = isSelected,
            tooltip = cat.desc,
        }) then
            state.activeToolboxCategory = cat.id
            Toolbox._scrollY = 0
        end
    end

    local rows = math.ceil(#Constants.ASSET_CATEGORIES / cols)
    curY = curY + rows * (cellH + gap) + 8

    -- Hierarchy containers quick create
    local halfW = math.floor((innerW - 4) * 0.5)
    if Widgets.button(ui, "tbx_new_group", bx + pad, curY, halfW, 22, "+ Group", {
        icon = "layers",
        tooltip = "Create a Group node in the Scene Hierarchy",
    }) then
        actions.spawnGroup()
    end
    if Widgets.button(ui, "tbx_new_folder", bx + pad + halfW + 4, curY, innerW - halfW - 4, 22, "+ Folder", {
        icon = "layers",
        tooltip = "Create a Folder node in the Scene Hierarchy",
    }) then
        actions.spawnFolder()
    end
    curY = curY + 28

    Theme.setColor(Theme.C.border)
    render.drawLine(bx + pad, curY, bx + pad + innerW, curY)
    curY = curY + 8

    local q = string.lower(string.trim(state.toolboxSearch or ""))

    if state.activeToolboxCategory == "models" then
        -- Custom mounted .mdl path spawner
        render.setFont(Theme.Fonts.Small)
        Theme.setColor(Theme.C.textSecondary)
        render.drawSimpleText(bx + pad, curY, "Custom Mounted Model (.mdl)", TEXT_ALIGN.LEFT, TEXT_ALIGN.TOP)
        curY = curY + 15

        Widgets.textBox(
            ui,
            "tbx_custom_mdl",
            bx + pad,
            curY,
            innerW,
            24,
            function() return state.customModelPath end,
            function(v) state.customModelPath = v end,
            "models/...",
            "Enter any mounted GMod model path (e.g. models/props_c17/oildrum001.mdl)"
        )
        curY = curY + 28

        local customOk = checkModelMounted(state.customModelPath)
        local spawnLabel = customOk and "Spawn Custom Model" or "Model Path Not Found"
        if Widgets.button(ui, "tbx_spawn_custom", bx + pad, curY, innerW, 24, spawnLabel, {
            icon = "cube",
            disabled = not customOk,
            tooltip = customOk and ("Spawn " .. state.customModelPath .. " in front of camera") or "Verify path starts with models/ and exists in GMod",
        }) then
            local fname = string.getFileFromFilename(state.customModelPath) or "Model"
            local cleanName = string.stripExtension(fname)
            actions.spawnQuickModel(cleanName ~= "" and cleanName or "Model", state.customModelPath)
        end
        curY = curY + 32

        render.setFont(Theme.Fonts.Small)
        Theme.setColor(Theme.C.textSecondary)
        render.drawSimpleText(bx + pad, curY, "Starter Models (Click to Spawn)", TEXT_ALIGN.LEFT, TEXT_ALIGN.TOP)
        curY = curY + 16

        local shown = 0
        for idx, item in ipairs(Constants.STARTER_MODELS) do
            local matches = (q == "")
                or string.find(string.lower(item.name), q, 1, true) ~= nil
                or string.find(string.lower(item.model), q, 1, true) ~= nil
            if matches then
                local mounted = checkModelMounted(item.model)
                if mounted then
                    shown = shown + 1
                    if Widgets.button(ui, "tbx_mdl_" .. idx, bx + pad, curY, innerW, 24, item.name, {
                        icon = "cube",
                        subtle = true,
                        tooltip = "Spawn " .. item.model .. " in front of Freecam",
                    }) then
                        actions.spawnQuickModel(item.name, item.model)
                    end
                    curY = curY + 26
                end
            end
        end
        if shown == 0 then
            render.setFont(Theme.Fonts.Small)
            Theme.setColor(Theme.C.textMuted)
            render.drawSimpleText(bx + pad, curY, "No starter models match filter.", TEXT_ALIGN.LEFT, TEXT_ALIGN.TOP)
            curY = curY + 20
        end

        curY = curY + 6
        local nh = Widgets.phaseNotice(
            bx + pad, curY, innerW,
            "Full Asset Scanner",
            { "Auto-indexing all GMod/addon", "models arrives in Phase 6." },
            "Phase 6"
        )
        curY = curY + nh + 8

    elseif state.activeToolboxCategory == "sprites" then
        render.setFont(Theme.Fonts.Small)
        Theme.setColor(Theme.C.textSecondary)
        render.drawSimpleText(bx + pad, curY, "Starter Sprites (Click to Spawn)", TEXT_ALIGN.LEFT, TEXT_ALIGN.TOP)
        curY = curY + 16

        for idx, item in ipairs(Constants.STARTER_SPRITES) do
            if q == "" or string.find(string.lower(item.name), q, 1, true) ~= nil then
                if Widgets.button(ui, "tbx_spr_" .. idx, bx + pad, curY, innerW, 24, item.name, {
                    icon = "sparkle",
                    subtle = true,
                    tooltip = "Spawn 3D Sprite (" .. item.material .. ")",
                }) then
                    actions.spawnSprite(item.name, item.material)
                end
                curY = curY + 26
            end
        end

        curY = curY + 6
        local nh = Widgets.phaseNotice(
            bx + pad, curY, innerW,
            "Dedicated Sprite Editor",
            { "Size/fade/lifetime curves & material", "browser arrive in Phase 7." },
            "Phase 7"
        )
        curY = curY + nh + 8
    else
        local nh = Widgets.phaseNotice(
            bx + pad,
            curY,
            innerW,
            activeCatInfo.label,
            {
                activeCatInfo.desc,
                "",
                "Use the Models or Sprites tabs above",
                "to spawn objects in Phase 2.",
            },
            "Upcoming"
        )
        curY = curY + nh + 8
    end

    Toolbox._contentH = (curY - startY) + pad

    if maxScroll > 0 then
        local barW = 4
        local barX = bx + bw - barW - 2
        local trackH = bh - 4
        local thumbH = math.max(24, math.floor(trackH * (bh / Toolbox._contentH)))
        local thumbY = by + 2 + math.floor((trackH - thumbH) * (Toolbox._scrollY / maxScroll))
        Theme.setColor(Theme.C.bgInput)
        render.drawRectFast(barX, by + 2, barW, trackH)
        Theme.setColor(Theme.C.borderLight)
        render.drawRectFast(barX, thumbY, barW, thumbH)
    end

    ui:popClip()
end

return Toolbox
