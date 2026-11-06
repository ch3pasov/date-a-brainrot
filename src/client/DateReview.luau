local Locations = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Locations)
local UI = require(script.Parent.UI)
local C = UI.colors
local Review = {}
function Review.mount(parent, recap, width, top)
    local review = recap and recap.dateReview
    if not review then return 0 end
    local missed = false
    for i = 1, recap.total do if recap.hits[i] == false then missed = true; break end end
    if not missed then return 0 end
    local items = Locations.get(review.locationId).items
    local font = UI.readableSize(17)
    local small = UI.readableSize(13, 10)
    local titleH = UI.textHeight("РАЗБОР ПОРЯДКА", font, width, true)
    local hint = review.reversed and "Здесь план уже развёрнут: от последнего предмета к первому." or "Сравним план с тем, что получилось. В новом раунде порядок может измениться."
    local hintH = UI.textHeight(hint, small, width, false)
    local box = UI.frame(parent, "DateReview", UDim2.fromOffset(0, top), UDim2.fromOffset(width, 0), C.panel, 0)
    UI.label(box, "Title", "РАЗБОР ПОРЯДКА", UDim2.fromOffset(0, 0), UDim2.fromOffset(width, titleH), font, C.ink, true)
    UI.label(box, "Hint", hint, UDim2.fromOffset(0, titleH+8), UDim2.fromOffset(width, hintH), small, C.muted)
    local numberW = math.max(32, math.ceil(font*1.7))
    local columnW = (width-numberW-20)/2
    local x1, x2 = numberW+8, numberW+columnW+16
    local y = titleH+hintH+20
    local labelH = math.max(UI.textHeight("По плану", small, columnW, true), UI.textHeight("Твой выбор", small, columnW, true))
    UI.label(box, "ExpectedHeading", "По плану", UDim2.fromOffset(x1, y), UDim2.fromOffset(columnW, labelH), small, C.muted, true)
    UI.label(box, "ChoiceHeading", "Твой выбор", UDim2.fromOffset(x2, y), UDim2.fromOffset(columnW, labelH), small, C.muted, true)
    y += labelH+8
    for i = 1, recap.total do
        local expected, choice = items[review.expected[i]], items[review.choices[i]]
        if not expected or not choice then continue end
        local good = recap.hits[i] == true
        local rowH = math.ceil(math.max(UI.textHeight(expected.label, font, columnW-12, true), UI.textHeight(choice.label, font, columnW-12, true), font*1.4))+16
        local row = UI.frame(box, "Step_"..i, UDim2.fromOffset(0, y), UDim2.fromOffset(width, rowH), C.card, 5)
        row:SetAttribute("Correct", good)
        UI.label(row, "Number", tostring(i), UDim2.fromOffset(0, 8), UDim2.fromOffset(numberW, rowH-16), font, C.muted, true).TextXAlignment=Enum.TextXAlignment.Center
        UI.label(row, "Expected", expected.label, UDim2.fromOffset(x1+6, 8), UDim2.fromOffset(columnW-12, rowH-16), font, C.ink, true)
        local chosen = UI.frame(row, "Choice", UDim2.fromOffset(x2, 4), UDim2.fromOffset(columnW, rowH-8), good and C.aqua or C.panel, 4)
        UI.stroke(chosen, good and C.mint or C.pink).Thickness=2
        UI.label(chosen, "Item", choice.label, UDim2.fromOffset(6, 4), UDim2.new(1, -12, 1, -8), font, C.ink, true)
        y += rowH+8
    end
    box.Size=UDim2.fromOffset(width,y)
    return y+12
end
return Review
