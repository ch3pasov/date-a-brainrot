-- Один сервер владеет профилем до финального сохранения или истечения аренды.
-- Адаптер позволяет проверять таймауты и смену серверов без живого DataStore.
local Session = {}
Session.__index = Session
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in value do result[key] = copy(item) end
    return result
end
local function profileOnly(value)
    local result = copy(value)
    if result then result._session = nil; result._lastRelease = nil end
    return result
end
function Session.new(options)
    return setmetatable({
        update = options.update, now = options.now, wait = options.wait,
        token = options.token, normalize = options.normalize, validate = options.validate,
        changed = options.changed or function() end,
        jitter = options.jitter or function() return 0 end,
        leaseSeconds = options.leaseSeconds or 180,
        attempts = options.attempts or 5, sessions = {}, loadTokens = {},
    }, Session)
end
function Session:_notify(userId) pcall(self.changed, userId) end
function Session:_retry(attempt) self.wait(math.min(2 ^ (attempt - 1), 4) + self.jitter()) end
function Session:load(userId, profileNow)
    local previous = self.sessions[userId]
    if previous and previous.closing and not previous.writing then
        -- Повторный вход в тот же сервер сначала завершает неудачный выход.
        local ok, err = self:save(userId, previous.releaseSnapshot, true)
        if not ok and (err == "session_lost" or err == "revision_conflict") then
            self.sessions[userId] = nil
        elseif not ok then return nil, "load_failed" end
    end
    if self.sessions[userId] then return nil, "profile_in_use" end
    -- Повтор загрузки использует прежний токен, если ответ на захват аренды потерялся.
    local token = self.loadTokens[userId] or self.token()
    self.loadTokens[userId] = token
    local session = { id = token, loading = true, savedRevision = -1 }
    self.sessions[userId] = session
    local reason = "load_failed"
    for attempt = 1, self.attempts do
        local refusal
        local ok, stored = pcall(self.update, "player_" .. userId, function(old)
            refusal = nil
            -- Неизвестная версия или повреждённая запись не становится пустым профилем.
            if old ~= nil and (type(old) ~= "table" or old.version ~= 1) then
                refusal = "unsupported_profile"; return nil
            end
            if self.validate and not self.validate(old) then refusal = "unsupported_profile"; return nil end
            local lock = old and old._session
            if lock and (type(lock) ~= "table" or type(lock.id) ~= "string" or type(lock.expiresAt) ~= "number"
                or lock.expiresAt ~= lock.expiresAt or math.abs(lock.expiresAt) == math.huge) then
                refusal = "unsupported_profile"; return nil
            end
            if lock and lock.id ~= session.id and lock.expiresAt > self.now() then
                refusal = "profile_in_use"; return nil
            end
            local profile = self.normalize(profileOnly(old), profileNow)
            profile._session = { id = session.id, expiresAt = self.now() + self.leaseSeconds }
            profile._lastRelease = old and old._lastRelease or nil
            return profile
        end)
        if ok and stored and stored._session and stored._session.id == session.id then
            session.loading = false
            session.expiresAt = stored._session.expiresAt
            session.savedRevision = stored.revision
            session.savedAt = self.now()
            session.profile = profileOnly(stored)
            self.loadTokens[userId] = nil
            return session.profile
        end
        reason = refusal or "load_failed"
        if reason == "unsupported_profile" then break end
        if attempt < self.attempts then self:_retry(attempt) end
    end
    self.sessions[userId] = nil
    if reason == "unsupported_profile" then self.loadTokens[userId] = nil end
    return nil, reason
end
function Session:canWrite(userId)
    local s = self.sessions[userId]
    if not s or s.loading or s.closing then return false, "profile_in_use" end
    if s.lost then return false, "session_lost" end
    if self.now() >= s.expiresAt then return false, "session_expired" end
    return true
end
function Session:status(userId, revision)
    local s = self.sessions[userId]
    if not s or s.loading then return { state = "loading" } end
    local state = "saved"
    if s.lost or self.now() >= s.expiresAt then state = "blocked"
    elseif s.error then state = "retrying"
    elseif s.writing or (revision or 0) > s.savedRevision then state = "saving" end
    return { state = state, savedRevision = s.savedRevision, savedAt = s.savedAt }
end
function Session:save(userId, profile, release)
    local s = self.sessions[userId]
    if not s or s.loading then return false, "not_loaded" end
    -- Отложенное сохранение ушедшего игрока не закрывает его новую сессию.
    if profile ~= s.profile and profile ~= s.releaseSnapshot then return false, "stale_profile" end
    if s.closing and not release then return false, "closing" end
    if release then s.closing = true end
    -- Снимок делается после ожидания: старый запрос не обгонит более новый.
    while s.writing do self.wait(0.05) end
    if self.sessions[userId] ~= s or s.closed then return release == true, "closed" end
    if s.closing and not release then return false, "closing" end
    if s.lost then return false, s.lost end
    if type(profile) ~= "table" then return false, "invalid_profile" end
    local snapshot = release and s.releaseSnapshot or profileOnly(profile)
    if snapshot.version ~= 1 or type(snapshot.revision) ~= "number" or (self.validate and not self.validate(snapshot)) then
        return false, "invalid_profile"
    end
    local operation = release and s.releaseOperation or self.token()
    if release then
        operation = operation or self.token()
        s.releaseSnapshot, s.releaseOperation = snapshot, operation
    end
    s.writing = true; s.error = nil; self:_notify(userId)
    local reason = "save_failed"
    for attempt = 1, self.attempts do
        local refusal, releasedAlready
        local ok, stored = pcall(self.update, "player_" .. userId, function(old)
            refusal = nil; releasedAlready = false
            -- Запись могла пройти до таймаута. Повтор освобождения идемпотентен.
            if release and type(old) == "table" and old._lastRelease == operation then
                releasedAlready = true; return nil
            end
            local lock = type(old) == "table" and old._session
            if type(lock) ~= "table" or lock.id ~= s.id then refusal = "session_lost"; return nil end
            if old.version ~= 1 or type(old.revision) ~= "number" or old.revision > snapshot.revision then
                refusal = "revision_conflict"; return nil
            end
            local nextValue = copy(snapshot)
            if release then nextValue._lastRelease = operation
            else
                nextValue._lastRelease = old._lastRelease
                nextValue._session = { id = s.id, expiresAt = self.now() + self.leaseSeconds }
            end
            return nextValue
        end)
        if ok and (releasedAlready or stored ~= nil) and not refusal then
            s.writing = false; s.error = nil
            s.savedRevision = snapshot.revision; s.savedAt = self.now()
            if release then
                s.closed = true; self.sessions[userId] = nil
            else
                s.expiresAt = stored._session.expiresAt
                self:_notify(userId)
            end
            return true
        end
        reason = refusal or "save_failed"
        s.error = reason
        if reason == "session_lost" or reason == "revision_conflict" then s.lost = reason; break end
        self:_notify(userId)
        if attempt < self.attempts then self:_retry(attempt) end
    end
    s.writing = false; self:_notify(userId)
    return false, reason
end
return Session
