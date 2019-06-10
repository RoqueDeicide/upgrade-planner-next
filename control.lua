require("mod-gui")
local Event = require('__stdlib__/stdlib/event/event')
local Gui = require('__stdlib__/stdlib/event/gui')
local UPGui = require('upgrade-planner/gui')
local UPconvert = require('upgrade-planner/converter')
MAX_CONFIG_SIZE = 24
MAX_STORAGE_SIZE = 12
in_range_check_is_annoying = true

function global_init()
  global.config = {}
  global["config-tmp"] = {}
  global.storage = {}
  global.storage_index = {}
end

function get_type(entity)
  if game.item_prototypes[entity] then
    return game.item_prototypes[entity].type
  end
  return ""
end

function count_keys(hashmap)

  local result = 0

  for _, __ in pairs(hashmap) do
    result = result + 1
  end

  return result

end

function get_config_item(player, index, type)

  if not global["config-tmp"][player.name]
  or index > #global["config-tmp"][player.name]
  or global["config-tmp"][player.name][index][type] == "" then
    return nil
  end
  if not game.item_prototypes[global["config-tmp"][player.name][index][type]] then
    return nil
  end
  if not game.item_prototypes[global["config-tmp"][player.name][index][type]].valid then
    return nil
  end

  return game.item_prototypes[global["config-tmp"][player.name][index][type]].name

end


function gui_save_changes(player)

  -- Saving changes consists in:
  --   1. copying config-tmp to config
  --   2. removing config-tmp

  if global["config-tmp"][player.name] then
    local i = 0
    global.config[player.name] = {}
    for i = 1, #global["config-tmp"][player.name] do
      global.config[player.name][i] = {
        from = global["config-tmp"][player.name][i].from,
        to = global["config-tmp"][player.name][i].to
      }
    end
  end
  if not global.storage then
    global.storage = {}
  end
  if not global.storage[player.name] then
    global.storage[player.name] = {}
  end
  local gui = player.gui.left.mod_gui_frame_flow.upgrade_planner_config_frame
  if not gui then return end
  local drop_down = gui.upgrade_planner_storage_flow.children[1]
  local name = drop_down.get_item(global.storage_index[player.name])
  global.storage[player.name][name] = global.config[player.name]
end

function gui_set_rule(player, type, index, element)
  local items = game.item_prototypes
  local name = element.elem_value
  local frame = player.gui.left.mod_gui_frame_flow.upgrade_planner_config_frame
  local ruleset_grid = frame["upgrade_planner_ruleset_grid"]
  local storage_name = element.parent.parent.upgrade_planner_storage_flow.children[1].get_item(global.storage_index[player.name])
  local storage = global["config-tmp"][player.name]
  if not frame or not storage then return end
  if not name then
    ruleset_grid["upgrade_planner_" .. type .. "_" .. index].tooltip = ""
    storage[index][type] = ""
    gui_save_changes(player)
    return
  end
  local opposite = "from"
  local i = 0
  if type == "from" then
    opposite = "to"
    for i = 1, #storage do
      if index ~= i and storage[i].from == name then
        player.print({"upgrade-planner.item-already-set"})
        gui_restore(player, storage_name)
        return
      end
    end
  end
  local related = storage[index][opposite]
  if related ~= "" then
    if related == name then
      player.print({"upgrade-planner.item-is-same"})
      gui_restore(player, storage_name)
      return
    end
    if get_type(name) ~= get_type(related) and (not is_exception(get_type(name), get_type(related))) then
      player.print({"upgrade-planner.item-not-same-type"})
      if storage[index][type] == "" then
        element.elem_value = nil
      elseif items[storage[index][type]] then
        element.elem_value = storage[index][type]
      else
        element.elem_value = nil
      end
      return
    end
  end
  storage[index][type] = name
  ruleset_grid["upgrade_planner_" .. type .. "_" .. index].tooltip = items[name].localised_name
  gui_save_changes(player)
end

