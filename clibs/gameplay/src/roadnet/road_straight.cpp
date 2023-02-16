#include "roadnet/road_straight.h"
#include "roadnet/network.h"

namespace roadnet::road {
    void straight::init(uint16_t id, uint16_t len, direction dir) {
        this->id = id;
        this->len = len;
        this->dir = dir;
    }
    bool straight::canEntry(network& w, lorryid l, uint16_t offset)  {
        if (endpointid& e = w.EndpointInRoad(lorryOffset+offset)) {
            endpoint& ep = w.Endpoint(e);
            auto& lorry = w.Lorry(l);
            bool arrive = lorry.ending.id == id && lorry.ending.offset == offset;
            return ep.canEntry(arrive? straight_type::endpoint_in: straight_type::straight);
        }
        return !hasLorry(w, offset);
    }
    bool straight::canEntry(network& w, lorryid l)  {
        return canEntry(w, l, len-1);
    }
    bool straight::tryEntry(network& w, lorryid l, uint16_t offset) {
        if (endpointid& e = w.EndpointInRoad(lorryOffset+offset)) {
            endpoint& ep = w.Endpoint(e);
            auto& lorry = w.Lorry(l);
            bool arrive = lorry.ending.id == id && lorry.ending.offset == offset;
            return ep.tryEntry(w, l, arrive? straight_type::endpoint_in: straight_type::straight);
        }
        if (!hasLorry(w, offset)) {
            addLorry(w, l, offset);
            return true;
        }
        return false;
    }
    bool straight::tryEntry(network& w, lorryid l)  {
        return tryEntry(w, l, len-1);
    }
    void straight::setNeighbor(roadid id) {
        assert(neighbor == roadid::invalid());
        neighbor = id;
    }
    void straight::setEndpoint(network& w, uint16_t offset, endpointid id) {
        w.EndpointInRoad(lorryOffset + offset) = id;
    }
    void straight::addLorry(network& w, lorryid l, uint16_t offset) {
        w.LorryInRoad(lorryOffset + offset) = l;
        w.Lorry(l).initTick(kTime);
    }
    bool straight::hasLorry(network& w, uint16_t offset) {
        return !!w.LorryInRoad(lorryOffset + offset);
    }
    void straight::delLorry(network& w, uint16_t offset) {
        w.LorryInRoad(lorryOffset + offset) = lorryid::invalid();
    }
    void straight::update(network& w, uint64_t ti) {
        // The last offset of straight(0) is the waiting area of crossroad, driven by crossroad.
        // see also: crossroad::waitingLorry()
        for (uint16_t i = 1; i < len; ++i) {
            if (endpointid& e = w.EndpointInRoad(lorryOffset+i)) {
                endpoint& ep = w.Endpoint(e);
                ep.updateStraight(w, [&](lorryid l){ return tryEntry(w, l, i-1); });
            }
            else if (lorryid l = w.LorryInRoad(lorryOffset+i)) {
                if (tryEntry(w, l, i-1)) {
                    delLorry(w, i);
                }
            }
        }
    }
    lorryid& straight::waitingLorry(network& w) {
        if (endpointid& e = w.EndpointInRoad(lorryOffset)) {
            endpoint& ep = w.Endpoint(e);
            return ep.getOutOrStraight();
        }
        else {
            return w.LorryInRoad(lorryOffset);
        }
    }
}
