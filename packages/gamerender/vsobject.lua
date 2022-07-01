local ecs = ...
local world = ecs.world
local w = world.w

local math3d = require "math3d"
local mathpkg = import_package"ant.math"
local mc = mathpkg.constant
local igame_object = ecs.import.interface "vaststars.gamerender|igame_object"
local iom = ecs.import.interface "ant.objcontroller|iobj_motion"
local ientity = ecs.import.interface "ant.render|ientity"
local imaterial	= ecs.import.interface "ant.asset|imaterial"
local ientity_object = ecs.import.interface "vaststars.gamerender|ientity_object"
local imesh = ecs.import.interface "ant.asset|imesh"
local ifs = ecs.import.interface "ant.scene|ifilter_state"
local irq = ecs.import.interface "ant.render|irenderqueue"
local iprototype = require "gameplay.interface.prototype"
local imodifier = ecs.import.interface "ant.modifier|imodifier"
local terrain = ecs.require "terrain"

local plane_vb <const> = {
	-0.5, 0, 0.5, 0, 1, 0,	--left top
	0.5,  0, 0.5, 0, 1, 0,	--right top
	-0.5, 0,-0.5, 0, 1, 0,	--left bottom
	-0.5, 0,-0.5, 0, 1, 0,
	0.5,  0, 0.5, 0, 1, 0,
	0.5,  0,-0.5, 0, 1, 0,	--right bottom
}

local rotators <const> = {
    N = math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(0)}),
    E = math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(90)}),
    S = math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(180)}),
    W = math3d.ref(math3d.quaternion{axis=mc.YAXIS, r=math.rad(270)}),
}

local CONSTRUCT_COLOR_INVALID <const> = {}
local CONSTRUCT_COLOR_RED <const> = math3d.constant("v4", {2.5, 0.0, 0.0, 0.55})
local CONSTRUCT_COLOR_GREEN <const> = math3d.constant("v4", {0.0, 2.5, 0.0, 0.55})
local CONSTRUCT_COLOR_WHITE <const> = math3d.constant("v4", {1.5, 2.5, 1.5, 0.55})
local CONSTRUCT_COLOR_YELLOW <const> = math3d.constant("v4", {2.5, 2.5, 0.0, 0.55})

local CONSTRUCT_BLOCK_COLOR_INVALID <const> = {}
local CONSTRUCT_BLOCK_COLOR_RED <const> = math3d.constant("v4", {1, 0.0, 0.0, 1.0})
local CONSTRUCT_BLOCK_COLOR_GREEN <const> = math3d.constant("v4", {0.0, 1, 0.0, 1.0})
local CONSTRUCT_BLOCK_COLOR_WHITE <const> = math3d.constant("v4", {1, 1, 1, 1.0})

local FLUIDFLOW_BLUE <const> = math3d.constant("v4", {0.0, 0.0, 2.5, 0.55})
local FLUIDFLOW_CHARTREUSE <const> = math3d.constant("v4", {1.2, 2.5, 0.0, 0.55})
local FLUIDFLOW_CHOCOLATE <const> = math3d.constant("v4", {2.1, 2.0, 0.3, 0.55})
local FLUIDFLOW_DARKVIOLET <const> = math3d.constant("v4", {1.4, 0.0, 2.1, 0.55})

