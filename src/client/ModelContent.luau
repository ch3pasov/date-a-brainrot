local ContentProvider = game:GetService("ContentProvider")
local Content = {}
-- PreloadAsync reports failed downloads through statuses rather than throwing.
-- A missing texture must not replace geometry that successfully loaded.
function Content.load(model)
    local descendants=model:GetDescendants()
    local successful=true
    local ok=pcall(function()
        ContentProvider:PreloadAsync(descendants,function(_,status)
            if status~=Enum.AssetFetchStatus.Success then successful=false end
        end)
    end)
    local meshes={}
    for _,object in descendants do
        if object:IsA("MeshPart") or object:IsA("SpecialMesh") then
            local id=object.MeshId
            if id and id~="" then meshes[id]=true end
        end
    end
    if not next(meshes) then return ok and successful,false end
    local ready,failed=true,false
    for id in meshes do
        local queried,status=pcall(function()return ContentProvider:GetAssetFetchStatus(id)end)
        ready=ready and queried and status==Enum.AssetFetchStatus.Success
        failed=failed or queried and (status==Enum.AssetFetchStatus.Failure or status==Enum.AssetFetchStatus.TimedOut)
    end
    return ready,failed
end
return Content
