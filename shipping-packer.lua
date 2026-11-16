local machine_name = "qol-logistics-shipping-packer"
local machine_icon = "__qol-logistics__/graphics/shipping-packer-icon.png"
local empty_name = "qol-logistics-shipping-container"
local cargo_prefix = "qol-logistics-packed-"
local packed_stack_size = 50
local rocket_lift_weight = data.raw["utility-constants"].default.default_rocket_lift_weight
local packed_weight = rocket_lift_weight / packed_stack_size
local packer_stack_size = 10
local pack_category = "qol-logistics-packing"
local unpack_category = "qol-logistics-unpacking"
local locale = "qol-logistics."

local machine = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
machine.name = machine_name
machine.icons = nil
machine.icon = machine_icon
machine.icon_size = 128
local function packer_animation(direction, width, height)
  return {
    filename = "__qol-logistics__/graphics/shipping-packer-" .. direction .. ".png",
    width = width,
    height = height,
    scale = 0.5,
    frame_count = 12,
    line_length = 4,
    animation_speed = 0.25
  }
end

machine.graphics_set = {
  animation = {
    north = packer_animation("north", 256, 384),
    east = packer_animation("east", 384, 256),
    south = packer_animation("south", 256, 384),
    west = packer_animation("west", 384, 256)
  }
}
machine.animation_random_start_frame = false
machine.water_reflection = nil
machine.localised_name = {locale .. "machine"}
machine.localised_description = {locale .. "machine-description"}
machine.minable = {mining_time = 0.5, result = machine_name}
machine.collision_box = {{-1.95, -2.95}, {1.95, 2.95}}
machine.selection_box = {{-2, -3}, {2, 3}}
machine.crafting_categories = {pack_category, unpack_category}
machine.fast_replaceable_group = nil
machine.next_upgrade = nil
machine.fluid_boxes = nil
machine.fluid_boxes_off_when_no_fluid_recipe = nil
machine.module_slots = 3
machine.allowed_module_categories = {"speed"}
machine.allowed_effects = {"consumption", "speed", "pollution"}
machine.crafting_speed = 1
machine.energy_usage = "200kW"

local crate_icon = "__base__/graphics/icons/steel-chest.png"
local technology = data.raw.technology["automation-2"]

local function unlock(recipe_name)
  if technology then
    technology.effects = technology.effects or {}
    technology.effects[#technology.effects + 1] = {type = "unlock-recipe", recipe = recipe_name}
  end
end

local function ingredient(name, count)
  return {type = "item", name = name, amount = count}
end

local function recipe(name, category, label, ingredients, products, main_product)
  unlock(name)
  return {
    type = "recipe",
    name = name,
    categories = {category},
    localised_name = label,
    enabled = technology == nil,
    ingredients = ingredients,
    results = products,
    main_product = main_product,
    energy_required = 1,
    allow_productivity = false,
    allow_quality = false,
    auto_recycle = false,
    allow_decomposition = false
  }
end

local prototypes = {
  machine,
  {type = "recipe-category", name = pack_category},
  {type = "recipe-category", name = unpack_category},
  {type = "item-group", name = pack_category, icon = crate_icon, icon_size = 64, order = "zz-a[qol-packing]"},
  {type = "item-group", name = unpack_category, icon = "__base__/graphics/icons/iron-plate.png",
    icon_size = 64, order = "zz-b[qol-unpacking]"},
  {type = "item-subgroup", name = pack_category, group = pack_category, order = "a"},
  {type = "item-subgroup", name = unpack_category, group = unpack_category, order = "a"},
  {
    type = "item",
    name = machine_name,
    localised_name = machine.localised_name,
    localised_description = machine.localised_description,
    icon = machine_icon,
    icon_size = 128,
    subgroup = "production-machine",
    order = "z[shipping-packer]",
    place_result = machine_name,
    stack_size = packer_stack_size,
    weight = rocket_lift_weight / packer_stack_size
  },
  {
    type = "item",
    name = empty_name,
    localised_name = {locale .. "empty-container"},
    icon = crate_icon,
    subgroup = "storage",
    order = "z[shipping-container]",
    weight = kg,
    stack_size = 50
  },
  recipe(machine_name, "crafting", machine.localised_name,
    {ingredient("assembling-machine-2", 1), ingredient("steel-plate", 20),
      ingredient("iron-gear-wheel", 10)}, {ingredient(machine_name, 1)}, machine_name),
  recipe(empty_name, "crafting", {locale .. "empty-container"},
    {ingredient("steel-plate", 1)}, {ingredient(empty_name, 1)}, empty_name)
}

local names = {}
for name in pairs(data.raw.item) do
  names[#names + 1] = name
end
table.sort(names)

for _, name in ipairs(names) do
  local item = data.raw.item[name]
  -- Spoilable and inventory-bearing items need per-item state that a recipe cannot preserve.
  if item.stack_size > 1 and item.stack_size <= 65535 and not item.hidden
    and (item.spoil_ticks or 0) == 0 and #name <= 170 then
    local cargo_name = cargo_prefix .. name
    local label = item.localised_name or {"?", {"item-name." .. name},
      {"entity-name." .. (item.place_result or name)}, name}
    local icons = {{icon = crate_icon, icon_size = 64}}
    local badges = table.deepcopy(item.icons or {{icon = item.icon, icon_size = item.icon_size}})
    for _, badge in ipairs(badges) do
      badge.icon_size = badge.icon_size or item.icon_size or 64
      badge.scale = (badge.scale or 32 / badge.icon_size) * 0.5
      local shift = badge.shift or {0, 0}
      badge.shift = {7 + (shift[1] or shift.x) * 0.5, -7 + (shift[2] or shift.y) * 0.5}
      icons[#icons + 1] = badge
    end
    prototypes[#prototypes + 1] = {
      type = "item",
      name = cargo_name,
      localised_name = {locale .. "packed", label},
      localised_description = {locale .. "packed-description", tostring(item.stack_size)},
      icons = icons,
      subgroup = pack_category,
      order = (item.order or "") .. "[" .. name .. "]",
      stack_size = packed_stack_size,
      weight = packed_weight,
      auto_recycle = false
    }

    local pack = recipe("qol-logistics-pack-" .. name, pack_category, {locale .. "pack", label},
      {ingredient(name, item.stack_size), ingredient(empty_name, 1)},
      {ingredient(cargo_name, 1)}, cargo_name)
    pack.energy_required = 5
    pack.subgroup = pack_category
    pack.hide_from_player_crafting = true
    prototypes[#prototypes + 1] = pack

    local unpack = recipe("qol-logistics-unpack-" .. name, unpack_category, {locale .. "unpack", label},
      {ingredient(cargo_name, 1)},
      {ingredient(name, item.stack_size), ingredient(empty_name, 1)}, name)
    unpack.energy_required = 5
    unpack.subgroup = unpack_category
    unpack.hide_from_player_crafting = true
    prototypes[#prototypes + 1] = unpack
  end
end

data:extend(prototypes)