function gui_clear_rule(player, index)
  local frame = player.gui.left.mod_gui_frame_flow.upgrade_planner_config_frame
  if not frame or not global["config-tmp"][player.name] then return end
  local ruleset_grid = frame["upgrade_planner_ruleset_grid"]
  global["config-tmp"][player.name][index] = { from = "", to = "" }
  ruleset_grid["upgrade_planner_from_" .. index].elem_value = nil
  ruleset_grid["upgrade_planner_from_" .. index].tooltip = ""
  ruleset_grid["upgrade_planner_to_" .. index].elem_value = nil
  ruleset_grid["upgrade_planner_to_" .. index].tooltip = ""
  gui_save_changes(player)
end

function gui_restore(player, name)

  local frame = player.gui.left.mod_gui_frame_flow.upgrade_planner_config_frame
  if not frame then return end
  if not global.storage[player.name] then return end
  local storage = global.storage[player.name][name]
  if not storage and name == "New storage" then
    storage = {}
  end
  if not storage then return end

  global["config-tmp"][player.name] = {}
  local items = game.item_prototypes
  local i = 0
  local ruleset_grid = frame["upgrade_planner_ruleset_grid"]
  local items = game.item_prototypes
  for i = 1, MAX_CONFIG_SIZE do
    if i > #storage then
      global["config-tmp"][player.name][i] = { from = "", to = "" }
    else
      global["config-tmp"][player.name][i] = {
        from = storage[i].from,
        to = storage[i].to
      }
    end
    local name = get_config_item(player, i, "from")
    ruleset_grid["upgrade_planner_from_" .. i].elem_value = name
    if name and name ~= "" then
      ruleset_grid["upgrade_planner_from_" .. i].tooltip = items[name].localised_name
    else
      ruleset_grid["upgrade_planner_from_" .. i].tooltip = ""
    end
    local name = get_config_item(player, i, "to")
    ruleset_grid["upgrade_planner_to_" .. i].elem_value = name
    if name and name ~= "" then
      ruleset_grid["upgrade_planner_to_" .. i].tooltip = items[name].localised_name
    else
      ruleset_grid["upgrade_planner_to_" .. i].tooltip = ""
    end
  end
  global.config[player.name] = global["config-tmp"][player.name]

end

Gui.on_click(
  "upgrade_planner_storage_rename",
  function(event)
    local children = event.element.parent.children
    for k, child in pairs(children) do
      child.visible = true
    end
    children[4].text = children[1].get_item(children[1].selected_index)
    if children[4].text == "New storage" then
      children[4].text = ""
    end
  end
)

Gui.on_click(
  "upgrade_planner_storage_cancel",
  function(event)
    local children = event.element.parent.children
    for k = 4, 6 do
      children[k].visible = false
    end
    children[4].text = children[1].get_item(children[1].selected_index)
  end
)

Gui.on_click(
  "upgrade_planner_storage_confirm",
  function(event)
    local player = game.players[event.player_index]
    local index = global.storage_index[player.name]
    local children = event.element.parent.children
    local new_name = children[4].text
    local length = string.len(new_name)
    if length < 1 then
      player.print({"upgrade-planner.storage-name-too-short"})
      return
    end
    for k = 4, 6 do
      children[k].visible = false
    end
    local items = children[1].items
    if index > #items then
      index = #items
    end
    local old_name = items[index]
    if old_name == "New storage" then
      children[1].add_item("New storage")
    end
    if not global.storage then
      global.storage = {}
    end
    if not global.storage[player.name] then
      global.storage[player.name] = {}
    end
    if global.storage[player.name][old_name] then
      global.storage[player.name][new_name] = global.storage[player.name][old_name]
    else
      global.storage[player.name][new_name] = {}
    end
    global.storage[player.name][old_name] = nil
    --game.print(serpent.block(global.storage[player.name][new_name]))
    children[1].set_item(index, new_name)
    children[1].selected_index = 0
    children[1].selected_index = index
    global.storage_index[player.name] = index
    return
  end
)

Gui.on_click(
  "upgrade_planner_storage_delete",
  function(event)
    local player = game.players[event.player_index]
    local element = event.element
    local children = element.parent.children
    local dropdown = children[1]
    local index = dropdown.selected_index
    local name = dropdown.get_item(index)
    global.storage[player.name][name] = nil
    if name ~= "New storage" then
      dropdown.remove_item(index)
    end
    if index > 1 then
      index = index - 1
    end
    dropdown.selected_index = 0
    dropdown.selected_index = index
    gui_restore(player, dropdown.get_item(index))
    global.storage_index[player.name] = index
    return
  end
)

