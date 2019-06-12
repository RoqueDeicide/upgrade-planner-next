local upgrade_planner_entity_upgrade = {}

local function get_hashmap(config)
  local items = game.item_prototypes
  local hashmap = {}
  for k, entry in pairs(config) do
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
        hashmap[item_from.straight_rail.name] = {
          entity_to = item_to.straight_rail.name,
          item_to = entry.to,
          item_from = entry.from
        }
        hashmap[item_from.curved_rail.name] = {
          entity_to = item_to.curved_rail.name,
          item_to = entry.to,
          item_from = entry.from,
          item_amount = 4
        }
      end
    end
  end
  return hashmap
end
upgrade_planner_entity_upgrade.get_hashmap = get_hashmap

local function get_recipe(owner)
  local recipe
  if not owner.valid then
    return
  end
  if owner.type == "beacon" then
    recipe = game.recipe_prototypes["stone-furnace"] --Some dummy recipe to get correct limitation
  elseif owner.type == "assembling-machine" or owner.type == "furnace" then
    recipe = owner.get_recipe() or "iron-gear-wheel"
  end
  return recipe
end

local function check_module_eligibility(name, recipe)
  if not recipe then
    return true
  end
  local item = game.item_prototypes[name]
  if not item then
    return false
  end
  local effects = item.module_effects
  if not effects then
    return true
  end
  if not effects.productivity then
    return true
  end
  if not item.limitations then
    return true
  end
  if item.limitations[recipe.name] then
    return true
  end
  return false
end

local function player_upgrade_modules(player, inventory, map, owner)
  for k = 1, #inventory do
    local slot = inventory[k]
    if slot.valid and slot.valid_for_read then
      if not global.temporary_ignore[slot.name] then
        local upgrade = map[slot.name]
        local recipe = get_recipe(owner)
        if upgrade and upgrade.item_to and recipe and check_module_eligibility(upgrade.item_to, recipe) then
          if player.get_item_count(upgrade.item_to) >= slot.count or player.cheat_mode then
            player.remove_item {name = upgrade.item_to, count = slot.count}
            player.insert {name = slot.name, count = slot.count}
            slot.set_stack {name = upgrade.item_to, count = slot.count}
          else
            global.temporary_ignore[slot.name] = true
            owner.surface.create_entity {
              name = "flying-text",
              position = {owner.position.x - 1.3, owner.position.y - 0.5},
              text = "Insufficient items",
              color = {r = 1, g = 0.6, b = 0.6}
            }
          end
        end
      end
    end
  end
end

