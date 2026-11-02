-- Temporary QA gallery. Only uses prepared assets and the project's own viewer.
local player = game.Players.LocalPlayer
local Catalog = require(game.ReplicatedStorage.Shared.Catalog)
local Config = require(game.ReplicatedStorage.Shared.Config)
local Viewer = require(player.PlayerScripts.PrototypeClient.ModelViewer)
local previous = player.PlayerGui:FindFirstChild("RosterQA")
if previous then previous.Page:Invoke(99); previous:Destroy() end
local gui = Instance.new("ScreenGui"); gui.Name = "RosterQA"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 500; gui.Parent = player.PlayerGui
local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1,1); bg.BackgroundColor3 = Color3.fromRGB(17,20,35); bg.BorderSizePixel = 0; bg.Parent = gui
local title = Instance.new("TextLabel"); title.Size = UDim2.new(1,0,0,35); title.TextSize = 18; title.TextColor3 = Color3.new(1,1,1); title.BackgroundTransparency=1; title.Parent=bg
local grid=Instance.new("Frame");grid.Position=UDim2.fromOffset(0,36);grid.Size=UDim2.new(1,0,1,-36);grid.BackgroundTransparency=1;grid.Parent=bg
local rows = {}
local bridge = Instance.new("BindableFunction"); bridge.Name = "Page"; bridge.Parent = gui
bridge.OnInvoke = function(page)
    for _, row in rows do row.dispose() end; table.clear(rows)
    for _, c in grid:GetChildren() do c:Destroy() end
    title.Text = "34 prepared characters — camera and rig QA · page " .. page .. "/3"
    for index=(page-1)*12+1, math.min(page*12,#Catalog) do
        local c=Catalog[index];local pos=(index-1)%12;local col=pos%4;local line=math.floor(pos/4)
        local card=Instance.new("Frame");card.Size=UDim2.new(.25,-12,1/3,-8);card.Position=UDim2.new(col/4,6,line/3,4);card.BackgroundColor3=Color3.fromRGB(37,40,61);card.BorderSizePixel=0;card.Parent=grid
        local art=Instance.new("Frame");art.Size=UDim2.new(1,0,1,-27);art.BackgroundTransparency=1;art.Parent=card
        local view=Viewer.mount(art,c,Config.Variants[1],{small=true});table.insert(rows,view)
        local label=Instance.new("TextLabel");label.Position=UDim2.new(0,4,1,-27);label.Size=UDim2.new(1,-8,0,27);label.Text=c.name;label.TextSize=13;label.TextColor3=Color3.new(1,1,1);label.BackgroundTransparency=1;label.Parent=card
        if index%4==0 then task.wait() end
    end
    return {page=page,count=#rows}
end
bridge:Invoke(1)
return {ready=true,pages=3}