Gui.on_click("upgrade_planner_config_button", UPGui.open_frame_event)

Gui.on_click("upgrade_planner_frame_close", UPGui.close_frame)

Event.register(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element
  local player = game.players[event.player_index]
  if not string.find(element.name, "upgrade_planner_") then return end
  if element.selected_index > 0 then
    global.storage_index[player.name] = element.selected_index
    local name = element.get_item(element.selected_index)
    gui_restore(player, name)
    global.config[player.name] = global.storage[player.name][name]
  end
end)

Event.register(defines.events.on_gui_elem_changed, function(event)

  local element = event.element
  local player = game.players[event.player_index]
  if not string.find(element.name, "upgrade_planner_") then return end
  local type, index = string.match(element.name, "upgrade_planner_(%a+)_(%d+)")
  if type and index then
    if type == "from" or type == "to" then
      gui_set_rule(player, type, tonumber(index), element)
    end
  end
end)

Event.register(Event.core_events.init, function()
  global_init()
  for k, player in pairs (game.players) do
    UPGui.init(player)
  end
end)

Event.register(defines.events.on_player_selected_area, function(event)
  on_selected_area(event)
end)

Event.register(defines.events.on_player_alt_selected_area, function(event)
  on_alt_selected_area(event)
end)

function on_selected_area(event)
  if event.item ~= "upgrade-builder" then return end--If its a upgrade builder

  local player = game.players[event.player_index]
  local config = global.config[player.name]
  if config == nil then return end
  local hashmap = get_hashmap(config)
  local surface = player.surface
  global.temporary_ignore = {}
  for k, belt in pairs (event.entities) do --Get the items that are set to be upgraded
    if belt.valid then
      local upgrade = hashmap[belt.name]
      if belt.get_module_inventory() then
        player_upgrade_modules(player, belt.get_module_inventory(), hashmap, belt)
      end
      if upgrade ~= nil and upgrade ~= "" then
        player_upgrade(player,belt,upgrade,true)
      end
    end
  end
  global.temporary_ignore = nil
end

function get_hashmap(config)
  local items = game.item_prototypes
  local hashmap = {}
  for k, entry in pairs (config) do
    local item_from = items[entry.from]
    local item_to = items[entry.to]
    if item_to and item_from then
      hashmap[entry.from] = {item_to = entry.to}
      local entity_from = item_from.place_result
      local entity_to = item_to.place_result
      if entity_from and entity_to then
        hashmap[entity_from.name] = {entity_to = entity_to.name, item_to = entry.to, item_from = entry.from}
      end
      if item_from.type == "rail-planner" and item_to.type == "rail-planner" then
        hashmap[item_from.straight_rail.name] = {entity_to = item_to.straight_rail.name, item_to = entry.to, item_from = entry.from}
        hashmap[item_from.curved_rail.name] = {entity_to = item_to.curved_rail.name, item_to = entry.to, item_from = entry.from, item_amount = 4}
      end
    end
  end
  return hashmap
end

function player_upgrade_modules(player, inventory, map, owner)
  for k = 1, #inventory do
    local slot = inventory[k]
    if slot.valid and slot.valid_for_read then
      if not global.temporary_ignore[slot.name] then
        local upgrade = map[slot.name]
        local recipe = get_recipe(owner)
        if upgrade and upgrade.item_to and recipe and check_module_eligibility(upgrade.item_to, recipe) then
          if player.get_item_count(upgrade.item_to) >= slot.count or player.cheat_mode then
            player.remove_item{name = upgrade.item_to, count = slot.count}
            player.insert{name = slot.name, count = slot.count}
            slot.set_stack{name = upgrade.item_to, count = slot.count}
          else
            global.temporary_ignore[slot.name] = true
            owner.surface.create_entity{name = "flying-text", position = {owner.position.x-1.3,owner.position.y-0.5}, text = "Insufficient items", color = {r=1,g=0.6,b=0.6}}
          end
        end
      end
    end
  end
end

