local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")
local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Logic = require(Shared.GameLogic)
local Games = require(Shared.Minigames)
local Feel = require(Shared.Feel)
local Layout = require(Shared.Layout)
local FeedLayout = require(Shared.FeedLayout)
local PresentationLayout = require(Shared.PresentationLayout)
local Preferences = require(Shared.Preferences)
local UI = require(script.Parent.UI)
local StateCard=require(script.Parent.StateCard)
local Viewer = require(script.Parent.ModelViewer)
local Feedback = require(script.Parent.Feedback)
local Inbox = require(script.Parent.MatchInbox)
local ListReading = require(script.Parent.ListReading)
local Album = require(script.Parent.Album)
local Collection = require(Shared.Collection)
local Remix = require(Shared.DateRemix)
local Guide = require(script.Parent.Guide)
local Locations = require(Shared.Locations)
local Scene = require(script.Parent.SceneViewer)
local Presentation = require(script.Parent.GamePresentation)
local DatePlaces = require(script.Parent.DatePlaces)
local ResultCard = require(script.Parent.ResultCard)
local StoryBook = require(script.Parent.StoryBook)
local MatchLetter = require(script.Parent.MatchLetter)
local RemixBoard = require(script.Parent.RemixBoard)
local PhotoBooth = require(script.Parent.PhotoBooth)
local JourneyIdeas = require(Shared.JourneyIdeas)
local JourneyBoard = require(script.Parent.JourneyBoard)
local net = ReplicatedStorage:WaitForChild("BrainrotNet")
local request = net:WaitForChild("Request")
local changed = net:WaitForChild("Changed")
local C = UI.colors
local state = { swipes = {}, matches = {}, album = {}, pending = 0, totalLikes = 0, totalPasses = 0, feed = {} }
local activeTab, activeGame, currentCard, modal = "feed", nil, nil, nil
local albumPage,albumFocusKey,albumFocusTarget=1,nil,nil
local modalViewer = nil
local modalRebuild, restoringModal = nil, false
local busy, inputStart, dragDistance = false, nil, 0
local transportBusy, nextRequestAt = false, 0
local swiping, cardWidget, cardStamp = false, nil, nil
local views, connections, gameConnections = {}, {}, {}
local gameInputLocked = false
local dateRevealing = false
local scrollPositions = {}
local renderedListKey = nil
local pendingListRestore = nil
local renderedFeedKey,pendingFeedRestore
local emptyReading={}
local gamePresentation = nil
local gamePresentationToken, dateRevealState = nil, nil
local dateCollectionState = nil
local gameReactionState = nil
local inFlightGameInput = nil
local previewLocationId = "park"
local preferenceState, preferenceWorker = Preferences.new(), false
local savePreferences, setPreference
local actions = {}
local profileReady, startupRunning, lastLoadError = false, false, nil
local storageStatus = { state = "loading" }
local beginLoad, renderLoadScreen
local render, renderGame, refresh, startGame, showMatch, showStory, showReturn, showGuide, showResult, showRemixes, showPhotoStudio, showIdeas
local mobile = false
local width, height = 1200, 760
local playerGui = player:WaitForChild("PlayerGui")
playerGui.ScreenOrientation = StarterGui.ScreenOrientation
local rotationRequired = false
local toastFrame
local visibilityEpoch = 0
local windowFocused, robloxMenuOpen = true, GuiService.MenuIsOpen
local function revealIsPaused()
    return not windowFocused or robloxMenuOpen or rotationRequired or modal ~= nil or toastFrame ~= nil
end
local function refreshRevealPause()
    if gamePresentation and gamePresentation.refreshRevealPause then gamePresentation.refreshRevealPause() end
end
local function visibilityChanged()
    visibilityEpoch+=1
    refreshRevealPause()
