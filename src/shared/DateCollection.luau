local DateCollection = {}
DateCollection.maximum = 4

function DateCollection.capacity(state)
    return type(state) == "table" and state.total == 6 and 6 or 4
end

function DateCollection.slot(slot, total)
    if total == 6 then return ((slot - 1) % 3 - 1) * .94, slot <= 3 and 1.1 or 2.1 end
    return slot % 2 == 1 and -.65 or .65, slot <= 2 and 1.1 or 2.1
end

local function validIndex(value)
    return type(value) == "number" and value >= 1 and value <= DateCollection.maximum and value % 1 == 0
end

local function copyConfirmed(target, source)
    if type(source) ~= "table" or type(source.choices) ~= "table" or type(source.hits) ~= "table" then return end
    for attempt = 1, target.total do
        local choice, hit = source.choices[attempt], source.hits[attempt]
        if validIndex(choice) and type(hit) == "boolean" then
            target.choices[attempt] = choice; target.hits[attempt] = hit
        end
    end
end

function DateCollection.restore(session, previous)
    session = type(session) == "table" and session or {}
    local state = { token = session.token, total = DateCollection.capacity(session), choices = {}, hits = {} }
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
    if type(attempt) == "number" and attempt % 1 == 0 and attempt >= 1 and attempt <= result.total and validIndex(choice) and type(good) == "boolean" then
        result.choices[attempt] = choice; result.hits[attempt] = good
    end
    return result
end

function DateCollection.entries(state)
    local confirmed = DateCollection.restore(state)
    local entries = {}
    for attempt = 1, confirmed.total do
        if confirmed.hits[attempt] == true then
            table.insert(entries, { attempt = attempt, choice = confirmed.choices[attempt] })
        end
    end
    return entries
end

return DateCollection
