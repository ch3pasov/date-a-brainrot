local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Locations = require(Shared.Locations)
local DateReveal = require(Shared.DateReveal)
local DateCollection = require(Shared.DateCollection)
local Remix = require(Shared.DateRemix)
local PresentationLayout = require(Shared.PresentationLayout)
local UI = require(script.Parent.UI)
local Scene = require(script.Parent.SceneViewer)
local Feedback = require(script.Parent.Feedback)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Presentation = {}
local function centered(parent, name, text, position, size, font, color, bold)
    local label = UI.label(parent, name, text, position, size, font, color, bold); label.TextXAlignment = Enum.TextXAlignment.Center; return label
end
Presentation.gestureIcon = Icons.gesture
function Presentation.mount(body, session, character, variant, options)
    local mobile, w, h = options.mobile, options.width, options.height
    local total = session.total or (session.stage == 2 and 6 or 4)
    local remix = Remix.get(session.remixId)
    local layout = PresentationLayout.resolve(w, h, mobile, UI.touchMinimum)
    local alive = true
    local controller = { session = session, locked = false, revealing = false, buttons = {}, scenes = {}, connections = {} }
    local root = UI.frame(body, "Minigame", UDim2.fromOffset(0, options.rootTop or (options.immersive and 0 or 70)), UDim2.fromOffset(w, h), C.panel, options.immersive and 0 or 24)
    root:SetAttribute("Stage", session.stage); root:SetAttribute("Presentation", ({ "phone_chat", "dual_video", "interactive_date" })[session.stage])
    controller.root = root
    local function addScene(parent, c, v, settings)
        settings.userId = settings.userId or options.userId; settings.avatarSnapshot = settings.avatarSnapshot or options.avatarSnapshot
        local scene = Scene.mount(parent, c, v, settings); table.insert(controller.scenes, scene); return scene
    end
    local status, replyArea, log, phone, npcScene, playerScene, dateScene, prompt, counter, gestureCue
    local chatPhoneW = mobile and w or 432
    local function dots(parent, total, y)
        local row = UI.frame(parent, "RoundDots", UDim2.new(.5, -total * 17, 0, y), UDim2.fromOffset(total * 34, 28), C.panel, 0); row.BackgroundTransparency = 1
        for i = 1, total do
            local slot = UI.frame(row, "Round" .. i, UDim2.fromOffset((i - 1) * 34 + 14, 14), UDim2.fromOffset(28, 28), C.card, 14)
            slot.AnchorPoint = Vector2.new(.5, .5)
            UI.stroke(slot, C.purple, 1)
            centered(slot, "Mark", tostring(i), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 15, C.muted, true)
        end
        return row
    end
    local roundDots
    local revealState
    local dateCollectionState
    local reactionState
    local previewChoice
    function controller.getRevealState() return revealState end
    function controller.getDateCollectionState() return dateCollectionState end
    function controller.getReactionState() return reactionState end
    local function updateDots(confirmedHit, animated)
        if not roundDots then return end
        local completed = session.stage == 2 and controller.session.attempts or controller.session.step - 1
        local hasConfirmation = type(confirmedHit) == "boolean"
        for i = 1, total do
            local slot = roundDots:FindFirstChild("Round" .. i)
            local label = slot.Mark
            local hit = controller.session.hits and controller.session.hits[i]
            local justConfirmed = hasConfirmation and i == completed + 1
            if justConfirmed then hit = confirmedHit end
            local done = i <= completed or justConfirmed
            local current = not hasConfirmation and i == completed + 1
            label.Text = done and (hit and "♥" or "×") or tostring(i)
            label.TextColor3 = done and (hit and C.panel or C.muted) or (current and C.purple or C.muted)
            slot.BackgroundColor3 = done and (hit and C.mint or C.card) or C.panel
            slot.UIStroke.Transparency = current and .15 or 1
            slot:SetAttribute("Completed", done)
            slot:SetAttribute("Hit", done and hit == true)
            if justConfirmed and animated ~= false then Feedback.pop(slot, .8) end
        end
    end
    if session.stage == 1 then
        root.BackgroundColor3 = C.aqua
        if not mobile then
            local setting = UI.frame(root, "ChatSetting", UDim2.fromOffset(16, 16), UDim2.fromOffset(w - chatPhoneW - 60, h - 32), C.card, 20)
            npcScene = addScene(setting, character, variant, { locationId = Locations.forPersonality(character.personality) })
            UI.pill(setting, "Place", Locations.get(Locations.forPersonality(character.personality)).name, UDim2.fromOffset(14, 14), 260, C.purple)
        end
        root.BackgroundTransparency = 1
        local phoneW, phoneH = chatPhoneW - 16, h - 16
        local phoneLayout = PresentationLayout.resolve(phoneW, phoneH, mobile, UI.touchMinimum)
        phone = UI.frame(root, "PhoneChat", UDim2.fromOffset(mobile and 8 or w - chatPhoneW - 10, 8), UDim2.fromOffset(phoneW, phoneH), Color3.fromRGB(252, 235, 184), 26)
        UI.stroke(phone, C.ink, 0).Thickness = 8
        status = UI.frame(phone, "PhoneStatusBar", UDim2.fromOffset(16, 5), UDim2.new(1, -32, 0, 23), C.panel, 0); status.BackgroundTransparency = 1
        UI.label(status, "Clock", "09:41", UDim2.fromOffset(9, 0), UDim2.fromOffset(90, 23), 12, C.text, true)
        UI.frame(status, "Speaker", UDim2.new(.5, -30, 0, 7), UDim2.fromOffset(60, 6), Color3.fromRGB(77, 81, 78), 3)
        for i = 1, 4 do UI.frame(status, "Signal" .. i, UDim2.new(1, -46 + i * 5, 0, 15 - i * 2), UDim2.fromOffset(3, i * 2 + 3), C.text, 1) end
        UI.frame(status, "Battery", UDim2.new(1, -14, 0, 7), UDim2.fromOffset(16, 8), C.mint, 2)
        local peer = UI.frame(phone, "PeerHeader", UDim2.fromOffset(12, 31), UDim2.new(1, -24, 0, 68), C.yellow, 6)
        UI.stroke(peer, C.ink, 0)
        local avatar = UI.frame(peer, "PeerAvatar", UDim2.fromOffset(10, 14), UDim2.fromOffset(40, 40), C.aqua, 20)
        Presentation.gestureIcon(avatar, ({ music = "dance", humor = "dance", food = "heart", art = "heart" })[character.personality] or "wave", UDim2.fromOffset(4, 4), UDim2.fromOffset(32, 32))
        UI.label(peer, "Name", character.name, UDim2.fromOffset(60, 3), UDim2.new(1, -70, 0, 42), UI.readableSize(#character.name > 27 and 17 or 20), C.text, true)
        UI.label(peer, "Online", "на связи", UDim2.fromOffset(70, 47), UDim2.new(1, -80, 0, 18), 12, C.mint)
        UI.frame(peer, "OnlineDot", UDim2.fromOffset(60, 53), UDim2.fromOffset(6, 6), C.mint, 3)
        local replyH, repliesH = phoneLayout.replyHeight, phoneLayout.repliesHeight
        log = UI.new("ScrollingFrame", { Name = "ChatLog", Position = UDim2.fromOffset(12, 109), Size = UDim2.new(1, -24, 0, phoneLayout.logHeight), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, phone)
        UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, log)
        replyArea = UI.frame(phone, "Replies", UDim2.new(0, 12, 1, -repliesH - 18), UDim2.new(1, -24, 0, repliesH), C.panel, 0); replyArea.BackgroundTransparency = 1
        for i = 1, 3 do
            local button = UI.button(replyArea, "Answer_" .. i, "", UDim2.fromOffset(0, (i - 1) * (replyH + 8)), UDim2.new(1, 0, 0, replyH), C.panel, function() options.submit(i) end)
            local answer = UI.label(button, "AnswerText", "", UDim2.fromOffset(48, 6), UDim2.new(1, -58, 1, -12), UI.readableSize(mobile and 18 or 17), C.ink, true)
            answer.Font = Enum.Font.GothamBold
            local number = UI.frame(button, "ReplyNumber", UDim2.new(0, 9, .5, -14), UDim2.fromOffset(28, 28), C.ink, 14)
            centered(number, "Number", tostring(i), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), UI.readableSize(18), C.panel, true)
            table.insert(controller.buttons, button)
        end
        UI.frame(phone, "HomeIndicator", UDim2.new(.5, -46, 1, -10), UDim2.fromOffset(92, 4), Color3.fromRGB(85, 91, 86), 2)
        local function rebuildChat(nextSession)
            for _, child in log:GetChildren() do if not child:IsA("UIListLayout") then child:Destroy() end end
            local messages = table.clone(nextSession.messages or {}); table.insert(messages, { from = "npc", text = nextSession.prompt, current = true })
            for i, message in messages do
                local row = UI.frame(log, "MessageRow_" .. i, UDim2.new(), UDim2.new(1, -4, 0, 1), C.panel, 0); row.BackgroundTransparency = 1; row.AutomaticSize = Enum.AutomaticSize.Y; row.LayoutOrder = i
                local mine = message.from == "player"
                local bubble = UI.frame(row, mine and "OutgoingMessage" or "IncomingMessage", UDim2.new(mine and .12 or 0, 0, 0, 0), UDim2.new(.88, 0, 0, 1), mine and C.aqua or C.panel, 7); bubble.AutomaticSize = Enum.AutomaticSize.Y
                UI.stroke(bubble, C.ink, .15).Thickness = 1
                local label = UI.label(bubble, "MessageText", message.text or "", UDim2.fromOffset(12, 9), UDim2.new(1, -24, 0, 1), UI.readableSize(mobile and 18 or 17), C.text); label.AutomaticSize = Enum.AutomaticSize.Y; label.TextYAlignment = Enum.TextYAlignment.Top
                UI.new("UIPadding", { PaddingBottom = UDim.new(0, 10) }, bubble)
            end
            for i, button in controller.buttons do button.AnswerText.Text = nextSession.options[i] end
            phone:SetAttribute("MessageNumber", nextSession.step)
            peer.Online.Text = "на связи · " .. nextSession.step .. "/4"
            task.defer(function() task.wait(); if alive and log.Parent then log.CanvasPosition = Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteSize.Y)) end end)
        end
        controller.updateContent = rebuildChat
    elseif session.stage == 2 then
        root.BackgroundColor3 = C.ink
        UI.pill(root, "Live", "НА СВЯЗИ", UDim2.fromOffset(16, 9), 160, C.pink).Label.TextSize = UI.readableSize(12, 10)
        counter = centered(root, "CallCounter", "", UDim2.new(1, -140, 0, 8), UDim2.fromOffset(120, 28), UI.readableSize(14, 10), C.panel, true)
        local videoH, videoW = layout.videoHeight, layout.cameraWidth
        local yours = UI.frame(root, "PlayerVideo", UDim2.fromOffset(18, 47), UDim2.fromOffset(videoW, layout.cameraHeight), C.panel, 20)
        local theirs = UI.frame(root, "BrainrotVideo", UDim2.fromOffset(layout.secondCameraX, layout.secondCameraY), UDim2.fromOffset(videoW, layout.cameraHeight), C.panel, 20)
        UI.stroke(yours, C.yellow, 0).Thickness = 4; UI.stroke(theirs, C.yellow, 0).Thickness = 4
        playerScene = addScene(yours, nil, nil, { onlyPlayer = true, closePlayer = true, emotes = true, locationId = "park" })
        npcScene = addScene(theirs, character, variant, { portrait = true, keepPortraitWidth = true, emotes = true, portraitAim = character.cameraAim, locationId = Locations.forPersonality(character.personality) == "park" and "cafe" or Locations.forPersonality(character.personality) })
        UI.pill(yours, "PlayerTag", "ТЫ · У ВОДЫ", UDim2.fromOffset(7, 8), math.min(videoW - 14, 160), C.yellow).Label.TextSize = UI.readableSize(12, 10)
        UI.pill(theirs, "BrainrotTag", mobile and "БРЕЙНРОТ" or "СОБЕСЕДНИК", UDim2.fromOffset(7, 8), math.min(videoW - 14, mobile and 130 or 190), C.yellow).Label.TextSize = UI.readableSize(12, 10)
        gestureCue = UI.frame(root, "GestureCue", UDim2.new(.5, -20, 0, 3), UDim2.fromOffset(40, 40), C.panel, 20)
        local promptPlate = UI.frame(root, "CallPromptPlate", UDim2.fromOffset(22, videoH + 52), UDim2.new(1, -44, 0, 38), C.yellow, 4)
        prompt = centered(promptPlate, "GesturePrompt", "", UDim2.fromOffset(4, 0), UDim2.new(1, -8, 1, 0), UI.readableSize(mobile and 24 or 26), C.ink, true)
        local controlsY = layout.controlsY
        for i, gesture in Locations.gestures do
            local button = UI.button(root, "Gesture_" .. i, "", UDim2.new((i - 1) / 3, 8, 0, controlsY), UDim2.new(1 / 3, -16, 0, layout.controlsHeight), C.panel, function() options.submit(i) end)
            local iconY = (layout.controlsHeight - 74) / 2
            Presentation.gestureIcon(button, gesture.id, UDim2.new(.5, -24, 0, iconY), UDim2.fromOffset(48, 48))
            centered(button, "ActionName", gesture.label, UDim2.fromOffset(2, iconY + 46), UDim2.new(1, -4, 0, 26), UI.readableSize(mobile and 16 or 17, 10), C.text, true)
            UI.stroke(button, C.yellow, 0); table.insert(controller.buttons, button)
        end
        roundDots = dots(root, 6, h - 32)
        controller.updateContent = function(nextSession)
            local gesture = Locations.gestures[nextSession.gesture]
            prompt.Text = gesture.hint; counter.Text = tostring(nextSession.attempts + 1) .. " / 6"
            if gestureCue:FindFirstChild("GestureIcon") then gestureCue.GestureIcon:Destroy() end
            Presentation.gestureIcon(gestureCue, gesture.id, UDim2.fromOffset(4, 4), UDim2.fromOffset(32, 32))
            npcScene.prompt(gesture.id)
            for i, button in controller.buttons do button.BackgroundColor3 = C.panel; button:SetAttribute("GestureId", Locations.gestures[i].id) end
            updateDots()
        end
    else
        local location = Locations.get(session.locationId)
        local immersive = options.immersive == true
        local style = Scene.style(location.id)
        root.BackgroundColor3 = Color3.fromRGB(251, 242, 218)
        if not immersive then UI.pill(root, "Location", location.name, UDim2.fromOffset(15, 8), mobile and 285 or 330, C.pink) end
        local artW, artH = immersive and w or w - 24, immersive and h or h - 100
        local art = UI.frame(root, "DateWorld", UDim2.fromOffset(immersive and 0 or 12, immersive and 0 or 47), UDim2.fromOffset(artW, artH), C.card, immersive and 0 or 20)
        dateScene = addScene(art, character, variant, {
            locationId = location.id, pair = true, interactive = true, radius = immersive and 0 or 18,
            dateTotal = total,
            itemLayout = { width = artW, height = artH, targetWidth = math.max(112, UI.touchMinimum or 0), targetHeight = math.max(immersive and 132 or 90, UI.touchMinimum or 0) },
        })
        local dateHeader = PresentationLayout.dateHeader(w, mobile, UI.touchMinimum, UI.readableSize(mobile and 21 or 30))
        if immersive then
            local title = UI.label(art, "PicnicTitle", remix and string.upper(remix.name) or (mobile and style.mobileTitle or style.title), UDim2.fromOffset(dateHeader.titleX, dateHeader.titleY), UDim2.fromOffset(dateHeader.titleWidth, dateHeader.titleHeight), UI.readableSize(mobile and 21 or 30), style.cream, true)
            title.Font = Enum.Font.GothamBlack; title.TextStrokeColor3 = style.ink; title.TextStrokeTransparency = .1
        end
        counter = centered(root, "DateCounter", "", immersive and UDim2.new(1, -100, 1, -52) or UDim2.new(1, -115, 0, 8), UDim2.fromOffset(80, 28), 14, immersive and style.ink or C.muted, true)
        counter.Visible = not immersive
        controller.dateScene = dateScene
        dateCollectionState = DateCollection.restore(session, options.dateCollectionState)
        local cue = UI.frame(art, "DateCue", immersive and UDim2.new(.5, mobile and -190 or -220, 0, dateHeader.cueY) or UDim2.new(.5, mobile and -150 or -220, 0, 10), UDim2.fromOffset(immersive and (mobile and 380 or 440) or (mobile and 300 or 440), 44), immersive and style.cream or C.panel, immersive and 4 or 14); cue.BackgroundTransparency = immersive and 0 or .08
        if immersive then
            cue.Rotation = 2; UI.stroke(cue, style.ink, .15).Thickness = 2
        end
        prompt = centered(cue, "DatePrompt", "", UDim2.fromOffset(5, 2), UDim2.new(1, -10, 1, -4), UI.readableSize(mobile and 19 or 21), immersive and style.ink or C.text, true)
        for i, item in location.items do
            local button = UI.button(art, "DateItem_" .. i, "", UDim2.fromScale(.5, .5), UDim2.fromOffset(112, immersive and 132 or 90), C.panel, function() options.submit(i) end)
            button.AnchorPoint = Vector2.new(.5, .5); button.BackgroundTransparency = 1; button.AutoButtonColor = false
            local badge = UI.frame(button, "ItemLabel", UDim2.fromOffset(0, immersive and 104 or 61), UDim2.new(1, 0, 0, 28), immersive and style.cream or C.panel, immersive and 3 or 11); badge.BackgroundTransparency = immersive and 0 or .12
            if immersive then badge.Rotation = i % 2 == 0 and 3 or -3; UI.stroke(badge, style.ink, .1) end
            centered(badge, "Name", (mobile and "" or tostring(i) .. " ") .. item.label, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), UI.readableSize(mobile and 15 or 16), immersive and style.ink or C.text, true)
            button:SetAttribute("ItemIndex", i); table.insert(controller.buttons, button)
        end
        table.insert(controller.connections, RunService.RenderStepped:Connect(function()
            if not alive or art.AbsoluteSize.X <= 0 then return end
            for i, button in controller.buttons do local p = dateScene.project(i); button.Position = UDim2.fromScale(p.X, p.Y) end
        end))
        roundDots = dots(root, total, h - (immersive and 48 or 33))
        local turnPrompt = remix and remix.cue or "Теперь твой ход"
        local function showReveal()
            local cue = DateReveal.current(revealState)
            root:SetAttribute("RevealPhase", cue.phase); root:SetAttribute("RevealIndex", cue.index); root:SetAttribute("RevealTotal", cue.total)
            root:SetAttribute("RevealPaused", cue.paused)
            dateScene.setRevealCue(cue.item)
            for i, button in controller.buttons do
                local badge = button.ItemLabel
                local selected = cue.item == i
                badge.BackgroundColor3 = selected and C.ink or (immersive and style.cream or C.panel)
                badge.BackgroundTransparency = selected and 0 or (immersive and 0 or .12)
                badge:FindFirstChild("Name").TextColor3 = selected and C.yellow or (immersive and style.ink or C.text)
                local outline = badge:FindFirstChild("UIStroke")
                if outline then
                    outline.Color = selected and C.yellow or style.ink
                    outline.Transparency = selected and 0 or .1
                end
            end
            prompt.Text = cue.finished and turnPrompt or ("Запоминай · " .. cue.index .. "/" .. cue.total .. (session.remixId == "reverse" and " · потом наоборот" or ""))
        end
        controller.updateContent = function(nextSession)
            counter.Text = tostring(nextSession.step) .. " / " .. total
            if revealState and controller.revealing then showReveal() else prompt.Text = turnPrompt end
            dateCollectionState = DateCollection.restore(nextSession, dateCollectionState)
            dateScene.setCollected(dateCollectionState)
            updateDots()
        end
        if session.step == 1 and session.sequence then
            revealState = DateReveal.mount(session.sequence, session.token, options.revealState)
            DateReveal.setPaused(revealState, options.revealPaused and options.revealPaused() or false)
            controller.revealing = not DateReveal.current(revealState).finished
            options.revealing(controller.revealing)
            showReveal()
            local revealConnection
            revealConnection = RunService.RenderStepped:Connect(function(delta)
                if not alive then revealConnection:Disconnect(); return end
                if not controller.revealing then revealConnection:Disconnect(); return end
                if DateReveal.setPaused(revealState, options.revealPaused and options.revealPaused() or false) then showReveal() end
                if DateReveal.advance(revealState, delta) then
                    showReveal()
                    if DateReveal.current(revealState).finished then
                        controller.revealing = false; options.revealing(false); controller.setLocked(controller.locked); revealConnection:Disconnect()
                    end
                end
            end)
            table.insert(controller.connections, revealConnection)
        end
    end
    function controller.setLocked(value)
        controller.locked = value; root:SetAttribute("InputLocked", value or controller.revealing)
        for _, button in controller.buttons do button.Active = not value and not controller.revealing; button.Selectable = button.Active end
    end
    local function releasePreview(keepPlayerPose)
        if not previewChoice then return end
        if playerScene then playerScene.clearPlayerPreview(keepPlayerPose) end
        if dateScene then dateScene.setPendingItem(nil) end
        if session.stage == 2 then
            for _, button in controller.buttons do button.BackgroundColor3 = C.panel end
        end
        previewChoice = nil; root:SetAttribute("PendingChoice", nil)
    end
    function controller.preview(choice)
        if not alive or controller.revealing or previewChoice or not controller.buttons[choice] then return false end
        if session.stage == 2 then
            local gesture = Locations.gestures[choice]; if not gesture then return false end
            playerScene.previewPlayer(gesture.id)
            controller.buttons[choice].BackgroundColor3 = Color3.fromRGB(232, 239, 246)
            prompt.Text = "Твой жест…"
        elseif session.stage == 3 then
            local item = dateScene.items[choice]; if not item then return false end
            dateScene.setPendingItem(choice); prompt.Text = "Выбрано: " .. item.label
        else return false end
        previewChoice = choice; root:SetAttribute("PendingChoice", choice)
        return true
    end
    function controller.clearPreview()
        if not alive or not previewChoice then return end
        releasePreview(false)
        controller.updateContent(controller.session)
    end
    function controller.update(nextSession)
        reactionState = nil
        releasePreview(false)
        if playerScene then playerScene.setPlayerConfirmation(nil) end
        controller.session = nextSession; controller.updateContent(nextSession); controller.setLocked(controller.locked)
    end
    function controller.react(choice, good, animated)
        if not alive then return end
        if type(good) ~= "boolean" then controller.clearPreview(); return end
        reactionState = { token = controller.session.token, stage = controller.session.stage,
            turn = session.stage == 2 and controller.session.attempts + 1 or controller.session.step,
            choice = choice, good = good }
        local alreadyPerformed = previewChoice == choice
        releasePreview(alreadyPerformed)
        updateDots(good, animated)
        if session.stage == 1 then if npcScene and animated ~= false then npcScene.act("npc", good and "heart" or "wave", .7) end
        elseif session.stage == 2 then
            local gesture = Locations.gestures[choice]
            playerScene.setPlayerConfirmation(gesture.id)
            if animated ~= false then
                if not alreadyPerformed then playerScene.act("player", gesture.id, .8) end
                npcScene.act("npc", good and gesture.id or "wave", .8)
            end
            prompt.Text = good and "Есть контакт! ♥" or "Ой! Попробуем следующий жест"
            local button = controller.buttons[choice]
            if button then
                button.BackgroundColor3 = good and Color3.fromRGB(196, 232, 213) or Color3.fromRGB(252, 219, 226)
                if animated ~= false then Feedback.pop(button, .94) end
            end
        else
            dateCollectionState = DateCollection.confirm(dateCollectionState, controller.session.step, choice, good)
            dateScene.setCollected(dateCollectionState, animated ~= false and controller.session.step or nil)
            if animated ~= false then dateScene.flash(choice, good); dateScene.act("both", good and "heart" or "wave", .7) end
            prompt.Text = good and "Вот это общий вайб! ♥" or "Немного импровизации!"
        end
    end
    function controller.restoreReaction(previous)
        -- A resize during the response pause must not erase an acknowledged
        -- heart/cross or replay the celebration. Never carry it to another turn.
        local turn = session.stage == 2 and controller.session.attempts + 1 or controller.session.step
        if type(previous) ~= "table" or previous.token ~= controller.session.token or previous.stage ~= session.stage
            or previous.turn ~= turn or type(previous.good) ~= "boolean" or not controller.buttons[previous.choice] then return end
        controller.react(previous.choice, previous.good, false)
    end
    function controller.dispose(destroying)
        if not alive then return end
        alive = false
        for _, connection in controller.connections do connection:Disconnect() end
        for _, scene in controller.scenes do scene.dispose() end
        if not destroying then root:Destroy() end
    end
    root.Destroying:Connect(function() controller.dispose(true) end)
    controller.update(session)
    controller.restoreReaction(options.reactionState)
    return controller
end
return Presentation
