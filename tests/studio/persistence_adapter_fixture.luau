-- Studio-only fault injection. Prepend to an EDIT-TIME copy of GameServer for QA.
-- Never include this file in default.project.json or publish that temporary copy.
-- Stop Play and restore GameServer.Source from src before saving/publishing Studio.
do
    assert(game:GetService("RunService"):IsStudio(), "Persistence fixture must never run live")
    local Http = game:GetService("HttpService")
    local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
    local Logic = require(Shared.GameLogic)
    local Store = require(script.Parent.ProfileStore)
    local Session = require(script.Parent.ProfileSession)
    local data, requests, commits = {}, 0, 0
    local function copy(value)
        if value == nil then return nil end
        return Http:JSONDecode(Http:JSONEncode(value))
    end
    workspace:SetAttribute("PersistenceTestFailures", 5)
    workspace:SetAttribute("PersistenceTestDelay", 0)
    local sessions = Session.new({
        update = function(key, transform)
            requests += 1
            local delay = workspace:GetAttribute("PersistenceTestDelay") or 0
            if delay > 0 then task.wait(delay) end
            local failures = workspace:GetAttribute("PersistenceTestFailures") or 0
            if failures > 0 then
                workspace:SetAttribute("PersistenceTestFailures", failures - 1)
                error("Intentional Studio persistence test outage")
            end
            local value = transform(copy(data[key]))
            if value == nil then return nil end
            data[key] = copy(value); commits += 1
            return copy(value)
        end,
        now = os.time, wait = task.wait,
        token = function() return Http:GenerateGUID(false) end,
        normalize = Logic.normalizeProfile, validate = Logic.validSavedProfile,
        changed = function(userId) Store.onChanged(userId) end,
    })
    Store.mode = "persistent_fixture"
    Store.load = function(userId, now) return sessions:load(userId, now) end
    Store.save = function(userId, profile) return sessions:save(userId, profile, false) end
    Store.release = function(userId, profile) return sessions:save(userId, profile, true) end
    Store.canWrite = function(userId) return sessions:canWrite(userId) end
    Store.status = function(userId, revision) return sessions:status(userId, revision) end
    local bridge = Instance.new("BindableFunction")
    bridge.Name = "PersistenceFixture"; bridge.Parent = game:GetService("ServerStorage")
    bridge.OnInvoke = function()
        local out = {}
        for key, value in data do
            out[key] = { revision = value.revision, likes = value.totalLikes, passes = value.totalPasses,
                owned = value._session ~= nil }
        end
        return { requests = requests, commits = commits, data = out }
    end
end
