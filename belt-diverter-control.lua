local name = "qol-logistics-belt-diverter"
local directions = {
  [defines.direction.north] = {0, -1},
  [defines.direction.east] = {1, 0},
  [defines.direction.south] = {0, 1},
  [defines.direction.west] = {-1, 0}
}

local prefix = name .. "-"
local function is_diverter_name(prototype_name)
  return prototype_name == name or prototype_name:sub(1, #prefix) == prefix
end

local function is_diverter(entity)
  return entity and entity.valid and entity.type == "loader-1x1" and is_diverter_name(entity.name)
end

local function keep_input_direction(entity)
  if entity.loader_type == "input" then return end
  local direction = entity.direction
  entity.loader_type = "input"
  entity.direction = direction
end

local function register(entity)
  if entity and entity.valid and entity.type == "entity-ghost" and entity.ghost_type == "loader-1x1" and is_diverter_name(entity.ghost_name) then
    keep_input_direction(entity)
    return
  end
  if is_diverter(entity) then
    storage.belt_diverters = storage.belt_diverters or {}
    storage.belt_diverters[entity.unit_number] = {entity = entity, next_lane = 1}
    keep_input_direction(entity)
  end
end

local function adopt()
  storage.belt_diverters = storage.belt_diverters or {}
  local names = {}
  for prototype_name, prototype in pairs(prototypes.entity) do
    if prototype.type == "loader-1x1" and is_diverter_name(prototype_name) then
      names[#names + 1] = prototype_name
    end
  end
  if #names == 0 then return end
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = names}) do
      if not storage.belt_diverters[entity.unit_number] then
        register(entity)
      end
    end
  end
end

local function belt_at(entity, x, y)
  local p = entity.position
  local belt = entity.surface.find_entities_filtered{
    position = {p.x + x, p.y + y},
    type = {"transport-belt", "underground-belt"},
    force = entity.force,
    limit = 1
  }[1]
  if belt and (belt.type == "transport-belt" or belt.belt_to_ground_type == "input") then
    return belt
  end
end

local function front_stack(line)
  local count = #line
  if count == 0 then return end
  if line.get_item_position(1) <= 0 then return line[1] end
  if line.get_item_position(count) <= 0 then return line[count] end
end

local function transfer(stack, output)
  if not output.can_insert_at_back() then return false end
  storage.diverter_transfer_buffer = storage.diverter_transfer_buffer or game.create_inventory(1)
  local copy = storage.diverter_transfer_buffer[1]
  if not copy.set_stack(stack) then return false end
  copy.count = 1
  local inserted = output.insert_at_back(copy)
  copy.clear()
  if inserted then
    stack.count = stack.count - 1
  end
  return inserted
end

local function divert(entity, stack, x, y, parallel_lane)
  local belt = belt_at(entity, x, y)
  if not belt then return end

  if belt.direction == entity.direction then
    return transfer(stack, belt.get_transport_line(parallel_lane))
  end

  local flow = directions[belt.direction]
  if not flow then return end

  -- A reversed parallel belt swaps which of its lanes is closest.
  if flow[1] * x + flow[2] * y == 0 then
    return transfer(stack, belt.get_transport_line(3 - parallel_lane))
  elseif flow[1] == x and flow[2] == y then
    return transfer(stack, belt.get_transport_line(parallel_lane))
      or transfer(stack, belt.get_transport_line(3 - parallel_lane))
  end
end

local function update_arrows(state, x, y, left, right)
  local entity = state.entity
  if state.arrow_direction == entity.direction and state.left_arrow == left
    and state.right_arrow == right then return end

  for _, arrow in ipairs(state.arrows or {}) do
    if arrow.valid then arrow.destroy() end
  end
  state.arrows = {}
  state.arrow_direction = entity.direction
  state.left_arrow = left
  state.right_arrow = right

  local function draw_arrow(dx, dy)
    local function line(x1, y1, x2, y2)
      state.arrows[#state.arrows + 1] = rendering.draw_line{
        color = {r = 0.2, g = 0.85, b = 1, a = 1},
        width = 3,
        from = {entity = entity, offset = {x1, y1}},
        to = {entity = entity, offset = {x2, y2}},
        surface = entity.surface,
        only_in_alt_mode = true
      }
    end
    line(dx * 0.43, dy * 0.43, dx * 0.85, dy * 0.85)
    line(dx * 0.85, dy * 0.85, dx * 0.64 - dy * 0.12, dy * 0.64 + dx * 0.12)
    line(dx * 0.85, dy * 0.85, dx * 0.64 + dy * 0.12, dy * 0.64 - dx * 0.12)
  end

  if left then draw_arrow(y, -x) end
  if right then draw_arrow(-y, x) end
end

local tread_directions = {
  [defines.direction.north] = "north",
  [defines.direction.east] = "east",
  [defines.direction.south] = "south",
  [defines.direction.west] = "west"
}

local function update_tread(state)
  local entity = state.entity
  local direction = entity.direction
  if state.tread and state.tread.valid then
    if state.tread_direction ~= direction then
      state.tread.animation = entity.name .. "-tread-" .. tread_directions[direction]
    end
  else
    state.tread = rendering.draw_animation{
      animation = entity.name .. "-tread-" .. tread_directions[direction],
      animation_speed = entity.prototype.belt_speed * 32,
      target = entity,
      surface = entity.surface,
      render_layer = "floor-mechanics"
    }
  end
  -- The item layer lies between the animated tread and the housing.
  if not state.housing or not state.housing.valid then
    state.housing = rendering.draw_sprite{
      sprite = "qol-logistics-belt-diverter-housing",
      target = entity,
      surface = entity.surface,
      render_layer = "lower-object"
    }
  end
  state.tread_direction = direction
end

local function round_robin(state, stack, x, y)
  local preferred = state.next_side or 1
  local sign = preferred == 1 and 1 or -1
  if divert(state.entity, stack, sign * y, -sign * x, 3 - preferred) then
    state.next_side = 3 - preferred
  else
    divert(state.entity, stack, -sign * y, sign * x, preferred)
  end
end

local function route(state)
  local entity = state.entity
  keep_input_direction(entity)
  local flow = directions[entity.direction]
  if not flow then return end
  local x, y = flow[1], flow[2]
  update_tread(state)
  local shared = state.round_robin and state.round_robin_item
  local left_filter = not state.round_robin and entity.get_filter(1)
  local right_filter = not state.round_robin and entity.get_filter(2)
  update_arrows(state, x, y, not not (shared or left_filter), not not (shared or right_filter))
  for lane = 1, 2 do
    local stack = front_stack(entity.get_transport_line(lane))
    if stack then
      if shared and stack.name == shared then
        round_robin(state, stack, x, y)
      elseif left_filter and stack.name == left_filter.name then
        divert(entity, stack, y, -x, 2)
      elseif right_filter and stack.name == right_filter.name then
        divert(entity, stack, -y, x, 1)
      else
        local ahead = belt_at(entity, x, y)
        if ahead and ahead.direction == entity.direction then
          local preferred = state.next_lane
          local other = 3 - preferred
          if transfer(stack, ahead.get_transport_line(preferred)) then
            state.next_lane = other
          elseif transfer(stack, ahead.get_transport_line(other)) then
            state.next_lane = preferred
          end
        end
      end
    end
  end
end

local function tick()
  for key, state in pairs(storage.belt_diverters or {}) do
    if state.entity.valid then
      route(state)
    else
      storage.belt_diverters[key] = nil
    end
  end
end

return {
  register = register,
  adopt = adopt,
  tick = tick,
  is_diverter = is_diverter,
  directions = directions
}
