---@class RseResult
---@field name data.ItemID
---@field quality? data.QualityID
---@field weight? integer Positive relative probability in a random result array.

---@class RsePlaceholderOverrides
---@field icon? data.FileName
---@field icons? data.IconData[]
---@field localised_name? data.LocalisedString
---@field localised_description? data.LocalisedString

---@class RseRegistrationData
---@field original_item_type string
---@field original_item_name data.ItemID
---@field results RseResult|RseResult[]|table<string, RseResult|RseResult[]>
---@field key_selector? string
---@field items_per_trigger? data.ItemCountType
---@field placeholder_spoil_into_self? boolean
---@field fallback_spoilage? data.ItemID
---@field additional_trigger? data.TriggerItem
---@field placeholder_overrides? RsePlaceholderOverrides

---@class RseDefinition
---@field type "mod-data"
---@field name string
---@field data_type "rse_definition"
---@field data RseDefinitionData

---@class RseDefinitionData: RseRegistrationData
---@field registration_name string
---@field selector string
---@field possible_results table

---@class RseRegistration
---@field type "mod-data"
---@field name string
---@field data_type "rse_registration"
---@field data RseRegistrationData

---@class RseFunctionPrototype
---@field type "mod-data"
---@field name string
---@field data_type "rse_function"
---@field data {func: string}

---@class RseWeightedResult: RseResult
---@field weight integer

---@class RsePreprocessedResult: RseResult
---@field weight number Cumulative weight.

---@class RsePreprocessedResults: RsePreprocessedResult[]
---@field cumulative_weight number

---@param possible_results RseWeightedResult[]
---@return RsePreprocessedResults
local function preprocess_weights(possible_results)
    local cumulative_weight = 0
    local sorted_options = {}

    -- Build sorted list of cumulative_weights
    for _, option in ipairs(possible_results) do
        cumulative_weight = cumulative_weight + option.weight
        table.insert(sorted_options, {name = option.name, quality=option.quality, weight = cumulative_weight})
    end

    -- Ensure sorting is correct (ascending order)
    ---@param a RsePreprocessedResult
    ---@param b RsePreprocessedResult
    ---@return boolean
    local function compare_cumulative_weight(a, b)
        return a.weight < b.weight
    end
    table.sort(sorted_options, compare_cumulative_weight)

    sorted_options.cumulative_weight = cumulative_weight
    return sorted_options
end


