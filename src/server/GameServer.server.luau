local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = require(Shared.GameLogic)
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Games = require(Shared.Minigames)
local Locations = require(Shared.Locations)
local AvatarData = require(Shared.AvatarData)
local Store = require(script.Parent.ProfileStore)
local net = Instance.new("Folder"); net.Name = "BrainrotNet"; net.Parent = ReplicatedStorage
local request = Instance.new("RemoteFunction"); request.Name = "Request"; request.Parent = net
local changed = Instance.new("RemoteEvent"); changed.Name = "Changed"; changed.Parent = net
local profiles, games, offsets, busy, lastRequest = {}, {}, {}, {}, {}
local loading, closing, saveScheduled = {}, {}, {}
local shuttingDown = false
local requestSave
local returnNews = {}
local lastResolution = {}
local random = Random.new()
local avatarSnapshots = {}
Players.CharacterAutoLoads = false
local function clock(player) return os.time() + (offsets[player] or 0) end
local function payload(player, extra)
    local state = Logic.publicSnapshot(profiles[player], clock(player))
    state.storageMode = Store.mode; state.studio = RunService:IsStudio()
    state.placeVersion = game.PlaceVersion
    state.storageStatus = Store.status(player.UserId, profiles[player].revision)
    state.playerUserId = player.UserId; state.avatarSnapshot = avatarSnapshots[player]
    if extra then for k, v in extra do state[k] = v end end
    return state
end
Store.onChanged = function(userId)
    local player = Players:GetPlayerByUserId(userId)
    if player and profiles[player] and not closing[player] then
        changed:FireClient(player, { storageStatus = Store.status(userId, profiles[player].revision) })
    end
end
requestSave = function(player, delaySeconds)
    if saveScheduled[player] or closing[player] or not profiles[player] or shuttingDown then return end
    saveScheduled[player] = true
    -- Серия свайпов объединяется в одну запись; мини-игры не ждут ответа хранилища.
    task.delay(delaySeconds or 6, function()
        local profile = profiles[player]
        if not profile or closing[player] or shuttingDown then saveScheduled[player] = nil; return end
        local ok, err = Store.save(player.UserId, profile)
        saveScheduled[player] = nil
        if not ok then warn("Profile save will retry: " .. tostring(err)) end
        if profiles[player] == profile and not closing[player] then
            local status = Store.status(player.UserId, profile.revision)
            if status.state ~= "blocked" and (not ok or (status.savedRevision and status.savedRevision < profile.revision)) then
                requestSave(player, ok and 6 or 15)
            end
        end
    end)
