local upgrade_planner_gui = {}

upgrade_planner_gui.init = function(player)
  local flow = mod_gui.get_button_flow(player)
  if not flow.upgrade_planner_config_button then
    local button =
      flow.add {
      type = "sprite-button",
      name = "upgrade_planner_config_button",
      style = mod_gui.button_style,
      sprite = "item/upgrade-builder",
      tooltip = {"upgrade-planner.button-tooltip"}
    }
    button.visible = true
  end
end

local function find_gui_recursive(gui, name)
  for k, child in pairs(gui.children) do
    if child.name == name then
      return child
    end
    find_gui_recursive(child, name)
  end
end

upgrade_planner_gui.nuke_all_guis = function()
  for k, player in pairs(game.players) do
    for j, name in pairs({"upgrade-planner.storage-frame", "upgrade-planner-config-button"}) do
      local found = find_gui_recursive(player.gui, name)
      if found then
        found.destroy()
      end
    end
  end
end

local function open_frame(player)
  local flow = mod_gui.get_frame_flow(player)

  local frame = flow.upgrade_planner_config_frame

  if frame then
    frame.destroy()
    global["config-tmp"][player.name] = nil
    return
  end

  global.config[player.name] = global.config[player.name] or {}
  global["config-tmp"][player.name] = {}
  local i = 0
  for i = 1, MAX_CONFIG_SIZE do
    if i > #global.config[player.name] then
      global["config-tmp"][player.name][i] = {from = "", to = ""}
    else
      global["config-tmp"][player.name][i] = {
        from = global.config[player.name][i].from,
        to = global.config[player.name][i].to
      }
    end
  end

  -- Now we can build the GUI.
  frame =
    flow.add {
    type = "frame",
    caption = {"upgrade-planner.config-frame-title"},
    name = "upgrade_planner_config_frame",
    direction = "vertical"
  }
  if not global.storage_index then
    global.storage_index = {}
  end
  if not global.storage_index[player.name] then
    global.storage_index[player.name] = 1
  end
  local storage_flow = frame.add {type = "table", name = "upgrade_planner_storage_flow", column_count = 3}
  --storage_flow.style.horizontal_spacing = 2
  local drop_down = storage_flow.add {type = "drop-down", name = "upgrade_planner_drop_down"}
  --drop_down.style.minimal_height = 50
  drop_down.style.minimal_width = 164
  drop_down.style.maximal_width = 0
  if not global.storage then
    global.storage = {}
  end
  if not global.storage[player.name] then
    global.storage[player.name] = {}
  end
  for key, _ in pairs(global.storage[player.name]) do
    drop_down.add_item(key)
  end
  if not global.storage[player.name]["New storage"] then
    drop_down.add_item("New storage")
  end
  local items = drop_down.items
  local index = math.min(global.storage_index[player.name], #items)
  index = math.max(index, 1)
  drop_down.selected_index = index
  global.storage_index[player.name] = index
  local storage_to_restore = drop_down.get_item(drop_down.selected_index)
  local rename_button =
    storage_flow.add {
    type = "sprite-button",
    name = "upgrade_planner_storage_rename",
    sprite = "utility/rename_icon_normal",
    tooltip = {"upgrade-planner.rename-button-tooltip"}
  }
  rename_button.style = "slot_button"
  rename_button.style.maximal_width = 24
  rename_button.style.minimal_width = 24
  rename_button.style.maximal_height = 24
  rename_button.style.minimal_height = 24
  local remove_button =
    storage_flow.add {
    type = "sprite-button",
    name = "upgrade_planner_storage_delete",
    sprite = "utility/remove",
    tooltip = {"upgrade-planner.delete-storage-button-tooltip"}
  }
  remove_button.style = "red_slot_button"
  remove_button.style.maximal_width = 24
  remove_button.style.minimal_width = 24
  remove_button.style.maximal_height = 24
  remove_button.style.minimal_height = 24
  local rename_field =
    storage_flow.add {
    type = "textfield",
    name = "upgrade_planner_storage_rename_textfield",
    text = drop_down.get_item(drop_down.selected_index)
  }
  rename_field.visible = false
  local confirm_button =
    storage_flow.add {
    type = "sprite-button",
    name = "upgrade_planner_storage_confirm",
    sprite = "utility/confirm_slot",
    tooltip = {"upgrade-planner.confirm-storage-name"}
  }
  confirm_button.style = "green_slot_button"
  confirm_button.style.maximal_width = 24
  confirm_button.style.minimal_width = 24
  confirm_button.style.maximal_height = 24
  confirm_button.style.minimal_height = 24
  confirm_button.visible = false
  local cancel_button =
    storage_flow.add {
    type = "sprite-button",
    name = "upgrade_planner_storage_cancel",
    sprite = "utility/set_bar_slot",
    tooltip = {"upgrade-planner.cancel-storage-name"}
  }
  cancel_button.style = "red_slot_button"
  cancel_button.style.maximal_width = 24
  cancel_button.style.minimal_width = 24
  cancel_button.style.maximal_height = 24
  cancel_button.style.minimal_height = 24
  cancel_button.visible = false
  local ruleset_grid =
    frame.add {
    type = "table",
    column_count = (MAX_CONFIG_SIZE / 6 - MAX_CONFIG_SIZE % 6) * 3,
    name = "upgrade_planner_ruleset_grid",
    style = "slot_table"
  }

  for i = 1, MAX_CONFIG_SIZE / 6 do
    ruleset_grid.add {
      type = "label",
      caption = {"upgrade-planner.config-header-1"}
    }
    ruleset_grid.add {
      type = "label",
      caption = {"upgrade-planner.config-header-2"}
    }
    ruleset_grid.add {
      type = "label"
    }
  end

  local items = game.item_prototypes
  for i = 1, MAX_CONFIG_SIZE do
    local sprite = nil
    local tooltip = nil
    local from = get_config_item(player, i, "from")
    if from then
      --sprite = "item/"..get_config_item(player, i, "from")
      tooltip = items[from].localised_name
    end
    local elem =
      ruleset_grid.add {
      type = "choose-elem-button",
      name = "upgrade_planner_from_" .. i,
      style = "slot_button",
      --sprite = sprite,
      elem_type = "item",
      tooltip = tooltip
    }
    elem.elem_value = from
    local sprite = nil
    local tooltip = nil
    local to = get_config_item(player, i, "to")
    if to then
      --sprite = "item/"..get_config_item(player, i, "to")
      tooltip = items[to].localised_name
    end
    local elem =
      ruleset_grid.add {
      type = "choose-elem-button",
      name = "upgrade_planner_to_" .. i,
      --style = "slot_button",
      --sprite = sprite,
      elem_type = "item",
      tooltip = tooltip
    }
    elem.elem_value = to
    ruleset_grid.add {
      type = "label"
    }
  end

  local button_grid =
    frame.add {
    type = "table",
    column_count = 5
  }
  button_grid.add {
    type = "sprite-button",
    name = "upgrade_blueprint",
    sprite = "item/blueprint",
    tooltip = {"upgrade-planner.config-button-upgrade-blueprint"},
    style = mod_gui.button_style
  }
  button_grid.add {
    type = "sprite-button",
    name = "upgrade_planner_import_config",
    sprite = "utility/import_slot",
    tooltip = {"upgrade-planner.config-button-import-config"},
    style = mod_gui.button_style
  }
  button_grid.add {
    type = "sprite-button",
    name = "upgrade_planner_export_config",
    sprite = "utility/export_slot",
    tooltip = {"upgrade-planner.config-button-export-config"},
    style = mod_gui.button_style
  }
  button_grid.add {
    type = "sprite-button",
    name = "upgrade_planner_configure_plan",
    sprite = "item/upgrade-planner",
    tooltip = {"upgrade-planner.config-button-export-config"},
    style = mod_gui.button_style
  }
  button_grid.add {
    type = "button",
    caption = {"gui.close"},
    name = "upgrade_planner_frame_close",
    style = mod_gui.button_style
  }
  gui_restore(player, storage_to_restore)
end

upgrade_planner_gui.open_frame_event = function(event)
  local player = game.players[event.player_index]
  open_frame(player)
end

upgrade_planner_gui.open_frame = open_frame

function gui_close_frame(event)
  local player = game.players[event.player_index]
  local element = event.element
  while element.type ~= "frame" do
    element = element.parent
  end

  if element.name == "upgrade_planner_config_frame" then
    local ieframe = player.gui.left.mod_gui_frame_flow.upgrade_planner_export_frame
    if ieframe then
      ieframe.destroy()
    end
  else
    open_frame(player)
  end

  element.destroy()
end

upgrade_planner_gui.import_export_config = function(event, import)
  local player = game.players[event.player_index]
  local caption = {"upgrade-planner.export-config"}

  if import then
    caption = {"upgrade-planner.import-config"}
  end

  player.opened = nil
  local gui = player.gui.left.mod_gui_frame_flow
  local frame =
    gui.add {
    type = "frame",
    caption = caption,
    name = "upgrade_planner_export_frame",
    direction = "vertical"
  }
  local textfield = frame.add {type = "text-box"}
  textfield.word_wrap = true
  textfield.read_only = not import
  textfield.style.minimal_width = 500
  textfield.style.minimal_height = 200
  textfield.style.maximal_height = 500
  if not import then
    textfield.text = enc(serpent.dump(global.storage[player.name]))
  end
  local flow = frame.add {type = "flow"}
  if import then
    flow.add {
      type = "button",
      caption = {"upgrade-planner.import-button"},
      name = "upgrade_planner_import_config_button",
      style = mod_gui.button_style
    }
  end
  flow.add {
    type = "button",
    caption = {"gui.close"},
    name = "upgrade_planner_frame_close",
    style = mod_gui.button_style
  }
  frame.visible = true
  player.opened = frame
  open_frame(player)
end

return upgrade_planner_gui