local function player_upgrade(player, belt, upgrade, bool)
  if not belt then
    return
  end
  if not upgrade.entity_to then
    log("Tried to upgrade when entry had no entity: " .. serpent.line(upgrade))
    return
  end
  if global.temporary_ignore[belt.name] then
    return
  end
  local surface = player.surface
  local amount = upgrade.item_amount or 1
  if player.get_item_count(upgrade.item_to) >= amount or player.cheat_mode then
    local d = belt.direction
    local f = belt.force
    local p = belt.position
    local new_item
    script.raise_event(defines.events.on_pre_player_mined_item, {player_index = player.index, entity = belt})
    if belt.type == "underground-belt" then
      if belt.neighbours and bool then
        player_upgrade(player, belt.neighbours, upgrade, false)
      end
      new_item =
        surface.create_entity {
        name = upgrade.entity_to,
        position = belt.position,
        force = belt.force,
        fast_replace = true,
        direction = belt.direction,
        type = belt.belt_to_ground_type,
        player = player,
        spill = false
      }
    elseif belt.type == "loader" then
      new_item =
        surface.create_entity {
        name = upgrade.entity_to,
        position = belt.position,
        force = belt.force,
        fast_replace = true,
        direction = belt.direction,
        type = belt.loader_type,
        player = player,
        spill = false
      }
    elseif belt.type == "inserter" then
      local drop = {x = belt.drop_position.x, y = belt.drop_position.y}
      local pickup = {x = belt.pickup_position.x, y = belt.pickup_position.y}
      new_item =
        surface.create_entity {
        name = upgrade.entity_to,
        position = belt.position,
        force = belt.force,
        fast_replace = true,
        direction = belt.direction,
        player = player,
        spill = false
      }
      if new_item.valid then
        new_item.pickup_position = pickup
        new_item.drop_position = drop
      end
    elseif belt.type == "straight-rail" or belt.type == "curved-rail" then
      belt.destroy()
      new_item =
        surface.create_entity {
        name = upgrade.entity_to,
        position = p,
        force = f,
        direction = d
      }
    else
      new_item =
        surface.create_entity {
        name = upgrade.entity_to,
        position = belt.position,
        force = belt.force,
        fast_replace = true,
        direction = belt.direction,
        player = player,
        spill = false
      }
    end
    if belt.valid then
      --If the create entity fast replace didn't work, we use this blueprint technique
      if new_item and new_item.valid then
        new_item.destroy()
      end
      local a = belt.bounding_box
      player.cursor_stack.set_stack {name = "blueprint", count = 1}
      player.cursor_stack.create_blueprint {surface = surface, force = belt.force, area = a}
      local old_blueprint = player.cursor_stack.get_blueprint_entities()
      local record_index = nil
      for index, entity in pairs(old_blueprint) do
        if (entity.name == belt.name) then
          record_index = index
        else
          old_blueprint[index] = nil
        end
      end
      if record_index == nil then
        player.print("Blueprint index error line " .. debug.getinfo(1).currentline)
        return
      end
      old_blueprint[record_index].name = upgrade.entity_to
      old_blueprint[record_index].position = p
      player.cursor_stack.set_stack {name = "blueprint", count = 1}
      player.cursor_stack.set_blueprint_entities({old_blueprint[record_index]})
      if not player.cheat_mode then
        player.insert {name = upgrade.item_from, count = amount}
      end
      script.raise_event(
        defines.events.on_player_mined_item,
        {
          player_index = player.index,
          item_stack = {
            name = upgrade.item_from,
            count = amount
          }
        }
      )
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
      player.cursor_stack.build_blueprint {surface = surface, force = f, position = {0, 0}}
      local ghost = surface.find_entities_filtered {area = a, name = "entity-ghost"}
      local p_x = player.position.x
      local p_y = player.position.y
      while ghost[1] ~= nil do
        ghost[1].revive()
        player.teleport({math.random(p_x - 5, p_x + 5), math.random(p_y - 5, p_y + 5)})
        ghost = surface.find_entities_filtered {area = a, name = "entity-ghost"}
      end
      player.teleport({p_x, p_y})
      local assembling = surface.find_entities_filtered {area = a, name = upgrade.entity_to}[1]
      if not assembling then
        player.print("Upgrade planner error - Entity to raise was not found")
        player.cursor_stack.set_stack {name = "upgrade-builder", count = 1}
        player.insert {name = upgrade.item_from, count = amount}
        return
      end
      script.raise_event(defines.events.on_built_entity, {player_index = player.index, created_entity = assembling})
      --Give back the inventory to the new entity
      for j, items in pairs(inventories) do
        for l, contents in pairs(items.contents) do
          if assembling ~= nil then
            local inv = assembling.get_inventory(items.name)
            if inv then
              inv.insert {name = l, count = contents}
            end
          end
        end
      end
      local proxy = surface.find_entities_filtered {area = a, name = "item-request-proxy"}
      if proxy[1] ~= nil then
        proxy[1].destroy()
      end
      player.cursor_stack.set_stack {name = "upgrade-builder", count = 1}
    else
      player.remove_item {name = upgrade.item_to, count = amount}
      --player.insert{name = upgrade.item_from, count = amount}
      script.raise_event(
        defines.events.on_player_mined_item,
        {player_index = player.index, item_stack = {name = upgrade.item_from, count = 1}}
      )
      script.raise_event(
        defines.events.on_built_entity,
        {player_index = player.index, created_entity = new_item, stack = player.cursor_stack}
      )
    end
  else
    global.temporary_ignore[belt.name] = true
    surface.create_entity {
      name = "flying-text",
      position = {belt.position.x - 1.3, belt.position.y - 0.5},
      text = "Insufficient items",
      color = {r = 1, g = 0.6, b = 0.6}
    }
  end
