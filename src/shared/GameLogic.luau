-- Pure, deterministic game rules. The server owns random rolls and timestamps.
local Logic = {}
local Config
local Catalog
local Locations
local Preferences
if script then
    Config = require(script.Parent.Config)
    Catalog = require(script.Parent.Catalog)
    Locations = require(script.Parent.Locations)
    Preferences = require(script.Parent.Preferences)
else
    Config = require("./Config")
    Catalog = require("./Catalog")
    Locations = require("./Locations")
    Preferences = require("./Preferences")
end
local byId = {}
local variants = {}
for _, c in Catalog do byId[c.id] = c end
for _, v in Config.Variants do variants[v.id] = v end

function Logic.character(id) return byId[id] end
function Logic.variant(id) return variants[id] end
function Logic.key(characterId, variantId) return characterId .. ":" .. variantId end
function Logic.chance(characterId, variantId)
    local c, v = byId[characterId], variants[variantId]
    if not c or not v then return nil end
    return math.clamp(Config.Rarities[c.rarity].chance * c.affinity * v.chanceFactor, 0.05, 0.90)
end
function Logic.newProfile(now)
    return { version = 1, createdAt = now, lastSeen = now, swipes = {}, matches = {}, album = {}, totalLikes = 0, totalPasses = 0, revision = 0, preferences = Preferences.normalize(nil) }
end
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function validScores(scores)
    if type(scores) ~= "table" then return false end
    for key, value in scores do
        if (key ~= "1" and key ~= "2" and key ~= "3") or not finite(value) or value < 0 or value > 1 then return false end
    end
    return true
end
local function validVisitedLocations(visited)
    if visited == nil then return true end
    if type(visited) ~= "table" then return false end
    local count = 0
    for locationId, value in visited do
        if not Locations.valid(locationId) or value ~= true then return false end
        count += 1
    end
    return count <= #Locations.list
end
local function visitedLocations(photo)
    local visited = {}
    for _, location in Locations.list do
        if type(photo.visitedLocations) == "table" and photo.visitedLocations[location.id] == true then
            visited[location.id] = true
        end
    end
    -- A saved selfie from before passports is proof of one successful date.
    if Locations.valid(photo.locationId) then visited[photo.locationId] = true end
    return visited
