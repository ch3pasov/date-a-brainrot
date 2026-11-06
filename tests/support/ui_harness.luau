-- Executes production UI builders with controlled instances. Geometry and
-- callbacks are real; Roblox font rasterization and GPU rendering are not.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Screen = require("../../src/shared/Layout")
local Harness = {}
function Harness.new(width, height)
    local logical = Screen.resolve(width, height - 58, true)
    local function instance(class)
        local fields = { ClassName = class, Name = class, children = {}, attributes = {}, signals = {} }
        local object
        fields.FindFirstChild = function(_, name) return fields.children[name] end
        fields.GetPropertyChangedSignal = function(_, property) return {Connect = function(_,callback) fields.signals[property]=callback end} end
        fields.SetAttribute = function(_, name, value) fields.attributes[name] = value end
        fields.GetAttribute = function(_, name) return fields.attributes[name] end
        fields.Activated = {Connect = function(_, callback) fields.action = callback end}
        fields.Destroy = function()
            if fields.Parent then fields.Parent.children[fields.Name]=nil end
            fields.Parent=nil;fields.destroyed=true
        end
        object = setmetatable({}, {
            __index = function(_, key)
                if fields[key]~=nil then return fields[key] end
                return fields.children[key]
            end,
            __newindex = function(_, key, value)
                fields[key] = value
                if key == "Parent" and value then value.children[fields.Name] = object end
            end,
        })
        return object
    end
    local enum = { TextXAlignment = {Center="center", Left="left"}, TextYAlignment = {Center="center"},
        ApplyStrokeMode = {Border="border"}, Font = {GothamBlack="bold", Gotham="regular"},
        AutomaticSize = {Y="y"}, SortOrder = {LayoutOrder="order"} }
    local env = { Instance={new=instance}, Color3=roblox.Color3, UDim=roblox.UDim, UDim2=roblox.UDim2, Vector2=roblox.Vector2,
        Enum=enum, Feedback={bind=function() end, play=function() end} }
    local source = fs.readFile("src/client/UI.luau")
    local first = assert(source:find("local UI = {}", 1, true))
    local ui = luau.load(source:sub(first), {environment=env})()
    ui.scale = logical.scale; ui.touchMinimum = logical.touchMinimum
    env.UI = ui
    local h = { logical=logical, ui=ui, root=instance("Frame"), environment=env }
    function h.module(path, dependencies, marker)
        local code = fs.readFile(path)
        local moduleEnv = table.clone(env)
        for name, dependency in dependencies or {} do moduleEnv[name] = dependency end
        local start = assert(code:find(marker or "local C = UI.colors", 1, true))
        return luau.load(code:sub(start), {environment=moduleEnv})()
    end
    function h.options()
        return {mobile=logical.mobile, availableHeight=logical.height, availableWidth=width/logical.scale}
    end
    return h
end
function Harness.rect(node, width, height)
    return { x=node.Position.X.Scale*width+node.Position.X.Offset, y=node.Position.Y.Scale*height+node.Position.Y.Offset,
        w=node.Size.X.Scale*width+node.Size.X.Offset, h=node.Size.Y.Scale*height+node.Size.Y.Offset }
end
return Harness
