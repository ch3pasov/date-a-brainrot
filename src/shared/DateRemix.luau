-- Optional post-story memory games. No timers, daily resets or paid attempts.
local Locations = if script then require(script.Parent.Locations) else require("./Locations")
local Remix = {}
Remix.list = {
    { id = "long", name = "Большой заказ", short = "6 предметов", total = 6, required = 5,
        rule = "Запомни 6 предметов. Повтори в том же порядке.", cue = "Повтори по порядку", symbol = "6" },
    { id = "reverse", name = "Перемотка", short = "Наоборот", total = 4, required = 3,
        rule = "Запомни 4 предмета. Повтори от последнего к первому.", cue = "Начни с последнего", symbol = "↶" },
}
local byId = {}; for _, mode in Remix.list do byId[mode.id] = mode end
local souvenirs = {
    cafe = { long = { name = "Какао на шестерых", caption = "Заказ огромный. Столик всё ещё на двоих.", shape = "cup" },
        reverse = { name = "Пончик времени", caption = "Десерт был первым. Прекрасный план.", shape = "donut" } },
    park = { long = { name = "Запасливое яблоко", caption = "На пикник пришли вдвоём. Еды хватило и утке.", shape = "apple" },
        reverse = { name = "Цветок наоборот", caption = "Шли за цветами. Вернулись с маленькой легендой.", shape = "flower" } },
    rooftop = { long = { name = "Карманное созвездие", caption = "Шесть желаний. Ни одного серьёзного.", shape = "star" },
        reverse = { name = "Подарок из будущего", caption = "Вечер ещё не начался, а воспоминание уже здесь.", shape = "gift" } },
}
local byStamp = {}
for _, location in Locations.list do
    for _, mode in Remix.list do
        local souvenir = souvenirs[location.id][mode.id]
        local key = location.id .. ":" .. mode.id
        byStamp[key] = { key = key, locationId = location.id, remixId = mode.id,
            name = souvenir.name, caption = souvenir.caption, shape = souvenir.shape }
    end
end
function Remix.get(id) return type(id) == "string" and byId[id] or nil end
function Remix.key(locationId, id) return locationId .. ":" .. id end
function Remix.souvenir(locationId, id)
    return souvenirs[locationId] and souvenirs[locationId][id] or nil
end
function Remix.find(stamp) return type(stamp) == "string" and byStamp[stamp] or nil end
function Remix.passed(id, score)
    local mode = Remix.get(id)
    return mode ~= nil and type(score) == "number" and score >= mode.required / mode.total and score <= 1
end
function Remix.sticker(photo)
    local souvenir = photo and Remix.find(photo.pinnedSouvenir)
    if souvenir and photo.remixScores and Remix.passed(souvenir.remixId, photo.remixScores[souvenir.key]) then return souvenir end
    return nil
end
function Remix.validScores(scores)
    if scores == nil then return true end -- saves written before remixes
    if type(scores) ~= "table" then return false end
    local allowed = {}
    for _, location in Locations.list do
        for _, mode in Remix.list do allowed[Remix.key(location.id, mode.id)] = true end
    end
    for key, score in scores do
        if not allowed[key] or type(score) ~= "number" or score ~= score or score < 0 or score > 1 then return false end
    end
    return true
end
function Remix.progress(photo)
    local scores = photo and photo.remixScores or {}
    local collected, perfect = 0, 0
    for _, location in Locations.list do
        for _, mode in Remix.list do
            local score = scores[Remix.key(location.id, mode.id)] or 0
            if Remix.passed(mode.id, score) then collected += 1 end
            if score == 1 then perfect += 1 end
        end
    end
    return { collected = collected, perfect = perfect, total = #Locations.list * #Remix.list }
end
function Remix.sequence(id, draw)
    local mode = assert(Remix.get(id), "Unknown date remix")
    -- Begin with a shuffled set so every round uses all four choices. Longer
    -- orders add two beats. A reverse round can never be a palindrome.
    local sequence = { 1, 2, 3, 4 }
    for i = #sequence, 2, -1 do local j = draw(i); sequence[i], sequence[j] = sequence[j], sequence[i] end
    for i = #sequence + 1, mode.total do sequence[i] = draw(4) end
    return sequence
end
function Remix.answer(sequence, id, step)
    return sequence[id == "reverse" and #sequence - step + 1 or step]
end
return Remix
