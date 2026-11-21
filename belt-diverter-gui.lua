local diverters = require("belt-diverter-control")
local frame_name = "qol-logistics-diverter-config"

local function show(player, entity)
  local old = player.gui.center[frame_name]
  if old then old.destroy() end

  local frame = player.gui.center.add{type = "frame", name = frame_name,
    caption = entity.localised_name, direction = "vertical"}
  local state = storage.belt_diverters[entity.unit_number]
  frame.add{type = "checkbox", caption = {"qol-logistics.diverter-round-robin"},
    state = state.round_robin == true, tags = {diverter_mode = entity.unit_number}}
  if state.round_robin then
    local row = frame.add{type = "flow", direction = "horizontal"}
    row.add{type = "label", caption = {"qol-logistics.diverter-round-robin-item"}}
    local selector = row.add{type = "choose-elem-button", elem_type = "item",
      tags = {diverter_shared = entity.unit_number}}
    selector.elem_value = state.round_robin_item
    frame.add{type = "label", caption = {"qol-logistics.diverter-round-robin-help"}}
    player.opened = frame
    return
  end
  frame.add{type = "label", caption = {"qol-logistics.diverter-help"}}
  local grid = frame.add{type = "table", column_count = 3}
  local direction = diverters.directions[entity.direction]
  local x, y = direction[1], direction[2]

  for row = -1, 1 do
    for column = -1, 1 do
      local slot
      if column == y and row == -x then slot = 1 end
      if column == -y and row == x then slot = 2 end
      if slot then
        local selector = grid.add{type = "choose-elem-button", elem_type = "item",
          tooltip = {"qol-logistics.diverter-side"},
          tags = {diverter_slot = slot, diverter_unit = entity.unit_number}}
        local filter = entity.get_filter(slot)
        if filter then selector.elem_value = filter.name end
      else
        local tile = grid.add{type = "sprite-button", enabled = false}
        if column == 0 and row == 0 then tile.sprite = "item/" .. entity.name end
        if column == x and row == y then
          tile.caption = ({["0,-1"] = "↑", ["1,0"] = "→", ["0,1"] = "↓", ["-1,0"] = "←"})[x .. "," .. y]
          tile.tooltip = {"qol-logistics.diverter-ahead"}
        end
      end
    end
  end
  player.opened = frame
end

script.on_event(defines.events.on_gui_opened, function(event)
  if not diverters.is_diverter(event.entity) then return end
  if not (storage.belt_diverters and storage.belt_diverters[event.entity.unit_number]) then
    diverters.register(event.entity)
  end
  show(game.get_player(event.player_index), event.entity)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.valid and event.element.name == frame_name then
    event.element.destroy()
  end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  local element = event.element
  local tags = element.tags
  if tags.diverter_shared then
    local state = storage.belt_diverters[tags.diverter_shared]
    if state and diverters.is_diverter(state.entity) then
      state.round_robin_item = element.elem_value
    end
    return
  end
  if not tags.diverter_slot then return end
  local state = storage.belt_diverters and storage.belt_diverters[tags.diverter_unit]
  if not state or not diverters.is_diverter(state.entity) then return end

  local entity = state.entity
  local slot = tags.diverter_slot
  local filter = element.elem_value
  if filter then
    local other = entity.get_filter(3 - slot)
    if other and other.name == filter then
      entity.set_filter(3 - slot, nil)
    end
  end
  entity.set_filter(slot, filter and {name = filter} or nil)
  show(game.get_player(event.player_index), entity)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local unit = event.element.tags.diverter_mode
  local state = unit and storage.belt_diverters[unit]
  if not state or not diverters.is_diverter(state.entity) then return end
  state.round_robin = event.element.state
  if state.round_robin and not state.round_robin_initialized then
    local filter = state.entity.get_filter(1) or state.entity.get_filter(2)
    state.round_robin_item = filter and filter.name
    state.round_robin_initialized = true
  end
  show(game.get_player(event.player_index), state.entity)
end)
