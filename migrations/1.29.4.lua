for _, force in pairs(game.forces) do
  local recipe = force.recipes["qol-logistics-burner-generator"]
  if recipe then
    recipe.enabled = false
  end
end
