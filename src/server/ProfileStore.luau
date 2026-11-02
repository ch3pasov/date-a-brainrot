-- Studio использует отдельную память; живой профиль получает аренду на сервере.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Logic = require(Shared.GameLogic)
local Config = require(Shared.Config)
local ProfileSession = require(script.Parent.ProfileSession)
local Store = { onChanged = function() end }
Store.mode = RunService:IsStudio() and "local" or "persistent"
local sessions, memory = nil, {}
local function clone(value)
    if value == nil then return nil end
    return HttpService:JSONDecode(HttpService:JSONEncode(value))
end
if Store.mode == "persistent" and game.GameId > 0 then
    local ok, backing = pcall(function() return DataStoreService:GetDataStore(Config.DataStoreName) end)
    if ok then
        sessions = ProfileSession.new({
            update = function(key, transform) return backing:UpdateAsync(key, transform) end,
            now = os.time, wait = task.wait,
            token = function() return HttpService:GenerateGUID(false) end,
            normalize = Logic.normalizeProfile, validate = Logic.validSavedProfile,
            jitter = function() return math.random() * 0.3 end,
            changed = function(userId) Store.onChanged(userId) end,
        })
    else Store.mode = "unavailable" end
else Store.mode = "local" end
function Store.load(userId, now)
    if Store.mode == "unavailable" then return nil, "load_failed" end
    if sessions then return sessions:load(userId, now) end
    return Logic.normalizeProfile(clone(memory[userId]), now)
end
function Store.save(userId, profile)
    if Store.mode == "unavailable" then return false, "store_unavailable" end
    if sessions then return sessions:save(userId, profile, false) end
    memory[userId] = clone(profile)
    return true
end
function Store.release(userId, profile)
    if sessions then return sessions:save(userId, profile, true) end
    return Store.save(userId, profile)
end
function Store.canWrite(userId)
    if sessions then return sessions:canWrite(userId) end
    return Store.mode == "local", "store_unavailable"
end
function Store.status(userId, revision)
    if sessions then return sessions:status(userId, revision) end
    return { state = Store.mode == "local" and "local" or "blocked" }
end
return Store
