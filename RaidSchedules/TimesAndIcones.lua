eventIcons = {
    
    ["Background"] = "addon/Raidschedules/images/bg/Background.dds",
    ["TDLBackground"] = "addon/Raidschedules/images/bg/TDListBG.dds",
    ["Reset"] = "addon/Raidschedules/images/reset.dds",
    ["G.R"] = "addon/Raidschedules/images/game_events/GR.dds",
    ["C.R"] = "addon/Raidschedules/images/game_events/CR.dds",
    ["S.G C.R"] = "addon/Raidschedules/images/game_events/CR.dds",
    ["J.MG"] = "addon/Raidschedules/images/game_events/JMG.dds",
    ["Hiram Rift"] = "addon/Raidschedules/images/game_events/CR.dds",

    ["Maintenance"] = "addon/Raidschedules/images/server_events/Maintenance.dds",
    ["Red Dragon"] = "addon/Raidschedules/images/server_events/RedDragon.dds",
    ["Lusca"] = "addon/Raidschedules/images/server_events/Lusca.dds", 
    ["Black Dragon"] = "addon/Raidschedules/images/server_events/BlackDragon.dds",
    ["SjinderSon"] = "addon/Raidschedules/images/server_events/SjinderSon.dds",
    ["Kraken"] = "addon/Raidschedules/images/server_events/kraken.dds",
    ["Leviathan"] = "addon/Raidschedules/images/server_events/leviathan.dds",
    ["Charybdis"] = "addon/Raidschedules/images/server_events/Charybdis.dds",
    ["Anthalon"] = "addon/Raidschedules/images/server_events/Anthalon.dds",
    ["Halcy"] = "addon/Raidschedules/images/server_events/Halcy.dds",
    ["Event Dragon"] = "addon/Raidschedules/images/server_events/Eventdragon.dds",
    ["Abyssal"] = "addon/Raidschedules/images/server_events/Abyssal.dds",
    ["Hasla"] = "addon/Raidschedules/images/server_events/Hasla.dds",
    ["Akasch"] = "addon/Raidschedules/images/server_events/Akasch.dds",
    ["Scramble"] = "addon/Raidschedules/images/server_events/Scramble.dds",
    --["Titan's Rift"] = "addon/Raidschedules/images/server_events/TitanFarm.dds",
    --["Titan's Boss"] = "addon/Raidschedules/images/server_events/TitanBoss.dds",
    
    ["Cinderstone"] = "addon/Raidschedules/images/zone_events/war_correct.dds",
    ["Ynystere"] = "addon/Raidschedules/images/zone_events/war_correct.dds",
    ["Garden"] = "addon/Raidschedules/images/zone_events/Garden.dds",
    ["Aegis"] = "addon/Raidschedules/images/zone_events/event.dds",
    ["Whalesong"] = "addon/Raidschedules/images/zone_events/event.dds"
    
}

zoneIds = {102, 103, 17, 20, 133}

gameEvents = {
    ["G.R"] = { startHour = 00, Minute = 00, isAM = true },
    ["C.R"] = { startHour = 00, Minute = 00, isAM = false },
    ["S.G C.R"] = { startHour = 6, Minute = 00, isAM = false },
    ["J.MG"] = { startHour = 6, Minute = 00, isAM = true },
    ["Hiram Rift"] = { startHour = 9, Minute = 00, isAM = false }
}

serverEvents = {
    ["Lusca"] = {{ times = {{hour = 16, Minute = 30, Duration = 60}, {hour = 21, Minute = 00, Duration = 60}}, days = {1, 2, 3, 4, 5, 6, 7}}},
    ["Black Dragon"] = {
        { times = {{hour = 9, Duration = 60}}, days = {1}},
        { times = {{hour = 20, Duration = 60}}, days = {3}},
        { times = {{hour = 17, Duration = 60}}, days = {7}}
    },
    ["Kraken"] = {
        { times = {{hour = 10, Minute = 30, Duration = 60}}, days = {1}},
        { times = {{hour = 18, Minute = 30, Duration = 60}}, days = {3, 7}}
    },
    ["Leviathan"] = {{ times = {{hour = 20, Minute = 05, Duration = 120}}, days = {2, 4, 6}}},
    ["Charybdis"] = {{ times = {{hour = 21, Minute = 30, Duration = 60}}, days = {1, 5}}},
    ["Anthalon"] = {
        { times = {{hour = 13, Duration = 60}}, days = {1}},
        { times = {{hour = 21, Duration = 60}}, days = {4, 7}}
    },
    ["Halcy"] = {
        { times = {{hour = 8, Duration = 30}}, days = {1, 2, 3, 4, 5, 6, 7}},
        { times = {{hour = 12, Minute = 30, Duration = 60}, {hour = 22, Minute = 30, Duration = 60}}, days = {1, 7}},
        { times = {{hour = 14, Duration = 60}, {hour = 22, Duration = 60}}, days = {2, 3, 4, 5, 6}}
    },
    ["Red Dragon"] = {{ times = {{hour = 7, Minute = 30, Duration = 60}, {hour = 11, Duration = 60}, {hour = 20, Duration = 60}}, days = {1, 2, 4, 6}}},
    ["Abyssal"] = {{ times = {{hour = 15, Minute = 59, Duration = 60}, {hour = 20, Minute = 29, Duration = 60}}, days = {3, 5, 7}}},
    ["Hasla"] = {{ times = {{hour = 13, Duration = 30}, {hour = 19, Duration = 30}, {hour = 20, Duration = 30}}, days = {1, 2, 3, 4, 5, 6, 7}}},
    ["Akasch"] = {{ times = {{hour = 8, Minute = 30, Duration = 41}, {hour = 16, Minute = 30, Duration = 41}, {hour = 21, Minute = 30, Duration = 41}}, days = {7, 2}}},
    ["Scramble"] = {{ times = {{hour = 9, Duration = 60}, {hour = 21, Duration = 60}}, days = {1, 3}}},
    ["SjinderSon"] = {{ times = {{hour = 14, Duration = 30}}, days = {7}}},
    ["Maintenance"] = {{ times = {{hour = 7, Duration = 40}}, days = {3}}},
    --["Titan's Rift"] = {{ times = {{hour = 01, Duration = 30}, {hour = 04, Duration = 30}, {hour = 07, Duration = 30}, {hour = 10, Duration = 30}, {hour = 13, Duration = 30}, {hour = 16, Duration = 30}, {hour = 19, Duration = 30}, {hour = 22, Duration = 30}}, days = {3, 6}}},
    --["Titan's Boss"] = {{ times = {{hour = 14, Duration = 30}, {hour = 22, Duration = 30}}, days = {7, 4}}},
}