function check_module_eligibility(name, recipe)
  if not recipe then return true end
  local item = game.item_prototypes[name]
  if not item then return false end
  local effects = item.module_effects
  if not effects then return true end
  if not effects.productivity then return true end
  if not item.limitations then return true end
  if item.limitations[recipe.name] then return true end
  return false
end

function player_upgrade(player,belt,upgrade, bool)
  if not belt then return end
  if not upgrade.entity_to then
    log("Tried to upgrade when entry had no entity: "..serpent.line(upgrade))
    return
  end
  if global.temporary_ignore[belt.name] then return end
  local surface = player.surface
  local amount = upgrade.item_amount or 1
  if player.get_item_count(upgrade.item_to) >= amount or player.cheat_mode then
    local d = belt.direction
    local f = belt.force
    local p = belt.position
    local n = belt.name
    local new_item
    script.raise_event(defines.events.on_pre_player_mined_item,{player_index = player.index, entity = belt})
    if belt.type == "underground-belt" then
      if belt.neighbours and bool then
        player_upgrade(player,belt.neighbours,upgrade,false)
      end
      new_item = surface.create_entity
      {
        name = upgrade.entity_to,
        position = belt.position,
        force = belt.force,
        fast_replace = true,
        direction = belt.direction,
        type = belt.belt_to_ground_type,
        player = player,
        spill=false
      }
    elseif belt.type == "loader" then
      new_item = surface.create_entity
      {
        name = upgrade.entity_to,
        position = belt.position,
        force = belt.force,
        fast_replace = true,
        direction = belt.direction,
        type = belt.loader_type,
        player = player,
        spill=false
      }
    elseif belt.type == "inserter" then
      local drop = {x = belt.drop_position.x, y = belt.drop_position.y}
      local pickup = {x = belt.pickup_position.x, y = belt.pickup_position.y}
      new_item = surface.create_entity
      {
        name = upgrade.entity_to,
        position = belt.position,
        force = belt.force,
        fast_replace = true,
        direction = belt.direction,
        player = player,
        spill=false
      }
      if new_item.valid then
        new_item.pickup_position = pickup
        new_item.drop_position = drop
      end
    elseif belt.type == "straight-rail" or belt.type == "curved-rail" then
      belt.destroy()
      new_item = surface.create_entity
      {
        name = upgrade.entity_to,
        position = p,
        force = f,
        direction = d,
      }
    else
      new_item = surface.create_entity
      {
        name = upgrade.entity_to,
        position = belt.position,
        force = belt.force,
        fast_replace = true,
        direction = belt.direction,
        player = player,
        spill=false
      }
    end
    if belt.valid then
      --If the create entity fast replace didn't work, we use this blueprint technique
      if new_item and new_item.valid then new_item.destroy() end
      local a = belt.bounding_box
      player.cursor_stack.set_stack{name = "blueprint", count = 1}
      player.cursor_stack.create_blueprint{surface = surface, force = belt.force, area = a}
      local old_blueprint = player.cursor_stack.get_blueprint_entities()
      local record_index = nil
      for index, entity in pairs (old_blueprint) do
        if (entity.name == belt.name) then
          record_index = index
        else
          old_blueprint[index] = nil
        end
      end
      if record_index == nil then player.print("Blueprint index error line "..debug.getinfo(1).currentline) return end
      old_blueprint[record_index].name = upgrade.entity_to
      old_blueprint[record_index].position = p
      player.cursor_stack.set_stack{name = "blueprint", count = 1}
      player.cursor_stack.set_blueprint_entities({old_blueprint[record_index]})
      if not player.cheat_mode then
        player.insert{name = upgrade.item_from, count = amount}
      end
      script.raise_event(defines.events.on_player_mined_item,
      {
        player_index = player.index,
        item_stack =
        {
          name = upgrade.item_from,
          count = amount
        }
      })
      --And then copy the inventory to some table
      local inventories = {}
      for index = 1, 10 do
        if belt.get_inventory(index) ~= nil then
          inventories[index] = {}
          inventories[index].name = index
          inventories[index].contents = belt.get_inventory(index).get_contents()
        end
      end
      belt.destroy()
      player.cursor_stack.build_blueprint{surface = surface, force = f, position = {0,0}}
      local ghost = surface.find_entities_filtered{area = a, name = "entity-ghost"}
      player.remove_item{name = upgrade.item_from, count = count}
      local p_x = player.position.x
      local p_y = player.position.y
      while ghost[1] ~= nil do
        ghost[1].revive()
        player.teleport({math.random(p_x -5, p_x +5), math.random(p_y -5, p_y +5)})
        ghost = surface.find_entities_filtered{area = a, name = "entity-ghost"}
      end
      player.teleport({p_x,p_y})
      local assembling = surface.find_entities_filtered{area = a, name = upgrade.entity_to}[1]
      if not assembling then
        player.print("Upgrade planner error - Entity to raise was not found")
        player.cursor_stack.set_stack{name = "upgrade-builder", count = 1}
        player.insert{name = upgrade.item_from, count = amount}
        return
      end
      script.raise_event(defines.events.on_built_entity,{player_index = player.index, created_entity = assembling})
      --Give back the inventory to the new entity
      for j, items in pairs (inventories) do
        for l, contents in pairs (items.contents) do
          if assembling ~= nil then
            local inv = assembling.get_inventory(items.name)
            if inv then inv.insert{name = l, count = contents} end
          end
        end
      end
      inventories = nil
      local proxy = surface.find_entities_filtered{area = a, name = "item-request-proxy"}
      if proxy[1] ~= nil then
        proxy[1].destroy()
      end
      player.cursor_stack.set_stack{name = "upgrade-builder", count = 1}
    else
      player.remove_item{name = upgrade.item_to, count = amount}
      --player.insert{name = upgrade.item_from, count = amount}
      script.raise_event(defines.events.on_player_mined_item,{player_index = player.index, item_stack = {name = upgrade.item_from, count = 1}})
      script.raise_event(defines.events.on_built_entity,{player_index = player.index, created_entity = new_item, stack = player.cursor_stack})
    end
  else
    global.temporary_ignore[belt.name] = true
    surface.create_entity{name = "flying-text", position = {belt.position.x-1.3,belt.position.y-0.5}, text = "Insufficient items", color = {r=1,g=0.6,b=0.6}}
  end
