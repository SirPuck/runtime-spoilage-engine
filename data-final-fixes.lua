local rse = require("data-registry")

if data.raw["mod-data"] then
    for _, content in pairs(data.raw["mod-data"]) do
        if content and content.data_type == "rse_function" then
            rse.register_key_selector_prototype(content)
        end
    end
    for _, content in pairs(data.raw["mod-data"]) do
        if content and content.data_type == "rse_registration" then
            rse.make_rse_definition(content)
        end
    end
end