local typeinfos = {
    ["indicator"] = {state = "translucent", color = CONSTRUCT_COLOR_WHITE, block_color = CONSTRUCT_BLOCK_COLOR_INVALID, block_edge_size = 0}, -- 已确认
    ["construct"] = {state = "opaque", color = CONSTRUCT_COLOR_INVALID, block_color = CONSTRUCT_BLOCK_COLOR_GREEN, block_edge_size = 4}, -- 未确认, 合法
    ["invalid_construct"] = {state = "opaque", color = CONSTRUCT_COLOR_INVALID, block_color = CONSTRUCT_BLOCK_COLOR_RED, block_edge_size = 4}, -- 未确认, 非法
    ["confirm"] = {state = "translucent", color = CONSTRUCT_COLOR_WHITE, block_color = CONSTRUCT_BLOCK_COLOR_INVALID, block_edge_size = 0}, -- 已确认
    ["constructed"] = {state = "opaque", color = CONSTRUCT_COLOR_INVALID, block_color = CONSTRUCT_BLOCK_COLOR_INVALID, block_edge_size = 0}, -- 已施工
    ["teardown"] = {state = "translucent", color = CONSTRUCT_COLOR_YELLOW, block_color = CONSTRUCT_BLOCK_COLOR_INVALID, block_edge_size = 0}, -- 拆除

    ["fluidflow_blue"] = {state = "translucent", color = FLUIDFLOW_BLUE, block_color = CONSTRUCT_BLOCK_COLOR_INVALID, block_edge_size = 0},
    ["fluidflow_chartreuse"] = {state = "translucent", color = FLUIDFLOW_CHARTREUSE, block_color = CONSTRUCT_BLOCK_COLOR_INVALID, block_edge_size = 0},
    ["fluidflow_chocolate"] = {state = "translucent", color = FLUIDFLOW_CHOCOLATE, block_color = CONSTRUCT_BLOCK_COLOR_INVALID, block_edge_size = 0},
    ["fluidflow_darkviolet"] = {state = "translucent", color = FLUIDFLOW_DARKVIOLET, block_color = CONSTRUCT_BLOCK_COLOR_INVALID, block_edge_size = 0},
}

local gen_id do
    local id = 0
    function gen_id()
        id = id + 1
        return id
    end
end

local entity_events = {}
entity_events.set_material_property = function(_, e, ...)
    imaterial.set_property(world:entity(e.id), ...)
end
entity_events.set_position = function(_, e, ...)
    iom.set_position(e, ...)
end
entity_events.set_rotation = function(_, e, ...)
    iom.set_rotation(e, ...)
end
entity_events.update_render_object = function(_, e, ...)
    irq.update_render_object(e, true)
end

local function create_block(color, block_edge_size, area, position, rotation)
    if color == CONSTRUCT_BLOCK_COLOR_INVALID then
        return
    end
    local width, height = iprototype.unpackarea(area)
    local eid = ecs.create_entity{
		policy = {
			"ant.render|simplerender",
			"ant.general|name",
		},
		data = {
			scene 		= { r = rotation, s = {terrain.tile_size * width + block_edge_size, 1, terrain.tile_size * height + block_edge_size}, t = position},
			material 	= "/pkg/vaststars.resources/materials/singlecolor.material",
			filter_state= "main_view",
			name 		= ("plane_%d"):format(gen_id()),
			simplemesh 	= imesh.init_mesh(ientity.create_mesh({"p3|n3", plane_vb}, nil, math3d.ref(math3d.aabb({-0.5, 0, -0.5}, {0.5, 0, 0.5}))), true),
			on_ready = function (e)
				w:sync("render_object:in", e)
				ifs.set_state(e, "main_view", true)
				imaterial.set_property(e, "u_color", color)
				w:sync("render_object_update:out", e)
			end
		},
	}

    return ientity_object.create(eid, entity_events)
end

local function set_srt(e, srt)
    if not srt then
        return
    end
    iom.set_scale(e, srt.s)
    iom.set_rotation(e, srt.r)
    iom.set_position(e, srt.t)
end

local function get_rotation(self)
    return math3d.ref(iom.get_rotation(world:entity(self.game_object.root)))
end

local function set_position(self, position)
    iom.set_position(world:entity(self.game_object.root), position)
    if self.block_object then
        local block_pos = math3d.ref(math3d.add(position, {0, terrain.surface_height, 0}))
        self.block_object:send("set_position", block_pos)
    end
end

local function get_position(self)
    return iom.get_position(world:entity(self.game_object.root))
end