end

function on_alt_selected_area(event)
  --this is a lot simpler... but less cool
  if event.item ~= "upgrade-builder" then return end
  local player = game.players[event.player_index]
  local config = global.config[player.name]
  if not config then return end
  local hashmap = get_hashmap(config)
  local surface = player.surface
  for k, entity in pairs (event.entities) do
    if entity.valid then
      local upgrade = hashmap[entity.name]
      if upgrade and upgrade ~= "" then
        entity.order_upgrade({force=entity.force,target=upgrade['entity_to']})
      end
      if entity.valid and entity.get_module_inventory() then
        robot_upgrade_modules(entity.get_module_inventory(), hashmap, entity)
      end
    end
  end
end

function robot_upgrade_modules(inventory, map, owner)
  if not owner then return end
  if not owner.valid then return end
  local surface = owner.surface
  local modules = {}
  local proxy = false
  for k = 1, #inventory do
    local slot = inventory[k]
    if slot.valid and slot.valid_for_read then
      local upgrade = map[slot.name]
      local recipe = get_recipe(owner)
      if upgrade and upgrade.item_to and recipe and check_module_eligibility(upgrade.item_to, recipe) then
        local entity = surface.create_entity{name = "item-on-ground", stack = {name = slot.name, count = slot.count}, position = owner.position, force = owner.force}
        entity.order_deconstruction(owner.force)
        if modules[upgrade.item_to] then
          modules[upgrade.item_to] = modules[upgrade.item_to] + slot.count
        else
          modules[upgrade.item_to] = slot.count
        end
        proxy = true
        slot.clear()
      end
    end
  end
  if proxy then
    surface.create_entity{name = "item-request-proxy", force = owner.force, position = owner.position, modules = modules, target = owner}
  end
end

function get_recipe(owner)
  local recipe
  if not owner.valid then return end
  if owner.type == "beacon" then
    recipe = game.recipe_prototypes["stone-furnace"] --Some dummy recipe to get correct limitation
  elseif owner.type == "assembling-machine" or owner.type == "furnace" then
    recipe = owner.get_recipe() or "iron-gear-wheel"
  end
  return recipe
end

