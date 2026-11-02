-- Authored outdoor date settings; IDs are persisted in completed album stories.
local Locations = {}
Locations.list = {
    { id = "cafe", name = "Кафе на площади", short = "Кафе", caption = "Какао, пончики и твой странный собеседник.", sky = { .91, .96, 1 }, ground = { .96, .86, .73 }, accent = { .93, .47, .50 },
      plan = "Собери наш заказ", items = {
          { label = "Какао", shape = "cup", color = { .64, .38, .26 } },
          { label = "Пончик", shape = "donut", color = { .99, .60, .70 } },
          { label = "Пирожное", shape = "cake", color = { .97, .82, .38 } },
          { label = "Цветок", shape = "flower", color = { .75, .61, .95 } },
      } },
    { id = "park", name = "Парк у воды", short = "Парк", caption = "Пикник, утки и очень важные глупости.", sky = { .83, .95, 1 }, ground = { .65, .83, .59 }, accent = { .30, .66, .51 },
      plan = "Собери наш пикник", items = {
          { label = "Яблоко", shape = "apple", color = { .94, .39, .42 } },
          { label = "Сок", shape = "cup", color = { 1, .76, .32 } },
          { label = "Сэндвич", shape = "sandwich", color = { .87, .71, .41 } },
          { label = "Цветок", shape = "flower", color = { .80, .58, .91 } },
      } },
    { id = "rooftop", name = "Крыша над городом", short = "Крыша", caption = "Город внизу. Наш общий вайб — выше.", sky = { .86, .85, 1 }, ground = { .76, .77, .90 }, accent = { .55, .44, .78 },
      plan = "Подготовь наш вечер", items = {
          { label = "Звезда", shape = "star", color = { 1, .84, .38 } },
          { label = "Лимонад", shape = "cup", color = { .72, .92, .48 } },
          { label = "Подарок", shape = "gift", color = { .97, .55, .71 } },
          { label = "Фонарик", shape = "lantern", color = { .93, .75, .33 } },
      } },
}
local byId = {}; for _, location in Locations.list do byId[location.id] = location end
function Locations.valid(id) return type(id) == "string" and byId[id] ~= nil end
function Locations.get(id) return byId[id] or byId.park end
function Locations.forPersonality(personality)
    return ({ food = "cafe", humor = "cafe", nature = "park", art = "park", music = "rooftop", adventure = "rooftop" })[personality] or "park"
end
Locations.gestures = {
    { id = "wave", label = "Помахать", hint = "Помаши мне!" },
    { id = "heart", label = "Сердечко", hint = "Покажи сердечко!" },
    { id = "dance", label = "Танец", hint = "Потанцуем?" },
}
-- Enumerate the small balanced deck once: every gesture appears twice,
-- with no adjacent repeats. A round selects one whole pattern uniformly.
local gesturePatterns = {}
local function addPatterns(pattern, remaining)
    if #pattern == #Locations.gestures * 2 then
        table.insert(gesturePatterns, table.clone(pattern))
        return
    end
    for gesture = 1, #Locations.gestures do
        if remaining[gesture] > 0 and pattern[#pattern] ~= gesture then
            remaining[gesture] -= 1
            table.insert(pattern, gesture)
            addPatterns(pattern, remaining)
            table.remove(pattern)
            remaining[gesture] += 1
        end
    end
end
addPatterns({}, table.create(#Locations.gestures, 2))
Locations.gesturePatternCount = #gesturePatterns
function Locations.gesture(attempt, seed)
    local pattern = gesturePatterns[(seed - 1) % #gesturePatterns + 1]
    return pattern[(attempt - 1) % #pattern + 1]
end
return Locations
