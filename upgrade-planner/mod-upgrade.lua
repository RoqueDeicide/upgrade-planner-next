return {
  ["1.6.9"] = function()
    game.print("Upgrade to version 1.6.9 of Upgrade Planner")
    global.current_config = {}
    for player_name, config in pairs(global.config) do
      global.current_config[game.players[player_name].index] = config
    end
    global.config = nil

    local temp_storage_index = global.storage_index
    global.storage_index = {}

    for player_name, index in pairs(temp_storage_index) do
      global.storage_index[game.players[player_name].index] = index
    end
  end
}