local function set_dir(self, dir)
    iom.set_rotation(world:entity(self.game_object.root), rotators[dir])
    if self.block_object then
        self.block_object:send("set_rotation", rotators[dir])
    end
end

local function remove(self)
    if self.game_object then
        self.game_object:remove()
    end

    if self.block_object then
        self.block_object:remove()
    end
end

--TODO bad taste
local function update(self, t)
    local old_typeinfo = typeinfos[self.type]
    local new_typeinfo = typeinfos[t.type or self.type]

    if t.prototype_name or new_typeinfo.state ~= old_typeinfo.state then
        local srt
        local old_game_object = self.game_object
        if old_game_object then
            srt = world:entity(old_game_object.root).scene
            old_game_object:remove()
        end

        local prototype_name = t.prototype_name or self.prototype_name
        local state = new_typeinfo.state
        local color = new_typeinfo.color

        local typeobject = iprototype.queryByName("entity", prototype_name)
        local game_object = igame_object.create(typeobject.model, self.group_id, state, color, self.id)
        set_srt(world:entity(game_object.root), srt)
        self.srt_modifier = imodifier.create_bone_modifier(game_object.game_object.root, self.group_id, "/pkg/vaststars.resources/glb/animation/Interact_build.glb|animation.prefab", "Bone") -- TODO

        self.game_object, self.prototype_name = game_object, prototype_name
    else
        local game_object = self.game_object
        if new_typeinfo.state == "translucent" and new_typeinfo.color and not math3d.isequal(old_typeinfo.color, new_typeinfo.color) then
            game_object:send("set_material_property", "u_basecolor_factor", new_typeinfo.color)
        end
    end

    if self.block_object then
        self.block_object:remove()
        self.block_object = nil
    end

    if new_typeinfo.block_color then
        local typeobject = iprototype.queryByName("entity", self.prototype_name)
        local block_pos = math3d.ref(math3d.add(self:get_position(), {0, terrain.surface_height, 0}))
        local rotation = get_rotation(self)
        self.block_object = create_block(new_typeinfo.block_color, new_typeinfo.block_edge_size, typeobject.area, block_pos, rotation)
    end

    self.type = t.type or self.type
end

local function send(self, ...)
    self.game_object:send(...)
end

local function attach(self, ...)
    self.game_object:attach(...)
end

local function detach(self, ...)
    self.game_object:detach(...)
end

local function animation_update(self, ...)
    self.game_object:animation_update(...)
end

-- init = {
--     prototype_name = prototype_name,
--     type = xxx,
--     position = position,
--     dir = 'N',
-- }
return function (init)
    local typeobject = iprototype.queryByName("entity", init.prototype_name)
    local typeinfo = assert(typeinfos[init.type], ("invalid type `%s`"):format(init.type))

    local game_object = assert(igame_object.create(typeobject.model, init.group_id, typeinfo.state, typeinfo.color, init.id))
    iom.set_position(world:entity(game_object.root), init.position)
    iom.set_rotation(world:entity(game_object.root), rotators[init.dir])

    local block_pos = math3d.ref(math3d.add(init.position, {0, terrain.surface_height, 0}))
    local block_object = create_block(typeinfo.block_color, typeinfo.block_edge_size, typeobject.area, block_pos, rotators[init.dir])

    local vsobject = {
        id = init.id,
        prototype_name = init.prototype_name,
        type = init.type,
        group_id = init.group_id,

        game_object = game_object,
        block_object = block_object,
        srt_modifier = imodifier.create_bone_modifier(game_object.game_object.root, init.group_id, "/pkg/vaststars.resources/glb/animation/Interact_build.glb|animation.prefab", "Bone"), -- TODO

        --
        update = update,
        set_position = set_position,
        get_position = get_position,
        set_dir = set_dir,
        remove = remove,
        attach = attach,
        detach = detach,
        send   = send,
        animation_update = animation_update,
    }
    return vsobject
end
