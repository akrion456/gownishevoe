--@client
--[[
    SOLACE — Right-Top Explorer Panel
    Live Scene IR hierarchy tree synchronized bidirectionally with Viewport selection.
    Supports search, expand/collapse, multi-selection (Ctrl+Click), visibility toggle,
    node creation (Group/Folder), Focus, and Delete.
]]

local Constants = require("../../core/constants.lua")
local Theme = require("../theme.lua")
local Widgets = require("../widgets.lua")

local Explorer = {
    _scrollY = 0,
    _contentH = 0,
}

local KIND_ICONS = {
    [Constants.NODE_KINDS.ROOT]     = "scene",
    [Constants.NODE_KINDS.FOLDER]   = "layers",
    [Constants.NODE_KINDS.GROUP]    = "layers",
    [Constants.NODE_KINDS.MODEL]    = "cube",
    [Constants.NODE_KINDS.HOLOGRAM] = "holo",
    [Constants.NODE_KINDS.CAMERA]   = "camera",
    [Constants.NODE_KINDS.SPRITE]   = "sparkle",
    [Constants.NODE_KINDS.EFFECT]   = "burst",
    [Constants.NODE_KINDS.DECAL]    = "stamp",
}

function Explorer.draw(ui, state, sceneGraph, rect, actions)
    if rect.w <= 0 or rect.h <= 0 then return end

    local count = sceneGraph:getNodeCount()
    local countStr = string.format("%d node%s", count, count == 1 and "" or "s")
    local bx, by, bw, bh = Widgets.panelFrame(rect.x, rect.y, rect.w, rect.h, "Explorer", countStr)
    if bw < 20 or bh < 60 then return end

    local pad = Theme.Metrics.pad
    local topBarH = 56
    local listY = by + topBarH
    local listH = math.max(0, bh - topBarH)

    -- Scroll tree area with mouse wheel
    if ui.wheelDelta ~= 0 and ui:pointInRect(bx, listY, bw, listH) then
        Explorer._scrollY = Explorer._scrollY - ui.wheelDelta * 24
    end
    local maxScroll = math.max(0, Explorer._contentH - listH)
    Explorer._scrollY = math.clamp(Explorer._scrollY, 0, maxScroll)

    ui:pushClip(bx, by, bw, bh)

    -- Search box
    Widgets.textBox(
        ui,
        "explorer_search",
        bx + pad,
        by + 6,
        bw - pad * 2,
        22,
        function() return state.explorerSearch end,
        function(v) state.explorerSearch = v end,
        "Search scene hierarchy...",
        "Filter Scene IR nodes by name or kind"
    )

    -- Quick hierarchy toolbar strip
    local actY = by + 32
    local gap = 4
    local btnW = math.floor((bw - pad * 2 - gap * 3) / 4)
    local selNode = sceneGraph:getSelectedNode()
    local canDelete = (selNode ~= nil and selNode.id ~= sceneGraph:getRootId())

    if Widgets.button(ui, "exp_add_grp", bx + pad, actY, btnW, 20, "+Grp", {
        tooltip = "Create Group under selected container or root",
    }) then
        actions.spawnGroup()
    end
    if Widgets.button(ui, "exp_add_fld", bx + pad + (btnW + gap), actY, btnW, 20, "+Fld", {
        tooltip = "Create Folder under selected container or root",
    }) then
        actions.spawnFolder()
    end
    if Widgets.button(ui, "exp_focus", bx + pad + (btnW + gap) * 2, actY, btnW, 20, "Focus", {
        disabled = not canDelete,
        tooltip = "Focus Freecam on selected object (F)",
    }) then
        actions.focusSelected()
    end
    if Widgets.button(ui, "exp_del", bx + pad + (btnW + gap) * 3, actY, btnW, 20, "Del", {
        disabled = not canDelete,
        tooltip = "Delete selected object(s) (Delete)",
    }) then
        actions.deleteSelected()
    end

    Theme.setColor(Theme.C.border)
    render.drawLine(bx, listY - 1, bx + bw, listY - 1)

    -- Scrollable tree body
    ui:pushClip(bx, listY, bw, listH)

    local rows = sceneGraph:getFlatHierarchy(state.explorerSearch)
    local rowH = Theme.Metrics.rowH
    local primaryId = sceneGraph:getSelectedId()
    local curY = listY + 4 - Explorer._scrollY
    local startY = curY

    for _, item in ipairs(rows) do
        local node = item.node
        if curY + rowH >= listY and curY <= listY + listH then
            local indent = 8 + item.depth * 14
            local isSel = sceneGraph:isSelected(node.id)
            local isPrimary = (node.id == primaryId)
            local rowId = "exp_row_" .. node.id
            local eyeSize = 18
            local eyeX = bx + bw - eyeSize - (maxScroll > 0 and 10 or 6)

            local hot, _ = ui:hitTest(rowId, bx + 2, curY, bw - 4, rowH)

            if isSel then
                Theme.setColor(Theme.C.bgSelectionRow, isPrimary and 120 or 75)
                render.drawRectFast(bx + 2, curY, bw - 4, rowH)
                Theme.setColor(isPrimary and Theme.C.accentBright or Theme.C.accent)
                render.drawRectFast(bx + 2, curY, 2, rowH)
            elseif hot then
                Theme.setColor(Theme.C.bgControlHover, 140)
                render.drawRectFast(bx + 2, curY, bw - 4, rowH)
            end

            -- Expand / collapse chevron
            local handledClick = false
            if item.hasChildren then
                local chevX = bx + indent
                local chevHot, _ = ui:hitTest("exp_chev_" .. node.id, chevX - 2, curY, 16, rowH)
                Theme.drawIcon(
                    node.expanded and "chevronDown" or "chevronRight",
                    chevX,
                    curY + (rowH - 12) * 0.5,
                    12,
                    chevHot and Theme.C.textPrimary or Theme.C.textMuted
                )
                if chevHot and ui.leftPressed then
                    node.expanded = not node.expanded
                    handledClick = true
                end
            end

            -- Visibility toggle eye button (non-root nodes)
            if node.id ~= sceneGraph:getRootId() then
                local eyeHot, _ = ui:hitTest("exp_eye_" .. node.id, eyeX, curY, eyeSize, rowH)
                if eyeHot then
                    ui:setTooltip(node.visible and "Hide object" or "Show object")
                end
                Theme.drawIcon(
                    "eye",
                    eyeX + 2,
                    curY + (rowH - 13) * 0.5,
                    13,
                    node.visible and (eyeHot and Theme.C.textPrimary or Theme.C.textSecondary) or Theme.C.textDisabled
                )
                if eyeHot and ui.leftPressed then
                    sceneGraph:toggleNodeVisible(node.id)
                    handledClick = true
                end
            end

            -- Row selection (supports Ctrl+Click multi-select)
            if hot and ui.leftPressed and not handledClick then
                local ctrl = hasPermission("input") and input.isControlDown() or false
                if ctrl then
                    sceneGraph:toggleSelectedId(node.id)
                else
                    sceneGraph:setSelectedId(node.id)
                end
            end

            local iconX = bx + indent + 15
            local iconName = KIND_ICONS[node.kind] or "cube"
            local textAlpha = node.visible and 255 or 120
            Theme.drawIcon(
                iconName,
                iconX,
                curY + (rowH - 13) * 0.5,
                13,
                isSel and Theme.C.accentBright or Theme.C.textSecondary,
                textAlpha
            )

            render.setFont(isSel and Theme.Fonts.BodyBold or Theme.Fonts.Body)
            Theme.setColor(isSel and Theme.C.textPrimary or Theme.C.textSecondary, textAlpha)
            render.drawSimpleText(iconX + 18, curY + rowH * 0.5, node.name, TEXT_ALIGN.LEFT, TEXT_ALIGN.CENTER)

            render.setFont(Theme.Fonts.Small)
            Theme.setColor(Theme.C.textMuted, textAlpha)
            render.drawSimpleText(eyeX - 6, curY + rowH * 0.5, node.kind, TEXT_ALIGN.RIGHT, TEXT_ALIGN.CENTER)
        end
        curY = curY + rowH
    end

    Explorer._contentH = (curY - startY) + 8

    if maxScroll > 0 then
        local barW = 4
        local barX = bx + bw - barW - 2
        local trackH = listH - 4
        local thumbH = math.max(20, math.floor(trackH * (listH / Explorer._contentH)))
        local thumbY = listY + 2 + math.floor((trackH - thumbH) * (Explorer._scrollY / maxScroll))
        Theme.setColor(Theme.C.bgInput)
        render.drawRectFast(barX, listY + 2, barW, trackH)
        Theme.setColor(Theme.C.borderLight)
        render.drawRectFast(barX, thumbY, barW, thumbH)
    end

    ui:popClip()
    ui:popClip()
end

return Explorer