end
UserInputService.WindowFocusReleased:Connect(function() windowFocused=false; visibilityChanged() end)
UserInputService.WindowFocused:Connect(function() windowFocused=true; visibilityChanged() end)
GuiService.MenuOpened:Connect(function() robloxMenuOpen=true; visibilityChanged() end)
GuiService.MenuClosed:Connect(function() robloxMenuOpen=false; visibilityChanged() end)
local backdrop = UI.new("ScreenGui", { Name = "DateABrainrotBackdrop", ScreenInsets = Enum.ScreenInsets.None, ClipToDeviceSafeArea = false, ResetOnSpawn = false, DisplayOrder = 4 }, playerGui)
UI.frame(backdrop, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.bg, 0)
local gui = UI.new("ScreenGui", { Name = "DateABrainrot", ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ResetOnSpawn = false, DisplayOrder = 5, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local background = UI.frame(gui, "Background", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.bg, 0)
local canvas = UI.frame(background, "Canvas", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(width, height), C.bg, 0)
canvas.AnchorPoint = Vector2.new(0.5, 0.5)
local scale = UI.new("UIScale", { Scale = 1 }, canvas)
local rotationOverlay = UI.frame(background, "RotatePhoneOverlay", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.bg, 0)
rotationOverlay.Visible = false; rotationOverlay.Active = true; rotationOverlay.ZIndex = 100
local rotationBox = UI.frame(rotationOverlay, "RotatePhoneDialog", UDim2.new(.5, -180, .5, -112), UDim2.fromOffset(360, 224), C.panel, 24)
local phoneIcon = UI.frame(rotationBox, "PhoneIcon", UDim2.new(.5, -15, 0, 21), UDim2.fromOffset(30, 50), C.bg, 6)
local phoneOutline = UI.stroke(phoneIcon, C.mint); phoneOutline.Thickness = 2
local phoneScreen = UI.frame(phoneIcon, "Screen", UDim2.fromOffset(5, 6), UDim2.fromOffset(20, 30), C.mint, 2); phoneScreen.BackgroundTransparency = .85
UI.frame(phoneIcon, "Home", UDim2.fromOffset(12, 41), UDim2.fromOffset(6, 3), C.mint, 1)
UI.label(rotationBox, "Title", "Поверни телефон", UDim2.fromOffset(24, 86), UDim2.new(1, -48, 0, 40), 25, C.text, true).TextXAlignment = Enum.TextXAlignment.Center
UI.label(rotationBox, "Hint", "Держи его вертикально — так удобнее свайпать. Твой раунд останется с тобой.", UDim2.fromOffset(24, 140), UDim2.new(1, -48, 0, 64), 16, C.muted).TextXAlignment = Enum.TextXAlignment.Center
local header, sidebar, body
local function cleanup()
    if inFlightGameInput and (not activeGame or activeGame.token ~= inFlightGameInput.token) then inFlightGameInput = nil end
    if gamePresentation then
        gameReactionState = activeGame and activeGame.token == gamePresentationToken and gamePresentation.getReactionState() or nil
        if activeGame and activeGame.stage == 3 and activeGame.token == gamePresentationToken then
            dateRevealState = gamePresentation.getRevealState()
            dateCollectionState = gamePresentation.getDateCollectionState()
        else dateRevealState = nil; dateCollectionState = nil end
        gamePresentation.dispose(); gamePresentation = nil; gamePresentationToken = nil
    elseif not activeGame or activeGame.stage ~= 3 then dateRevealState = nil; dateCollectionState = nil end
    if not activeGame then gameReactionState = nil end
    if not activeGame or activeGame.stage ~= 3 then dateRevealing = false end
    for _, v in views do v.dispose() end; table.clear(views)
    for _, c in connections do c:Disconnect() end; table.clear(connections)
    for _, c in gameConnections do c:Disconnect() end; table.clear(gameConnections)
end
local function mount(parent, characterId, variantId, options)
    options = options or {}
    options.userId = options.userId or state.playerUserId or player.UserId
    options.avatarSnapshot = options.avatarSnapshot or state.avatarSnapshot
    local v = options.scene and Scene.mount(parent, Logic.character(characterId), Logic.variant(variantId), options) or Viewer.mount(parent, Logic.character(characterId), Logic.variant(variantId), options)
    if not options.modal then table.insert(views, v) end; return v
end
local function toast(text, color)
    if toastFrame then toastFrame:Destroy() end
    local toastW, font = mobile and 436 or 480, UI.readableSize(16)
    local measured, bounds = pcall(function()
        return TextService:GetTextSize(text, font, Enum.Font.GothamBlack, Vector2.new(toastW - 32, 10000))
    end)
    local toastH = math.max(58, math.ceil(measured and bounds.Y or font * 4) + 20)
    local shell = FeedLayout.resolve(width, height, mobile, UI.touchMinimum)
    local y
    if activeTab == "feed" and not activeGame then
        y = (mobile and shell.actionY or shell.bodyY + shell.actionY) - 12 - toastH
    else
        y = mobile and shell.bodyY + 8 or shell.dockY - 12 - toastH
    end
    local position = UDim2.new(.5, -toastW / 2, 0, math.max(8, y))
    local f = UI.frame(canvas, "Toast", position, UDim2.fromOffset(toastW, toastH), color or C.card, 15)
    f.ZIndex = 30
    local label = UI.label(f, "Message", text, UDim2.fromOffset(16, 10), UDim2.new(1, -32, 1, -20), font, color == C.bad and C.panel or C.text, true); label.ZIndex = 31
    toastFrame = f
    refreshRevealPause()
    local elapsed,epoch=0,visibilityEpoch
    local connection
    connection=RunService.Heartbeat:Connect(function(delta)
        if toastFrame~=f or not f.Parent then
            connection:Disconnect()
            if toastFrame==f then toastFrame=nil;refreshRevealPause()end
            return
        end
        local uninterrupted=epoch==visibilityEpoch
        epoch=visibilityEpoch
        if uninterrupted and windowFocused and not robloxMenuOpen and not rotationRequired then
            elapsed+=math.clamp(delta,0,.1)
        end
        if elapsed>=3.3 then
            toastFrame=nil;f:Destroy();connection:Disconnect();refreshRevealPause()
        end
    end)
end
local pendingMatchNews, notificationScheduled = {}, false
local seenMatchNews = {}
local function notifyMatches(news)
    for _, key in news or {} do
        if not seenMatchNews[key] then pendingMatchNews[key] = true; seenMatchNews[key] = true end
    end
    if notificationScheduled or not next(pendingMatchNews) then return end
    notificationScheduled = true
    task.spawn(function()
        while gui.Parent and (busy or swiping or gameInputLocked or dateRevealing or inputStart or modal or rotationRequired or not windowFocused or robloxMenuOpen or toastFrame) do task.wait(.05) end
        if not gui.Parent then return end
        local count = 0; for _ in pendingMatchNews do count += 1 end
        table.clear(pendingMatchNews); notificationScheduled = false
        if count > 0 then
            Feedback.play("success")
            toast(count == 1 and "♥ Новый ответ! Загляни в мэтчи, когда закончишь." or ("♥ Новых ответов: " .. count .. ". Они ждут в мэтчах."), C.card)
        end
    end)
end
local errors = {
    already_swiped = "Ты уже свайпнул этот вариант.", too_fast = "Дай сигналу немного времени.",
    ready_first = "Нажми «Начать», когда будешь готов.",
    invalid_photo_style = "Не удалось выбрать эту позу или рамку.", photo_frame_locked = "Эта рамка ещё не открыта в вашей истории.",
    loading = "Ещё загружаем коллекцию…", busy = "Секунду…",
    load_failed = "Не удалось загрузить историю. Попробуй ещё раз.",
    profile_in_use = "Предыдущая сессия ещё сохраняет историю. Подожди немного.",
    unsupported_profile = "Не удалось открыть историю. Сохранение оставлено без изменений.",
    session_lost = "История открыта в другой сессии. Перезайди в игру.",
    session_expired = "Связь с сохранением потеряна. Ждём восстановления.",
    server_error = "Не получилось. Попробуй ещё раз.", memorize_first = "Сначала запомни последовательность.",
    expired_game = "Начни эту мини-игру ещё раз.",
    story_not_complete = "Сначала завершите вашу историю.", invalid_remix = "Выбери один из доступных ремиксов.",
    souvenir_locked = "Сначала заработай этот сувенир в ремиксе.", invalid_souvenir = "Выбери сувенир из вашей коллекции.",
}
local function updateStorage(value)
    local previous = storageStatus.state
    if value then
        if not (value.savedRevision and storageStatus.savedRevision and value.savedRevision < storageStatus.savedRevision) then
            storageStatus = value
        end
    end
    local shown = storageStatus.state
    if shown == "saved" and (storageStatus.savedRevision or 0) < (state.revision or 0) then shown = "saving" end
    state.storageStatus = storageStatus
    gui:SetAttribute("StorageState", shown)
    if header and header:FindFirstChild("Tagline") then
        local text = ({ saving = "Сохраняем твою историю…", retrying = "Сохранение задерживается. Подожди…", blocked = "Прогресс на паузе. Перезайди в игру." })[shown]
        header.Tagline.Text = text or "СВАЙПНИ В СВОЙ ХАОС"
        header.Tagline.TextColor3 = (shown == "retrying" or shown == "blocked") and C.bad or C.muted
        if activeGame then
            header.Tagline.Visible = shown == "retrying" or shown == "blocked"
        end
    end
    if (previous == "retrying" or previous == "blocked") and shown == "saved" then toast("Твоя история сохранена.", C.panel) end
end
local function syncPreferences()
    Feedback.applyPreferences(Preferences.effective(preferenceState))
    if header and header.Parent and header:FindFirstChild("SoundToggle") then
        header.SoundToggle.Text = Feedback.soundEnabled and "♪" or "♪ ×"
    end
    Guide.updatePreferences(modal)
end
local function applyState(result)
    if not result.swipes then updateStorage(result.storageStatus); return end
    if result.revision and state.revision and result.revision < state.revision then return end
    local oldFeed = state.feed
    local hasFeed = type(result.feed) == "table"
    result.avatarSnapshot = result.avatarSnapshot or state.avatarSnapshot
    state = result; state.feed = result.feed or oldFeed or {}
    if hasFeed then profileReady = true end
    Preferences.receive(preferenceState, result.preferences); syncPreferences()
    updateStorage(result.storageStatus)
    if savePreferences then savePreferences() end
end
local function rpc(action, args, quiet, backgroundRequest)
    if busy then return nil, "busy" end
    if backgroundRequest then
        if transportBusy or os.clock() < nextRequestAt then return nil, "busy" end
    else
        busy = true
        -- A preference save must not swallow the next gameplay click. Reserve
        -- that action and send it as soon as the background request finishes.
        while transportBusy or os.clock() < nextRequestAt do task.wait() end
    end
    transportBusy = true
    local ok, result = pcall(function() return request:InvokeServer(action, args or {}) end)
    transportBusy = false; nextRequestAt = os.clock() + .07
    if not backgroundRequest then busy = false end
    if not ok or type(result) ~= "table" then
        if not quiet then toast("Связь прервалась. Попробуй ещё раз.", C.bad) end
        return nil, "connection_failed"
    end
    if result.error then
        if result.error == "session_lost" or result.error == "session_expired" then
            updateStorage({ state = "blocked", savedRevision = storageStatus.savedRevision })
        end
        if not quiet then toast(errors[result.error] or "Попробуй ещё раз.", C.bad) end
        return nil, result.error
    end
    applyState(result)
    return result
end
savePreferences = function()
    if preferenceWorker or not next(preferenceState.pending) then return end
    preferenceWorker = true
    task.spawn(function()
        local warned = false
        while gui.Parent and next(preferenceState.pending) do
            task.wait(.35)
            if not gui.Parent then break end
            if not profileReady or busy or gameInputLocked or swiping or inputStart then continue end
            local changes, receipt = Preferences.request(preferenceState)
            local result, err = rpc("preferences", changes, true, true)
            if not gui.Parent then break end
            if result then
                Preferences.acknowledge(preferenceState, receipt); syncPreferences(); warned = false
            elseif err ~= "busy" and err ~= "too_fast" then
                if not warned then toast("Настройки действуют до выхода. Сохранение пока недоступно.", C.bad); warned = true end
                if err == "session_lost" or err == "session_expired" or err == "store_unavailable" or err == "invalid_request" or err == "unknown_action" then break end
                task.wait(3)
            end
        end
        preferenceWorker = false
    end)
end
setPreference = function(key, value)
    if not Preferences.choose(preferenceState, key, value) then return end
    syncPreferences(); savePreferences()
end
local function countUnread()
    local n = 0; for _, m in state.matches do if m.unread then n += 1 end end; return n
end
local function getMatch(key)
    for _, m in state.matches do if m.key == key then return m end end
end
local function closeModal()
    modalRebuild = nil
    if modalViewer then modalViewer.dispose(); modalViewer = nil end
    if modal then modal:Destroy(); modal = nil end
end
local function nav(tab,photoKey)
    if not profileReady then return end
    if busy or swiping or gameInputLocked then return end
    if activeGame then rpc("cancelGame"); activeGame = nil end
    albumFocusKey=nil
    if tab=="album" and photoKey then
        for index,photo in state.album do
            if photo.key==photoKey then albumPage=math.ceil(index/6);albumFocusKey=photoKey;break end
        end
    end
    closeModal(); activeTab = tab; render()
end
local function buildShell()
    UI.clear(canvas)
    local shellLayout = FeedLayout.resolve(width, height, mobile, UI.touchMinimum)
    local settingsSize = shellLayout.headerButtonSize
    header = UI.frame(canvas, "Header", UDim2.fromOffset(26, 16), UDim2.new(1, -52, 0, 70), C.bg, 0)
    local brand = UI.label(header, "Logo", "BRAINROT ♥", UDim2.fromOffset(0, 0), UDim2.fromOffset(mobile and 276 or 550, 40), mobile and 30 or 35, C.pink, true)
    brand.Rotation = -2
    brand.Size = UDim2.new(1, -settingsSize * 2 - 22, 0, 40); brand.TextScaled = true
    UI.new("UITextSizeConstraint", { MinTextSize = 18, MaxTextSize = mobile and 30 or 35 }, brand)
    UI.label(header, "Tagline", "СВАЙПНИ В СВОЙ ХАОС", UDim2.fromOffset(0, 43), UDim2.new(1, -settingsSize * 2 - 22, 0, 22), 12, C.muted, true)
    updateStorage()
    if not mobile then UI.pill(header, "CollectionBadge", "34 БРЕЙНРОТА · 4 ВАЙБА", UDim2.new(1, -357, 0, 7), 207, C.purple) end
    UI.button(header, "GuideButton", "?", UDim2.new(1, -settingsSize * 2 - 10, 0, 0), UDim2.fromOffset(settingsSize, settingsSize), C.panel, function() showGuide() end).TextSize = 24
    local sound = UI.button(header, "SoundToggle", Feedback.soundEnabled and "♪" or "♪ ×", UDim2.new(1, -settingsSize, 0, 0), UDim2.fromOffset(settingsSize, settingsSize), C.panel, function()
        setPreference("soundEnabled", not Feedback.soundEnabled)
    end); sound.TextSize = 23
    local dockW = mobile and 436 or 700
    sidebar = UI.frame(canvas, "Navigation", UDim2.fromOffset(mobile and 22 or (width - dockW) / 2, shellLayout.dockY), UDim2.fromOffset(dockW, shellLayout.dockHeight), C.bg, 0)
    sidebar.BackgroundTransparency = 1
    local feed = activeTab == "feed" and not activeGame
    if mobile then
        body = UI.new("ScrollingFrame", { Name = "Body", Position = UDim2.fromOffset(22, shellLayout.bodyY), Size = UDim2.new(1, -44, 0, feed and shellLayout.bodyHeight or shellLayout.dockY - shellLayout.bodyY - 18), BackgroundColor3 = C.bg, BorderSizePixel = 0, ScrollBarThickness = (activeGame or (feed and shellLayout.scrollable)) and 3 or 0, CanvasSize = UDim2.fromOffset(0, feed and shellLayout.cardHeight or 0), ScrollingEnabled = activeGame ~= nil or (feed and shellLayout.scrollable), ClipsDescendants = not feed or shellLayout.scrollable, ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable }, canvas)
    elseif activeGame and activeGame.stage == 1 then
        body = UI.new("ScrollingFrame", { Name = "Body", Position = UDim2.fromOffset(26, 106), Size = UDim2.fromOffset(width - 52, height - 214), BackgroundColor3 = C.bg, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.fromOffset(0, 0), ScrollingEnabled = false, ScrollingDirection = Enum.ScrollingDirection.Y }, canvas)
    else
        body = UI.frame(canvas, "Body", UDim2.fromOffset(26, 106), UDim2.fromOffset(width - 52, height - 214), C.bg, 0)
    end
    local labels = {
        { "feed", "♥  Свайпы" },
        { "matches", "Знакомства" .. (profileReady and ("  " .. #state.matches) or "") },
        { "album", "Селфи" .. (profileReady and ("  " .. #state.album) or "") },
    }
    for i, item in labels do
        local selected = activeTab == item[1]
        local b = UI.button(sidebar, "Nav_" .. item[1], item[2], UDim2.new((i - 1) / 3, 6, 0, 6), UDim2.new(1 / 3, -12, 1, -12), selected and C.yellow or C.panel, function() nav(item[1]) end)
        b.TextSize = mobile and 15 or 17
        b.TextColor3 = C.ink
        if selected then b.Rotation = i == 2 and 1 or -2; UI.stroke(b, C.ink).Thickness = 3 end
        if item[1] == "matches" and countUnread() > 0 then UI.frame(b, "UnreadDot", UDim2.new(1, -12, 0, 4), UDim2.fromOffset(8, 8), C.pink, 4) end
    end
    if not mobile and state.studio then
        UI.button(canvas, "ReturnLater", "+10 минут", UDim2.fromOffset(26, height - 80), UDim2.fromOffset(136, 46), C.card, function() actions.returnLater(600) end)
        UI.button(canvas, "ReturnTomorrow", "+24 часа", UDim2.new(1, -162, 1, -80), UDim2.fromOffset(136, 46), C.card, function() actions.returnLater(86400) end)
    end
end
local function empty(parent, title, description, buttonText, callback)
    local contentWidth=mobile and math.max(436,(UI.availableWidth or 480)-44) or width-52
    local contentHeight=mobile and FeedLayout.resolve(width,height,mobile,UI.touchMinimum).dockY-parent.Position.Y.Offset-18 or parent.Size.Y.Offset
    parent.Position=UDim2.fromOffset((width-contentWidth)/2,parent.Position.Y.Offset)
    parent.Size=UDim2.fromOffset(contentWidth,contentHeight)
    if parent:IsA("ScrollingFrame")then
        parent.ScrollingEnabled=false;parent.ScrollBarThickness=0;parent.CanvasSize=UDim2.fromOffset(0,0)
    end
    local key=title.."\n"..description
    StateCard.mount(parent,{mobile=mobile,title=title,note=description,icon=profileReady and "photo" or "clock",
        actionText=buttonText,action=callback,scrollPosition=emptyReading[key],scrolled=function(position)emptyReading[key]=position end})
end
renderLoadScreen = function()
    UI.clear(body)
    gui:SetAttribute("LoadState", lastLoadError or "loading")
    if lastLoadError then
        empty(body, "История подождёт тебя", errors[lastLoadError] or "Проверь соединение и попробуй снова.", "Попробовать снова", function() beginLoad(true) end)
    else empty(body, "Знакомство начинается…", "Загружаем персонажей и твою историю.") end
end
local function setCardVariant(id)
    if not currentCard or busy or swiping or modal then return end
    if id==currentCard.variantId or not Logic.variant(id) or state.swipes[Logic.key(currentCard.characterId,id)] then return end
    currentCard.variantId = id; render()
end
local function swipe(liked)
    if activeTab ~= "feed" or activeGame or modal or not currentCard or busy or swiping then return end
    local c, v = Logic.character(currentCard.characterId), Logic.variant(currentCard.variantId)
    if state.swipes[Logic.key(c.id, v.id)] then toast("Этот вариант уже просмотрен. Выбери другой."); return end
    swiping = true; inputStart = nil
    local card = cardWidget; local started = os.clock()
    local direction = liked and 1 or -1
    Feedback.play(liked and "like" or "pass")
    if card and card.Parent then
        if cardStamp then cardStamp.Text = liked and "НРАВИТСЯ ♥" or "ПОКА! ×"; cardStamp.TextColor3 = liked and C.mint or C.pink; cardStamp.TextTransparency = 0 end
        Feedback.tween(card, 0.23, { Position = UDim2.fromOffset(direction * (card.Size.X.Offset + 160), -35), Rotation = direction * 18 }, Enum.EasingStyle.Quad)
    end
    local result = rpc("swipe", { characterId = c.id, variantId = v.id, liked = liked })
    if not result then
        swiping = false
        if card and card.Parent then Feedback.tween(card, 0.35, { Position = UDim2.fromOffset(0, 0), Rotation = 0 }, Enum.EasingStyle.Back); if cardStamp then cardStamp.TextTransparency = 1 end end
        return
    end
    if Feedback.motionEnabled then task.wait(math.max(0, 0.23 - (os.clock() - started))) end
    currentCard = nil; swiping = false; render()
    if result.result == "matched" then showMatch(result.lastKey)
    elseif result.result == "pending" then toast("♥ Лайк улетел. Ответ может прийти позже.", C.card)
    elseif result.result == "declined" then toast("Вайб разминулся. Следующий персонаж уже машет тебе.", C.card) end
end
actions.swipe = swipe
actions.setVariant = setCardVariant
actions.undoPass = function()
    if busy or swiping or activeGame or modal then return end
    local result = rpc("undoPass")
    if not result then return end
    currentCard = result.restored; render(); Feedback.play("reveal")
    toast("Карточка вернулась. Можно выбрать другой ответ.", C.card)
end
local function renderFeed()
    if currentCard and state.swipes[Logic.key(currentCard.characterId, currentCard.variantId)] then currentCard = nil end
    if not currentCard then
        for _, card in state.feed do
            if not state.swipes[Logic.key(card.characterId, card.variantId)] then currentCard = table.clone(card); break end
        end
    end
    if not currentCard then
        local description, destination = "Можно вернуться к вашим историям и открыть новые места для свиданий.", "album"
        for _, match in state.matches do
            if match.stage <= 3 then description = "У тебя есть знакомство, которое можно продолжить. Следующий шаг уже ждёт."; destination = "matches"; break end
        end
        if state.pending > 0 then description = "Некоторые сердечки ещё в пути. Ответы могут прийти, пока тебя нет."; destination = "matches"
        elseif #state.album == 0 and #state.matches == 0 then
            description = state.lastPass and "Все варианты уже просмотрены. Последнюю пропущенную карточку ещё можно вернуть." or "Не каждый лайк становится взаимным. Отправленные сердечки остались в знакомствах."
            destination = "matches"
        end
        empty(body, "Ты просмотрел всю коллекцию", description, state.lastPass and "Вернуть последнюю карточку" or (destination == "album" and "Открыть истории" or "Открыть знакомства"), state.lastPass and actions.undoPass or function() nav(destination) end)
        return
    end
    local character, variant = Logic.character(currentCard.characterId), Logic.variant(currentCard.variantId)
    local rarity = Config.Rarities[character.rarity]
    local baseLayout=FeedLayout.resolve(width,height,mobile,UI.touchMinimum,{availableWidth=UI.availableWidth})
    local nameFont=UI.readableSize(#character.name>27 and 20 or 25)
    local bioFont=UI.readableSize(mobile and 16 or 15)
    local variantFont=UI.readableSize(13,10)
    local badgeFont=UI.readableSize(12,10)
    local nameH=UI.textHeight(character.name,nameFont,baseLayout.cardWidth-36,true)
    local bioH=UI.textHeight(character.bio,bioFont,baseLayout.cardWidth-36,false)
    local rarityW=math.min(200,math.floor((baseLayout.cardWidth-50)*.4))
    local chanceW=math.min(340,baseLayout.cardWidth-50-rarityW)
    local chanceText=("ВЗАИМНОСТЬ %d%%"):format(math.floor(Logic.chance(character.id,variant.id)*100+.5))
    local badgeH=math.max(28,UI.textHeight(rarity.label,badgeFont,rarityW-14,true)+8,UI.textHeight(chanceText,badgeFont,chanceW-14,true)+8)
    local variantH=0
    local variantLabels={}
    for i,label in {"База","Золото","Неон","Космос"}do
        variantLabels[i]=label..(state.swipes[Logic.key(character.id,Config.Variants[i].id)] and " ✓" or "")
        variantH=math.max(variantH,UI.textHeight(variantLabels[i],variantFont,baseLayout.variantWidth-12,true)+12)
    end
    local feedLayout=FeedLayout.resolve(width,height,mobile,UI.touchMinimum,{availableWidth=UI.availableWidth,
        captionHeight=nameH+bioH+18,badgeHeight=badgeH,variantHeight=variantH,figureHeight=math.max(160,math.ceil(80/(UI.scale or 1)))})
    local cardW, cardH = feedLayout.cardWidth, feedLayout.cardHeight
    if mobile then
        body.Position=UDim2.fromOffset((width-cardW)/2,feedLayout.bodyY)
        body.Size=UDim2.fromOffset(cardW,feedLayout.bodyHeight)
        body.ScrollingEnabled=feedLayout.scrollable;body.ScrollBarThickness=feedLayout.scrollable and 3 or 0
        body.ClipsDescendants=feedLayout.scrollable
    end
    local x = 0
    local backCard = UI.frame(body, "NextCardStack", UDim2.fromOffset(12, 13), UDim2.fromOffset(cardW - 24, cardH - 12), C.card, 24)
    backCard.Rotation = 2
    local card = UI.frame(body, "SwipeCard", UDim2.fromOffset(x, 0), UDim2.fromOffset(cardW, cardH), C.panel, 24)
    card.ZIndex = 3
    cardWidget = card
    card.ClipsDescendants = false
    local artH = feedLayout.artHeight
    local art = UI.frame(card, "Portrait", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, artH - 8), C.aqua, 3)
    local figureArt = art
    if feedLayout.variantRows > 1 then
        local top = 18 + feedLayout.variantRows * (feedLayout.variantHeight + 6)
        figureArt = UI.frame(art, "CompactFigureStage", UDim2.fromOffset(0, top), UDim2.new(1, 0, 1, -top - badgeH-14), C.aqua, 0)
    end
    local view = mount(figureArt, character.id, variant.id, { scene = true, locationId = Locations.forPersonality(character.personality), loadingTop = feedLayout.variantRows == 1 and feedLayout.variantHeight + 22 or 10 })
    local tapGesture = ({ music = "dance", humor = "dance", food = "heart", art = "heart" })[character.personality] or "wave"
    -- Keep a tap readable even on figures without arm bones. The same small
    -- icon remains available in calm mode, without particles or movement.
    local tapCueY = feedLayout.variantRows > 1 and 12 or feedLayout.variantHeight + 18
    local tapCue = Presentation.gestureIcon(figureArt, tapGesture, UDim2.new(.5, -24, 0, tapCueY), UDim2.fromOffset(48, 48))
    tapCue.Name = "CharacterTapCue"; tapCue.ZIndex = 4; tapCue.Visible = false
    local tapCueVersion = 0
    local stampFont=UI.readableSize(34)
    local stampH=math.max(68,UI.textHeight("НРАВИТСЯ ♥",stampFont,cardW-56,true)+8)
    cardStamp = UI.label(art, "SwipeStamp", "НРАВИТСЯ ♥", UDim2.fromOffset(20, 18+feedLayout.variantRows*(feedLayout.variantHeight+6)), UDim2.new(1, -40, 0, stampH), stampFont, C.mint, true)
    cardStamp.TextTransparency = 1; cardStamp.TextXAlignment = Enum.TextXAlignment.Center; cardStamp.Rotation = -8; cardStamp.ZIndex = 4
    local rarityBadge=UI.pill(art,"Rarity",rarity.label,UDim2.new(0,12,1,-badgeH-8),rarityW,UI.rgb(rarity.color))
    rarityBadge.Size=UDim2.fromOffset(rarityW,badgeH);rarityBadge.Label.TextSize=badgeFont
    local chanceBadge=UI.pill(art,"Chance",chanceText,UDim2.new(1,-chanceW-12,1,-badgeH-8),chanceW,C.yellow)
    chanceBadge.Size=UDim2.fromOffset(chanceW,badgeH);chanceBadge.Label.TextSize=badgeFont
    UI.label(card,"CharacterName",character.name,UDim2.fromOffset(18,artH+4),UDim2.new(1,-36,0,nameH),nameFont,C.ink,true)
    UI.label(card,"Bio",character.bio,UDim2.fromOffset(18,artH+nameH+10),UDim2.new(1,-36,0,bioH),bioFont,C.muted)
    for i, v in Config.Variants do
        local variantWidth = feedLayout.variantWidth
        local selected = variant.id == v.id
        local viewed=state.swipes[Logic.key(character.id,v.id)]~=nil
        local column, row = (i - 1) % feedLayout.variantColumns, math.floor((i - 1) / feedLayout.variantColumns)
        local b = UI.button(art, "Variant_" .. v.id,variantLabels[i], UDim2.fromOffset(12 + column * (variantWidth + 6), 12 + row * (feedLayout.variantHeight + 6)), UDim2.fromOffset(variantWidth, feedLayout.variantHeight), selected and C.yellow or (viewed and C.bg or C.panel), function() setCardVariant(v.id) end)
        b.TextSize = variantFont;b.TextWrapped=true
        b.Active=not viewed;b.Selectable=not viewed;b.AutoButtonColor=not viewed
        b.TextColor3=viewed and C.muted or C.ink;b:SetAttribute("Viewed",viewed)
        b.ZIndex = 4
        if selected then b.Rotation = -2; UI.stroke(b, C.ink).Thickness = 3 end
    end
    local controls = card
    local actionY = feedLayout.actionY
    if mobile then
        controls = UI.frame(canvas, "FeedActions", UDim2.fromOffset(22, feedLayout.actionY), UDim2.fromOffset(436, feedLayout.actionHeight), C.bg, 0)
        actionY = 0
    end
    local actionW = mobile and feedLayout.actionWidth or (cardW - 60) / 2
    local pass = UI.button(controls, "Pass", "×   МИМО", UDim2.fromOffset(mobile and 0 or 24, actionY), UDim2.fromOffset(actionW, feedLayout.actionHeight), C.panel, function() swipe(false) end)
    pass.TextSize = UI.readableSize(mobile and 24 or 22);pass.TextWrapped=true
    local like = UI.button(controls, "Like", "♥   ЛАЙК", UDim2.fromOffset(mobile and feedLayout.likeX or cardW / 2 + 6, actionY), UDim2.fromOffset(actionW, feedLayout.actionHeight), C.pink, function() swipe(true) end); like.TextColor3 = C.panel; like.TextSize = pass.TextSize;like.TextWrapped=true
    if mobile then
        local undo = UI.button(controls, "UndoPass", "←", UDim2.fromOffset(feedLayout.undoX, 0), UDim2.fromOffset(feedLayout.undoWidth, feedLayout.actionHeight), C.yellow, actions.undoPass)
        undo.TextSize = 31; undo.Active = state.lastPass ~= nil; undo.Selectable = undo.Active; undo.TextTransparency = undo.Active and 0 or .55
    end
    if not mobile then
        local asideW = width - 52 - 638
        local aside = UI.frame(body, "FeedNotes", UDim2.fromOffset(638, 0), UDim2.fromOffset(asideW, cardH), C.bg, 0)
        UI.label(aside, "PlacesTitle", "Куда пойдём?", UDim2.fromOffset(4, 0), UDim2.new(1, -8, 0, 42), 29, C.text, true)
        for i, location in Locations.list do
            local tile = UI.frame(aside, "Destination_" .. location.id, UDim2.new((i - 1) / 3, 4, 0, 57), UDim2.new(1 / 3, -12, 0, 167), C.panel, 18)
            local view = Scene.mount(tile, nil, nil, { locationId = location.id }); table.insert(views, view)
            local selected = previewLocationId == location.id
            local outline = UI.stroke(tile, selected and C.mint or C.line, selected and 0 or .65)
            outline.Thickness = selected and 3 or 1
            UI.pill(tile, "Name", (selected and "✓  " or "") .. location.short, UDim2.new(0, 5, 1, -38), (asideW / 3) - 30, selected and C.mint or C.purple)
            local select = UI.button(tile, "PreviewLocation_" .. location.id, "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.panel, function()
                if busy or swiping or modal or inputStart or previewLocationId == location.id then return end
                previewLocationId = location.id; render(); Feedback.play("reveal")
            end)
            select.BackgroundTransparency = 1; select.ZIndex = 3
        end
        local me = UI.frame(aside, "YourWorld", UDim2.fromOffset(4, 242), UDim2.new(1, -8, 0, cardH - 246), C.panel, 23)
        local figure = Scene.mount(me, nil, nil, { onlyPlayer = true, userId = state.playerUserId or player.UserId, avatarSnapshot = state.avatarSnapshot, locationId = previewLocationId }); table.insert(views, figure)
        UI.pill(me, "PlayerName", "ТЫ · " .. Locations.get(previewLocationId).short, UDim2.fromOffset(14, 12), math.min(190, asideW - 175), C.mint)
        local pending = UI.frame(me, "PendingPanel", UDim2.new(1, -145, 0, 12), UDim2.fromOffset(131, 28), C.panel, 12)
        UI.label(pending, "Label", "Ждём ответ:", UDim2.fromOffset(8, 0), UDim2.fromOffset(98, 28), 12, C.muted)
        UI.label(pending, "PendingNumber", tostring(state.pending), UDim2.new(1, -28, 0, 0), UDim2.fromOffset(24, 28), 14, C.purple, true)
        -- Preserve the counter's existing update path while the graphic lives inside the world.
        pending.Parent = aside; pending.Position = UDim2.fromOffset(asideW - 149, 254)
        local wavePosition = state.lastPass and UDim2.new(1, -180, 1, -65) or UDim2.new(.5, -85, 1, -65)
        UI.button(me, "WaveAtCamera", "Помахать!", wavePosition, UDim2.fromOffset(170, 48), C.panel, function() figure.act("player", "wave"); Feedback.play("reveal") end)
        if state.lastPass then UI.button(aside, "UndoPass", "←  Вернуть карточку", UDim2.fromOffset(10, cardH - 64), UDim2.fromOffset(180, 48), C.panel, actions.undoPass) end
    else
        body.CanvasSize = UDim2.fromOffset(0, cardH)
    end
    local touch = UI.new("TextButton", { Name = "DragSurface", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Active = true, ZIndex = 2 }, art)
    local dragInput, lastX, lastTime, velocity = nil, 0, 0, 0
    local function cancelDrag()
        if not inputStart then return end
        inputStart = nil; dragInput = nil; dragDistance = 0; velocity = 0
        if card.Parent then
            card.Position = UDim2.fromOffset(x, 0); card.Rotation = 0
            cardStamp.TextTransparency = 1
            if view.look then view.look(0) end
        end
    end
    table.insert(connections, UserInputService.WindowFocusReleased:Connect(cancelDrag))
    touch.InputBegan:Connect(function(input)
        if busy or swiping or modal or inputStart then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            inputStart = input.Position; dragDistance = 0; dragInput = input; lastX = 0; lastTime = os.clock(); velocity = 0
        end
    end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if inputStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput) then
            dragDistance = (input.Position.X - inputStart.X) / scale.Scale
            local vertical = (input.Position.Y - inputStart.Y) / scale.Scale
            if math.abs(vertical) > 24 and math.abs(vertical) > math.abs(dragDistance) * 1.3 then
                cancelDrag(); return
            end
            local now = os.clock(); velocity = (dragDistance - lastX) / math.max(now - lastTime, 0.008); lastX = dragDistance; lastTime = now
            local px, py, rotation, strength = Feel.pose(dragDistance, (input.Position.Y - inputStart.Y) / scale.Scale, cardW)
            card.Rotation = rotation; card.Position = UDim2.fromOffset(x + px, py)
            if view.look then view.look(dragDistance / cardW * 0.35) end
            cardStamp.Text = dragDistance >= 0 and "НРАВИТСЯ ♥" or "ПОКА! ×"; cardStamp.TextColor3 = dragDistance >= 0 and C.mint or C.pink
            cardStamp.TextTransparency = 1 - strength
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if inputStart and input == dragInput then
            inputStart = nil
            if view.look then view.look(0) end
            local delta = dragDistance; dragDistance = 0
            if os.clock() - lastTime > 0.12 then velocity = 0 end
            local direction = Feel.direction(delta, velocity, cardW)
            if direction ~= 0 then swipe(direction > 0)
            else
                Feedback.tween(card, 0.36, { Rotation = 0, Position = UDim2.fromOffset(x, 0) }, Enum.EasingStyle.Back)
                Feedback.tween(cardStamp, 0.15, { TextTransparency = 1 })
                if math.abs(delta) < 8 then
                    view.act("npc", tapGesture, 1.5); Feedback.play("reveal")
                    tapCueVersion += 1; local currentTap = tapCueVersion
                    tapCue.Visible = true; Feedback.pop(tapCue, .82)
                    task.delay(1.5, function()
                        if tapCue.Parent and tapCueVersion == currentTap then tapCue.Visible = false end
                    end)
                end
            end
        end
    end))
    Feedback.pop(card, 0.98)
    if view.tracks.idle then gui:SetAttribute("CurrentIdleLoaded", true) end
end
local listPage, inboxFilter = 1, "matches"
local function renderMatches()
    Inbox.render(body, state, mobile, inboxFilter, listPage, {
        mount = mount,
        filter = function(value) inboxFilter = value; listPage = 1; render() end,
        page = function(value) listPage = value; render() end,
        feed = function() nav("feed") end,
        open = function(key, stage) if stage > 3 then nav("album",key); showStory(key) else startGame(key) end end,
    })
end
showGuide = function(scrollPosition)
    if busy or swiping or gameInputLocked then return end
    closeModal()
    modal = Guide.open(canvas, mobile, function() closeModal(); render() end, {
        placeVersion=state.placeVersion,storageMode=state.storageMode,setPreference=setPreference,
        stage=activeGame and activeGame.stage,remixId=activeGame and activeGame.remixId,
        availableHeight=height,availableWidth=UI.availableWidth,scrollPosition=scrollPosition,
        scrolled=function(position)scrollPosition=position end,
        ideas=not activeGame and function()
            if busy or swiping or gameInputLocked or activeGame then return end
            closeModal();showIdeas()
        end or nil,
    })
    modalRebuild = function() showGuide(scrollPosition) end
end
actions.guide = showGuide
local function renderAlbum()
    local location=Album.render(body, state, mobile, albumPage, {
        focusKey=albumFocusKey,
        mount = mount,
        matches = function() nav("matches") end,
        page = function(value) albumFocusKey=nil; albumPage = value; render() end,
        open = function(key) showStory(key) end,
        ideas = function() showIdeas() end,
    })
    if location then
        albumPage=location.page
        albumFocusTarget=location.focusFrame
    end
end
showIdeas = function(scrollPosition,ideaOffset)
    ideaOffset=ideaOffset or 0
    closeModal();modalRebuild=function()showIdeas(scrollPosition,ideaOffset)end
    modal=UI.overlay(canvas,"JourneyOverlay",.04)
    local ideas,hasMore=JourneyIdeas.build(state,ideaOffset)
    modalViewer=JourneyBoard.mount(modal,ideas,{
        mobile=mobile,availableHeight=height,availableWidth=UI.availableWidth,scrollPosition=scrollPosition,
        scrolled=function(position)scrollPosition=position end,
        mount=mount,back=closeModal,
        more=hasMore and function()if not busy then showIdeas(nil,ideaOffset+1)end end or nil,
        choose=function(idea)
            if busy then return end
            closeModal()
            if idea.kind=="continue" then startGame(idea.key)
            elseif idea.kind=="travel" then startGame(idea.key,3,idea.locationId)
            elseif idea.kind=="remix" then startGame(idea.key,3,idea.locationId,idea.remixId)
            elseif idea.kind=="perfect" then startGame(idea.key,idea.practiceStage)
            elseif idea.kind=="photo" then nav("album",idea.key);showPhotoStudio(idea.key)
            elseif idea.kind=="discover" then nav("feed")
            else nav("matches") end
        end,
    })
    if not restoringModal then Feedback.pop(modalViewer.frame,.94)end
end
showStory = function(key,scrollPosition)
    local photo
    for _, item in state.album do if item.key == key then photo = item; break end end
    if not photo then return end
    local character, variant = Logic.character(photo.characterId), Logic.variant(photo.variantId)
    closeModal()
    modalRebuild = function() showStory(key,scrollPosition) end
    modal = UI.overlay(canvas, "StoryOverlay", .06)
    modalViewer = StoryBook.mount(modal, character, variant, photo, {
        mobile = mobile, availableHeight = height, availableWidth = UI.availableWidth, userId = state.playerUserId,
        mount = function(art, options) return mount(art, character.id, variant.id, options) end,
        scrollPosition=scrollPosition,scrolled=function(position)scrollPosition=position end,
        back = function()if not busy then closeModal()end end,
        editPhoto = function()if not busy then showPhotoStudio(key)end end,
        replay = function(stage)if busy then return end;closeModal();startGame(key,stage)end,
        dateAgain = function()if busy then return end;closeModal();startGame(key,3)end,
        remixes = function()if not busy then showRemixes(key)end end,
    })
    if not restoringModal then Feedback.pop(modalViewer.frame, .93) end
end
showPhotoStudio = function(key, selection)
    local photo
    for _,item in state.album do if item.key==key then photo=item;break end end
    if not photo then return end
    local character,variant=Logic.character(photo.characterId),Logic.variant(photo.variantId)
    closeModal();modalRebuild=function()showPhotoStudio(key,selection)end
    modal=UI.overlay(canvas,"PhotoBoothOverlay",.04)
    modalViewer=PhotoBooth.mount(modal,photo,{
        mobile=mobile,availableHeight=height,availableWidth=UI.availableWidth,selection=selection,
        mount=function(art,options)return mount(art,character.id,variant.id,options)end,
        changed=function(value)selection=value end,
        back=function()if not busy then showStory(key)end end,
        save=function(poseId,frameId)
            if busy then return end
            modalViewer.setSaving(true)
            local response=rpc("stylePhoto",{key=key,poseId=poseId,frameId=frameId})
            if response then showStory(key);toast("Фото обновлено ♥",C.panel)
            elseif modalViewer and modalViewer.setSaving then modalViewer.setSaving(false) end
        end,
    })
    modalViewer.setSaving(busy)
    if not restoringModal then Feedback.pop(modalViewer.frame,.96) end
end
showRemixes = function(key, scrollPosition)
    local photo
    for _, item in state.album do if item.key == key then photo = item; break end end
    if not photo then return end
    closeModal(); modalRebuild = function() showRemixes(key, scrollPosition) end
    modal = UI.overlay(canvas, "RemixOverlay", .06)
    modalViewer = RemixBoard.mount(modal, photo, {
        mobile = mobile, availableHeight = height, availableWidth = UI.availableWidth,
        scrollPosition = scrollPosition, scrollChanged = function(position) scrollPosition = position end,
        play = function(locationId, remixId) startGame(key, 3, locationId, remixId) end,
        pin = function(souvenirId)
            if rpc("pinSouvenir", {key = key, souvenirId = souvenirId}) then showRemixes(key, scrollPosition) end
        end,
        back = function() showStory(key) end,
    })
    if not restoringModal then Feedback.pop(modalViewer.frame, .94) end
end
showMatch = function(key,scrollPosition)
    local m = getMatch(key); if not m then return end
    local c, v = Logic.character(m.characterId), Logic.variant(m.variantId)
    closeModal()
    modalRebuild = function() showMatch(key,scrollPosition) end
    modal = UI.overlay(canvas, "MatchOverlay", .08)
    modalViewer = MatchLetter.mount(modal, c, v, {
        mobile = mobile, availableHeight = height, availableWidth=UI.availableWidth,
        scrollPosition=scrollPosition,scrolled=function(value)scrollPosition=value end,
        mount = function(art, options) return mount(art, c.id, v.id, options) end,
        back = closeModal,
        accept = function() closeModal(); startGame(key) end,
    })
    if not restoringModal then Feedback.play("success"); Feedback.pop(modalViewer.frame, .88); Feedback.burst(modal, width / 2, height / 2 - 80, C.mint, 18) end
end
showReturn = function(news,scrollPosition)
    if not news or #news == 0 then return end
    local fresh, included = {}, {}
    for _, key in news do
        if not included[key] and getMatch(key) and (restoringModal or not seenMatchNews[key]) then
            table.insert(fresh, key); included[key] = true
        end
    end
    if #fresh == 0 then return end
    news = fresh
    local match = getMatch(news[1]); if not match then return end
    local character, variant = Logic.character(match.characterId), Logic.variant(match.variantId)
    for _, key in news do seenMatchNews[key] = true end
    closeModal()
    modalRebuild = function() showReturn(news,scrollPosition) end
    modal = UI.overlay(canvas, "ReturnOverlay", .06)
    modalViewer = MatchLetter.mount(modal, character, variant, {
        mobile = mobile, availableHeight = height, availableWidth=UI.availableWidth, returning = true, count = #news,
        scrollPosition=scrollPosition,scrolled=function(value)scrollPosition=value end,
        mount = function(art, options) return mount(art, character.id, variant.id, options) end,
        back = closeModal,
        accept = function() inboxFilter = "matches"; closeModal(); nav("matches") end,
    })
    if not restoringModal then Feedback.play("success"); Feedback.pop(modalViewer.frame, .90); Feedback.burst(modal, width / 2, height / 2 - 70, C.pink, 15) end
end
local function completeGame(result)
    local key = activeGame and activeGame.key
    local completedStage = activeGame and activeGame.stage
    local completedLocation = activeGame and activeGame.locationId
    activeGame = nil; render()
    showResult(result, key, completedStage, completedLocation)
end
showResult = function(result, key, completedStage, completedLocation, scrollPosition)
    closeModal()
    modalRebuild = function() showResult(result, key, completedStage, completedLocation, scrollPosition) end
    local overlay = UI.overlay(canvas, "GameResultOverlay", .04); modal = overlay
    local stage = completedStage or result.stage or 1
    local match = getMatch(key)
    local character = match and Logic.character(match.characterId)
    local photo
    for _, item in state.album do if item.key == key then photo = item; break end end
    local followUp=result.remixId and Remix.followUp(photo,result)
    local box = ResultCard.mount(overlay, result, {
        mobile = mobile, availableHeight = height, availableWidth = UI.availableWidth, stage = stage, character = character, photo = photo, locationId = completedLocation,
        scrollPosition = scrollPosition, scrolled = function(position) scrollPosition = position end,
        mount = function(art, options) modalViewer = mount(art, character.id, match.variantId, options) end,
        editPhoto = function(frameId)
            if busy then return end
            nav("album",key);showPhotoStudio(key,{frameId=frameId})
        end,
        back = function()
            if busy then return end
            closeModal()
            if result.remixId then nav("album",key);showRemixes(key)
            elseif result.practice then nav("album",key);showStory(key)
            else nav("matches")end
        end,
        continue = function()
            if busy then return end
            closeModal()
            if followUp then
                if followUp.kind=="photo"then nav("album",key);showPhotoStudio(key,{frameId="souvenirs"})
                else startGame(key,3,followUp.locationId,followUp.remixId)end
            elseif result.practice then startGame(key,completedStage)
            elseif result.result=="album"then nav("album",key)
            else startGame(key)end
        end,
    })
    if not restoringModal then
        Feedback.pop(box, .92); Feedback.play(result.passed and "success" or "miss")
        if result.passed then Feedback.burst(overlay, width / 2, height / 2 - 50, result.result == "album" and C.pink or C.mint, 16) end
    end
end
local function syncGameControls()
    if gamePresentation then gamePresentation.setLocked(gameInputLocked) end
    if activeGame and activeGame.stage == 1 and gamePresentation and gamePresentation.height then
        body.CanvasSize = UDim2.fromOffset(0, gamePresentation.height)
        body.ScrollingEnabled = gamePresentation.height > body.Size.Y.Offset
        body.ScrollBarThickness = body.ScrollingEnabled and 3 or 0
    end
end
local function recoverExpiredGame(previous)
    -- The final answer can reach the server even if its response is lost.
    task.wait(.08)
    local snapshot = rpc("snapshot", nil, true)
    activeGame = nil; gameInputLocked = false
    nav(previous.practice and "album" or "matches",previous.practice and previous.key or nil)
    if snapshot then
        if previous.remixId then showRemixes(previous.key) elseif previous.practice then showStory(previous.key) end
        toast("Раунд уже закрыт. Твой прогресс обновлён.", C.panel)
        notifyMatches(snapshot.news)
    else
        toast("Раунд закрыт. Не удалось обновить прогресс — проверь связь.", C.bad)
    end
end
local function readyGame()
    if not activeGame or activeGame.stage ~= 3 or not activeGame.awaitingReady or busy or gameInputLocked then return end
    local token = activeGame.token
    gameInputLocked = true; syncGameControls()
    local response, readyError = rpc("readyGame", { token = token })
    if not activeGame or activeGame.token ~= token then return end
    if not response and readyError == "expired_game" then recoverExpiredGame(activeGame); return end
    gameInputLocked = false
    if response then activeGame = response; render(true) else syncGameControls() end
end
local function submitGame(choice)
    if not activeGame or busy or gameInputLocked or activeGame.awaitingReady or (activeGame.stage == 3 and dateRevealing) then return end
    gameInputLocked = true
    syncGameControls()
    local pending = { token = activeGame.token, turn = Games.turn(activeGame), choice = choice }
    inFlightGameInput = pending
    if gamePresentation then gamePresentation.preview(choice) end
    local started = os.clock()
    local result, inputError = rpc("gameInput", pending)
    if inFlightGameInput == pending then inFlightGameInput = nil end
    if not result then
        if gamePresentation then gamePresentation.clearPreview() end
        if inputError == "expired_game" then
            recoverExpiredGame(activeGame)
            return
        end
        gameInputLocked = false; syncGameControls(); return
    end
    if result.resynced then
        activeGame = result; renderGame(true)
        gameInputLocked = false; syncGameControls()
        toast("Связь восстановлена. Продолжаем с текущего хода.", C.panel)
        return
    end
    if result.good ~= nil then Feedback.play(result.good and "success" or "miss") end
    local stage = activeGame.stage
    if gamePresentation then gamePresentation.react(choice, result.good) end
    task.wait(stage == 1 and math.max(0, .30 - (os.clock() - started)) or .75)
    if result.passed ~= nil then completeGame(result)
    else activeGame = result; renderGame(true) end
    gameInputLocked = false
    syncGameControls()
end
actions.gameInput = submitGame
local function chooseLocation(key, practiceStage, selectedLocationId)
    local match = getMatch(key); if not match then return end
    local character, variant = Logic.character(match.characterId), Logic.variant(match.variantId)
    local passport, story
    for _, photo in state.album do if photo.key == key then story = photo; passport = Collection.passport(photo); break end end
    local selected = selectedLocationId or (story and (Collection.nextPlace(story) or story.locationId)) or Locations.forPersonality(character.personality)
    closeModal(); modalRebuild = function() chooseLocation(key, practiceStage, selected) end
    modal = UI.overlay(canvas, "LocationPickerOverlay", .04)
    modalViewer = DatePlaces.mount(modal, character, variant, {
        mobile = mobile, availableHeight = height, selectedLocationId = selected, passport = passport,
        userId = state.playerUserId or player.UserId, avatarSnapshot = state.avatarSnapshot,
        select = function(id) selected = id end,
        choose = function(id) closeModal(); startGame(key, practiceStage, id) end,
        cancel = function() closeModal(); if practiceStage then showStory(key) end end,
    })
    if not restoringModal then Feedback.pop(modalViewer.frame, .94) end
end
startGame = function(key, practiceStage, locationId, remixId)
    local match = getMatch(key)
    if not match then return end
    local stage = practiceStage or match.stage
    if stage == 3 and not locationId then chooseLocation(key, practiceStage); return end
    closeModal()
    local response = rpc("startGame", { key = key, practiceStage = practiceStage, locationId = locationId, remixId = remixId })
    if not response then return end
    activeTab = "matches"; activeGame = response; match.unread = false; render()
end
actions.startGame = startGame
renderGame = function(updateOnly)
    local session = activeGame; local match = getMatch(session.key)
    if not match then activeGame = nil; renderMatches(); return end
    if updateOnly and gamePresentation then gamePresentation.update(session); syncGameControls(); return end
    local character, variant = Logic.character(match.characterId), Logic.variant(match.variantId)
    dateRevealing = false
    local immersive = session.stage == 3
    local focused = immersive or session.stage <= 2
    local settingsSize = math.max(66, UI.touchMinimum or 0)
    local focusTop = math.max(94, settingsSize + 32)
    local gameW=immersive and width or (mobile and 436 or width-52)
    if mobile and session.stage==2 then gameW=math.max(gameW,(UI.availableWidth or 480)-44)end
    if focused then
        sidebar.Visible = false
        body.Position = immersive and UDim2.fromOffset(0, 0) or UDim2.fromOffset((width-gameW)/2, focusTop)
        body.Size = immersive and UDim2.fromOffset(width, height) or UDim2.fromOffset(gameW, height - focusTop - 14)
        body.BackgroundTransparency = 1
        if mobile then body.ScrollingEnabled = false; body.ScrollBarThickness = 0 end
        -- Keep settings and save warnings accessible without the app's chrome.
        header.ZIndex = 3; header.BackgroundTransparency = 1
        header.Logo.Visible = false; header.Tagline.Visible = false
        if header:FindFirstChild("CollectionBadge") then header.CollectionBadge.Visible = false end
        header.Tagline.Position = UDim2.fromOffset(settingsSize + 14, settingsSize - 23)
        header.Tagline.Size = UDim2.new(1, -settingsSize * 2 - 28, 0, 18)
        header.Tagline.TextSize = 12
        header.Tagline.Visible = storageStatus.state == "retrying" or storageStatus.state == "blocked"
        header.GuideButton.BackgroundColor3 = C.panel
        header.GuideButton.Position = UDim2.new(1, -settingsSize, 0, 0)
        header.SoundToggle.Visible = false
        body.ZIndex = 1
    end
    local back = UI.button(focused and header or body, "Back", focused and "←" or (session.practice and "←  К истории" or "←  Назад"), UDim2.fromOffset(0, 0), UDim2.fromOffset(focused and settingsSize or (mobile and 145 or 178), focused and settingsSize or 54), C.panel, function()
        if busy or gameInputLocked then return end
        rpc("cancelGame"); activeGame = nil
        if session.remixId then nav("album",session.key); showRemixes(session.key)
        elseif session.practice then nav("album",session.key); showStory(session.key) else render() end
    end)
    if focused then
        back.TextSize = 30
        if not immersive then UI.label(header, "StageTitle", Games.stageNames[session.stage], UDim2.fromOffset(settingsSize + 14, 0), UDim2.new(1, -settingsSize * 2 - 28, 0, settingsSize - 26), mobile and 21 or 28, C.ink, true) end
    else UI.label(body, "StageTitle", Games.stageNames[session.stage], UDim2.fromOffset(mobile and 160 or 198, 0), UDim2.new(1, mobile and -160 or -198, 0, 54), mobile and 25 or 28, C.text, true) end
    local gameH = immersive and height or (focused and height - focusTop - 14 or (mobile and math.max(470, math.min(630, height - 281)) or height - 284))
    if session.stage == 1 then
        gameH = math.max(gameH, PresentationLayout.minimumPhoneHeight(mobile, UI.touchMinimum))
        if mobile then body.ScrollingEnabled = gameH > height - focusTop - 14; body.ScrollBarThickness = body.ScrollingEnabled and 3 or 0 end
    end
    gamePresentation = Presentation.mount(body, session, character, variant, {
        mobile = mobile, width = gameW, height = gameH, immersive = immersive, rootTop = focused and 0 or nil, userId = state.playerUserId or player.UserId, avatarSnapshot = state.avatarSnapshot,
        submit = submitGame, ready = readyGame, revealing = function(value) dateRevealing = value end,
        revealState = dateRevealState,
        dateCollectionState = dateCollectionState,
        reactionState = gameReactionState,
        revealPaused = revealIsPaused,
    })
    gamePresentationToken = session.token
    if inFlightGameInput and inFlightGameInput.token == session.token then gamePresentation.preview(inFlightGameInput.choice) end
    if mobile then body.CanvasSize = UDim2.fromOffset(0, gameH + (focused and 0 or 74)) end
    gui:SetAttribute("ActiveStage", session.stage)
    syncGameControls()
end

render = function(preserveModal)
    local rebuild = preserveModal and modalRebuild
    if body and renderedFeedKey and pendingFeedRestore~=body then
        local range=math.max(0,body.AbsoluteCanvasSize.Y-body.AbsoluteWindowSize.Y)
        scrollPositions[renderedFeedKey]={ratio=range>0 and math.clamp(body.CanvasPosition.Y/range,0,1) or 0}
    end
    if body and renderedListKey then
        local list = body:FindFirstChild("AlbumGrid") or body:FindFirstChild("MatchList")
        if list and pendingListRestore~=list then scrollPositions[renderedListKey]=ListReading.capture(list) end
    end
    inputStart = nil; dragDistance = 0; albumFocusTarget=nil
    renderedFeedKey=nil;pendingFeedRestore=nil
    renderedListKey=nil;pendingListRestore=nil
    cleanup(); closeModal(); toastFrame = nil
    buildShell()
    if not profileReady then renderLoadScreen(); return end
    gui:SetAttribute("LoadState", "ready")
    if activeGame then renderGame()
    elseif activeTab == "feed" then renderFeed()
    elseif activeTab == "matches" then renderMatches()
    else renderAlbum() end
    if mobile and not activeGame and activeTab=="feed" and currentCard then
        local key="feed:"..Logic.key(currentCard.characterId,currentCard.variantId)
        renderedFeedKey=key
        local saved=scrollPositions[key]
        if saved then
            local surface=body;pendingFeedRestore=surface
            task.defer(function()
                task.wait()
                if not surface.Parent then return end
                local range=math.max(0,surface.AbsoluteCanvasSize.Y-surface.AbsoluteWindowSize.Y)
                surface.CanvasPosition=Vector2.new(0,range*saved.ratio)
                if pendingFeedRestore==surface then pendingFeedRestore=nil end
            end)
        end
    end
    if not activeGame then
        local list = body:FindFirstChild(activeTab == "album" and "AlbumGrid" or "MatchList")
        local key = activeTab == "album" and ("album:" .. albumPage) or ("matches:" .. inboxFilter .. ":" .. listPage)
        if list then renderedListKey = key end
        local focus=activeTab=="album" and albumFocusTarget
        local focusKey=albumFocusKey
        if list and (focus or scrollPositions[key]) then
            local saved = scrollPositions[key]
            pendingListRestore=list
            task.defer(function()
                task.wait()
                if not list.Parent then return end
                if focus and focus.Parent==list then
                    local target=list.CanvasPosition.Y+focus.AbsolutePosition.Y-list.AbsolutePosition.Y
                    local maximum=math.max(0,list.AbsoluteCanvasSize.Y-list.AbsoluteWindowSize.Y)
                    list.CanvasPosition=Vector2.new(0,math.clamp(target,0,maximum))
                    if albumFocusKey==focusKey then albumFocusKey=nil end
                elseif saved then list.CanvasPosition=Vector2.new(0,ListReading.restore(list,saved)) end
                if pendingListRestore==list then pendingListRestore=nil end
            end)
        end
    end
    gui:SetAttribute("ActiveTab", activeTab)
    gui:SetAttribute("ActiveStage", activeGame and activeGame.stage or 0)
    gui:SetAttribute("MatchCount", #state.matches)
    gui:SetAttribute("AlbumCount", #state.album)
    gui:SetAttribute("PendingCount", state.pending)
    if rebuild then restoringModal = true; rebuild(); restoringModal = false end
end
actions.returnLater = function(seconds)
    if busy or swiping or gameInputLocked then return end
    activeGame = nil; currentCard = nil; closeModal()
    local result = rpc("returnLater", { seconds = seconds })
    if not result then return end
    render()
    local n = result.news and #result.news or 0
    if n > 0 then showReturn(result.news)
    else toast("Ты вернулся. Новых взаимных лайков пока нет.", C.panel) end
end
actions.navigate = nav
refresh = function()
    local result = rpc("snapshot")
    if result then render(); if result.news and #result.news > 0 then showReturn(result.news) end end
    return result
end
actions.refresh = refresh
local function updateScale()
    local viewport = workspace.CurrentCamera.ViewportSize
    local previousRotation = rotationRequired
    rotationRequired = UserInputService.TouchEnabled and viewport.X > viewport.Y and viewport.Y < 500
    if rotationRequired and not previousRotation then phoneIcon.Rotation = -25; Feedback.tween(phoneIcon, .35, { Rotation = 0 }, Enum.EasingStyle.Back) end
    rotationOverlay.Visible = rotationRequired
    canvas.Visible = not rotationRequired
    gui:SetAttribute("RotationRequired", rotationRequired)
    -- Размер доступной области уже учитывает системное меню Roblox и вырез экрана.
    local available = background.AbsoluteSize
    if available.X < 1 or available.Y < 1 then available = viewport end
    local layout = Layout.resolve(available.X, available.Y, UserInputService.TouchEnabled)
    local newMobile = layout.mobile
    local layoutChanged = newMobile ~= mobile
    local heightChanged = math.abs(height - layout.height) > 1
    local touchChanged = UI.touchMinimum ~= layout.touchMinimum
    local textBucket = math.ceil(12 / layout.scale)
    local textChanged = UI.textBucket ~= textBucket
    local availableWidth = available.X / layout.scale
    local modalWidthChanged = UI.availableWidth and math.abs(UI.availableWidth - availableWidth) > 1
    mobile = newMobile; width = layout.width; height = layout.height; UI.touchMinimum = layout.touchMinimum
    UI.scale = layout.scale; UI.textBucket = textBucket; UI.availableWidth = availableWidth
    canvas.Size = UDim2.fromOffset(width, height)
    scale.Scale = layout.scale
    if (layoutChanged or heightChanged or touchChanged or textChanged or ((modal or (activeGame and activeGame.stage==2) or not activeGame) and modalWidthChanged)) and header then render(true) end
end
workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
workspace.CurrentCamera.CFrame = CFrame.new(0, 10, 20)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
background:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(updateScale)
updateScale()
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not profileReady or busy or modal or gameInputLocked or rotationRequired then return end
    if activeGame and activeGame.stage == 2 and input.KeyCode == Enum.KeyCode.Space then submitGame(1)
    elseif activeGame then
        local choice = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 })[input.KeyCode]
        if choice and (activeGame.stage == 3 or choice <= 3) and not dateRevealing then submitGame(choice) end
    elseif not activeGame and activeTab == "feed" then
        if input.KeyCode == Enum.KeyCode.Right then swipe(true) elseif input.KeyCode == Enum.KeyCode.Left then swipe(false) end
    end
end)
changed.OnClientEvent:Connect(function(result)
    applyState(result)
    -- Подтверждение сохранения не пересоздаёт карточку или текущую мини-игру.
    if not result.swipes or not profileReady then return end
    if not activeGame and not modal and not swiping and not busy and not inputStart then render() end
    if sidebar and sidebar:FindFirstChild("Nav_matches") then
        local button = sidebar.Nav_matches; button.Text = "Знакомства  " .. #state.matches
        if countUnread() > 0 and not button:FindFirstChild("UnreadDot") then UI.frame(button, "UnreadDot", UDim2.new(1, -12, 0, 4), UDim2.fromOffset(8, 8), C.mint, 4) end
    end
    if sidebar and sidebar:FindFirstChild("WaitCount") then sidebar.WaitCount.Text = "Ждём ответа: " .. state.pending end
    local notes = body and body:FindFirstChild("FeedNotes")
    if notes and notes:FindFirstChild("PendingPanel") then notes.PendingPanel.PendingNumber.Text = tostring(state.pending) end
    if result.news and #result.news > 0 then notifyMatches(result.news) end
end)
if RunService:IsStudio() then
    _G.BrainrotPrototypeClient = { actions = actions, getState = function() return state end, getGame = function() return activeGame end, getCard = function() return currentCard end, getPresentation = function() return gamePresentation end, render = render, gui = gui }
    local bridge = Instance.new("BindableFunction"); bridge.Name = "StudioTest"; bridge.Parent = gui
    bridge.OnInvoke = function(action, value)
        if action == "state" then return state elseif action == "game" then return activeGame elseif action == "card" then return currentCard
        elseif action == "render" then render(); return true
        elseif action == "startGame" and type(value) == "table" then startGame(value.key, value.practiceStage, value.locationId); return true
        elseif actions[action] then actions[action](value); return true end
    end
end
beginLoad = function(retry)
    if startupRunning or profileReady then return end
    startupRunning = true; lastLoadError = nil; renderLoadScreen()
    task.spawn(function()
        local deadline = os.clock() + 35
        local action = retry and "retryLoad" or "snapshot"
        repeat
            local result, err = rpc(action, nil, true)
            action = "snapshot"
            if result then
                startupRunning = false; lastLoadError = nil
                render()
                if result.news and #result.news > 0 then showReturn(result.news) end
                return
            end
            if err ~= "loading" and err ~= "busy" and err ~= "too_fast" then lastLoadError = err; break end
            task.wait(.5)
        until os.clock() >= deadline
        startupRunning = false; lastLoadError = lastLoadError or "load_failed"; renderLoadScreen()
    end)
end
buildShell()
beginLoad(false)
