return {
  ["1.6.9"] = function()
    game.print("doing an Upgrade")
    if global.config then
      global.current_config = global.config
      global.config = nil
    end
  end
}
