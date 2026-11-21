local add_belt_diverter = require("belt-diverter")
local diverter_by_belt = {}
local add_lane_sorter = require("lane-sorter")
local sorter_by_belt = {}
local add_train_loader = require("train-loader")
local prefix = "adaptive-belt-loader-"
local template = data.raw["loader-1x1"]["loader-1x1"]
local belts = data.raw["transport-belt"]
local starter_belt = belts["transport-belt"]
local inserter_cost_speed = starter_belt and starter_belt.speed or 0.03125
local undergrounds = data.raw["underground-belt"]
local items_by_entity = {}
local sources_by_item = {}
local unlocks_by_recipe = {}
local loader_by_belt = {}
local generated = {}

-- Nudge the housing seven sprite pixels toward its belt opening.
local housing_shift = 7 / 32
local housing_shifts = {{0, housing_shift}, {-housing_shift, 0},
  {0, -housing_shift}, {housing_shift, 0}}

local function housing_frame(index)
  return {
    filename = "__qol-logistics__/graphics/loader-housing.png",
    width = 128,
    height = 128,
    x = 128 * index,
    shift = housing_shifts[index + 1],
    scale = 0.5
  }
end

-- The renderer reverses the apparent direction for input loaders.
-- Share the directional frames so the steel plate faces the inventory in both modes.
local housing_frames = {
  north = housing_frame(0),
  east = housing_frame(1),
  south = housing_frame(2),
  west = housing_frame(3)
}
local housing = {direction_in = housing_frames, direction_out = housing_frames}

local function sorted_keys(entries)
  local keys = {}
  for key in pairs(entries) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- Read the actual item-to-entity relationship, since modded names can differ.
for _, item in pairs(data.raw.item or {}) do
  if item.place_result and not item.hidden then
    local existing = items_by_entity[item.place_result]
    if not existing or item.name == item.place_result
      or (existing.name ~= item.place_result and item.name < existing.name) then
      items_by_entity[item.place_result] = item
    end
  end
end

