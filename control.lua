require("mod-gui")
local Event = require("__stdlib__/stdlib/event/event")
local Changes = require("__stdlib__/stdlib/event/changes")
local UPGui = require("upgrade-planner/gui")
local UPGuiEvent = require("upgrade-planner/gui-events")
local UPEntityUpgrade = require("upgrade-planner/entity-upgrade")

MAX_CONFIG_SIZE = 24
MAX_STORAGE_SIZE = 12
in_range_check_is_annoying = true

-----------------------------------------------
-- Initialization
-----------------------------------------------
Changes.register("mod_versions", "upgrade-planner/mod-upgrade")

function global_init()
  global.current_config = {}
  global["config-tmp"] = {}
  global.storage = {}
  global.storage_index = {}
end

function player_init(player_idx)
  global.current_config[player_idx] = global.current_config[player_idx] or {}
  global.storage_index[player_idx] = global.storage_index[player_idx] or 1
end

Event.register(
  Event.core_events.init,
  function()
    global_init()
    for player_idx, player in pairs(game.players) do
      UPGui.init(player)
      player_init(player_idx)
    end
  end
)

Event.register(
  Event.core_events.on_configuration_changed,
  function(event)
    if not event or not event.mod_changes then
      return
    end
    verify_all_configs()
  end
)

-- Verify if all items selected for upgrade still exists (e.g. modded items)
function verify_all_configs()
  local items = game.item_prototypes
  local verify_config = function(config)
    for k, entry in pairs(config) do
      local to = items[entry.to]
      local from = items[entry.from]
      local changed = false
      if not (to and from) then
        log("Deleted invalid config: " .. k .. serpent.line(entry))
        entry[k] = nil
        changed = true
      end
      return changed
    end
  end
  for name, config in pairs(global.current_config) do
    local changed = verify_config(config)
    if changed then
      UPGui.open_frame(game.players[name])
      UPGui.open_frame(game.players[name])
    end
  end
  for name, config in pairs(global["config-tmp"]) do
    verify_config(config)
  end
  for name, storage in pairs(global.storage) do
    for storage_name, config in pairs(storage) do
      verify_config(config)
    end
  end
end

Event.register(
  defines.events.on_player_joined_game,
  function(event)
    local player = game.players[event.player_index]
    UPGui.init(player)
    player_init(event.player_index)
  end
)

Event.register(
  defines.events.on_pre_player_removed,
  function(event)
    local player = game.players[event.player_index]
    global.current_config[event.player_index] = nil
    global.storage_index[player.index] = nil
  end
)

-----------------------------------------------
-- GUI events
-----------------------------------------------

UPGuiEvent.register()

-----------------------------------------------
-- Upgrade handling
-----------------------------------------------
Event.register(defines.events.on_player_selected_area, UPEntityUpgrade.upgrade_area_player)
Event.register(defines.events.on_player_alt_selected_area, UPEntityUpgrade.upgrade_area_bot)

-----------------------------------------------
-- Key bindings
-----------------------------------------------
Event.register(
  "upgrade-planner-hide",
  function(event)
    local player = game.players[event.player_index]
    local button_flow = mod_gui.get_button_flow(player)
    if button_flow["upgrade_planner_config_button"] then
      button_flow["upgrade_planner_config_button"].visible = not button_flow.upgrade_planner_config_button.visible
      return
    end
    local button =
      button_flow.add {
      type = "sprite-button",
      name = "upgrade_planner_config_button",
      style = mod_gui.button_style,
      sprite = "item/upgrade-builder",
      tooltip = {"upgrade-planner.button-tooltip"}
    }
    button.visible = true
  end
)

--- Clean up additional upgrade planner items
-- Whenever more than one Upgrade planner is in a player inventory, destroy it.
-- If a planner lands in the trash inventory, destroy it.
Event.register(
  {defines.events.on_player_trash_inventory_changed, defines.events.on_player_main_inventory_changed},
  function(event)
    local player = game.players[event.player_index]
    local is_trash = event.name == defines.events.on_player_trash_inventory_changed
    local inventory

    if is_trash then
      inventory = player.get_inventory(defines.inventory.character_trash)
    elseif is_trash == false then
      inventory = player.get_main_inventory()
    else
      return
    end

    if game.item_prototypes["upgrade-builder"] then
      if is_trash then
        local upgrade_builder = inventory.find_item_stack("upgrade-builder")
        if upgrade_builder then
          upgrade_builder.clear()
        end
      else
        local cnt = inventory.get_item_count("upgrade-builder")
        if cnt > 1 then
          inventory.remove {name = "upgrade-builder", count = cnt - 1}
        end
      end
    end
  end
)