end
function Logic.validSavedProfile(data)
    if data == nil then return true end
    if type(data) ~= "table" or data.version ~= 1 then return false end
    for _, key in { "totalLikes", "totalPasses", "revision" } do
        local value = data[key]
        if value ~= nil and (not finite(value) or value < 0 or value % 1 ~= 0) then return false end
    end
    for _, key in { "createdAt", "lastSeen" } do
        if data[key] ~= nil and not finite(data[key]) then return false end
    end
    for _, field in { "swipes", "matches", "album" } do
        local entries = data[field]
        if entries ~= nil and type(entries) ~= "table" then return false end
        for key, entry in entries or {} do
            if type(entry) ~= "table" or not byId[entry.characterId] or not variants[entry.variantId]
                or key ~= Logic.key(entry.characterId, entry.variantId) then return false end
            if field == "swipes" then
                if not finite(entry.likedAt) then return false end
                if entry.status ~= "passed" then
                    if entry.status ~= "pending" and entry.status ~= "matched" and entry.status ~= "declined" and entry.status ~= "unanswered" then return false end
                    if type(entry.willMatch) ~= "boolean" or not finite(entry.dueAt) or not finite(entry.expiresAt) then return false end
                end
            else
                if entry.key ~= key or not validScores(entry.scores) then return false end
                if field == "matches" then
                    if not finite(entry.matchedAt) or not finite(entry.stage) or entry.stage % 1 ~= 0 or entry.stage < 1 or entry.stage > 4 then return false end
                else
                    if not finite(entry.completedAt) then return false end
                    if entry.locationId ~= nil and not Locations.valid(entry.locationId) then return false end
                    if entry.selfieAt ~= nil and not finite(entry.selfieAt) then return false end
                    if not validVisitedLocations(entry.visitedLocations) then return false end
                    if entry.avatarUserId ~= nil and (not finite(entry.avatarUserId) or entry.avatarUserId % 1 ~= 0) then return false end
                    if entry.avatarSnapshot ~= nil and (type(entry.avatarSnapshot) ~= "string" or #entry.avatarSnapshot > 64000) then return false end
                end
            end
        end
    end
    return true
end
function Logic.normalizeProfile(data, now)
    if type(data) ~= "table" or data.version ~= 1 then return Logic.newProfile(now) end
    for _, k in { "swipes", "matches", "album" } do if type(data[k]) ~= "table" then data[k] = {} end end
    data.totalLikes = tonumber(data.totalLikes) or 0
    data.totalPasses = tonumber(data.totalPasses) or 0
    data.revision = tonumber(data.revision) or 0
    data.lastSeen = tonumber(data.lastSeen) or now
    data.preferences = Preferences.normalize(data.preferences)
    for _, photo in data.album do photo.visitedLocations = visitedLocations(photo) end
    return data
end
function Logic.setPreferences(profile, changes)
    local nextPreferences = Preferences.patch(profile.preferences, changes)
    if not nextPreferences then return false, "invalid_request" end
    local current = Preferences.normalize(profile.preferences)
    if current.soundEnabled ~= nextPreferences.soundEnabled or current.motionEnabled ~= nextPreferences.motionEnabled then
        profile.preferences = nextPreferences; profile.revision += 1
    end
    return true
end
function Logic.decide(characterId, variantId, now, rolls)
    local chance = Logic.chance(characterId, variantId)
    if not chance then return nil end
    local accepted = rolls.acceptance < chance
    local immediate = rolls.timing < (accepted and Config.ImmediateResponseShare or Config.ImmediateDeclineShare)
    local delay = math.floor(Config.ResponseDelayMin + rolls.delay * (Config.ResponseDelayMax - Config.ResponseDelayMin))
    return {
        characterId = characterId, variantId = variantId, likedAt = now,
        dueAt = immediate and now or now + delay,
        willMatch = accepted, delivery = immediate and "immediate" or "delayed",
        status = immediate and (accepted and "matched" or "declined") or "pending",
        expiresAt = now + Config.NeverResponseWindow,
    }
end
local function createMatch(profile, key, swipe, now)
    if profile.matches[key] then return false end
    profile.matches[key] = { key = key, characterId = swipe.characterId, variantId = swipe.variantId, matchedAt = now, stage = 1, scores = {}, unread = true }
    return true
end
function Logic.swipe(profile, characterId, variantId, liked, now, rolls)
    local key = Logic.key(characterId, variantId)
    if not byId[characterId] or not variants[variantId] then return false, "unknown_profile" end
    if profile.swipes[key] then return false, "already_swiped" end
    profile.lastPassKey = nil
    if not liked then
        profile.swipes[key] = { characterId = characterId, variantId = variantId, status = "passed", likedAt = now }
        profile.lastPassKey = key
        profile.totalPasses += 1
        profile.revision += 1
        return true, "passed"
    end
    local decision = Logic.decide(characterId, variantId, now, rolls)
    profile.swipes[key] = decision
    profile.totalLikes += 1
    profile.revision += 1
    if decision.status == "matched" then createMatch(profile, key, decision, now) end
    return true, decision.status
end
function Logic.undoPass(profile)
    local key = profile.lastPassKey
    local swipe = key and profile.swipes[key]
    if not swipe or swipe.status ~= "passed" then return false, "no_recent_pass" end
    profile.swipes[key] = nil; profile.lastPassKey = nil
    profile.totalPasses = math.max(0, profile.totalPasses - 1); profile.revision += 1
    return true, { characterId = swipe.characterId, variantId = swipe.variantId }
end
function Logic.resolvePending(profile, now)
    local news = {}
    for key, swipe in profile.swipes do
        if swipe.status == "pending" then
            if swipe.willMatch and now >= swipe.dueAt then
                swipe.status = "matched"
                if createMatch(profile, key, swipe, swipe.dueAt) then table.insert(news, key) end
                profile.revision += 1
            elseif not swipe.willMatch and now >= swipe.expiresAt then
                -- This character never reciprocates. Do not show a fake delayed rejection.
                swipe.status = "unanswered"
                profile.revision += 1
            end
        end
    end
    table.sort(news)
    return news
end
function Logic.finishStage(profile, key, stage, score, now)
    local match = profile.matches[key]
    if not match then return false, "no_match" end
    if match.stage ~= stage or stage < 1 or stage > 3 then return false, "wrong_stage" end
    if not finite(score) or score < 0 or score > 1 then return false, "invalid_score" end
    if score < Config.MinigameThreshold then return false, "retry" end
    match.scores[tostring(stage)] = math.clamp(score, 0, 1)
    match.stage += 1
    match.unread = false
    profile.revision += 1
    if stage == 3 then
        if not profile.album[key] then
            profile.album[key] = { key = key, characterId = match.characterId, variantId = match.variantId, completedAt = now, scores = table.clone(match.scores) }
        end
        return true, "album"
    end
    return true, "next_stage"
end
function Logic.practiceStage(profile, key, stage, score)
    local match = profile.matches[key]
    local photo = profile.album[key]
    if not match or match.stage ~= 4 or not photo then return false, "story_not_complete" end
    if type(stage) ~= "number" or stage % 1 ~= 0 or stage < 1 or stage > 3 then return false, "invalid_stage" end
    if type(score) ~= "number" or score ~= score or score < 0 or score > 1 then return false, "invalid_score" end
    local previous = match.scores[tostring(stage)] or 0
    local improved = score > previous
    if improved then
        match.scores[tostring(stage)] = score; photo.scores[tostring(stage)] = score; profile.revision += 1
    end
    return true, { improved = improved, best = math.max(previous, score), passed = score >= Config.MinigameThreshold }
end
function Logic.recordSelfie(profile, key, locationId, userId, avatarSnapshot, now)
    local match, photo = profile.matches[key], profile.album[key]
    if not match or match.stage ~= 4 or not photo then return false, "story_not_complete" end
    if not Locations.valid(locationId) then return false, "invalid_location" end
    if type(userId) ~= "number" or userId % 1 ~= 0 then return false, "invalid_player" end
    if avatarSnapshot ~= nil and (type(avatarSnapshot) ~= "string" or #avatarSnapshot > 64000) then return false, "invalid_avatar" end
    if not finite(now) then return false, "invalid_time" end
    photo.visitedLocations = visitedLocations(photo)
    photo.visitedLocations[locationId] = true
    match.dateLocationId = locationId
    photo.locationId = locationId; photo.avatarUserId = userId; photo.avatarSnapshot = avatarSnapshot; photo.selfieAt = now
    profile.revision += 1
    return true
end
function Logic.publicSnapshot(profile, now)
    local pending, unanswered, swipes, sentLikes = 0, 0, {}, {}
    for key, s in profile.swipes do
        swipes[key] = s.status
        if s.status == "pending" then pending += 1 end
        if s.status == "unanswered" then unanswered += 1 end
        if s.status ~= "passed" then
            table.insert(sentLikes, { key = key, characterId = s.characterId, variantId = s.variantId, status = s.status, likedAt = s.likedAt })
        end
    end
    local matches, album = {}, {}
    for _, m in profile.matches do table.insert(matches, table.clone(m)) end
    for _, a in profile.album do
        local photo = table.clone(a)
        photo.visitedLocations = visitedLocations(a)
        table.insert(album, photo)
    end
    local function matchPriority(match)
        if match.stage > 3 then return 2 end
        return match.unread and 0 or 1
    end
    table.sort(matches, function(a, b)
        local ap, bp = matchPriority(a), matchPriority(b)
        if ap ~= bp then return ap < bp end
        if a.matchedAt ~= b.matchedAt then return a.matchedAt > b.matchedAt end
        return a.key < b.key
    end)
    table.sort(album, function(a, b)
        local at, bt = a.selfieAt or a.completedAt, b.selfieAt or b.completedAt
        if at ~= bt then return at > bt end
        return a.key < b.key
    end)
    table.sort(sentLikes, function(a, b) if a.likedAt == b.likedAt then return a.key < b.key end; return a.likedAt > b.likedAt end)
    -- Acceptance rolls and scheduled outcomes stay private to the server.
    local pass = profile.lastPassKey and profile.swipes[profile.lastPassKey]
    local lastPass = pass and pass.status == "passed" and { characterId = pass.characterId, variantId = pass.variantId } or nil
    return { now = now, pending = pending, unanswered = unanswered, swipes = swipes, sentLikes = sentLikes, matches = matches, album = album, lastPass = lastPass, totalLikes = profile.totalLikes, totalPasses = profile.totalPasses, revision = profile.revision, preferences = Preferences.normalize(profile.preferences) }
end
return Logic