for _, technology in pairs(data.raw.technology or {}) do
  if not technology.hidden then
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" then
        local unlocks = unlocks_by_recipe[effect.recipe] or {}
        unlocks[#unlocks + 1] = technology
        unlocks_by_recipe[effect.recipe] = unlocks
      end
    end
  end
end

for _, recipe in pairs(data.raw.recipe or {}) do
  if not recipe.hidden then
    for _, product in ipairs(recipe.results or {}) do
      if product.type ~= "fluid" and product.name then
        local sources = sources_by_item[product.name] or {}
        sources[#sources + 1] = recipe
        sources_by_item[product.name] = sources
      end
    end
  end
end

local function item_unlocks(item)
  local unlocks = {}
  for _, recipe in ipairs(sources_by_item[item.name] or {}) do
    if recipe.enabled ~= false then
      return {}
    end
    for _, technology in ipairs(unlocks_by_recipe[recipe.name] or {}) do
      unlocks[technology.name] = technology
    end
  end
  return unlocks
end

local function recipe_uses_belt(underground_item, belt_item)
  for _, recipe in ipairs(sources_by_item[underground_item.name] or {}) do
    for _, ingredient in ipairs(recipe.ingredients or {}) do
      if ingredient.type ~= "fluid" and ingredient.name == belt_item.name then
        return true
      end
    end
  end
  return false
end

local function matching_underground(belt, belt_item)
  local expected, replacements = belt.name:gsub("transport%-belt", "underground-belt", 1)
  local best_item, best_score, tied
  for name, underground in pairs(undergrounds) do
    local item = items_by_entity[name]
    if item and not underground.hidden and underground.speed == belt.speed then
      local score = 0
      if replacements > 0 and name == expected then
        score = score + 4
      end
      if recipe_uses_belt(item, belt_item) then
        score = score + 2
      end
      if item.subgroup == belt_item.subgroup then
        score = score + 1
      end
      if not best_score or score > best_score then
        best_item, best_score, tied = item, score, false
      elseif score == best_score then
        tied = true
      end
    end
  end
  if not tied then
    return best_item
  end
end

local function icon_layers(belt_item, housing_icon, icon_size)
  local icons = {{
    icon = "__qol-logistics__/graphics/" .. housing_icon,
    icon_size = icon_size or 128
  }}
  local belt_icons = table.deepcopy(belt_item.icons or {
    {icon = belt_item.icon, icon_size = belt_item.icon_size}
  })
  for _, layer in ipairs(belt_icons) do
    layer.icon_size = layer.icon_size or belt_item.icon_size or 64
    layer.scale = (layer.scale or 32 / layer.icon_size) * 0.38
    local shift = layer.shift or {0, 0}
    layer.shift = {10 + (shift[1] or shift.x) * 0.38, 10 + (shift[2] or shift.y) * 0.38}
    icons[#icons + 1] = layer
  end
  return icons
end

for _, belt_name in ipairs(sorted_keys(belts)) do
  local belt = belts[belt_name]
  local belt_item = items_by_entity[belt_name]
  if belt_item and not belt.hidden then
    local underground_item = matching_underground(belt, belt_item)
    if underground_item then
      local name = prefix .. belt_name
      local label = {"adaptive-belt-loaders.name",
        belt_item.localised_name or belt.localised_name or
          {"?", {"item-name." .. belt_item.name}, {"entity-name." .. belt_name}, belt_name}}
      local description = {"adaptive-belt-loaders.description",
        string.format("%.4g", belt.speed * 480)}
      local icons = icon_layers(belt_item, "loader-icon.png")

      local loader = table.deepcopy(template)
      loader.name = name
      loader.hidden = false
      loader.flags = {"placeable-neutral", "player-creation"}
      loader.localised_name = label
      loader.localised_description = description
      loader.icon = nil
      loader.icons = table.deepcopy(icons)
      loader.structure = table.deepcopy(housing)
      loader.speed = belt.speed
      loader.belt_animation_set = table.deepcopy(belt.belt_animation_set)
      loader.animation_speed_coefficient = belt.animation_speed_coefficient or 32
      loader.allow_container_interaction = true
      loader.allow_rail_interaction = false
      loader.fast_replaceable_group = "adaptive-belt-loader"
      loader.next_upgrade = nil
      loader.minable = {mining_time = 0.1, result = name}
      loader_by_belt[belt_name] = loader

      local item = {
        type = "item",
        name = name,
        localised_name = label,
        localised_description = description,
        icons = icons,
        subgroup = belt_item.subgroup or "belt",
        order = (belt_item.order or "") .. "[adaptive-loader]",
        place_result = name,
        stack_size = belt_item.stack_size
      }
      local unlocks = item_unlocks(underground_item)
      if not next(unlocks) then
        unlocks = item_unlocks(belt_item)
      end
      if not next(unlocks) then
        unlocks = item_unlocks(data.raw.item.inserter)
      end
      local inserter_count = math.ceil(belt.speed / inserter_cost_speed)
      local recipe = {
        type = "recipe",
        name = name,
        enabled = not next(unlocks),
        energy_required = 0.5,
        ingredients = {
          {type = "item", name = belt_item.name, amount = 1},
          {type = "item", name = underground_item.name, amount = 1},
          {type = "item", name = "inserter", amount = inserter_count}
        },
        results = {{type = "item", name = name, amount = 1}}
      }
      for _, technology_name in ipairs(sorted_keys(unlocks)) do
        local technology = unlocks[technology_name]
        technology.effects[#technology.effects + 1] = {type = "unlock-recipe", recipe = name}
      end
      add_train_loader(belt, loader, item, icon_layers(belt_item, "train-loader-icon.png"))
      sorter_by_belt[belt_name] = add_lane_sorter(belt, belt_item, unlocks, label[2], icons)
      diverter_by_belt[belt_name] = add_belt_diverter(
        belt, belt_item, unlocks, label[2], icon_layers(belt_item, "belt-diverter-icon.png", 64), sorter_by_belt[belt_name].name)
      generated[#generated + 1] = loader
      generated[#generated + 1] = item
      generated[#generated + 1] = recipe
    else
      log("[adaptive-belt-loaders] No unambiguous underground belt for " .. belt_name)
    end
  end
end

for belt_name, loader in pairs(loader_by_belt) do
  local replacement = loader_by_belt[belts[belt_name].next_upgrade]
  if replacement then
    loader.next_upgrade = replacement.name
    sorter_by_belt[belt_name].next_upgrade = sorter_by_belt[belts[belt_name].next_upgrade].name
    diverter_by_belt[belt_name].next_upgrade = diverter_by_belt[belts[belt_name].next_upgrade].name
  end
end

if #generated > 0 then
  data:extend(generated)
end

require("shipping-packer")
require("gravel-path")
require("burner-generator")
