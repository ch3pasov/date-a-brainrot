local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Locations = require(Shared.Locations)
local Album = require(script.Parent.Album)
local RemixResult = require(script.Parent.RemixResult)
local UI = require(script.Parent.UI)
local C = UI.colors
local Result = {}

function Result.mount(parent, result, options)
    if result.remixId then return RemixResult.mount(parent, result, options) end
    local stage, mobile = options.stage, options.mobile
    local selfie = result.passed and stage == 3 and options.character ~= nil
    local w = mobile and 436 or 650
    local buttonH = math.max(66, UI.touchMinimum or 0)
    local preferredBottom = selfie and 640 or 566
    local preferredH = preferredBottom + buttonH + 20
    local h = math.min(preferredH, (options.availableHeight or 760) - 24)
    local compression = preferredH - h
    local contentBottom = preferredBottom - compression
    local box = UI.frame(parent, "ResultDialog", UDim2.new(.5, -w / 2, .5, -h / 2), UDim2.fromOffset(w, h), C.panel, 4)
    box.ZIndex = 2
    UI.pill(box, "Stage", ({ "01  /  ПЕРЕПИСКА", "02  /  НА СВЯЗИ", "03  /  СВИДАНИЕ" })[stage], UDim2.fromOffset(24, 20), 190, C.pink)
    local title = not result.passed and "БЫВАЕТ!\nПОПРОБУЕМ ЕЩЁ?" or (result.practice and (result.improved and "НОВЫЙ\nРЕКОРД!" or "ЕЩЁ ОДИН\nОБЩИЙ ВАЙБ") or (selfie and "ВАШЕ\nПЕРВОЕ СЕЛФИ!" or "ЕСТЬ\nКОНТАКТ!"))
    UI.label(box, "Title", title, UDim2.fromOffset(24, 58), UDim2.fromOffset(w - 174, 78), mobile and 28 or 32, C.ink, true)
    local score = UI.frame(box, "ScoreSeal", UDim2.fromOffset(w - 134, 48), UDim2.fromOffset(110, 88), result.passed and C.yellow or C.card, 8)
    score.Rotation = 5; UI.stroke(score, C.ink).Thickness = 2
    local percent = UI.label(score, "Score", math.floor(result.score * 100 + .5) .. "%", UDim2.fromOffset(3, 3), UDim2.new(1, -6, 0, 54), 34, C.ink, true)
    percent.TextXAlignment = Enum.TextXAlignment.Center
    local scoreCaption = UI.label(score, "Caption", "ВАШ ВАЙБ", UDim2.fromOffset(2, 56), UDim2.new(1, -4, 0, 25), UI.readableSize(12, 10), C.ink, true)
    scoreCaption.TextXAlignment = Enum.TextXAlignment.Center
    if selfie then
        local locationId = (options.photo and options.photo.locationId) or options.locationId or "park"
        local photo = UI.frame(box, "ResultPhoto", UDim2.fromOffset(24, 152), UDim2.new(1, -48, 0, 286 - compression), C.panel, 2)
        UI.stroke(photo, C.ink).Thickness = 2
        local art = UI.frame(photo, "ResultSelfie", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 234 - compression), C.aqua, 1)
        options.mount(art, {
            modal = true, scene = true, photo = true, pair = true, locationId = locationId,
            userId = options.photo and options.photo.avatarUserId,
            avatarSnapshot = options.photo and options.photo.avatarSnapshot,
        })
        local caption = UI.label(photo, "PhotoCaption", Locations.get(locationId).name .. "  ♥", UDim2.fromOffset(8, 246 - compression), UDim2.new(1, -16, 0, 32), UI.readableSize(17), C.pink, true)
        caption.TextXAlignment = Enum.TextXAlignment.Center
        local tape = UI.frame(photo, "PhotoTape", UDim2.new(.5, -42, 0, -7), UDim2.fromOffset(84, 18), C.yellow, 1)
        tape.Rotation = -4; tape.BackgroundTransparency = .2; tape.ZIndex = 4
        if options.photo then Album.passport(box, options.photo, UDim2.fromOffset(24, 446 - compression), UDim2.new(1, -48, 0, 30)) end
    else
        local portraitW = mobile and 140 or 184
        UI.label(box, "Sender", options.character and options.character.name or "Наш общий вайб", UDim2.fromOffset(24, 148), UDim2.new(1, -48, 0, 54), UI.readableSize(18), C.ink, true)
        local portrait = UI.frame(box, "ReactionPortrait", UDim2.fromOffset(24, 208), UDim2.fromOffset(portraitW, 186), C.aqua, 3)
        UI.stroke(portrait, C.ink).Thickness = 2
        if options.character then options.mount(portrait, { modal = true, scene = true, portrait = true, portraitAim = options.character.cameraAim, radius = 3, locationId = Locations.forPersonality(options.character.personality) }) end
        local bubble = UI.frame(box, "LastReaction", UDim2.fromOffset(36 + portraitW, 208), UDim2.fromOffset(w - portraitW - 60, 186), result.passed and C.aqua or C.card, 9)
        UI.stroke(bubble, C.ink).Thickness = 2
        UI.label(bubble, "Reply", result.response or "Каждый раунд — ещё одна маленькая история.", UDim2.fromOffset(12, 12), UDim2.new(1, -24, 1, -24), UI.readableSize(mobile and 19 or 18), C.ink)
    end
    local recapY = (selfie and 490 or 410) - compression
    if result.recap then
        local count = result.recap.total
        local cellW = (w - 48 - (count - 1) * 8) / count
        for i = 1, count do
            local hit = result.recap.hits[i]
            local cell = UI.frame(box, "ResultAttempt_" .. i, UDim2.fromOffset(24 + (i - 1) * (cellW + 8), recapY), UDim2.fromOffset(cellW, 36), hit and C.mint or C.card, 4)
            UI.stroke(cell, C.ink).Thickness = 1
            local mark = UI.label(cell, "Mark", hit and "♥" or "×", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 24, hit and C.panel or C.pink, true)
            mark.TextXAlignment = Enum.TextXAlignment.Center
        end
    end
    local total = result.recap and result.recap.total or (stage == 2 and 6 or 4)
    local required = math.ceil(Config.MinigameThreshold * total)
    local goal = ({ "тёплые ответы", "совпавшие жесты", "совпадения" })[stage]
    local description
    if result.practice then
        description = result.passed and ("Рекорд: " .. math.floor(result.best * 100 + .5) .. "%. Ваша история остаётся в альбоме.") or ("Рекорд: %d%%. Нужно %d из %d. Селфи сохранено — попробуем ещё?"):format(math.floor(result.best * 100 + .5), required, total)
    elseif result.passed then
        description = selfie and "Вы вдвоём, это место, этот момент. Забирай снимок в альбом!" or "Один шаг ближе. Впереди ещё немного общего хаоса."
    else
        description = ("Нужны %s: %d из %d. Можно повторить — мэтч остаётся с тобой."):format(goal, required, total)
    end
    UI.label(box, "Description", description, UDim2.fromOffset(24, recapY + 50), UDim2.new(1, -48, 0, selfie and 80 or 100), UI.readableSize(18), C.muted)
    UI.button(box, "BackToMatches", result.practice and "К истории" or "К мэтчам", UDim2.fromOffset(24, contentBottom), UDim2.fromOffset((w - 60) / 2, buttonH), C.card, options.back).TextSize = UI.readableSize(17)
    local nextText = result.practice and "Ещё раунд" or (result.passed and (result.result == "album" and "В альбом ♥" or "Дальше →") or "Ещё раз →")
    local nextButton = UI.button(box, "ResultContinue", nextText, UDim2.fromOffset(w / 2 + 6, contentBottom), UDim2.fromOffset((w - 60) / 2, buttonH), C.mint, options.continue)
    nextButton.TextColor3 = C.panel; nextButton.TextSize = UI.readableSize(17)
    return box
end
return Result
