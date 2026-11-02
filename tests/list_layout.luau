local Layout = require("../src/shared/Layout")
local Feed = require("../src/shared/FeedLayout")
local List = require("../src/shared/ListLayout")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function phone(w, h)
    local base = Layout.resolve(w, h - 58, true)
    local shell = Feed.resolve(base.width, base.height, base.mobile, base.touchMinimum)
    return base, shell.dockY - shell.bodyY - 18
end
test("Short-phone filters and pagers cannot overlap the scrolling list", function()
    for _, viewport in { {320,480}, {390,650}, {430,932} } do
        local base, height = phone(viewport[1], viewport[2])
        for _, sent in {false,true} do
            local list = List.resolve(height, true, base.touchMinimum, sent, true)
            assert(list.filterY + list.filterHeight + 12 <= list.gridY)
            assert(list.gridY + list.gridHeight + 8 <= list.pager.y)
            assert(list.pager.y + list.pager.size <= height)
            assert(list.filterHeight * base.scale >= 44 and list.pager.size * base.scale >= 44)
        end
    end
end)
test("Row actions and separate paging buttons remain full touch targets", function()
    for _, viewport in { {320,480}, {390,650}, {430,932} } do
        local base, height = phone(viewport[1], viewport[2])
        for _, sent in {false,true} do
            local list = List.resolve(height, true, base.touchMinimum, sent, true)
            assert(list.actionHeight * base.scale >= 44)
            assert(list.actionY >= (sent and 120 or 99) + 10)
            assert(list.actionY + list.actionHeight + 12 <= list.rowHeight)
            assert(list.pager.nextX >= list.pager.size + 8)
            assert(list.pager.nextX + list.pager.size <= 436)
        end
    end
end)
test("Empty postcards fit above navigation on supported short phones", function()
    for _, viewport in { {320,480}, {390,650}, {430,932} } do
        local base, height = phone(viewport[1], viewport[2])
        local list = List.resolve(height, true, base.touchMinimum, false, false)
        for _, top in {list.gridY,140} do
            local empty = List.empty(height, top, true, base.touchMinimum)
            assert(not empty.scrollable and empty.bottom <= height)
            assert(empty.imageY + empty.imageHeight + 10 <= empty.noteY)
            assert(empty.noteY + empty.noteHeight + 12 <= empty.actionY)
            assert(empty.actionY + empty.actionHeight + 12 <= empty.height)
            assert(empty.actionHeight * base.scale >= 44)
        end
    end
end)
test("Very short empty states expose scrolling instead of hiding the action under the dock", function()
    local base, height = phone(320,370)
    local list = List.resolve(height, true, base.touchMinimum, false, false)
    local empty = List.empty(height, list.gridY, true, base.touchMinimum)
    assert(empty.scrollable and empty.bottom > height)
    assert(empty.imageHeight >= 100 and empty.noteY > empty.imageY + empty.imageHeight)
    assert(empty.actionY + empty.actionHeight < empty.height)
end)
test("Desktop lists keep their existing compact grid with separate pagination", function()
    local list = List.resolve(546, false, nil, false, true)
    assert(list.filterY == 91 and list.filterHeight == 44 and list.gridY == 151)
    assert(list.rowHeight == 306 and list.artHeight == 150 and list.actionHeight == 52)
    assert(list.gridY + list.gridHeight + 10 <= list.pager.y)
    local empty = List.empty(546, list.gridY, false, nil)
    assert(not empty.scrollable and empty.imageHeight >= 200 and empty.bottom <= 546)
end)
fs.writeFile("prototype/evidence/list-layout-tests.json", serde.encode("json", { passed = #tests, tests = tests }, true))
print("Passed " .. #tests .. " collection layout regressions")
