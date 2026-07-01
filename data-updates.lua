for _, machine in pairs(data.raw["assembling-machine"]) do
    machine.trash_inventory_size = 5
end

for _, lab in pairs(data.raw["lab"]) do
    lab.trash_inventory_size = 5
end
