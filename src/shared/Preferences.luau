local Preferences = {}
local keys = { soundEnabled = true, motionEnabled = true }
function Preferences.normalize(value)
    local out = {}
    for key, fallback in keys do
        out[key] = fallback
        if type(value) == "table" and type(value[key]) == "boolean" then out[key] = value[key] end
    end
    return out
end
function Preferences.patch(current, changes)
    if type(changes) ~= "table" then return nil end
    for key, value in changes do
        if keys[key] == nil or type(value) ~= "boolean" then return nil end
    end
    local out = Preferences.normalize(current)
    for key, value in changes do out[key] = value end
    return out
end
function Preferences.new()
    return { confirmed = Preferences.normalize(nil), pending = {}, serial = 0 }
end
function Preferences.effective(state)
    local out = Preferences.normalize(state.confirmed)
    for key, change in state.pending do out[key] = change.value end
    return out
end
function Preferences.receive(state, value)
    state.confirmed = Preferences.normalize(value)
end
function Preferences.choose(state, key, value)
    if keys[key] == nil or type(value) ~= "boolean" then return false end
    if Preferences.effective(state)[key] == value then return true end
    state.serial += 1
    state.pending[key] = { value = value, serial = state.serial }
    return true
end
function Preferences.request(state)
    local changes, receipt = {}, {}
    for key, change in state.pending do
        changes[key], receipt[key] = change.value, change.serial
    end
    return changes, receipt
end
function Preferences.acknowledge(state, receipt)
    for key, serial in receipt do
        local change = state.pending[key]
        if change and change.serial == serial then state.pending[key] = nil end
    end
end
return Preferences
