---@class RtRseDefinition
---@field name string
---@field original_item_name string
---@field selector string
---@field possible_results table
---@field key_selector? string

local registry = {}
registry.rse_definitions = {}
registry.key_selectors = {
  quality = function(event)
    return event.quality or "normal"
  end,
}

function registry.register_key_selector(name, selector)
  if type(name) ~= "string" or name == "" then
    error("[RSE] Key selector registration requires a non-empty string name.", 0)
  end
  if type(selector) ~= "function" then
    error("[RSE] Key selector '"..name.."' must be a function, got "..type(selector)..".", 0)
  end
  if name == "quality" then
    error("[RSE] Key selector name 'quality' is reserved for RSE's built-in quality selector.", 0)
  end
  registry.key_selectors[name] = selector
end

local function compile_function_from_string(name, code_str)
  if type(code_str) ~= "string" then
    error("[RSE] Function registration error for '"..name.."': `data.func` must be a function expression string, got "..type(code_str), 0)
  end

  -- Prefer expression form: "function(event) ... end"
  -- Wrap with `return (...)` so the chunk evaluates to the function value.
  local wrapped = "return (" .. code_str .. ")"

  local chunk, err = load(wrapped, name .. "::<rse-func>", "t", _ENV)
  if not chunk then
    -- As a fallback, try raw (maybe author wrote "return function(event) ... end")
    chunk, err = load(code_str, name .. "::<rse-func>", "t", _ENV)
    if not chunk then
      error("[RSE] Function registration error for '"..name.."': `data.func` has invalid Lua syntax: "..tostring(err), 0)
    end
  end

  local ok, fn_or_val = pcall(chunk)
  if not ok then
    error("[RSE] Function registration error for '"..name.."': evaluating `data.func` failed: "..tostring(fn_or_val), 0)
  end
  if type(fn_or_val) ~= "function" then
    error("[RSE] Function registration error for '"..name.."': `data.func` did not evaluate to a function.", 0)
  end

  registry.register_key_selector(name, fn_or_val)
end

---Yes it's... not great. But Factorio serializes table indexes to strings.
---And I don't want that. Moreover, this allows to only keep the minimal info needed.
function registry.make_registry()
    
    local mod_data = prototypes.mod_data

    for _, proto in pairs(mod_data) do
        if proto.data_type == "rse_definition" then

            local rse_definition = {
                name = proto.name,
                original_item_name = proto.data.original_item_name,
                registration_name = proto.data.registration_name or proto.name,
                selector = proto.data.selector,
                possible_results = {},
                key_selector = proto.data.key_selector
            }

            if proto.data.selector == "weighted_choice" or proto.data.selector == "select_one_result_over_n_unweighted" then
                for key, value in pairs(proto.data.possible_results) do
                    if key == "cumulative_weight" then rse_definition.possible_results[key] = value
                    else rse_definition.possible_results[tonumber(key)] = value end
                end
            elseif proto.data.selector == "keyed_random_weighted" or proto.data.selector == "keyed_random_unweighted" then
                for condition, conditional_results in pairs(proto.data.possible_results) do
                    local results_ = {}
                    for key, value in pairs(conditional_results) do
                        if key == "cumulative_weight" then results_[key] = value
                        else results_[tonumber(key)] = value end
                    end
                    
                    rse_definition.possible_results[condition] = results_
                end
            elseif proto.data.selector == "deterministic" then
                rse_definition.possible_results = proto.data.possible_results
            elseif proto.data.selector == "fixed_result" then
                rse_definition.possible_results = proto.data.possible_results
            end
            registry.rse_definitions[proto.name] = rse_definition
        end
    end
end

function registry.compile_functions()
    for _, proto in pairs(prototypes.mod_data) do
        if proto.data_type == "rse_function" then
            compile_function_from_string(proto.name, proto.data.func)
        end
    end
end


return {
    registry = registry,
}