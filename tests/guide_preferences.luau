-- Real Guide construction, real client sync/set/save worker and Preferences.
-- Only UI instances, task scheduling and RPC acknowledgement are controlled.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Preferences = require("../src/shared/Preferences")
local Logic = require("../src/shared/GameLogic")
local app = fs.readFile("src/client/App.client.luau")
local guideSource = fs.readFile("src/client/Guide.luau")
local syncFirst = assert(app:find("local function syncPreferences()", 1, true))
local syncLast = assert(app:find("\nlocal function applyState(", syncFirst, true))
local saveFirst = assert(app:find("savePreferences = function()", 1, true))
local saveLast = assert(app:find("\nlocal function countUnread()", saveFirst, true))
local guideFirst = assert(guideSource:find("local C = UI.colors", 1, true))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = if ok then nil else tostring(err) })
    if not ok then print("FAILED: " .. name .. ": " .. tostring(err)) end
end
local function node(parent, name, properties)
    local n = { Name = name, Parent = parent, children = {} }
    function n:FindFirstChild(key, recursive)
        if self.children[key] then return self.children[key] end
        if recursive then for _, child in self.children do
            local found = child:FindFirstChild(key, true); if found then return found end
        end end
        return nil
    end
    for key, value in properties or {} do n[key] = value end
    setmetatable(n, { __index = function(self, key) return self.children[key] end })
    if parent then parent.children[name] = n end
    return n
