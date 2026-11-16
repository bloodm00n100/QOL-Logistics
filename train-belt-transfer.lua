local function load_buffer(line, inventory)
  local size = #line
  if size == 0 then
    return
  end
  local front = 1
  if line.get_item_position(front) > 0 then
    front = size
    if line.get_item_position(front) > 0 then
      return
    end
  end
  local stack = line[front]
  local inserted = inventory.insert(stack)
  if inserted > 0 then
    stack.count = stack.count - inserted
  end
end

local function unload_buffer(line, inventory)
  if not line.can_insert_at_back() then
    return
  end
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack.valid_for_read then
      storage.train_transfer_buffer = storage.train_transfer_buffer or game.create_inventory(1)
      local copy = storage.train_transfer_buffer[1]
      if copy.set_stack(stack) then
        copy.count = 1
        if line.insert_at_back(copy) then
          stack.count = stack.count - 1
        end
        copy.clear()
      end
      return
    end
  end
end

return function(outlets, inventory, mode)
  if mode == "output" and inventory.is_empty() then
    return
  end
  local transfer_lane = mode == "input" and load_buffer or unload_buffer
  for _, outlet in ipairs(outlets) do
    if outlet.valid then
      transfer_lane(outlet.get_transport_line(1), inventory)
      transfer_lane(outlet.get_transport_line(2), inventory)
    end
  end
end
