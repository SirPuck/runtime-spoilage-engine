local selection_funcs = {}
local key_selectors = require("runtime_registry").registry.key_selectors

---@class PossibleResults
---@field [string] table

---@class ResultMapping
---@field possible_results PossibleResults

---@param result_mapping ResultMapping
function selection_funcs.weighted_choice(result_mapping)
    local possible_results = result_mapping.possible_results
    if not possible_results then return nil end

    local r = math.random() * possible_results.cumulative_weight
    local low, high = 1, #possible_results

    -- Binary search for correct cumulative weight
    while low < high do
        local mid = math.floor((low + high) / 2)
        if possible_results[mid].weight <= r then
            low = mid + 1
        else
            high = mid
        end
    end

    return possible_results[low]  -- Correctly selected option
end

-- Random selection functions
-----------------------------
--- This function selects and returns one outcome with equals chances of selection from an array of possible items
---@param result_mapping ResultMapping
function selection_funcs.select_one_result_over_n_unweighted(result_mapping, _)
    if #result_mapping.possible_results == 0 then return nil end
    return result_mapping.possible_results[math.random(1, #result_mapping.possible_results)]
end

---@param rse_definition RtRseDefinition
---@param event EventData.on_script_trigger_effect
local function select_key(rse_definition, event)
    local key_selector = key_selectors[rse_definition.key_selector]
    if not key_selector then error("[RSE] Registration error: key selector '"..tostring(rse_definition.key_selector).."' is not registered") end
    return tostring(key_selector(event))
end

---@param rse_definition RtRseDefinition
---@param event EventData.on_script_trigger_effect
local function get_keyed_results(rse_definition, event)
    local key = select_key(rse_definition, event)
    local result = rse_definition.possible_results[key]
    if result == nil then
        local expected = {}
        for expected_key in pairs(rse_definition.possible_results) do expected[#expected + 1] = tostring(expected_key) end
        table.sort(expected)
        error("[RSE] Registration error for '"..tostring(rse_definition.registration_name).."': key selector '"
            ..tostring(rse_definition.key_selector).."' returned unmapped key '"..key
            .."'. Expected one of: "..table.concat(expected, ", ")..".", 0)
    end
    return result
end
function selection_funcs.deterministic(rse_definition, event)
    return get_keyed_results(rse_definition, event)
end

---@param rse_definition RtRseDefinition
---@param event EventData.on_script_trigger_effect
function selection_funcs.fixed_result(rse_definition, _)
    return rse_definition.possible_results
end

function selection_funcs.keyed_random_unweighted(rse_definition, event)
    local result_mapping = {possible_results = get_keyed_results(rse_definition, event)}
    return selection_funcs.select_one_result_over_n_unweighted(result_mapping) -- function expects a table with `possible_results` element
end

---@param rse_definition RtRseDefinition
---@param event EventData.on_script_trigger_effect
function selection_funcs.keyed_random_weighted(rse_definition, event)
    local result_mapping = {possible_results = get_keyed_results(rse_definition, event)}
    return selection_funcs.weighted_choice(result_mapping) -- function expects a table with `possible_results` element
end

---@param rse_definition RtRseDefinition
---@param event EventData.on_script_trigger_effect
local function select_result(rse_definition, event)
    return selection_funcs[rse_definition.selector](rse_definition, event)
end

return select_result