---@param nested table<string, RseResult[]>
---@return RseResult[]
local function flatten_conditional_results(nested)
    local flat = {}
    for _, result_list in pairs(nested) do
        for _, entry in ipairs(result_list) do
            flat[#flat+1] = entry
        end
    end
    return flat
end


---@param prototype_name string
---@param results RseResult[]|table<string, RseResult[]>
---@param nested? boolean
---@return boolean
local function validate_is_weighted(prototype_name, results, nested)
    local weighted = false
    local all_weighted = true

    if nested then
        results = flatten_conditional_results(results)
    end

    for key, value in pairs(results) do
            
            if value.weight ~= nil then
                weighted = true
                if type(value.weight) ~= "number" or value.weight % 1 ~= 0 then
                    error("[RSE] RTM Error in registration '"..tostring(prototype_name).."': every `weight` must be a positive integer. See README.md#rtm-error-reference.", 0)
                end
            else
                all_weighted = false
            end

    end

    if weighted and not all_weighted then
        error("[RSE] RTM Error in registration '"..tostring(prototype_name).."': random results mix weighted and unweighted options. Either give every option a positive integer `weight`, or omit all weights for equal probability. See README.md#rtm-error-reference.", 0)
    end

    return weighted
end


---@param prototype_name string
---@param input_results table<string, RseResult[]>
---@return nil
local function validate_rc_results(prototype_name, input_results)
    if type(input_results) ~= "table" then
        error("validate_results: conditional_random_results must be a table, got " .. type(input_results))
    end

    for key, value in pairs(input_results) do
        if type(key) ~= "string" and type(key) ~= "number" then
            error("validate_results: in prototype "..prototype_name..", key '" .. tostring(key) .. "' is not a string|int|bool.")
        end
        if type(value) ~= "table" then
            error("validate_results: in prototype "..prototype_name..", value for key '" .. key .. "' must be a table, got " .. type(value))
        end
        for i, entry in ipairs(value) do
            if type(entry) ~= "table" then
                error("validate_results: in prototype "..prototype_name..", entry #" .. i .. " in '" .. key .. "' must be a table, got " .. type(entry))
            end
            if type(entry.name) ~= "string" then
                error("validate_results: in prototype "..prototype_name..", entry #" .. i .. " in '" .. key .. "' is missing a string 'name' field")
            end
        end
    end

end

---@param prototype_name string
---@param input_results table<string, RseResult>
---@return nil
local function validate_c_deterministic_results(prototype_name, input_results)
    if type(input_results) ~= "table" then
        error("validate_results: in prototype "..prototype_name..", conditional_results must be a table, got " .. type(input_results))
    end

    for key, value in pairs(input_results) do
        if type(key) ~= "string" then
            error("validate_results: in prototype "..prototype_name..", key '" .. tostring(key) .. "' is not a string.")
        end
        if type(value) ~= "table" then
             error("validate_results: in prototype "..prototype_name..", value for key '" .. key .. "' must be a table (item name), got " .. type(value))
        end
    end

end

local README_SECTION = "README.md#rtm-error-reference"

---@param registration_name string
---@param message string
---@return never
local function rtm_error(registration_name, message)
    error("[RSE] RTM Error in registration '"..tostring(registration_name).."': "..message
        .." See "..README_SECTION.." and copy the template matching your use case.", 0)
end

---@param registration_name string
---@param message string
---@return never
local function registration_error(registration_name, message)
    error("[RSE] Registration error for '"..tostring(registration_name).."': "..message, 0)
end

---@param value any
---@return boolean
local function is_result(value)
    return type(value) == "table" and type(value.name) == "string" and value.name ~= ""
end

---@param registration_name string
---@param result any
---@param location string
---@return nil
local function validate_result(registration_name, result, location)
    if type(result) ~= "table" then
        rtm_error(registration_name, location.." must be a result table, got "..type(result)..".")
    end
    if type(result.name) ~= "string" or result.name == "" then
        rtm_error(registration_name, location.." needs a non-empty string field `name`.")
    end
    if result.quality ~= nil and (type(result.quality) ~= "string" or result.quality == "") then
        rtm_error(registration_name, location.." field `quality` must be a non-empty string when provided.")
    end
    if result.weight ~= nil and (type(result.weight) ~= "number" or result.weight % 1 ~= 0 or result.weight <= 0) then
        rtm_error(registration_name, location.." field `weight` must be a positive integer.")
    end
end

---@param registration_name string
---@param results any
---@param location string
---@return nil
local function validate_result_array(registration_name, results, location)
    if type(results) ~= "table" then
        rtm_error(registration_name, location.." must be an array of result tables.")
    end
    local count = 0
    for key, result in pairs(results) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
            rtm_error(registration_name, location.." must be a dense array; unexpected key `"..tostring(key).."`.")
        end
        count = count + 1
        validate_result(registration_name, result, location.."["..key.."]")
    end
    if count == 0 then rtm_error(registration_name, location.." cannot be empty.") end
    for index = 1, count do
        if results[index] == nil then rtm_error(registration_name, location.." must be dense; index "..index.." is missing.") end
    end
end

---@param registration_name string
---@param results any
---@param key_selector? string
---@return "fixed"|"random"|"keyed"|"keyed_random"
local function classify_results(registration_name, results, key_selector)
    if type(results) ~= "table" then
        rtm_error(registration_name, "`data.results` must be a table, got "..type(results)..".")
    end
    if is_result(results) then
        if key_selector ~= nil then
            rtm_error(registration_name, "a single-result template cannot define `key_selector`.")
        end
        validate_result(registration_name, results, "data.results")
        return "fixed"
    end
    if key_selector == nil then
        validate_result_array(registration_name, results, "data.results")
        return "random"
    end
    if type(key_selector) ~= "string" or key_selector == "" then
        rtm_error(registration_name, "`data.key_selector` must be the non-empty name of an `rse_function` registration.")
    end

    local kind
    local count = 0
    for key, value in pairs(results) do
        if type(key) ~= "string" then
            rtm_error(registration_name, "result selector key `"..tostring(key).."` must be a string, got "..type(key)..".")
        end
        count = count + 1
        local current
        if is_result(value) then
            validate_result(registration_name, value, "data.results["..tostring(key).."]")
            current = "keyed"
        elseif type(value) == "table" then
            validate_result_array(registration_name, value, "data.results["..tostring(key).."]")
            current = "keyed_random"
        else
            rtm_error(registration_name, "data.results["..tostring(key).."] must be a result or an array of results.")
        end
        if kind and kind ~= current then
            rtm_error(registration_name, "keyed `results` cannot mix single results with arrays of results.")
        end
        kind = current
    end
    if count == 0 then rtm_error(registration_name, "keyed `data.results` cannot be empty.") end
    return kind
end

local registered_key_selectors = {quality = true}
local registered_targets = {}
local rse = {}

---@param content RseFunctionPrototype
---@return nil
function rse.register_key_selector_prototype(content)
    local name = content and content.name or "<missing name>"
    if name == "quality" then rtm_error(name, "`quality` is reserved for RSE's built-in quality key selector.") end
    if type(content) ~= "table" then rtm_error(name, "rse_function registration must be a table.") end
    if type(content.name) ~= "string" or content.name == "" then rtm_error(name, "rse_function `name` must be a non-empty string.") end
    if type(content.data) ~= "table" or type(content.data.func) ~= "string" or content.data.func == "" then
        rtm_error(name, "rse_function `data.func` must be a function expression string, e.g. [[function(event) return event.quality end]].")
    end
    local chunk, compile_error = load("return ("..content.data.func..")", name.."::<rse-function>", "t", {})
    if not chunk then registration_error(name, "rse_function `data.func` has invalid Lua syntax: "..tostring(compile_error)) end
    registered_key_selectors[name] = true
end

---@param registration any
---@return nil
local function validate_registration(registration)
    local name = registration and registration.name or "<missing name>"
    if type(registration) ~= "table" then rtm_error(name, "registration must be a table.") end
    if registration.type ~= "mod-data" then rtm_error(name, "prototype `type` must be `mod-data`.") end
    if registration.data_type ~= "rse_registration" then rtm_error(name, "`data_type` must be `rse_registration`.") end
    if type(registration.name) ~= "string" or registration.name == "" then rtm_error(name, "prototype `name` must be a non-empty string.") end
    if type(registration.data) ~= "table" then rtm_error(name, "`data` must be a table.") end
    local definition = registration.data
    local original_type = definition.original_item_type or definition.data_raw_table
    if type(original_type) ~= "string" or original_type == "" then
        rtm_error(name, "`data.original_item_type` is required and must be a non-empty string.")
    end
    if type(definition.original_item_name) ~= "string" or definition.original_item_name == "" then
        rtm_error(name, "`data.original_item_name` is required and must be a non-empty string.")
    end
    if not data.raw[original_type] then
        registration_error(name, "original item type `"..original_type.."` does not exist in data.raw. Check the prototype type and mod load order.")
    end
    if not data.raw[original_type][definition.original_item_name] then
        registration_error(name, "original prototype `"..original_type.."/"..definition.original_item_name.."` does not exist. Check its name and mod load order.")
    end
    local target = original_type.."/"..definition.original_item_name
    if registered_targets[target] then
        registration_error(name, "target `"..target.."` is already registered by `"..registered_targets[target].."`; each source prototype can only have one RSE registration.")
    end
    registered_targets[target] = name
    if definition.key_selector ~= nil and not registered_key_selectors[definition.key_selector] then
        registration_error(name, "`key_selector` names missing built-in or custom key selector `"..tostring(definition.key_selector).."`. Check its name and mod load order.")
    end
    if type(definition.results) ~= "table" then
        rtm_error(name, "`data.results` is required and must be a table. Old mode fields (`random`, `conditional`, etc.) are no longer a registration template.")
    end
    if definition.items_per_trigger ~= nil and (type(definition.items_per_trigger) ~= "number" or definition.items_per_trigger % 1 ~= 0 or definition.items_per_trigger <= 0) then rtm_error(name, "`items_per_trigger` must be a positive integer when provided.") end
    if definition.placeholder_spoil_into_self ~= nil and type(definition.placeholder_spoil_into_self) ~= "boolean" then rtm_error(name, "`placeholder_spoil_into_self` must be a boolean when provided.") end
    if definition.fallback_spoilage ~= nil and (type(definition.fallback_spoilage) ~= "string" or definition.fallback_spoilage == "") then rtm_error(name, "`fallback_spoilage` must be a non-empty prototype name when provided.") end
    if definition.additional_trigger ~= nil and type(definition.additional_trigger) ~= "table" then rtm_error(name, "`additional_trigger` must be a TriggerItem table when provided.") end
    if definition.placeholder_overrides ~= nil and type(definition.placeholder_overrides) ~= "table" then
        rtm_error(name, "`data.placeholder_overrides` must be a table when provided.")
    end
    if type(definition.placeholder_overrides) == "table" then
        local overrides = definition.placeholder_overrides
        if overrides.icon ~= nil and (type(overrides.icon) ~= "string" or overrides.icon == "") then
            rtm_error(name, "`placeholder_overrides.icon` must be a non-empty FileName string when provided.")
        end
        if overrides.icons ~= nil and type(overrides.icons) ~= "table" then
            rtm_error(name, "`placeholder_overrides.icons` must be an array of IconData tables when provided.")
        end
    end
end


---@param rse_registration RseRegistration
---@return nil
function rse.make_rse_definition(rse_registration)

    validate_registration(rse_registration)
    local prototype_name = rse_registration.name

    rse_registration.hidden = true
    rse_registration.hidden_in_factoriopedia = true

    local rse_definition = table.deepcopy(rse_registration)

    local data_def = rse_definition.data
    local type_key = data_def.original_item_type or data_def.data_raw_table
    local original_item = data.raw[type_key][data_def.original_item_name]
    local placeholder_icon = "__base__/graphics/icons/signal/signal-question-mark.png"
    ---@type data.ItemPrototype
    local placeholder = {
            type = "item",
            name = original_item.name .. "-rse-placeholder",
            icon = placeholder_icon,
            subgroup = "raw-material",
            stack_size = original_item.stack_size,
            spoil_ticks = 10,
            weight = original_item.weight,
            hidden = true,
            hidden_in_factoriopedia = true,
        }

    if data_def.placeholder_overrides then
        local overrides = data_def.placeholder_overrides
        if overrides.icon ~= nil and overrides.icons ~= nil then rtm_error(rse_registration.name, "placeholder_overrides cannot define both `icon` and `icons`.") end
        for _, field in ipairs{"icon", "icons", "localised_name", "localised_description"} do
            if overrides[field] ~= nil then placeholder[field] = overrides[field] end
        end
    end


    original_item.spoil_to_trigger_result =
    {
        items_per_trigger = rse_definition.data.items_per_trigger or original_item.stack_size, --This allows to trigger only one event by default for the entire stack.
        trigger =
        {
            {
                type = "direct",
                action_delivery =
                    {
                    type = "instant",
                    source_effects = 
                    {
                        {
                            type = "script",
                            effect_id = placeholder.name
                        },
                    }
                }
            },
        }
    }

    if rse_registration.data.additional_trigger then
        table.insert(original_item.spoil_to_trigger_result.trigger, rse_registration.data.additional_trigger)
    end

    original_item.spoil_result = placeholder.name

    if rse_registration.data.placeholder_spoil_into_self or (rse_registration.data.placeholder_spoil_into_self == nil and (rse_registration.data.loop_spoil_safe_mode or rse_registration.data.loop_spoil_safe_mode == nil)) then
        placeholder.spoil_result = placeholder.name
        placeholder.spoil_to_trigger_result = original_item.spoil_to_trigger_result
    elseif rse_registration.data.fallback_spoilage then
        placeholder.spoil_result = rse_registration.data.fallback_spoilage
    end

    data:extend{
        placeholder
    }

    rse_definition.name = placeholder.name
    rse_definition.data_type = "rse_definition"
    rse_definition.data.registration_name = prototype_name

    rse_definition.data["possible_results"] = {}

    if rse_definition.data.results then
        local results = rse_definition.data.results
        local kind = classify_results(prototype_name, results, rse_definition.data.key_selector)
        if kind == "fixed" then
            rse_definition.data.selector, rse_definition.data.possible_results = "fixed_result", results
        elseif kind == "keyed" then
            rse_definition.data.selector, rse_definition.data.possible_results = "deterministic", results
        elseif kind == "random" then
            local weighted = validate_is_weighted(prototype_name, results)
            rse_definition.data.selector = weighted and "weighted_choice" or "select_one_result_over_n_unweighted"
            rse_definition.data.possible_results = weighted and preprocess_weights(results) or results
        else
            local weighted = validate_is_weighted(prototype_name, results, true)
            rse_definition.data.selector = weighted and "keyed_random_weighted" or "keyed_random_unweighted"
            if weighted then
                for key, choices in pairs(results) do rse_definition.data.possible_results[key] = preprocess_weights(choices) end
            else rse_definition.data.possible_results = results end
        end
        data:extend{rse_definition}
        return
    end
    if rse_definition.data.conditional and rse_definition.data.random then
        validate_rc_results(prototype_name, rse_definition.data.conditional_random_results)

        local weighted = validate_is_weighted(prototype_name, rse_definition.data.conditional_random_results, true)
        
        if weighted then
            
            for condition_result, results in pairs(rse_definition.data.conditional_random_results) do
                rse_definition.data["possible_results"][condition_result] = preprocess_weights(results)
            end

            rse_definition.data["selector"] = "keyed_random_weighted"
            data:extend{rse_definition}
            return
        else
            rse_definition.data["possible_results"] = rse_definition.data.conditional_random_results
            rse_definition.data["selector"] = "keyed_random_unweighted"
            return
        end
    end

    if rse_definition.data.conditional then
        validate_c_deterministic_results(prototype_name, rse_definition.data.conditional_results)
        rse_definition.data["selector"] = "deterministic"
        rse_definition.data["possible_results"] = rse_definition.data.conditional_results
        data:extend{rse_definition}
        return
    end

    if rse_definition.data.random then
        local weighted = validate_is_weighted(prototype_name, rse_definition.data.random_results)
        if weighted then
            rse_definition.data["selector"] = "weighted_choice"
            rse_definition.data["possible_results"] = preprocess_weights(rse_definition.data.random_results)
        else
            rse_definition.data["selector"] = "select_one_result_over_n_unweighted"
            rse_definition.data["possible_results"] = rse_definition.data.random_results
        end
        data:extend{rse_definition}
    end

    if rse_definition.data.quality_cycling and rse_definition.data.deterministic_result == nil then
        rse_definition.data["selector"] = "quality_upscale"
        rse_definition.data["possible_results"] = {name = rse_registration.data.original_item_name}
        data:extend{rse_definition}
    end

    if rse_definition.data.quality_change and rse_definition.data.deterministic_result then
        rse_definition.data["selector"] = "quality_upscale"
        rse_definition.data["possible_results"] = rse_registration.data.deterministic_result
        data:extend{rse_definition}
    end
end

return rse