function handle_upgrade_planner (event)
  local player = game.players[event.player_index]
  local stack = player.cursor_stack
  if (stack and stack.valid and stack.valid_for_read and stack.is_upgrade_item) then
    config = UPconvert.from_upgrade_planner(stack)
    global.storage[player.name]["Imported storage"] = config
    player.print({"upgrade-planner.import-sucessful"})
    local count = 0
    for k, storage in pairs (global.storage[player.name]) do
      count = count + 1
    end
    global.storage_index[player.name] = count
    UPGui.open_frame(player)
    UPGui.open_frame(player)
  else
    local config = global.config[player.name]
    if not config then return end

    if player.clean_cursor() then
      stack = player.cursor_stack
      UPconvert.to_upgrade_planner(stack, config, player)
    end
  end
end

Gui.on_click("upgrade_planner_configure_plan", handle_upgrade_planner)

Event.register(Event.core_events.configuration_changed, function(event)
  if not event or not event.mod_changes then
    return
  end
  verify_all_configs()
end)

-- Verify if all items selected for upgrade still exists (e.g. modded items)
function verify_all_configs()
  local items = game.item_prototypes
  local verify_config = function (config)
    for k, entry in pairs (config) do
      local to = items[entry.to]
      local from = items[entry.from]
      local changed = false
      if not (to and from) then
        log("Deleted invalid config: "..k..serpent.line(entry))
        entry[k] = nil
        changed = true
      end
      return changed
    end
  end
  for name, config in pairs (global.config) do
    local changed = verify_config(config)
    if changed then
      UPGui.open_frame(game.players[name])
      UPGui.open_frame(game.players[name])
    end
  end
  for name, config in pairs (global["config-tmp"]) do
    verify_config(config)
  end
  for name, storage in pairs (global.storage) do
    for storage_name, config in pairs (storage) do
      verify_config(config)
    end
  end
end

Event.register(defines.events.on_player_joined_game, function(event)
  local player = game.players[event.player_index]
  UPGui.init(player)
end)


function update_blueprint_entities(stack, hashmap)
  if not (stack and stack.valid and stack.valid_for_read and stack.is_blueprint_setup()) then return end
  local entities = stack.get_blueprint_entities()
  if entities then
    for k, entity in pairs (entities) do
      local new = hashmap[entity.name]
      if new and new.entity_to then
        entities[k].name = new.entity_to
      end
      if entity.items then
        local new_items = {}
        for item, count in pairs (entity.items) do
          new_items[item] = count
        end
        for item, count in pairs (entity.items) do
          local new = hashmap[item]
          if new and new.item_to then
            if new_items[new.item_to] then
              new_items[new.item_to] = new_items[new.item_to] + count
            else
              new_items[new.item_to] = count
            end
            new_items[item] = new_items[item] - count
          end
        end
        for item, count in pairs (new_items) do
          if count == 0 then
            new_items[item] = nil
          end
        end
        entities[k].items = new_items
      end
    end
    stack.set_blueprint_entities(entities)
  end
  local tiles = stack.get_blueprint_tiles()
  if tiles then
    local tile_prototypes = game.tile_prototypes
    local items = game.item_prototypes
    for k, tile in pairs (tiles) do
      local prototype = tile_prototypes[tile.name]
      local items_to_place = prototype.items_to_place_this
      local item = nil
      if items_to_place then
        for name, to_place in pairs (items_to_place) do
          item = hashmap[name]
          if item and item.item_to then
            break
          end
        end
      end
      if item then
        local tile_item = items[item.item_to]
        if tile_item then
          local result = tile_item.place_as_tile_result
          if result then
            new_tile = tile_prototypes[result.result.name]
            if new_tile and new_tile.can_be_part_of_blueprint then
              tiles[k].name = result.result.name
            end
          end
        end
      end
    end
    stack.set_blueprint_tiles(tiles)
  end
  local icons = stack.blueprint_icons
  for k, icon in pairs (icons) do
    local new = hashmap[icon.signal.name]
    if new and new.item_to then icons[k].signal.name = new.item_to end
  end
  stack.blueprint_icons = icons
  return true
end

