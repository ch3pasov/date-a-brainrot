local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local records = {}
local function check(directory)
    for _, name in fs.readDir(directory) do
        local path = directory .. "/" .. name
        if fs.isDir(path) then check(path)
        elseif path:sub(-5) == ".luau" then
            local ok, result = pcall(luau.compile, fs.readFile(path))
            assert(ok, path .. ": " .. tostring(result))
            table.insert(records, { file = path, compiled = true })
        end
    end
end
check("src")
fs.writeFile("prototype/evidence/compile-tests.json", serde.encode("json", records, true))
print("Compiled " .. #records .. " Luau source files")
