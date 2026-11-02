-- All prototype tuning is in this module. No purchases or external services.
return {
    Version = 1,
    FeedSize = 12,
    ImmediateResponseShare = 0.55,
    ImmediateDeclineShare = 0.18,
    ResponseDelayMin = 45,
    ResponseDelayMax = 720,
    NeverResponseWindow = 24 * 60 * 60,
    MinigameThreshold = 0.55,
    DataStoreName = "DateABrainrot_Prototype_v1",
    Variants = {
        { id = "classic", label = "Классический", chanceFactor = 1, weight = 58, color = { 0.60, 0.75, 1 } },
        { id = "gold", label = "Золотой", chanceFactor = 0.85, weight = 22, color = { 1, 0.76, 0.27 } },
        { id = "neon", label = "Неоновый", chanceFactor = 0.72, weight = 14, color = { 0.38, 1, 0.83 } },
        { id = "cosmic", label = "Космический", chanceFactor = 0.60, weight = 6, color = { 0.73, 0.55, 1 } },
    },
    Rarities = {
        common = { label = "Обычный", color = { 0.58, 0.82, 0.73 }, chance = 0.68 },
        rare = { label = "Редкий", color = { 0.49, 0.70, 1 }, chance = 0.49 },
        epic = { label = "Эпический", color = { 0.75, 0.58, 1 }, chance = 0.32 },
        legendary = { label = "Легендарный", color = { 1, 0.77, 0.34 }, chance = 0.18 },
    },
}