end

upgrade_planner_entity_upgrade.upgrade_area_player = function(event)
  if event.item ~= "upgrade-builder" then
    return
  end
  --If its a upgrade builder

  local player = game.players[event.player_index]
  local config = global.current_config[player.index]
  if config == nil then
    return
  end
  local hashmap = get_hashmap(config)
  global.temporary_ignore = {}
  for k, belt in pairs(event.entities) do --Get the items that are set to be upgraded
    if belt.valid then
      local upgrade = hashmap[belt.name]
      if belt.get_module_inventory() then
        player_upgrade_modules(player, belt.get_module_inventory(), hashmap, belt)
      end
      if upgrade ~= nil and upgrade ~= "" then
        player_upgrade(player, belt, upgrade, true)
      end
    end
  end
  global.temporary_ignore = nil
end

local function robot_upgrade_modules(inventory, map, owner)
  if not owner then
    return
  end
  if not owner.valid then
    return
  end
  local surface = owner.surface
  local modules = {}
  local proxy = false
  for k = 1, #inventory do
    local slot = inventory[k]
    if slot.valid and slot.valid_for_read then
      local upgrade = map[slot.name]
      local recipe = get_recipe(owner)
      if upgrade and upgrade.item_to and recipe and check_module_eligibility(upgrade.item_to, recipe) then
        local entity =
          surface.create_entity {
          name = "item-on-ground",
          stack = {name = slot.name, count = slot.count},
          position = owner.position,
          force = owner.force
        }
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
    surface.create_entity {
      name = "item-request-proxy",
      force = owner.force,
      position = owner.position,
      modules = modules,
      target = owner
    }
  end
end

upgrade_planner_entity_upgrade.upgrade_area_bot = function(event)
  --this is a lot simpler... but less cool
  if event.item ~= "upgrade-builder" then
    return
  end
  local player = game.players[event.player_index]
  local config = global.current_config[player.index]
  if not config then
    return
  end
  local hashmap = get_hashmap(config)
  for k, entity in pairs(event.entities) do
    if entity.valid then
      local upgrade = hashmap[entity.name]
      if upgrade and upgrade ~= "" then
        entity.order_upgrade({force = entity.force, target = upgrade["entity_to"]})
      end
      if entity.valid and entity.get_module_inventory() then
        robot_upgrade_modules(entity.get_module_inventory(), hashmap, entity)
      end
    end
  end
end

local function update_blueprint_entities(stack, hashmap)
  if not (stack and stack.valid and stack.valid_for_read and stack.is_blueprint_setup()) then
    return
  end
  local entities = stack.get_blueprint_entities()
  if entities then
    for k, entity in pairs(entities) do
      local new_entity = hashmap[entity.name]
      if new_entity and new_entity.entity_to then
        entities[k].name = new_entity.entity_to
      end
      if entity.items then
        local new_items = {}
        for item, count in pairs(entity.items) do
          new_items[item] = count
        end
        for item, count in pairs(entity.items) do
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
        for item, count in pairs(new_items) do
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
    for k, tile in pairs(tiles) do
      local prototype = tile_prototypes[tile.name]
      local items_to_place = prototype.items_to_place_this
      local item = nil
      if items_to_place then
        for name, _ in pairs(items_to_place) do
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
            local new_tile = tile_prototypes[result.result.name]
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
  for k, icon in pairs(icons) do
    local new = hashmap[icon.signal.name]
    if new and new.item_to then
      icons[k].signal.name = new.item_to
    end
  end
  stack.blueprint_icons = icons
  return true
end

upgrade_planner_entity_upgrade.upgrade_blueprint = function(event)
  local player = game.players[event.player_index]
  local stack = player.cursor_stack
  if not (stack.valid and stack.valid_for_read) then
    return
  end

  local config = global.current_config[player.index]
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

return upgrade_planner_entity_upgrade
