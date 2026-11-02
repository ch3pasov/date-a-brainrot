local DateCollection = {}
DateCollection.maximum = 4

local function validIndex(value)
    return type(value) == "number" and value >= 1 and value <= DateCollection.maximum and value % 1 == 0
end

local function copyConfirmed(target, source)
    if type(source) ~= "table" or type(source.choices) ~= "table" or type(source.hits) ~= "table" then return end
    for attempt = 1, DateCollection.maximum do
        local choice, hit = source.choices[attempt], source.hits[attempt]
        if validIndex(choice) and type(hit) == "boolean" then
            target.choices[attempt] = choice; target.hits[attempt] = hit
        end
    end
end

function DateCollection.restore(session, previous)
    session = type(session) == "table" and session or {}
    local state = { token = session.token, choices = {}, hits = {} }
    -- Resize can arrive during the reaction pause, before App replaces its
    -- session. Preserve already acknowledged replies from this exact round.
    if type(previous) == "table" and type(session.token) == "string" and session.token ~= "" and previous.token == session.token then
        copyConfirmed(state, previous)
    end
    copyConfirmed(state, session)
    return state
end

function DateCollection.confirm(state, attempt, choice, good)
    local result = DateCollection.restore(state)
    -- Called only after the server reply, never by the input preview. Using
    -- the attempt number makes repeated reconciliation idempotent.
    if validIndex(attempt) and validIndex(choice) and type(good) == "boolean" then
        result.choices[attempt] = choice; result.hits[attempt] = good
    end
    return result
end

function DateCollection.entries(state)
    local confirmed = DateCollection.restore(state)
    local entries = {}
    for attempt = 1, DateCollection.maximum do
        if confirmed.hits[attempt] == true then
            table.insert(entries, { attempt = attempt, choice = confirmed.choices[attempt] })
        end
    end
    return entries
end

return DateCollection
