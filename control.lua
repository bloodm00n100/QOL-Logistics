local diverters = require("belt-diverter-control")
require("belt-diverter-gui")

-- Apply existing research when adding the mod to a save.
local function unlock_researched_recipes()
  for _, force in pairs(game.forces) do
    for _, technology in pairs(force.technologies) do
      if technology.researched then
        for _, effect in ipairs(technology.prototype.effects or {}) do
          if effect.type == "unlock-recipe"
            and (effect.recipe:find("^adaptive%-belt%-loader%-")
              or effect.recipe:find("^adaptive%-train%-loader%-")
              or effect.recipe:find("^qol%-logistics%-"))
            and force.recipes[effect.recipe] then
            force.recipes[effect.recipe].enabled = true
          end
        end
      end
    end
  end
end

local platform_prefix = "adaptive-train-loader-"
local outlet_prefix = platform_prefix .. "outlet-"
local storage_prefix = platform_prefix .. "storage-"

local function update_train_loader_recipes(force)
  local railway = force.technologies.railway
  for name, recipe in pairs(force.recipes) do
    if name:sub(1, #platform_prefix) == platform_prefix then
      local ingredient = recipe.ingredients[1]
      local matching_loader = ingredient and force.recipes[ingredient.name]
      recipe.enabled = railway ~= nil and railway.researched
        and matching_loader ~= nil and matching_loader.enabled
    end
  end
end

script.on_event({defines.events.on_research_finished, defines.events.on_research_reversed}, function(event)
  update_train_loader_recipes(event.research.force)
end)

local function upgrade_platform(legacy)
  local registration = script.register_on_object_destroyed(legacy)
  local outlets = storage.train_loaders and storage.train_loaders[registration]
  local platform = legacy.surface.create_entity{
    name = storage_prefix .. legacy.name:sub(#platform_prefix + 1),
    position = legacy.position,
    direction = legacy.direction,
    force = legacy.force,
    quality = legacy.quality
  }
  if not platform then
    return legacy
  end
  platform.health = legacy.health
  if outlets then
    storage.train_loaders[registration] = nil
    storage.train_loaders[script.register_on_object_destroyed(platform)] = outlets
  end
  legacy.destroy()
  platform.rotatable = false
  return platform
end

local function place_train_loader(event)
  local platform = event.entity or event.destination
  if event.destination and platform.valid and platform.name:sub(1, #outlet_prefix) == outlet_prefix then
    -- The cloned platform creates and owns its own outlets.
    platform.destroy()
    return
  end
  if not platform or not platform.valid or platform.name:sub(1, #platform_prefix) ~= platform_prefix then
    return
  end

  if platform.type == "simple-entity-with-owner" then
    platform = upgrade_platform(platform)
  end
  if platform.name:sub(1, #storage_prefix) ~= storage_prefix then
    return
  end

  local belt_name = platform.name:sub(#storage_prefix + 1)
  local direction = platform.direction
  local vertical = direction == defines.direction.north or direction == defines.direction.south
  local position = platform.position
  local registration = script.register_on_object_destroyed(platform)
  storage.train_loaders = storage.train_loaders or {}
  storage.train_buffers = storage.train_buffers or {}
  storage.train_buffers[registration] = {entity = platform}
  if storage.train_loaders[registration] then
    return
  end
  local outlets = {}
  storage.train_loaders[registration] = outlets
  local outlet_name = outlet_prefix .. belt_name
  local existing = {}
  local mode, outlet_direction = "output", direction
  if event.adopt_existing then
    for lane = -2.5, 2.5 do
      local lane_position = {position.x + (vertical and lane or 0), position.y + (vertical and 0 or lane)}
      local outlet = platform.surface.find_entity(outlet_name, lane_position)
      if outlet and outlet.force == platform.force then
        existing[lane] = outlet
        mode, outlet_direction = outlet.loader_type, outlet.direction
      end
    end
  end
  for lane = -2.5, 2.5 do
    local outlet = existing[lane] or platform.surface.create_entity{
      name = outlet_name,
      position = {position.x + (vertical and lane or 0), position.y + (vertical and 0 or lane)},
      direction = outlet_direction,
      type = mode,
      force = platform.force,
      quality = platform.quality
    }
    if outlet then
      outlet.destructible = false
      outlet.rotatable = false
      outlets[#outlets + 1] = outlet
    end
  end
  platform.rotatable = false
end

local function grant_circuit_research(force)
  if not settings.startup["qol-logistics-start-with-circuit-research"].value then
    return
  end

  for _, name in ipairs{"circuit-network", "advanced-combinators"} do
    local technology = force.technologies[name]
    if technology and not technology.researched then
      technology.researched = true
    end
  end
end

local function grant_starting_research()
  for _, force in pairs(game.forces) do
    if force.name ~= "enemy" and force.name ~= "neutral" then
      grant_circuit_research(force)
    end
  end
end

script.on_event(defines.events.on_force_created, function(event)
  grant_circuit_research(event.force)
end)

script.on_init(function()
  diverters.adopt()
  grant_starting_research()
  unlock_researched_recipes()
  for _, force in pairs(game.forces) do
    update_train_loader_recipes(force)
  end
  local names = {}
  for name, prototype in pairs(prototypes.entity) do
    if (prototype.type == "container" and name:sub(1, #storage_prefix) == storage_prefix)
      or (prototype.type == "simple-entity-with-owner" and name:sub(1, #platform_prefix) == platform_prefix) then
      names[#names + 1] = name
    end
  end
  if #names > 0 then
    for _, surface in pairs(game.surfaces) do
      for _, platform in ipairs(surface.find_entities_filtered{name = names}) do
        place_train_loader{entity = platform, adopt_existing = true}
      end
    end
  end
end)

script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  defines.events.on_entity_cloned
}, function(event)
  diverters.register(event.destination or event.entity or event.created_entity)
  place_train_loader(event)
end)

script.on_event(defines.events.on_object_destroyed, function(event)
  local platforms = storage.train_loaders
  local outlets = platforms and platforms[event.registration_number]
  if not outlets then
    return
  end
  if storage.train_buffers then
    storage.train_buffers[event.registration_number] = nil
  end
  for _, outlet in ipairs(outlets) do
    if outlet.valid then
      local surface = outlet.surface
      local position = outlet.position
      for line_index = 1, 2 do
        for _, stack in pairs(outlet.get_transport_line(line_index).get_contents()) do
          surface.spill_item_stack{position = position, stack = stack, enable_looted = true}
        end
      end
      outlet.destroy()
    end
  end
  platforms[event.registration_number] = nil
end)

local toggle_train_mode = require("train-mode")

script.on_event("adaptive-train-loader-toggle", function(event)
  local player = game.get_player(event.player_index)
  local platform = player and player.selected
  if not platform or platform.force ~= player.force
    or platform.name:sub(1, #storage_prefix) ~= storage_prefix then
    return
  end
  local platforms = storage.train_loaders
  local outlets = platforms and platforms[script.register_on_object_destroyed(platform)]
  if not outlets then
    return
  end
  local mode = toggle_train_mode(platform, outlets)
  if mode then
    local label = mode == "input" and "train-load-mode" or "train-unload-mode"
    player.create_local_flying_text{text = {"adaptive-belt-loaders." .. label}, position = platform.position}
  end
end)

script.on_configuration_changed(function()
  diverters.adopt()
  grant_starting_research()
  unlock_researched_recipes()
  for _, force in pairs(game.forces) do
    update_train_loader_recipes(force)
  end
  local legacy_names = {}
  for name, prototype in pairs(prototypes.entity) do
    if prototype.type == "simple-entity-with-owner" and name:sub(1, #platform_prefix) == platform_prefix then
      legacy_names[#legacy_names + 1] = name
    end
  end
  if #legacy_names > 0 then
    for _, surface in pairs(game.surfaces) do
      for _, entity in ipairs(surface.find_entities_filtered{name = legacy_names}) do
        place_train_loader{entity = entity}
      end
    end
  end
end)

local update_train_buffers = require("train-buffer")
script.on_event(defines.events.on_tick, function(event)
  update_train_buffers(event)
  diverters.tick()
end)
