local name = "qol-logistics-burner-generator"

-- Reuse the base burner generator behavior with a compact footprint.
local generator = table.deepcopy(data.raw["burner-generator"]["burner-generator"])
generator.name = name
generator.hidden = true
generator.collision_box = {{-1.35, -1.35}, {1.35, 1.35}}
generator.selection_box = {{-1.5, -1.5}, {1.5, 1.5}}
generator.localised_name = { "entity-name." .. name }
generator.icon = "__qol-logistics__/graphics/burner-generator-icon.png"
generator.icon_size = 64

local running = {
  filename = "__qol-logistics__/graphics/burner-generator-running.png",
  width = 224,
  height = 224,
  scale = 0.5,
  frame_count = 12,
  line_length = 4,
  animation_speed = 0.2
}
local idle = {
  filename = "__qol-logistics__/graphics/burner-generator-idle.png",
  width = 224,
  height = 224,
  scale = 0.5,
  repeat_count = 12
}
generator.animation = {north = running, east = running, south = running, west = running}
generator.idle_animation = {north = idle, east = idle, south = idle, west = idle}

local smoke = generator.burner.smoke[1]
smoke.north_position = {-0.3, -1.5}
smoke.east_position = smoke.north_position
smoke.south_position = smoke.north_position
smoke.west_position = smoke.north_position
generator.max_power_output = "500kW"
generator.minable.result = name
generator.burner.effectivity = 0.5

data:extend{
  generator,
  {
    type = "item",
    name = name,
    hidden = true,
    icon = generator.icon,
    icon_size = generator.icon_size,
    localised_name = generator.localised_name,
    subgroup = "energy",
    order = "a[steam-power]-0[burner-generator]",
    place_result = name,
    stack_size = 10
  },
  {
    type = "recipe",
    name = name,
    enabled = false,
    hidden = true,
    localised_name = generator.localised_name,
    subgroup = "energy",
    order = "a[steam-power]-0[burner-generator]",
    main_product = name,
    energy_required = 2,
    ingredients = {
      {type = "item", name = "iron-plate", amount = 10},
      {type = "item", name = "iron-gear-wheel", amount = 5},
      {type = "item", name = "copper-cable", amount = 5}
    },
    results = {{type = "item", name = name, amount = 1}}
  }
}
