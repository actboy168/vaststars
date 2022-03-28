local ecs = ...
local world = ecs.world
local w = world.w

local igame_object = ecs.import.interface "vaststars.gamerender|igame_object"
local construct_sys = ecs.system "construct_system"
local prototype = ecs.require "prototype"
local gameplay = ecs.require "gameplay"
local engine = ecs.require "engine"
local irq = ecs.import.interface "ant.render|irenderqueue"
local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
local math3d = require "math3d"
local terrain = ecs.require "terrain"
local fluidbox = ecs.require "fluidbox"
local dir = require "dir"
local dir_rotate = dir.rotate

local ui_construct_begin_mb = world:sub {"ui", "construct", "construct_begin"}       -- 建造模式
local ui_construct_entity_mb = world:sub {"ui", "construct", "construct_entity"}
local ui_construct_rotate_mb = world:sub {"ui", "construct", "rotate"}
local ui_construct_confirm_mb = world:sub {"ui", "construct", "construct_confirm"}
local ui_construct_complete_mb = world:sub {"ui", "construct", "construct_complete"} -- 开始施工
local ui_fluidbox_update_mb = world:sub {"ui", "construct", "fluidbox_update"}
local pickup_mapping_mb = world:sub {"pickup_mapping"}
local gesture_mb = world:sub {"gesture"}
local gesture_end_mb = world:sub {"gesture", "end"}

local CONSTRUCT_RED_BASIC_COLOR <const> = {50.0, 0.0, 0.0, 0.8}
local CONSTRUCT_GREEN_BASIC_COLOR <const> = {0.0, 50.0, 0.0, 0.8}
local CONSTRUCT_WHITE_BASIC_COLOR <const> = {50.0, 50.0, 50.0, 0.8}
local DISMANTLE_YELLOW_BASIC_COLOR <const> = {50.0, 50.0, 0.0, 0.8}

local cur_mode = ""

local function get_data_object(game_object)
    if game_object.construct_pickup then
        return game_object.gameplay_entity
    end

    return setmetatable(game_object.gameplay_entity, {
        __index = gameplay.entity(game_object.game_object.x, game_object.game_object.y) or {}
    })
end

local function check_construct_detector(prototype_name, x, y, dir)
    local game_object = igame_object.get_game_object(x, y)
    if not game_object then
        return true
    end
    return (game_object.construct_pickup == true)
end

local function update_game_object_color(game_object)
    local data_object = get_data_object(game_object)
    local color
    local construct_detector = prototype.get_construct_detector(data_object.prototype_name)
    if construct_detector then
        if not check_construct_detector(data_object.prototype_name, data_object.x, data_object.y, data_object.dir) then
            color = CONSTRUCT_RED_BASIC_COLOR
        else
            color = CONSTRUCT_GREEN_BASIC_COLOR
        end
    end
    igame_object.update(game_object.id, {color = color})
end

local function new_construct_object(prototype_name)
    local typeobject = prototype.query_by_name("entity", prototype_name)
    local ce = world:entity(irq.main_camera())
    local plane = math3d.vector(0, 1, 0, 0)
    local ray = {o = iom.get_position(ce), d = math3d.mul(math.maxinteger, iom.get_direction(ce))}
    local origin = math3d.tovalue(math3d.muladd(ray.d, math3d.plane_ray(ray.o, ray.d, plane), ray.o))
    local coord = terrain.adjust_position(origin, typeobject.area)

    local color
    local construct_detector = prototype.get_construct_detector(prototype_name)
    if construct_detector then
        if not check_construct_detector(prototype_name, coord[1], coord[2], 'N') then
            color = CONSTRUCT_RED_BASIC_COLOR
        else
            color = CONSTRUCT_GREEN_BASIC_COLOR
        end
    end
    igame_object.create(prototype_name, coord[1], coord[2], 'N', "translucent", color, true)
    if prototype.is_fluidbox(prototype_name) then
        world:pub {"ui_message", "show_set_fluidbox", true}
    end
end

local function clear_construct_pickup_object()
    local game_object = engine.world_singleton("construct_pickup", "construct_pickup")
    if game_object then
        igame_object.remove(game_object.id)
    end
end

