local Catalog = if script then require(script.Parent.Catalog) else require("./Catalog")
local Config = if script then require(script.Parent.Config) else require("./Config")
local Locations = if script then require(script.Parent.Locations) else require("./Locations")
local Remix = if script then require(script.Parent.DateRemix) else require("./DateRemix")
local Collection = {}
local valid = {}; for _, character in Catalog do valid[character.id] = true end
function Collection.passport(photo)
    local visited, count = {}, 0
    photo = photo or {}
    for _, location in Locations.list do
        if photo.locationId == location.id or (type(photo.visitedLocations) == "table" and photo.visitedLocations[location.id] == true) then
            visited[location.id] = true; count += 1
        end
    end
    return { visited = visited, count = count, maximum = #Locations.list, complete = count == #Locations.list }
end
function Collection.stats(album)
    local characters, keys, variants = {}, {}, {}
    for _, v in Config.Variants do variants[v.id] = 0 end
    local total, completedPassports, souvenirs = 0, 0, 0
    for _, photo in album or {} do
        if photo.key and not keys[photo.key] and valid[photo.characterId] and variants[photo.variantId] ~= nil then
            keys[photo.key] = true; characters[photo.characterId] = true; total += 1; variants[photo.variantId] += 1
            if Collection.passport(photo).complete then completedPassports += 1 end
            souvenirs += Remix.progress(photo).collected
        end
    end
    local unique = 0; for _ in characters do unique += 1 end
    return { total = total, maximum = #Catalog * #Config.Variants, characters = unique, characterMaximum = #Catalog, variants = variants, completedPassports = completedPassports, souvenirs = souvenirs }
end
function Collection.nextPlace(photo)
    local passport = Collection.passport(photo)
    for _, location in Locations.list do
        if not passport.visited[location.id] then return location.id end
    end
    return nil
end
function Collection.goalHint(photo)
    local nextPlace = Collection.nextPlace(photo)
    if nextPlace then return "ВПЕРЕДИ: " .. Locations.get(nextPlace).short .. " →" end
    local remixes = Remix.progress(photo)
    if remixes.collected < remixes.total then return "СУВЕНИРЫ " .. remixes.collected .. "/" .. remixes.total .. " →" end
    return "ВСЕ СУВЕНИРЫ СОБРАНЫ ♥"
end
function Collection.memento(personality)
    return ({
        food = "Вечер, когда последний кусочек стал двумя маленькими победами.",
        music = "Наш первый общий ритм. Немного странный, зато точно наш.",
        nature = "Тихий пикник. Волны, плед и хороший собеседник.",
        adventure = "Маленькое приключение, которое оказалось большой хорошей историей.",
        art = "Шедевр вышел кривым. Настроение получилось идеальным.",
        humor = "Два случайных огурца и очень удачный вечер.",
    })[personality] or "Маленькая история, которую хочется сохранить."
end
function Collection.perfect(photo)
    if not photo or type(photo.scores) ~= "table" then return false end
    for i = 1, 3 do if photo.scores[tostring(i)] ~= 1 then return false end end
    return true
end
return Collection
