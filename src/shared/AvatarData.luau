-- A public Roblox avatar description, captured for the album without photos or biometrics.
local AvatarData = {}
AvatarData.numbers = { "Shirt", "Pants", "GraphicTShirt", "Face", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "BodyTypeScale", "DepthScale", "HeadScale", "HeightScale", "ProportionScale", "WidthScale" }
AvatarData.strings = { "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory", "ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory" }
AvatarData.colors = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }
function AvatarData.capture(description)
    local out = { version = 1, values = {}, colors = {}, accessories = {} }
    for _, key in AvatarData.numbers do out.values[key] = description[key] end
    for _, key in AvatarData.strings do out.values[key] = description[key] end
    for _, key in AvatarData.colors do local c = description[key]; out.colors[key] = { c.R, c.G, c.B } end
    for _, accessory in description:GetAccessories(true) do
        table.insert(out.accessories, { id = accessory.AssetId, kind = accessory.AccessoryType.Name, layered = accessory.IsLayered, order = accessory.Order, puffiness = accessory.Puffiness })
    end
    return out
end
function AvatarData.description(data)
    if type(data) ~= "table" or data.version ~= 1 then return nil end
    for _, field in { "values", "colors", "accessories" } do
        if data[field] ~= nil and type(data[field]) ~= "table" then return nil end
    end
    local d = Instance.new("HumanoidDescription")
    local ok = pcall(function()
        for _, key in AvatarData.numbers do local value = data.values and data.values[key]; if type(value) == "number" and value >= 0 and value < 10^16 then d[key] = value end end
        for _, key in AvatarData.strings do local value = data.values and data.values[key]; if type(value) == "string" and #value < 2000 and not value:find("[^%d, ]") then d[key] = value end end
        for _, key in AvatarData.colors do local value = data.colors and data.colors[key]; if type(value) == "table" and #value == 3 then d[key] = Color3.new(math.clamp(tonumber(value[1]) or 0, 0, 1), math.clamp(tonumber(value[2]) or 0, 0, 1), math.clamp(tonumber(value[3]) or 0, 0, 1)) end end
        local accessories = {}
        for _, a in data.accessories or {} do
            local kind = type(a.kind) == "string" and Enum.AccessoryType[a.kind]
            if kind and type(a.id) == "number" and a.id > 0 then
                local accessory = { AssetId = a.id, AccessoryType = kind, IsLayered = a.layered == true }
                if accessory.IsLayered then accessory.Order = tonumber(a.order) or 0; accessory.Puffiness = tonumber(a.puffiness) or 0 end
                table.insert(accessories, accessory)
            end
        end
        if #accessories > 0 then d:SetAccessories(accessories, true) end
    end)
    if not ok then d:Destroy(); return nil end
    return d
end
return AvatarData
