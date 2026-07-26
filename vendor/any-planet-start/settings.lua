local setting = {
    type = "string-setting",
    name = "aps-planet",
    setting_type = "startup",
    default_value = "none",
    allowed_values = {"none", "vulcanus", "fulgora", "gleba"},
    order = "a",
}

data:extend{setting}

APS = {
    fixed_choice = false
}

---@param planet string
function APS.add_choice(planet)
    if APS.fixed_choice then return end
    setting.allowed_values[#setting.allowed_values+1] = planet
end

---@param planet string
function APS.remove_choice(planet)
    if APS.fixed_choice then return end
    for i, choice in pairs(setting.allowed_values) do
        if choice == planet then
            table.remove(setting.allowed_values, i)
            break
        end
    end
end

---@param planet string
function APS.set_fixed_choice(planet)
    setting.allowed_values = {planet}
    setting.default_value = planet
    APS.fixed_choice = true
end

---@param planet string
function APS.set_default_choice(planet)
    if APS.fixed_choice then return end
    setting.default_value = planet
end

data:extend{{
    type = "bool-setting",
    name = "aps-safe-orbit",
    setting_type = "startup",
    default_value = true,
    order = "a"
}, {
    type = "bool-setting",
    name = "aps-vulcanus-fulgora",
    setting_type = "startup",
    default_value = false,
    order = "c",
}, {
    type = "double-setting",
    name = "aps-vulcanus-rock-multiplier",
    setting_type = "startup",
    default_value = 1,
    minimum_value = 1,
    maximum_value = 100,
    order = "d",
}}