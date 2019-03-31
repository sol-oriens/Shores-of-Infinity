import orders.Order;
import ftl;
import saving;

import util.einsteinArrivalTime;

tidy class AbilityOrder : Order {
	int abilityId = -1;
	int moveId = -1;
	double range = 100.0;
	vec3d target;
	Object@ objTarget;
	bool casted = false;

	AbilityOrder(int id, vec3d targ, double range) {
		abilityId = id;
		target = targ;
		this.range = range;
	}

	AbilityOrder(int id, Object@ targ, double range) {
		abilityId = id;
		@objTarget = targ;
		this.range = range;
	}

	bool get_hasMovement() {
		return true;
	}

	vec3d getMoveDestination(const Object& obj) {
		if(objTarget !is null)
			return objTarget.position;
		return target;
	}

	AbilityOrder(SaveFile& file) {
		Order::load(file);
		file >> target;
		file >> moveId;
		file >> abilityId;
		file >> objTarget;
		if(file >= SV_0121)
			file >> casted;
	}

	void save(SaveFile& file) {
		Order::save(file);
		file << target;
		file << moveId;
		file << abilityId;
		file << objTarget;
		file << casted;
	}

	string get_name() {
		return "Use Ability";
	}

	OrderType get_type() {
		return OT_Ability;
	}

	OrderStatus tick(Object& obj, double time) {
		if(!obj.hasMover)
			return OS_COMPLETED;

		double realRange = range;
		realRange += obj.radius;

		if(objTarget !is null) {
			realRange += objTarget.radius;
			bool finishedMove = false;
			double distance = obj.position.distanceToSQ(objTarget.position);
			if(range != INFINITY && distance >= realRange * realRange) {
				finishedMove = useFTL(obj, objTarget, realRange * 0.95, time);
				if (!finishedMove)
					finishedMove = obj.moveTo(objTarget, moveId, realRange * 0.95, enterOrbit=false);
			}
			if(casted) {
				if(obj.isChanneling(abilityId))
					return OS_BLOCKING;
				else
					return OS_COMPLETED;
			}
			if(obj.isAbilityOnCooldown(abilityId))
				return OS_BLOCKING;
			if(distance <= realRange * realRange) {
				obj.activateAbility(abilityId, objTarget);
				if(moveId != -1) {
					moveId = -1;
					obj.stopMoving(false, false);
				}
				casted = true;
			}
			return OS_BLOCKING;
		}
		else {
			bool finishedMove = false;
			double distance = obj.position.distanceToSQ(target);
			if(realRange != INFINITY && distance >= realRange * realRange) {
				vec3d pt = target;
				pt += (obj.position - target).normalized(realRange * 0.95);
				finishedMove = useFTL(obj, pt, time);
				if (!finishedMove)
					finishedMove = obj.moveTo(pt, moveId, enterOrbit=false);
			}
			if(casted) {
				if(obj.isChanneling(abilityId))
					return OS_BLOCKING;
				else
					return OS_COMPLETED;
			}
			if(obj.isAbilityOnCooldown(abilityId))
				return OS_BLOCKING;
			if(distance <= realRange * realRange) {
				obj.activateAbility(abilityId, target);
				if(moveId != -1) {
					moveId = -1;
					obj.stopMoving(false, false);
				}
				casted = true;
			}
			return OS_BLOCKING;
		}
	}

	bool useFTL(Object& obj, Object& targ, double distance, double time) {
		double targDist = 0;

		if(targ.isRegion)
			targDist = targ.radius * 0.85;
		else
			targDist = max(distance, obj.radius + targ.radius);

		vec3d dir = (targ.position - obj.position);
		vec3d pt = obj.position + dir.normalized(dir.length - targDist);

		return useFTL(obj, pt, time);
	}

	double delay = 0;
	bool useFTL(Object& obj, vec3d pt, double time) {
		double freeFTL = 1.0 - obj.owner.FTLReserve;
		bool moved = false;
		delay -= time;

		if(obj.isShip && delay <= 0 && freeFTL > 0) {
			delay = 0;
			delay += 10.0;
			double eta = einsteinArrivalTime(obj.maxAcceleration, obj.position - pt, vec3d());
			print(eta);
			if (eta < 120)
				return moved;

			Empire@ owner = obj.owner;
			if(canHyperdrive(obj)) {
				double cost = hyperdriveCost(obj, pt);
				//Hyperdrive if at least the specified capacity of the empire's ftl capacity will be left
				if((owner.FTLStored - cost) / owner.FTLCapacity >= freeFTL) {
					obj.insertHyperdriveOrder(pt, getIndex());
					moved = true;
				}
			}

			if(!moved && canJumpdrive(obj)) {
				double cost = jumpdriveCost(obj, pt);
				double range = jumpdriveRange(obj);
				double dist = obj.position.distanceTo(pt);

				//Jumpdrive if at least the specified capacity of the empire's ftl capacity will be left
				if((owner.FTLStored - cost) / owner.FTLCapacity >= freeFTL && range >= dist) {
					obj.insertJumpdriveOrder(pt, getIndex());
					moved = true;
				}
			}

			if(!moved && owner.hasFlingBeacons) {
				double cost = flingCost(obj, pt);
				//Fling if at least the specified capacity of the empire's ftl capacity will be left
				if((owner.FTLStored - cost) / owner.FTLCapacity >= freeFTL) {
					Object@ fling = owner.getFlingBeacon(obj.position);
					if(fling !is null) {
						obj.insertFlingOrder(fling, pt, getIndex());
						moved = true;
					}
				}
			}
		}
		return moved;
	}
};