end
local function fixture()
    local f = { queued = {}, saves = {}, profile = Logic.newProfile(1000), feedback = { soundEnabled = true, motionEnabled = true } }
    function f.feedback.applyPreferences(value)
        f.feedback.soundEnabled = value.soundEnabled; f.feedback.motionEnabled = value.motionEnabled
    end
    f.feedback.pop = function() end
    local ui = { colors = { panel = "cream", aqua = "aqua", ink = "ink", card = "card", pink = "coral", mint = "green", yellow = "yellow", muted = "muted" } }
    function ui.new(_, properties, parent) return node(parent, properties.Name, properties) end
    function ui.frame(parent, name, position, size) return node(parent, name, { Position = position, Size = size }) end
    function ui.overlay(parent, name) return node(parent, name) end
    function ui.label(parent, name, text) return node(parent, name, { Text = text }) end
    function ui.button(parent, name, text, _, _, _, callback) return node(parent, name, { Text = text, activate = callback }) end
    function ui.stroke() return {} end
    function ui.readableSize(size) return size end
    function ui.textHeight(text,size,width) return math.ceil(math.max(1,math.ceil((utf8.len(text) or #text)*size*.75/width))*size*1.35) end
    local canvas = node(nil, "Canvas")
    local icons = {}; for _, key in { "phone", "clock", "photo", "video" } do icons[key] = function(parent) return node(parent, "Icon_" .. key) end end
    local guide = luau.load(guideSource:sub(guideFirst), { environment = {
        Remix = require("../src/shared/DateRemix"),
        UI = ui, Feedback = f.feedback, Icons = icons, UDim2 = roblox.UDim2,
        Enum = { TextXAlignment = { Center = "center" } },
    }, debugName = "actual guide hierarchy" })()
    local header = node(canvas, "Header"); node(header, "SoundToggle", { Text = "♪" })
    f.api = luau.load([[
        local preferenceState = Preferences.new()
        local modal, preferenceWorker, savePreferences, setPreference
        local header = initialHeader
        local function rpc(action, changes)
            assert(action == "preferences")
            local result = saveFixture(changes)
            -- The existing RPC/applyState adapter receives the saved preferences.
            Preferences.receive(preferenceState, result.preferences)
            return result
        end
    ]] .. app:sub(syncFirst, syncLast - 1) .. "\n" .. app:sub(saveFirst, saveLast - 1) .. [[
        return {
            choose = setPreference, sync = syncPreferences,
            worker = function() return preferenceWorker == true end,
            effective = function() return Preferences.effective(preferenceState) end,
            open = function()
                modal = Guide.open(canvas, true, function() modal = nil end,
                    { availableHeight = 760, placeVersion = 25, setPreference = setPreference })
                return modal
            end,
            close = function() modal = nil end,
        }
    ]], { environment = {
        Guide = guide, Preferences = Preferences, Feedback = f.feedback, initialHeader = header,
        canvas = canvas, gui = { Parent = true }, profileReady = true,
        saveFixture = function(changes)
            assert(Logic.setPreferences(f.profile, changes)); table.insert(f.saves, table.clone(changes))
            return { preferences = table.clone(f.profile.preferences) }
        end,
        task = { spawn = function(callback) table.insert(f.queued, callback) end, wait = function() end },
        toast = function() error("Successful fixture should not report a transport failure") end,
    }, debugName = "actual guide preference integration" })()
    function f.flush() while #f.queued > 0 do table.remove(f.queued, 1)() end end
    function f.open() f.modal = f.api.open(); return f.modal end
    function f.button(name) return f.modal.GuideDialog:FindFirstChild(name, true) end
    f.header = header
    return f
end
test("Real nested guide buttons update immediately and start one persisted preference worker", function()
    local f = fixture(); f.open()
    assert(f.modal.GuideDialog.GuideContent and not f.modal.GuideDialog:FindFirstChild("SoundToggle"))
    f.button("MotionToggle").activate(); f.button("SoundToggle").activate()
    assert(f.button("MotionToggle").Text == "ОТКЛИК\nТИХИЙ")
    assert(f.button("SoundToggle").Text == "♪ ЗВУК\nВЫКЛЮЧЕН" and f.header.SoundToggle.Text == "♪ ×")
    assert(#f.queued == 1 and f.api.worker())
    f.flush()
    assert(#f.saves == 1 and not f.profile.preferences.motionEnabled and not f.profile.preferences.soundEnabled)
    assert(not f.api.worker() and f.button("SoundToggle").Text == "♪ ЗВУК\nВЫКЛЮЧЕН")
end)
test("A save acknowledgement while the guide is open cannot strand the worker", function()
    local f = fixture(); f.api.choose("soundEnabled", false)
    f.open(); f.flush()
    assert(#f.saves == 1 and not f.api.worker())
    assert(f.button("SoundToggle").Text == "♪ ЗВУК\nВЫКЛЮЧЕН")
    f.button("SoundToggle").activate(); f.flush()
    assert(#f.saves == 2 and f.profile.preferences.soundEnabled and not f.api.worker())
    assert(f.button("SoundToggle").Text == "♪ ЗВУК\nВКЛЮЧЁН")
end)
test("Closing a guide before the acknowledgement preserves settings and a rebuilt view", function()
    local f = fixture(); f.api.choose("motionEnabled", false)
    f.open(); f.api.close(); f.flush()
    assert(not f.api.worker() and not f.profile.preferences.motionEnabled)
    f.open(); assert(f.button("MotionToggle").Text == "ОТКЛИК\nТИХИЙ")
    f.api.close(); f.api.choose("soundEnabled", false); f.flush()
    assert(not f.profile.preferences.soundEnabled and f.header.SoundToggle.Text == "♪ ×")
end)
local passed = 0; for _, record in tests do if record.passed then passed += 1 end end
fs.writeFile("prototype/evidence/guide-preferences-tests.json", serde.encode("json", { passed = passed, failed = #tests - passed,
    total = #tests, tests = tests, scope = "Actual Guide/open and client sync/set/save worker with real Preferences/Logic, controlled UI/task/RPC acknowledgement; no engine or live storage" }, true))
for _, record in tests do assert(record.passed, record.name .. ": " .. tostring(record.error)) end
print("Passed " .. passed .. " actual guide preference integration checks")
