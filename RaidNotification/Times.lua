zoneIds = {102, 103, 17, 20}
zoneNames = {"Aegis Island Defense", "Whalesong Tower Defense", "Ynystere War", "Cinderstone War"}

gameEvents = {
    ["Grimghast Rift"] = { startHour = 11, startMinute = 00, endMinute = 59, isAM = false },
    ["Crimson Rift"] = { startHour = 11, startMinute = 00, endMinute = 59, isAM = true },
    ["SG.Crimson Rift"] = { startHour = 5, startMinute = 00, endMinute = 59, isAM = false },
    ["Jola,Meina & Glenn"] = { startHour = 5, startMinute = 00, endMinute = 59, isAM = true },
    ["Hiram Rift"] = { startHour = 8, startMinute = 00, endMinute = 59, isAM = false }
}

serverEvents = {
    ["Lusca Awakening"] = {{ times = {{hour = 16, minute = 30}, {hour = 21}}, days = {1, 2, 3, 4, 5, 6, 7} }},
    ["Black Dragon"] = {
        { times = {{hour = 9}}, days = {1} },
        { times = {{hour = 20}}, days = {3} },
        { times = {{hour = 17}}, days = {7} }
    },
    ["Kraken"] = {
        { times = {{hour = 10, minute = 30}}, days = {1} },
        { times = {{hour = 18, minute = 30}}, days = {3, 7} }
    },
    ["Leviathan"] = {{ times = {{hour = 20, minute = 05}}, days = {2, 4, 6} }},
    ["Charybdis"] = {{ times = {{hour = 21, minute = 30}}, days = {1, 5} }},
    ["Anthalon (Garden)"] = {
        { times = {{hour = 13}}, days = {1} },
        { times = {{hour = 21}}, days = {4, 7} }
    },
    ["Golden Plains Battle"] = {
        { times = {{hour = 8}}, days = {1, 2, 3, 4, 5, 6, 7} },
        { times = {{hour = 12, minute = 30}, {hour = 22, minute = 30}}, days = {1, 7} },
        { times = {{hour = 14}, {hour = 22}}, days = {2, 3, 4, 5, 6} }
    },
    ["Red Dragon's Keep"] = {{ times = {{hour = 7, minute = 30}, {hour = 11}, {hour = 20}}, days = {1, 2, 4, 6} }},
    ["Abyssal Attack"] = {{ times = {{hour = 15, minute = 59}, {hour = 20, minute = 29}}, days = {3, 5, 7}}},
    ["Hasla Zombie Apocalypse"] = {{ times = {{hour = 13}, {hour = 19}, {hour = 20}}, days = {1, 2, 3, 4, 5, 6, 7} }},
    ["Akasch Invasion"] = {{ times = {{hour = 21, minute = 30}, {hour = 16, minute = 30}, {hour = 8, minute = 30}}, days = {7, 2} }},
    ["Guardian Scramble"] = {{ times = {{hour = 9}, {hour = 21}}, days = {1, 3} }},
    ["SjinderSon Dragon"] = {{ times = {{hour = 14}}, days = {7} }},
    ["Maintenance"] = {{ times = {{hour = 7}}, days = {3}}},
    --["Titan's Rift"] = {{ times = {{hour = 01}, {hour = 04}, {hour = 07}, {hour = 10}, {hour = 13}, {hour = 16}, {hour = 19}, {hour = 22}}, days = {3, 6}}},
    --["Titan's Boss"] = {{ times = {{hour = 14}, {hour = 22}}, days = {7, 4}}},
}