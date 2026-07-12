local swap_funcs = {}

---@param stack LuaItemStack
---@param result table
function swap_funcs.set_or_nil_stack(stack, result)
    if result ~= nil then
        stack.set_stack({ name = result.name, count = stack.count, quality = result.quality or stack.quality })
    else
        stack.set_stack(nil)
    end
end

--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition the name of the placeholder item.
--- @return nil
function swap_funcs.hotswap_item_in_character_inventory(result, entity, rse_definition, quality
)
    local inventory = entity.get_main_inventory()
    local placeholder_name = rse_definition.name
    if inventory then
        --local _placeholder_number = inventory.get_item_count(placeholder_name)

        local removed = inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
        if removed > 0 then
            if result ~= nil then
                inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
            end
            goto continue
        end

        ::continue::
        if entity.cursor_stack and entity.cursor_stack.valid_for_read and entity.cursor_stack.name == placeholder_name then
            swap_funcs.set_or_nil_stack(entity.cursor_stack, result)
        end
    end
end

--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition the name of the placeholder item.
--- @return nil
function swap_funcs.hotswap_in_belt(result, entity, rse_definition)
    local transport_lines = { entity.get_transport_line(1), entity.get_transport_line(2) }
    local placeholder_name = rse_definition.name
    for _, line in pairs(transport_lines) do
        for i = 1, #line do
            local stack = line[i]
            if stack.valid_for_read and stack.name == placeholder_name then
                swap_funcs.set_or_nil_stack(stack, result)
            end
        end
    end
end

--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition the name of the placeholder item.
--- @return nil
function swap_funcs.hotswap_in_underground_belt(result, entity, rse_definition)
    local placeholder_name = rse_definition.name

    for i = 1, entity.get_max_transport_line_index() do
        local line = entity.get_transport_line(i)

        for i = 1, #line do
            local stack = line[i]
            if stack.valid_for_read and stack.name == placeholder_name then
                swap_funcs.set_or_nil_stack(stack, result)
                return
            end
        end
    end
end

--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition the name of the placeholder item.
--- @return nil
function swap_funcs.hotswap_in_splitter(result, entity, rse_definition)
    local placeholder_name = rse_definition.name
    for line = 1, 4 do
        local line = entity.get_transport_line(line)
        for i = 1, #line do
            local stack = line[i]
            if stack.name == placeholder_name then
                swap_funcs.set_or_nil_stack(stack, result)
                return
            end
        end
    end
end

--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param result string
--- @return nil
function swap_funcs.hotswap_in_inserter(result, entity)
    if entity.held_stack.valid_for_read then
        swap_funcs.set_or_nil_stack(entity.held_stack, result)
    end
end

--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @return nil
function swap_funcs.hotswap_in_bot(result, entity)
    local stack = entity.get_inventory(defines.inventory.robot_cargo)[1]
    if stack.valid_for_read then
        swap_funcs.set_or_nil_stack(stack, result)
    end
end

--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param result string
--- @return nil
function swap_funcs.hotswap_in_cargo_pod(result, entity)
    local stack = entity.get_inventory(defines.inventory.cargo_unit)[1]
    if stack.valid_for_read then
        swap_funcs.set_or_nil_stack(stack, result)
    end
end

--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_machine(result, entity, rse_definition, quality)
    local placeholder_name = rse_definition.name
    local input = entity.get_inventory(defines.inventory.crafter_input)
    local output = entity.get_inventory(defines.inventory.crafter_output)
    local dump = entity.get_inventory(defines.inventory.assembling_machine_dump)
    local trash = entity.get_inventory(defines.inventory.crafter_trash)
    local modules = entity.get_inventory(defines.inventory.crafter_modules)
    local inventories = { input, output, dump, trash }

    if modules then
        table.insert(inventories, modules)
    end
    for _, inventory in pairs(inventories) do
        local item_count = inventory.get_item_count({ name = placeholder_name, quality = quality })
        if item_count > 0 then
            local removed = inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
            if removed > 0 then
                if result ~= nil then
                    if inventory.can_insert({ name = result.name, count = removed, quality = result.quality or quality }) then
                        inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
                        return
                    elseif trash ~= nil then
                        trash.insert({ name = result.name, count = removed, quality = result.quality or quality })
                        return
                    end
                end
            end
        end
    end
end

--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_generic_inventory(result, entity, rse_definition, inventory_definition, quality)
    local placeholder_name = rse_definition.name
    if inventory_definition then
        local inventory = entity.get_inventory(inventory_definition)
        if inventory then
            local removed = inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
            if removed > 0 then
                if result ~= nil then
                    inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
                end
                return
            end
        end
    else
        game.print("PLEASE REPORT TO RSE AUTHOR : Unhandled inventory type for")
        game.print(entity.type)
        return
    end
end

--- If the output is full, the spoiling item will just be deleted
--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_boiler_inventory(result, entity, rse_definition, quality)
    local placeholder_name = rse_definition.name
    local input_inventory = entity.get_inventory(defines.inventory.fuel)
    local output_inventory = entity.get_inventory(defines.inventory.burnt_result)
    for _, inventory in pairs({ input_inventory, output_inventory }) do
        if inventory then
            local removed = inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
            if removed > 0 then
                if result ~= nil then
                    inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
                end
                return
            end
        end
    end
end

