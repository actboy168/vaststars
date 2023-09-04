local entities = { {
  dir = "N",
  items = {},
  prototype_name = "指挥中心",
  x = 124,
  y = 120
}, {
  dir = "N",
  items = {},
  prototype_name = "铁制电线杆",
  x = 118,
  y = 136
}, {
  dir = "N",
  items = { { "无人机平台I", 8 } , { "采矿机I", 4 }, { "仓库I", 6 },{ "铁制电线杆", 15 } },
  prototype_name = "机身残骸",
  x = 107,
  y = 134
},{
  dir = "E",
  items = { { "水电站I", 1 }, { "化工厂I", 2 },{ "空气过滤器I", 2 },{ "空气过滤器框架", 2} },
  prototype_name = "机尾残骸",
  x = 118,
  y = 114
}, {
  dir = "S",
  items = { { "组装机I", 8 }, { "停车站", 6 }, { "熔炼炉I", 2 }, { "科研中心I", 2 }},
  prototype_name = "机尾残骸",
  x = 110,
  y = 120
}, {
  dir = "S",
  items = { { "锅炉I", 4 }, { "蓄电池I", 10 }, { "太阳能板框架", 6},{ "电解厂I", 1 } },
  prototype_name = "机翼残骸",
  x = 105,
  y = 111
}, {
  dir = "W",
  items = { { "风力发电机I", 1 }, { "运输车辆I", 10 }, { "地下水挖掘机I", 1 },{ "太阳能板I", 2 }},
  prototype_name = "机翼残骸",
  x = 133,
  y = 122
}, {
  dir = "E",
  items = { { "地下水挖掘机框架", 3}, { "破损运输车辆", 16},{ "无人机平台框架", 6 },{ "电线杆框架", 15 }},
  prototype_name = "机头残骸",
  x = 125,
  y = 108
}, {
  dir = "N",
  items = {  { "化工厂框架", 2},{ "水电站框架", 1},  { "蒸馏厂框架", 2 },{ "组装机框架", 6 }},
  prototype_name = "机头残骸",
  x = 136,
  y = 105
},
-- {
--   dir = "N",
--   prototype_name = "采矿机I",
--   recipe = "碎石挖掘",
--   x = 115,
--   y = 133
-- },
{
  dir = "N",
  prototype_name = "风力发电机I",
  x = 117,
  y = 121
}}
local road = {}

local mineral = {
  --9个碎石矿
  ["115,133"] = "碎石",
  ["144,86"] = "碎石",
  ["150,112"] = "碎石",
  ["192,132"] = "碎石",
  ["72,132"] = "碎石",
  ["93,102"] = "碎石",
  ["108,31"] = "碎石",
  ["62,167"] = "碎石",
  ["72,74"] = "碎石",
  ------------------------
  --19个铁矿
  ["75,93"] = "铁矿石",
  ["91,165"] = "铁矿石",
  ["138,174"] = "铁矿石",
  ["150,95"] = "铁矿石",
  ["138,140"] = "铁矿石",
  ["173,76"] = "铁矿石",
  ["180,193"] = "铁矿石",
  ["197,117"] = "铁矿石",
  ["209,162"] = "铁矿石",
  ["61,118"] = "铁矿石",
  ["62,185"] = "铁矿石",
  ["114,81"] = "铁矿石",
  ["58,19"] = "铁矿石",
  ["31,167"] = "铁矿石",
  ["42,205"] = "铁矿石",
  ["182,234"] = "铁矿石",
  ["226,241"] = "铁矿石",
  ["28,139"] = "铁矿石",
  ["66,147"] = "铁矿石",
  ------------------------
  --8个铝矿
  ["102,62"] = "铝矿石",
  ["166,159"] = "铝矿石",
  ["151,33"] = "铝矿石",
  ["103,190"] = "铝矿石",
  ["175,208"] = "铝矿石",
  ["216,189"] = "铝矿石",
  ["33,30"] = "铝矿石",
  ["145,149"] = "铝矿石",
  -----------------------
  --6个地热
  ["210,142"] = "地热气",
  ["93,203"] = "地热气",
  ["46,153"] = "地热气",
  ["129,70"] = "地热气",
  ["220,77"] = "地热气",
  ["229,223"] = "地热气",
}

return {
  name = "纯净模式",
  entities = entities,
  road = road,
  mineral = mineral,
}