end
local function resolveAndNotify(player, source)
    local profile = profiles[player]
    if not profile or closing[player] or not Store.canWrite(player.UserId) then return end
    local revision = profile.revision
    local news = Logic.resolvePending(profile, clock(player))
    if profile.revision ~= revision then
        lastResolution[player] = { source = source, news = #news, revision = profile.revision }
        if #news > 0 then
            -- A Changed event may arrive before the client is ready, or its
            -- accompanying snapshot reply may be lost. Keep every resolved key
            -- available to later snapshots for this session, exactly once.
            local retained, included = returnNews[player] or {}, {}
            for _, key in retained do included[key] = true end
            for _, key in news do
                if not included[key] then table.insert(retained, key); included[key] = true end
            end
            returnNews[player] = retained
        end
        changed:FireClient(player, payload(player, { news = news }))
        requestSave(player)
    end
end
local function join(player)
    if profiles[player] or loading[player] or closing[player] or shuttingDown then return end
    loading[player] = true
    player:SetAttribute("ProfileLoadFailed", false)
    player:SetAttribute("ProfileLoadError", nil)
    local profile, err = Store.load(player.UserId, clock(player))
    if not profile then
        loading[player] = nil
        if player.Parent then
            player:SetAttribute("ProfileLoadFailed", true)
            player:SetAttribute("ProfileLoadError", err or "load_failed")
        end
        warn("Profile load failed; saved progress remains untouched: " .. tostring(err))
        return
    end
    -- Игрок мог выйти, пока Roblox загружал профиль. Не оставляем его аренду висеть.
    if shuttingDown or player.Parent ~= Players then
        local ok, releaseError = Store.release(player.UserId, profile)
        if not ok then warn("Departed profile release failed: " .. tostring(releaseError)) end
        loading[player] = nil
        return
    end
    profiles[player] = profile
    loading[player] = nil
    local news = Logic.resolvePending(profile, clock(player))
    returnNews[player] = news
    profile.lastSeen = clock(player)
    player:SetAttribute("ProfileReady", true)
    requestSave(player)
    task.spawn(function()
        local ok, snapshot = pcall(function()
            local description = Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
            local value = HttpService:JSONEncode(AvatarData.capture(description)); description:Destroy(); return value
        end)
        if ok and player.Parent and profiles[player] then avatarSnapshots[player] = snapshot; changed:FireClient(player, payload(player)) end
    end)
end
Players.PlayerAdded:Connect(join)
for _, player in Players:GetPlayers() do task.spawn(join, player) end
local function feed(player)
    local out = {}
    local p = profiles[player]
    local visited, order = {}, {}
    for index, c in Catalog do
        order[c.id] = index
        local unseen = {}
        for _, v in Config.Variants do if not p.swipes[Logic.key(c.id, v.id)] then table.insert(unseen, v) end end
        if #unseen > 0 then
            visited[c.id] = #Config.Variants - #unseen
            local v = unseen[1]
            -- First visits show the base style; later variants keep the collection fresh.
            if p.totalLikes + p.totalPasses > 8 then
                local total = 0; for _, option in unseen do total += option.weight end
                local roll = random:NextNumber(0, total)
                for _, option in unseen do roll -= option.weight; if roll <= 0 then v = option; break end end
            end
            table.insert(out, { characterId = c.id, variantId = v.id })
        end
    end
    table.sort(out, function(a, b)
        if visited[a.characterId] ~= visited[b.characterId] then return visited[a.characterId] < visited[b.characterId] end
        return order[a.characterId] < order[b.characterId]
    end)
    return out
end
local function gameView(session)
    local out = { token = session.token, key = session.key, stage = session.stage, step = session.step, correct = session.correct, attempts = session.attempts, practice = session.practice }
    if session.stage == 1 then
        local q = session.chat[session.step]
        out.prompt = q.prompt; out.options = q.options; out.messages = session.messages
    elseif session.stage == 2 then
        out.gesture = Locations.gesture(session.attempts + 1, session.gestureSeed); out.serverStart = session.serverStart; out.target = 6; out.hits = session.hits
    else
        if session.step == 1 then out.sequence = session.sequence end
        out.revealSeconds = 3; out.revealEnds = session.serverStart + 3; out.theme = session.personality; out.locationId = session.locationId; out.choices = session.choices; out.hits = session.hits
    end
    return out
end
local function finish(player, session, score)
    games[player] = nil
    local recap = { hits = table.clone(session.hits), total = session.stage == 2 and 6 or 4 }
    if session.practice then
        local ok, result = Logic.practiceStage(profiles[player], session.key, session.stage, score)
        if not ok then return { error = result } end
        if session.stage == 3 and result.passed then Logic.recordSelfie(profiles[player], session.key, session.locationId, player.UserId, avatarSnapshots[player], clock(player)) end
        return payload(player, { result = "practice", practice = true, score = score, best = result.best, improved = result.improved, passed = result.passed, stage = session.stage, recap = recap })
    end
    local passed, result = Logic.finishStage(profiles[player], session.key, session.stage, score, clock(player))
    if passed and session.stage == 3 then Logic.recordSelfie(profiles[player], session.key, session.locationId, player.UserId, avatarSnapshots[player], clock(player)) end
    return payload(player, { result = result, score = score, passed = passed, stage = session.stage, recap = recap })
end
local function handle(player, action, args)
    if shuttingDown or closing[player] then return { error = "session_lost" } end
    if action == "retryLoad" then
        if not profiles[player] and not loading[player] then task.spawn(join, player) end
        action = "snapshot"
    end
    local p = profiles[player]
    if not p then return { error = player:GetAttribute("ProfileLoadError") or "loading" } end
    local writable, writeError = Store.canWrite(player.UserId)
    if not writable and action ~= "snapshot" then return { error = writeError or "session_lost" } end
    args = type(args) == "table" and args or {}
    resolveAndNotify(player, "request")
    if action == "snapshot" then
        -- A lost reply must not consume the return letter. The client presents
        -- each key once; this small session-local list is released on leave.
        local news = returnNews[player]
        return payload(player, { feed = feed(player), news = news })
    end
    if action == "preferences" then
        local ok, err = Logic.setPreferences(p, args)
        if not ok then return { error = err } end
        return payload(player)
    elseif action == "swipe" then
        if type(args.characterId) ~= "string" or type(args.variantId) ~= "string" or type(args.liked) ~= "boolean" then return { error = "invalid_request" } end
        local ok, result = Logic.swipe(p, args.characterId, args.variantId, args.liked, clock(player), { acceptance = random:NextNumber(), timing = random:NextNumber(), delay = random:NextNumber() })
        if not ok then return { error = result } end
        return payload(player, { result = result, feed = feed(player), lastKey = Logic.key(args.characterId, args.variantId) })
    elseif action == "read" then
        if p.matches[args.key] then p.matches[args.key].unread = false; p.revision += 1 end
        return payload(player)
    elseif action == "undoPass" then
        local ok, restored = Logic.undoPass(p)
        if not ok then return { error = restored } end
        return payload(player, { result = "undone", restored = restored, feed = feed(player) })
    elseif action == "startGame" then
        local match = p.matches[args.key]
        local practiceStage = args.practiceStage
        if practiceStage ~= nil then
            if type(practiceStage) ~= "number" or practiceStage % 1 ~= 0 or practiceStage < 1 or practiceStage > 3 then return { error = "invalid_stage" } end
            if not match or match.stage ~= 4 or not p.album[args.key] then return { error = "story_not_complete" } end
        elseif not match or match.stage > 3 then return { error = "no_active_match" } end
        local stage = practiceStage or match.stage
        local locationId = args.locationId or match.dateLocationId or "park"
        if stage == 3 and not Locations.valid(locationId) then return { error = "invalid_location" } end
        match.unread = false; p.revision += 1
        local session = { token = HttpService:GenerateGUID(false), key = args.key, stage = stage, practice = practiceStage ~= nil, step = 1, correct = 0, attempts = 0, hits = {}, started = os.clock(), serverStart = workspace:GetServerTimeNow(), locationId = locationId }
        local character = Logic.character(match.characterId)
        session.personality = character.personality
        if session.stage == 1 then session.chat = Games.chatFor(character, random:NextInteger(1, 2147483646)); session.messages = {} end
        if session.stage == 2 then session.gestureSeed = random:NextInteger(1, Locations.gesturePatternCount); session.hits = {} end
        if session.stage == 3 then session.sequence = {}; session.choices = {}; session.hits = {}; for _ = 1, 4 do table.insert(session.sequence, random:NextInteger(1, 4)) end end
        games[player] = session; return gameView(session)
    elseif action == "cancelGame" then
        games[player] = nil
        return payload(player)
    elseif action == "gameInput" then
        local s = games[player]
        local outcome = Games.applyInput(s, args, { server = workspace:GetServerTimeNow(), clock = os.clock() })
        if outcome.error then return outcome end
        if outcome.resynced then local result = gameView(s); result.resynced = true; return result end
        local result = outcome.score ~= nil and finish(player, s, outcome.score) or gameView(s)
        result.good = outcome.good; result.response = outcome.response
        return result
    elseif action == "returnLater" and RunService:IsStudio() then
        games[player] = nil
        local seconds = math.clamp(tonumber(args.seconds) or 600, 60, 172800)
        offsets[player] = (offsets[player] or 0) + seconds
        local news = Logic.resolvePending(p, clock(player))
        p.lastSeen = clock(player)
        return payload(player, { news = news, feed = feed(player), returned = seconds })
    elseif action == "resetDemo" and RunService:IsStudio() then
        profiles[player] = Logic.newProfile(clock(player)); games[player] = nil
        return payload(player, { feed = feed(player) })
    end
    return { error = "unknown_action" }
end
request.OnServerInvoke = function(player, action, args)
    if type(action) ~= "string" then return { error = "invalid_request" } end
    if busy[player] then return { error = "busy" } end
    if lastRequest[player] and os.clock() - lastRequest[player] < 0.06 then return { error = "too_fast" } end
    lastRequest[player] = os.clock(); busy[player] = true
    local previous = profiles[player]
    local revision = previous and previous.revision
    local ok, response = pcall(handle, player, action, args)
    busy[player] = nil
    local current = profiles[player]
    if current and (current ~= previous or current.revision ~= revision) then
        requestSave(player, ok and response and (response.score ~= nil or action == "preferences") and 0 or 6)
    end
    if not ok then warn("Prototype request failed: " .. tostring(response)); return { error = "server_error" } end
    return response
end
task.spawn(function()
    while true do
        task.wait(5)
        for player, p in profiles do
            if player.Parent then
                resolveAndNotify(player, "poll")
            end
        end
    end
end)
task.spawn(function()
    while not shuttingDown do
        task.wait(45)
        for player in profiles do requestSave(player, 0) end
    end
end)
local function leave(player)
    if closing[player] then return end
    closing[player] = true
    if profiles[player] then
        local profile = profiles[player]
        profile.lastSeen = clock(player)
        repeat
            local ok, err = Store.release(player.UserId, profile)
            if ok then break end
            warn("Final profile save failed: " .. tostring(err))
            if shuttingDown or err == "session_lost" or err == "revision_conflict"
                or err == "stale_profile" or err == "not_loaded" or err == "invalid_profile" then break end
            -- Пока сервер жив, временный сбой при выходе тоже получает повтор.
            task.wait(15)
        until false
    end
    profiles[player], games[player], offsets[player], busy[player], lastRequest[player] = nil, nil, nil, nil, nil
    returnNews[player], lastResolution[player], avatarSnapshots[player] = nil, nil, nil
    saveScheduled[player], closing[player] = nil, nil
end
Players.PlayerRemoving:Connect(leave)
game:BindToClose(function()
    shuttingDown = true
    -- Сохраняем игроков параллельно, чтобы один медленный запрос не съел время остальных.
    for player in profiles do task.spawn(leave, player) end
    local deadline = os.clock() + 25
    while (next(profiles) or next(loading)) and os.clock() < deadline do task.wait(0.05) end
end)
-- Introspection is only available inside Studio for validation; no client-visible outcomes.
if RunService:IsStudio() then
    _G.BrainrotPrototypeServer = { profiles = profiles, sessions = games, Logic = Logic, clock = clock, handle = handle }
    local bridge = Instance.new("BindableFunction"); bridge.Name = "StudioTest"; bridge.Parent = game:GetService("ServerStorage")
    bridge.OnInvoke = function(action, args)
        local player = Players:GetPlayers()[1]
        if action == "profile" then return profiles[player]
        elseif action == "session" then return games[player]
        elseif action == "handle" then return handle(player, args.action, args.args)
        elseif action == "seedMatch" then
            local id = args.characterId or Catalog[1].id; local variant = args.variantId or "classic"
            local key = Logic.key(id, variant)
            if not profiles[player].swipes[key] then Logic.swipe(profiles[player], id, variant, true, clock(player), { acceptance = 0, timing = 0, delay = 0 }) end
            changed:FireClient(player, payload(player)); return key
        elseif action == "seedLike" then
            local age = math.clamp(tonumber(args.ageSeconds) or 0, 0, 172800)
            local ok, result = Logic.swipe(profiles[player], args.characterId, args.variantId or "classic", true, clock(player) - age, args.rolls)
            changed:FireClient(player, payload(player))
            return { ok = ok, result = result }
        elseif action == "lastResolution" then return lastResolution[player]
        elseif action == "finishStage" then
            local ok, result = Logic.finishStage(profiles[player], args.key, args.stage, args.score, clock(player))
            changed:FireClient(player, payload(player))
            return { ok = ok, result = result }
        end
    end
end
