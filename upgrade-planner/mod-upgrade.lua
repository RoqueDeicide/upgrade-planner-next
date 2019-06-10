return {
  ["1.6.9"] = function()
    game.print("Upgrade to version 1.6.9 of Upgrade Planner")
    global.current_config = {}
    if global.config then
      for player_name, config in pairs(global.config) do
        global.current_config[game.players[player_name].index] = config
      end
      global.config = nil
    end
  end
}