local camera_move_speed <const> = 1.8
local delta = {
    ["left"]  = {-camera_move_speed, 0, 0},
    ["right"] = {camera_move_speed, 0, 0},
    ["down"]  = {0, 0, -camera_move_speed},
    ["up"]    = {0, 0, camera_move_speed},
}

function construct_sys:data_changed()
    for _, state in gesture_mb:unpack() do
        local d = delta[state]
        if d then
            local mq = w:singleton("main_queue", "camera_ref:in render_target:in")
            local ce = world:entity(mq.camera_ref)
            local game_object = engine.world_singleton("construct_pickup", "construct_pickup")
            iom.move_delta(ce, d)
            if game_object then
                igame_object.move_delta(game_object.id, d)
            end
        end
    end

    for _ in gesture_end_mb:unpack() do
        local game_object = engine.world_singleton("construct_pickup", "construct_pickup")
        if game_object then
            local pt = prototype.query_by_name("entity", game_object.gameplay_entity.prototype_name)
            local position = igame_object.get_position(game_object.id)
            local coord, position = terrain.adjust_position(position, pt.area)
            igame_object.set_position(game_object.id, position)
            game_object.gameplay_entity.x, game_object.gameplay_entity.y = coord[1], coord[2]
            game_object.game_object.x, game_object.game_object.y = coord[1], coord[2]
            update_game_object_color(game_object)
        end
    end

    for _, _, _, prototype_name in ui_construct_entity_mb:unpack() do
        clear_construct_pickup_object()
        new_construct_object(prototype_name)
    end

    for _ in ui_construct_rotate_mb:unpack() do
        local game_object = engine.world_singleton("construct_pickup", "construct_pickup")
        if game_object then
            game_object.gameplay_entity.dir = dir_rotate(game_object.gameplay_entity.dir, -1) -- 逆时针方向旋转一次
            igame_object.set_dir(game_object.id, game_object.gameplay_entity.dir)
        end
    end

    for _ in ui_construct_confirm_mb:unpack() do
        local game_object = engine.world_singleton("construct_pickup", "construct_pickup")
        if game_object then
            local gameplay_entity = game_object.gameplay_entity
            local construct_detector = prototype.get_construct_detector(gameplay_entity.prototype_name)
            if construct_detector then
                if not check_construct_detector(gameplay_entity.prototype_name, gameplay_entity.x, gameplay_entity.y, gameplay_entity.dir) then
                    print("can not construct") -- todo error tips
                else
                    igame_object.update(game_object.id, {state = "translucent", color = CONSTRUCT_WHITE_BASIC_COLOR})
                    game_object.construct_pickup = false

                    print("construct_confirm", gameplay_entity.x, gameplay_entity.y, gameplay_entity.prototype_name)
                    fluidbox:set(game_object.id, gameplay_entity.x, gameplay_entity.y, gameplay_entity.prototype_name)
                end
            end
            new_construct_object(gameplay_entity.prototype_name)
        end
    end

    for _ in ui_construct_begin_mb:unpack() do
        cur_mode = "construct"
        gameplay.world_update = false
        engine.set_camera_prefab("camera_construct.prefab")
    end

    for _ in ui_construct_complete_mb:unpack() do
        clear_construct_pickup_object()
        cur_mode = ""
        gameplay.world_update = true
        engine.set_camera_prefab("camera_default.prefab")
        world:pub {"ui_message", "show_set_fluidbox", false}

        for _, game_object in engine.world_select "construct_modify" do
            local entity = gameplay.entity(game_object.game_object.x, game_object.game_object.y)
            if not entity then
                gameplay.create_entity(game_object.gameplay_entity)
                igame_object.update(game_object.id, {state = "opaque"})
            else
                for k, v in pairs(game_object.gameplay_entity) do
                    entity[k] = v
                end
                igame_object.update(game_object.id, {state = "opaque"})
                game_object.game_object.x, game_object.game_object.y = entity.x, entity.y
            end
            game_object.gameplay_entity = {}
            game_object.construct_modify = false
        end

        gameplay.build()
    end

    for _, _, _, fluidname in ui_fluidbox_update_mb:unpack() do
        local game_object = engine.world_singleton("construct_pickup", "construct_pickup")
        if game_object then
            game_object.gameplay_entity.fluid = {fluidname, 0}
        end
    end

    for _, param, eid in pickup_mapping_mb:unpack() do
        if cur_mode == "construct" then

        end
    end
end
