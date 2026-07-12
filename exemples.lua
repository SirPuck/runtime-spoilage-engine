local by_key = {
    type = "mod-data",
    name = "john",
    data_type = "rse_registration",
    data = {
        original_item_type = "item",
        original_item_name = "copper-ore",
        placeholder_spoil_into_self = true,
        key_selector = "quality",
        results = {
            ["normal"] = {
                name = "iron-plate",
                quality = "rare"
            },
            ["rare"] = {
                name = "copper-plate",
                quality = "normal"
            }
        }
    }
}

local key_and_random = {
    type = "mod-data",
    name = "john",
    data_type = "rse_registration",
    data = {
        original_item_type = "item",
        original_item_name = "copper-ore",
        placeholder_spoil_into_self = true,
        key_selector = "quality",
        results = {
            ["normal"] = {
                {
                    name = "iron-plate",
                    quality = "rare",
                    weight = 1
                },
                {
                    name = "iron-plate",
                    quality = "epic",
                    weight = 2
                }
            },
            ["rare"] = {
                {
                    name = "copper-plate",
                    quality = "normal",
                    weight = 1
                }
            }
        }
    }
}

local random = {
    type = "mod-data",
    name = "john",
    data_type = "rse_registration",
    data = {
        original_item_type = "item",
        original_item_name = "copper-ore",
        placeholder_spoil_into_self = true,
        results = {
            {
                name = "iron-plate",
                quality = "rare",
                weight = 1
            },
            {
                name = "copper-plate",
                quality = "normal",
                weight = 2
            }
        }
    }
}

data.raw["item"]["iron-plate"].spoil_ticks = 120

local random_ex = {
    type = "mod-data",
    name = "john",
    data_type = "rse_registration",
    data = {
        original_item_type = "item",
        original_item_name = "iron-plate",
        placeholder_spoil_into_self = true,
        results = {
            {
                name = "iron-plate",
                weight = 1
            },
            {
                name = "iron-plate",
                weight = 2
            }
        }
    }
}

data:extend{random_ex}