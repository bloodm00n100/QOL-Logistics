local name = "qol-logistics-gravel-path"
local label = {"qol-logistics.gravel-path"}
local description = {"qol-logistics.gravel-path-description"}

-- Reuse base-game paving graphics; no Factorio artwork is redistributed.
local tile = table.deepcopy(data.raw.tile["stone-path"])
tile.name = name
tile.localised_name = label
tile.localised_description = description
tile.order = "a[artificial]-a[tier-1]-0[gravel-path]"
tile.minable = {mining_time = 0.1, result = "stone"}
tile.walking_speed_modifier = 1.2
tile.decorative_removal_probability = 1
tile.tint = {r = 0.75, g = 0.75, b = 0.75, a = 1}
tile.map_color = {r = 100, g = 100, b = 100}

-- Keep stone's existing recipes and uses; add native tile placement to it.
data.raw.item.stone.place_as_tile = {
  result = name,
  condition_size = 1,
  condition = {layers = {water_tile = true}}
}

data:extend{tile}