function upgrade_blueprint(event)
  local player = game.players[event.player_index]
  local stack = player.cursor_stack
  if not (stack.valid and stack.valid_for_read) then
    return
  end

  local config = global.config[player.name]
  if not config then
    return
  end
  local hashmap = get_hashmap(config)

  if stack.is_blueprint then
    if update_blueprint_entities(stack, hashmap) then
      player.print({"upgrade-planner.blueprint-upgrade-successful"})
    end
    return
  end

  if stack.is_blueprint_book then
    local inventory = stack.get_inventory(defines.inventory.item_main)
    local success = 0
    for k = 1, #inventory do
      if update_blueprint_entities(inventory[k], hashmap) then
        success = success + 1
      end
    end
    player.print({"upgrade-planner.blueprint-book-upgrade-successful", success})
    return
  end
end

function is_exception(from, to)
  local exceptions =
  {
    {from = "container", to = "logistic-container"},
    {from = "logistic-container", to = "container"}
  }
  for k, exception in pairs (exceptions) do
    if from == exception.from and to == exception.to then
      return true
    end
  end
  return false
end

Event.register("upgrade-planner-hide", function(event)
  local player = game.players[event.player_index]
  local button_flow = mod_gui.get_button_flow(player)
  if button_flow["upgrade_planner_config_button"] then
    button_flow["upgrade_planner_config_button"].visible = not button_flow.upgrade_planner_config_button.visible
    return
  end
  local button = button_flow.add
  {
    type = "sprite-button",
    name = "upgrade_planner_config_button",
    style = mod_gui.button_style,
    sprite = "item/upgrade-builder",
    tooltip = {"upgrade-planner.button-tooltip"}
  }
  button.visible = true
end)

Event.register(defines.events.on_gui_closed, function(event)
  local player = game.players[event.player_index]
  local element = event.element
  if not element then return end
  if element.name == "upgrade_planner_config_frame" then
    UPGui.open_frame(player)
    return
  end
  if element.name == "upgrade_planner_export_frame" then
    element.destroy()
    UPGui.open_frame(player)
    return
  end
end)

Event.register(defines.events.on_mod_item_opened, function(event)
  if event.item.name == "upgrade-builder" then
    UPGui.open_frame_event(event)
  end
end)

function cleanup_upgrade_planner(event)
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
      if upgrade_builder then upgrade_builder.clear() end
    else
      local cnt = inventory.get_item_count("upgrade-builder")
      if cnt > 1 then
        inventory.remove {name = "upgrade-builder", count = cnt-1}
      end
    end
  end
end

function print_full_gui_name(gui)
  local string = gui.name or "No_name"
  while gui.parent do
    local name = gui.parent.name or "No_name"
    string = name.."."..string
    gui = gui.parent
  end
  game.print(string)
end

Gui.on_click("upgrade_planner_import_config_open", function (event)
  UPGui.import_export_config(event,true)
end)

Gui.on_click("upgrade_planner_export_config_open", function (event)
  UPGui.import_export_config(event,false)
end)

function import_config_action(event)
  local player = game.players[event.player_index]

  if not player.opened then return end
  local frame = player.opened
  if not (frame.name and frame.name == "upgrade_planner_export_frame") then return end
  local textbox = frame.children[1]
  if not textbox.type == "text-box" then return end
  local text = textbox.text
  local result = loadstring(UPconvert.dec(text))
  if result then
    new_config = result()
  else
    player.print({"upgrade-planner.import-failed"})
    return
  end
  if new_config then
    for name, config in pairs (new_config) do
      if name == "New storage" then
        global.storage[player.name]["Imported storage"] = config
      else
        global.storage[player.name][name] = config
      end
    end
    player.print({"upgrade-planner.import-sucessful"})
    player.opened.destroy()
    local count = 0
    for k, storage in pairs (global.storage[player.name]) do
      count = count + 1
    end
    global.storage_index[player.name] = count
    UPGui.open_frame(player)
  else
    player.print({"upgrade-planner.import-failed"})
  end
end

Gui.on_click("upgrade_planner_import_config_button", import_config_action)

Event.register("upgrade-planner", UPGui.open_frame_event)
Event.register(
  {defines.events.on_player_trash_inventory_changed, defines.events.on_player_main_inventory_changed},
  cleanup_upgrade_planner
)

Gui.on_click("upgrade_blueprint", upgrade_blueprint)
