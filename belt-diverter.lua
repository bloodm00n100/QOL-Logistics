local base_name = "qol-logistics-belt-diverter"
local diverter = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
diverter.hidden = false
diverter.flags = {"placeable-neutral", "player-creation"}
diverter.filter_count = 2
diverter.belt_length = 1
diverter.belt_animation_set = nil
diverter.structure_render_layer = "transport-belt"
diverter.allow_container_interaction = false
diverter.allow_rail_interaction = false
diverter.icon = "__qol-logistics__/graphics/belt-diverter-icon.png"
diverter.icon_size = 64
diverter.icon_draw_specification = {scale = 0.4}
local housing = {
  filename = "__qol-logistics__/graphics/belt-diverter.png",
  width = 72,
  height = 72,
  scale = 0.5
}
local housing_sprite = table.deepcopy(housing)
housing_sprite.type = "sprite"
housing_sprite.name = "qol-logistics-belt-diverter-housing"
data:extend{housing_sprite}

-- Loaders draw an end cap. Put a straight belt tread under the housing
-- so the open center reads as a continuous belt instead of bare terrain.
local function through_belt_graphics(belt, name)
  local animation_set = belt.belt_animation_set
  local source = animation_set and animation_set.animation_set
  if not source or not source.filename or (source.line_length and source.line_length ~= 0)
    or not (source.width or source.size) or not (source.height or source.size)
    or math.floor(32 / (source.scale or 1)) > math.min(source.width or source.size, source.height or source.size)
    or (source.direction_count or 1) < 4 or source.x or source.y
    or source.shift or source.hr_version then
    animation_set = data.raw["transport-belt"]["transport-belt"].belt_animation_set
    source = animation_set.animation_set
  end
  local width = source.width or source.size
  local height = source.height or source.size
  local scale = source.scale or 1
  local crop = math.floor(32 / scale)
  local function frame(direction, index)
    local x = math.floor((width - crop) / 2)
    local y = (index - 1) * height + math.floor((height - crop) / 2)
    local tread = {
      filename = source.filename,
      x = x,
      y = y,
      width = crop,
      height = crop,
      scale = scale
    }
    local stripes = {}
    local frame_count = source.frame_count or 1
    for number = 1, frame_count do
      stripes[number] = {
        filename = source.filename,
        x = x + (number - 1) * width,
        y = y,
        width_in_frames = 1,
        height_in_frames = 1
      }
    end
    data:extend{{
      type = "animation",
      name = name .. "-tread-" .. direction,
      stripes = stripes,
      width = crop,
      height = crop,
      scale = scale,
      frame_count = frame_count
    }}
    return {layers = {tread, housing}}
  end
  local frames = {
    north = frame("north", animation_set.north_index or 3),
    east = frame("east", animation_set.east_index or 1),
    south = frame("south", animation_set.south_index or 4),
    west = frame("west", animation_set.west_index or 2)
  }
  -- The cursor preview uses the loader's output structure.
  return {
    direction_in = frames,
    direction_out = {north = frames.south, east = frames.west, south = frames.north, west = frames.east}
  }
end

diverter.fast_replaceable_group = base_name

return function(belt, belt_item, unlocks, tier_label, icons, sorter_name)
  local is_base = belt.name == "transport-belt"
  local name = is_base and base_name or base_name .. "-" .. belt.name
  local entity = table.deepcopy(diverter)
  entity.name = name
  entity.localised_name = is_base and {"entity-name." .. base_name}
    or {"qol-logistics.diverter-tier", tier_label}
  entity.localised_description = {"entity-description." .. base_name}
  entity.minable = {mining_time = 0.1, result = name}
  entity.speed = belt.speed
  entity.structure = through_belt_graphics(belt, name)
  entity.animation_speed_coefficient = belt.animation_speed_coefficient or 32
  if not is_base then
    entity.icons = icons
    entity.icon = nil
  end

  local item = {
    type = "item",
    name = name,
    localised_name = entity.localised_name,
    localised_description = entity.localised_description,
    icon = entity.icon,
    icons = entity.icons,
    icon_size = entity.icon_size,
    subgroup = belt_item.subgroup or "belt",
    order = (belt_item.order or "") .. "[belt-diverter]",
    place_result = name,
    stack_size = 50
  }
  local recipe = {
    type = "recipe",
    name = name,
    localised_name = entity.localised_name,
    enabled = false,
    energy_required = 1,
    ingredients = {
      {type = "item", name = sorter_name, amount = 1},
      {type = "item", name = belt_item.name, amount = 1}
    },
    results = {{type = "item", name = name, amount = 1}}
  }

  if is_base or not next(unlocks) then
    unlocks = {logistics = data.raw.technology.logistics}
  end
  for _, technology in pairs(unlocks) do
    technology.effects = technology.effects or {}
    technology.effects[#technology.effects + 1] = {type = "unlock-recipe", recipe = name}
  end

  data:extend{entity, item, recipe}
  return entity
end