--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_lab_inventory(result, entity, rse_definition, quality)
    local placeholder_name = rse_definition.name
    --local inventory = entity.get_inventory(defines.inventory.lab_input)
    local trash_inventory = entity.get_inventory(defines.inventory.crafter_trash)
    -- Currently, trash_inventory_size does nothing for labs so there is only one slot available. Excess spoiled items will be deleted.
    if trash_inventory and trash_inventory.can_insert({ name = result.name, count = removed, quality = result.quality or quality }) then
        local removed = trash_inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
        if removed > 0 then
            if result ~= nil then
                trash_inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
            end
            return
        end
    end
end

--- Mining drills do not have an inventory, they have an internal buffer that is not accessible
--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_mining_drill(result, entity, rse_definition, quality)
    -- The current behavior of mining drills don't allow runtime item replacement. So, if the modder
    -- wants to add a spoilable ore, either a fallback is needed for this item, either placeholder_spoil_into_self
    -- must be set to true
    --local placeholder_name = rse_definition.name
    --local inventory = "..."
    return
end

--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_furnace(result, entity, rse_definition, quality)
    local placeholder_name = rse_definition.name
    local inventory_result = entity.get_inventory(defines.inventory.crafter_output)
    local inventory_input = entity.get_inventory(defines.inventory.crafter_input)
    local modules = entity.get_inventory(defines.inventory.crafter_modules)
    local inventories = { inventory_input, inventory_result }

    if modules then
        table.insert(inventories, modules)
    end

    for _, inventory in pairs(inventories) do
        if inventory then
            local removed = inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
            if removed > 0 then
                if result ~= nil then
                    if string.sub(result.name, -3) == "ore" then
                        inventory_input.insert({ name = result.name, count = removed, quality = result.quality or quality })
                        return
                    end

                    inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
                end
                return
            end
        end
    end
end

--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_logistic_inventory(result, entity, rse_definition, quality)
    local placeholder_name = rse_definition.name
    local inventories = { entity.get_inventory(defines.inventory.chest), entity.get_inventory(defines.inventory
    .logistic_container_trash) }
    for _, inventory in pairs(inventories) do
        if inventory then
            local removed = inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
            if removed > 0 then
                if result ~= nil then
                    inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
                end
                return
            end
        end
    end
end

--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_roboport(result, entity, rse_definition, quality)
    local placeholder_name = rse_definition.name
    local inventories = { entity.get_inventory(defines.inventory.roboport_robot), entity.get_inventory(defines.inventory
    .roboport_material) }
    for _, inventory in pairs(inventories) do
        if inventory then
            local removed = inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
            if removed > 0 then
                if result ~= nil then
                    inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
                end
                return
            end
        end
    end
end

--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_agricultural_tower(result, entity, rse_definition, quality)
    local placeholder_name = rse_definition.name
    local inventories = { entity.get_inventory(defines.inventory.crafter_input), entity.get_inventory(defines.inventory
    .crafter_output) }
    for _, inventory in pairs(inventories) do
        if inventory then
            local removed = inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
            if removed > 0 then
                if result ~= nil then
                    inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
                end
                return
            end
        end
    end
end

--- @param result string|nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param quality string
--- @return nil
function swap_funcs.hotswap_in_spider(result, entity, rse_definition, quality)
    local placeholder_name = rse_definition.name
    local inventories = { entity.get_inventory(defines.inventory.spider_ammo), entity.get_inventory(defines.inventory
    .spider_trash), entity.get_inventory(defines.inventory.spider_trunk) }
    for _, inventory in pairs(inventories) do
        if inventory then
            local removed = inventory.remove({ name = placeholder_name, count = 9999999, quality = quality })
            if removed > 0 then
                if result ~= nil then
                    inventory.insert({ name = result.name, count = removed, quality = result.quality or quality })
                end
                return
            end
        end
    end
end

--- @param result string | nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @param rse_definition RtRseDefinition
--- @param inventory_definition defines.inventory.car_trunk|defines.inventory.cargo_wagon|defines.inventory.chest|defines.inventory.hub_main|defines.inventory.rocket_silo_rocket
function swap_funcs.hotswap_in_generic_inventory_in_place(result, entity, rse_definition, inventory_definition)
    local placeholder_name = rse_definition.name
    local inventory = entity.get_inventory(inventory_definition)
    if inventory then
        local current_count = inventory.get_item_count(placeholder_name)
        if current_count > 0 then
            for i = 1, #inventory do
                local stack = inventory[i]
                if stack.valid_for_read and stack.name == placeholder_name then
                    swap_funcs.set_or_nil_stack(stack, result)
                    return
                end
            end
        end
    end
end

--- @param result string | nil
--- @param entity LuaEntity (we assume source_entity and target_entity are the same).
--- @return nil
function swap_funcs.hotswap_on_ground(result, entity)
    return swap_funcs.set_or_nil_stack(entity.stack, result or nil)
end

--- @param result string | nil
--- @param event EventData.on_script_trigger_effect
--- @param rse_definition RtRseDefinition
function swap_funcs.hotswap_in_position(result, event, rse_definition)
    local surface = game.surfaces[event.surface_index]
    local entity = surface.find_entities_filtered(
        {
            position = event.source_position,
            name = "item-on-ground",
            radius = 2
        }
    )
    if entity and entity[1] and entity[1].stack.name == rse_definition.name then
        swap_funcs.set_or_nil_stack(entity[1].stack, result or nil)
    end
end

return swap_funcs
