local base_name = "qol-logistics-lane-sorter"
local template = data.raw["lane-splitter"]["lane-splitter"]

return function(belt, belt_item, unlocks, tier_label, tier_icons)
  local is_base = belt.name == "transport-belt"
  local name = is_base and base_name or base_name .. "-" .. belt.name
  local sorter = table.deepcopy(template)
  sorter.name = name
  sorter.hidden = false
  sorter.localised_name = is_base and {"entity-name." .. base_name}
    or {"qol-logistics.lane-sorter-tier", tier_label}
  sorter.localised_description = {"entity-description." .. base_name}
  sorter.minable.result = name
  sorter.speed = belt.speed
  sorter.belt_animation_set = table.deepcopy(belt.belt_animation_set)
  sorter.animation_speed_coefficient = belt.animation_speed_coefficient or 32
  sorter.next_upgrade = nil
  if not is_base then
    for index = 2, #tier_icons do
      sorter.icons[#sorter.icons + 1] = tier_icons[index]
    end
  end

  data:extend{
    sorter,
    {
      type = "item",
      name = name,
      localised_name = sorter.localised_name,
      localised_description = sorter.localised_description,
      icons = sorter.icons,
      subgroup = belt_item.subgroup or "belt",
      order = (belt_item.order or "") .. "[lane-sorter]",
      place_result = name,
      stack_size = 50
    },
    {
      type = "recipe",
      name = name,
      localised_name = sorter.localised_name,
      enabled = false,
      energy_required = 1,
      ingredients = {
        {type = "item", name = "splitter", amount = 1},
        {type = "item", name = belt_item.name, amount = 1}
      },
      results = {{type = "item", name = name, amount = 1}}
    }
  }

  if is_base or not next(unlocks) then
    unlocks = {logistics = data.raw.technology.logistics}
  end
  for _, technology in pairs(unlocks) do
    technology.effects = technology.effects or {}
    technology.effects[#technology.effects + 1] = {type = "unlock-recipe", recipe = name}
  end
  return sorter
end
