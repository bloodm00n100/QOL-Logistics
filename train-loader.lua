local train_prefix = "adaptive-train-loader-"
local storage_prefix = "adaptive-train-loader-storage-"
local outlet_prefix = "adaptive-train-loader-outlet-"

data:extend{{
  type = "custom-input",
  name = "adaptive-train-loader-toggle",
  key_sequence = "SHIFT + L",
  consuming = "none"
}}

local function platform_picture()
  local frames = {north = 2, east = 3, south = 0, west = 1}
  local picture = {}
  for direction, frame in pairs(frames) do
    local vertical = direction == "north" or direction == "south"
    local layers = {}
    for lane = -2.5, 2.5 do
      layers[#layers + 1] = {
        filename = "__qol-logistics__/graphics/train-loader-housing.png",
        width = 320,
        height = 320,
        x = 320 * frame,
        scale = 0.25,
        shift = vertical and {lane, 0} or {0, lane}
      }
    end
    picture[direction] = {layers = layers}
  end
  return picture
end

return function(belt, loader, item, unlocks, icons)
  local name = train_prefix .. belt.name
  local label = {"adaptive-belt-loaders.train-tier", loader.localised_name[2]}
  if belt.name == "transport-belt" then
    label = {"adaptive-belt-loaders.train-name"}
  end
  local description = {"adaptive-belt-loaders.train-description"}
  local outlet = table.deepcopy(data.raw.loader.loader)
  outlet.name = outlet_prefix .. belt.name
  outlet.hidden = true
  outlet.flags = {"placeable-neutral", "player-creation", "not-blueprintable", "not-deconstructable"}
  outlet.selectable_in_game = false
  outlet.collision_mask = {layers = {transport_belt = true}}
  outlet.minable = nil
  outlet.next_upgrade = nil
  outlet.fast_replaceable_group = nil
  outlet.circuit_connector = nil
  outlet.circuit_wire_max_distance = nil
  outlet.structure = nil
  outlet.speed = loader.speed
  outlet.belt_animation_set = loader.belt_animation_set
  outlet.animation_speed_coefficient = loader.animation_speed_coefficient
  outlet.allow_rail_interaction = false
  outlet.allow_container_interaction = false

  local platform = {
    type = "simple-entity-with-owner",
    name = name,
    localised_name = label,
    localised_description = description,
    icons = table.deepcopy(icons),
    flags = {"placeable-neutral", "player-creation", "placeable-player"},
    collision_box = {{-2.95, -0.95}, {2.95, 0.95}},
    selection_box = {{-3, -1}, {3, 1}},
    minable = {mining_time = 0.5, result = name},
    max_health = 450,
    picture = platform_picture(),
    render_layer = "lower-object"
  }

  -- Keep the old prototype available so placed loaders and old blueprints can be upgraded.
  platform.hidden = true
  local buffer = table.deepcopy(platform)
  local chest = data.raw.container["steel-chest"]
  buffer.type = "container"
  buffer.name = storage_prefix .. belt.name
  buffer.hidden = nil
  buffer.render_layer = nil
  buffer.direction_count = 4
  buffer.inventory_size = 40
  buffer.quality_affects_inventory_size = true
  buffer.circuit_wire_max_distance = chest.circuit_wire_max_distance
  buffer.circuit_connector = {}
  for direction = 1, 4 do
    buffer.circuit_connector[direction] = table.deepcopy(chest.circuit_connector)
  end

  local platform_item = table.deepcopy(item)
  platform_item.icons = icons
  platform_item.name = name
  platform_item.localised_name = label
  platform_item.localised_description = description
  platform_item.order = item.order .. "[train-loader]"
  platform_item.place_result = buffer.name

  local recipe = {
    type = "recipe",
    name = name,
    enabled = not next(unlocks),
    energy_required = 2,
    ingredients = {{type = "item", name = item.name, amount = 6}},
    results = {{type = "item", name = name, amount = 1}}
  }
  for _, technology in pairs(unlocks) do
    technology.effects[#technology.effects + 1] = {type = "unlock-recipe", recipe = name}
  end
  data:extend({outlet, platform, buffer, platform_item, recipe})
end
