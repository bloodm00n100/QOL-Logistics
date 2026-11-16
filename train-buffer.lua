local transfer_belts = require("train-belt-transfer")

local rail_offsets = {
  [defines.direction.north] = {x = 0, y = 2},
  [defines.direction.east] = {x = -2, y = 0},
  [defines.direction.south] = {x = 0, y = -2},
  [defines.direction.west] = {x = 2, y = 0}
}

local function find_wagon(platform)
  local offset = rail_offsets[platform.direction]
  local position = platform.position
  local x, y = position.x + offset.x, position.y + offset.y
  local along_x = offset.y ~= 0
  local dx, dy = along_x and 1.6 or 0.55, along_x and 0.55 or 1.6
  local best, best_distance
  for _, wagon in ipairs(platform.surface.find_entities_filtered{
    area = {{x - dx, y - dy}, {x + dx, y + dy}},
    type = "cargo-wagon",
    force = platform.force
  }) do
    local orientation = wagon.orientation % 0.5
    local aligned = math.abs(orientation - 0.25) < 0.01
    if not along_x then
      aligned = orientation < 0.01 or orientation > 0.49
    end
    local wx, wy = wagon.position.x - x, wagon.position.y - y
    local distance = wx * wx + wy * wy
    if aligned and wagon.speed == 0 and math.abs(wx) <= dx and math.abs(wy) <= dy
      and (not best_distance or distance < best_distance) then
      best, best_distance = wagon, distance
    end
  end
  return best
end

local function move_items(source, destination, count)
  if source.is_empty() or destination.is_full() then
    return
  end
  storage.train_transfer_buffer = storage.train_transfer_buffer or game.create_inventory(1)
  local copy = storage.train_transfer_buffer[1]
  for i = 1, #source do
    local stack = source[i]
    if stack.valid_for_read and copy.set_stack(stack) then
      copy.count = math.min(stack.count, count)
      local inserted = destination.insert(copy)
      copy.clear()
      if inserted > 0 then
        stack.count = stack.count - inserted
        count = count - inserted
        if count == 0 then
          return
        end
      end
    end
  end
end

return function(event)
  for registration, buffer in pairs(storage.train_buffers or {}) do
    local platform = buffer.entity
    local outlets = storage.train_loaders[registration]
    local outlet = outlets and outlets[1]
    if platform.valid and outlet and outlet.valid then
      local inventory = platform.get_inventory(defines.inventory.chest)
      local mode = outlet.loader_type
      transfer_belts(outlets, inventory, mode)
      if event.tick % 10 == registration % 10 or not buffer.checked then
        buffer.wagon = find_wagon(platform)
        buffer.checked = true
      end
      local wagon = buffer.wagon
      if wagon and wagon.valid and wagon.speed == 0 then
        local capacity = (buffer.fraction or 0) + outlet.prototype.belt_speed * 8 * #outlets
        local count = math.floor(capacity)
        buffer.fraction = capacity - count
        if count > 0 then
          local cargo = wagon.get_inventory(defines.inventory.cargo_wagon)
          if mode == "input" then
            move_items(inventory, cargo, count)
          else
            move_items(cargo, inventory, count)
          end
        end
      end
    end
  end
end
