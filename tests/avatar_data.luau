-- Actual saved-avatar capture/restore logic with a recorded description object.
-- Property/API rejection is controlled; no Roblox avatar rendering is performed.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local source = fs.readFile("src/shared/AvatarData.luau")
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    if not ok then print("FAILED: " .. name .. ": " .. tostring(err)) end
end
local function fixture()
    local f = { created = {}, kinds = { Hat = { Name = "Hat" }, Jacket = { Name = "Jacket" } } }
    local function description()
        local values = { accessories = {} }
        local d = { values = values }
        function d:Destroy() self.destroyed = true end
        function d:GetAccessories() return values.accessories end
        function d:SetAccessories(accessories)
            if f.rejectAccessories then error("accessory setter rejected input") end
            values.accessories = {}
            for _, a in accessories do
                table.insert(values.accessories, { AssetId = a.AssetId, AccessoryType = a.AccessoryType,
                    IsLayered = a.IsLayered, Order = a.Order, Puffiness = a.Puffiness })
            end
        end
        setmetatable(d, { __index = function(_, key) return values[key] end,
            __newindex = function(_, key, value)
                if key == f.rejectProperty then error("description property rejected input") end
                values[key] = value
            end })
        for _, key in f.module.numbers do values[key] = 0 end
        for _, key in f.module.strings do values[key] = "" end
        for _, key in f.module.colors do values[key] = roblox.Color3.new(.25, .5, .75) end
        table.insert(f.created, d); return d
    end
    f.module = luau.load(source, { environment = {
        Instance = { new = function(class) assert(class == "HumanoidDescription"); return description() end },
        Color3 = roblox.Color3, Enum = { AccessoryType = f.kinds },
    }, debugName = "actual saved avatar data" })()
    f.description = description
    return f
end
test("A valid saved appearance roundtrip preserves fields colors and layered accessories", function()
    local f = fixture(); local input = f.description()
    for _, key in f.module.numbers do input[key] = key:find("Scale$") and 1 or 123 end
    for _, key in f.module.strings do input[key] = "1, 2" end
    input.values.accessories = {
        { AssetId = 7, AccessoryType = f.kinds.Hat, IsLayered = false },
        { AssetId = 8, AccessoryType = f.kinds.Jacket, IsLayered = true, Order = 2, Puffiness = .5 },
    }
    local saved = f.module.capture(input); local before = serde.encode("json", saved)
    local result = f.module.description(saved)
    assert(result and not result.destroyed)
    assert(serde.encode("json", f.module.capture(result)) == before)
    assert(serde.encode("json", saved) == before, "Restore must not mutate the saved snapshot")
end)
test("Malformed container fields are rejected before allocating a description", function()
    for _, field in { "values", "colors", "accessories" } do
        local f = fixture(); local data = { version = 1, [field] = false }
        local ok, result = pcall(f.module.description, data)
        assert(ok and result == nil and #f.created == 0)
    end
end)
test("Property and accessory setter errors release the partial description and return a safe failure", function()
    for _, mode in { "property", "accessories" } do
        local f = fixture()
        if mode == "property" then f.rejectProperty = "Shirt" else f.rejectAccessories = true end
        local data = { version = 1, values = { Shirt = 123 }, accessories = { { id = 7, kind = "Hat" } } }
        local before = serde.encode("json", data)
        local ok, result = pcall(f.module.description, data)
        assert(ok and result == nil and #f.created == 1 and f.created[1].destroyed)
        assert(serde.encode("json", data) == before)
    end
end)
test("Malformed nested accessory entries cannot escape or leak a partially built appearance", function()
    local f = fixture(); local data = { version = 1, accessories = { false } }
    local ok, result = pcall(f.module.description, data)
    assert(ok and result == nil and #f.created == 1 and f.created[1].destroyed)
end)
local passed = 0; for _, record in tests do if record.passed then passed += 1 end end
fs.writeFile("prototype/evidence/avatar-data-tests.json", serde.encode("json", { passed = passed, failed = #tests - passed, total = #tests, tests = tests }, true))
for _, record in tests do assert(record.passed, record.name .. ": " .. tostring(record.error)) end
print("Passed " .. passed .. " actual saved avatar data checks")
