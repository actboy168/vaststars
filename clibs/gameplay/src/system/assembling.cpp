#include <lua.hpp>

#include "luaecs.h"
#include "core/world.h"
#include "core/entity.h"
#include "core/select.h"
extern "C" {
#include "util/prototype.h"
}

#define STATUS_IDLE 0
#define STATUS_DONE 1
#define STATUS_WORKING 2

static void
sync_input_fluidbox(world& w, assembling& a, fluidboxes& fb, recipe_container& container) {
	for (size_t i = 0; i < 4; ++i) {
		uint16_t fluid = fb.in[i].fluid;
		if (fluid != 0) {
			uint8_t index = ((a.fluidbox_in >> (i*4)) & 0xF) - 1;
			uint16_t value = 0;
			if (container.recipe_get(recipe_container::slot_type::in, index, value)) {
				w.fluidflows[fluid].set(fb.in[i].id, value);
			}
		}
	}
}

static void
sync_output_fluidbox(world& w, assembling& a, fluidboxes& fb, recipe_container& container) {
	for (size_t i = 0; i < 3; ++i) {
		uint16_t fluid = fb.out[i].fluid;
		if (fluid != 0) {
			uint8_t index = ((a.fluidbox_out >> (i*4)) & 0xF) - 1;
			uint16_t value = 0;
			if (container.recipe_get(recipe_container::slot_type::out, index, value)) {
				w.fluidflows[fluid].set(fb.out[i].id, value);
			}
		}
	}
}

static void
assembling_update(world& w, ecs::select::entity<assembling, entity, capacitance>& v) {
    assembling& a = v.get<assembling>();
    entity& e = v.get<entity>();
    capacitance& c = v.get<capacitance>();
    prototype_context p = w.prototype(e.prototype);

    // step.1
    unsigned int power = pt_power(&p);
    unsigned int drain = pt_drain(&p);
    unsigned int capacitance = power * 2;
    if (c.shortage + drain > capacitance) {
        return;
    }
    c.shortage += drain;

    if (a.recipe == 0) {
        return;
    }

    // step.2
    while (a.progress <= 0) {
        a.low_power = 0;
        prototype_context recipe = w.prototype(a.recipe);
        recipe_container& container = w.query_container<recipe_container>(a.container);
        if (a.status == STATUS_DONE) {
            recipe_items* r = (recipe_items*)pt_results(&recipe);
            if (!container.recipe_place(w, r)) {
                return;
            }
            w.stat.finish_recipe(w, a.recipe);
            a.status = STATUS_IDLE;
            if (a.fluidbox_out != 0) {
                fluidboxes* fb = w.sibling<fluidboxes>(v);
                if (fb) {
                    sync_output_fluidbox(w, a, *fb, container);
                }
            }
        }
        if (a.status == STATUS_IDLE) {
            recipe_items* r = (recipe_items*)pt_ingredients(&recipe);
            if (!container.recipe_pickup(w, r)) {
                return;
            }
            int time = pt_time(&recipe);
            a.progress += time * 100;
            a.status = STATUS_DONE;
            if (a.fluidbox_in != 0) {
                fluidboxes* fb = w.sibling<fluidboxes>(v);
                if (fb) {
                    sync_input_fluidbox(w, a, *fb, container);
                }
            }
        }
    }

    // step.3
    if (c.shortage + power > capacitance) {
        a.low_power = 50;
        return;
    }
    c.shortage += power;

    // step.4
    a.progress -= a.speed;
    if (a.low_power > 0) a.low_power--;
}

static int
lupdate(lua_State *L) {
    world& w = *(world*)lua_touserdata(L, 1);
    for (auto& v : w.select<assembling, entity, capacitance>()) {
        assembling_update(w, v);
    }
    return 0;
}

extern "C" int
luaopen_vaststars_assembling_system(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "update", lupdate },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
