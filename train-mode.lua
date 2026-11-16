local opposite_direction = {
  [defines.direction.north] = defines.direction.south,
  [defines.direction.east] = defines.direction.west,
  [defines.direction.south] = defines.direction.north,
  [defines.direction.west] = defines.direction.east
}

return function(platform, outlets)
  local first = outlets[1]
  if not first or not first.valid then
    return
  end
  local mode = first.loader_type == "output" and "input" or "output"
  local direction = mode == "input" and opposite_direction[platform.direction] or platform.direction
  for _, outlet in ipairs(outlets) do
    if outlet.valid then
      outlet.loader_type = mode
      if outlet.direction ~= direction then
        outlet.direction = direction
      end
    end
  end
  return mode
end
