import hooks;
import generic_hooks;
from generic_effects import IfHook;
from empire_effects import PeriodicData;

tidy final class IfNativeEither : IfHook {
	Document doc("Only apply the inner hook if the planet this is being executed on has a particular native resource.");
	Argument resource1(AT_PlanetResource, doc="First planetary resource to check for.");
  Argument resource2(AT_PlanetResource, doc="Second planetary resource to check for.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");

	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}

	bool condition(Object& obj) const override {
		for(uint i = 0, cnt = obj.nativeResourceCount; i < cnt; ++i) {
			if(obj.nativeResourceType[i] == uint(resource1.integer) || obj.nativeResourceType[i] == uint(resource2.integer))
				return true;
		}
		return false;
	}
};

class AddStatusStacks : GenericEffect {
  Document doc("Add stacks of a status effect to the object every set interval.");
	Argument type(AT_Status, doc="Type of status effect to create.");
  Argument stacks(AT_Integer, "1", doc="Number of stacks to add");
  Argument random_stack_margin(AT_Integer, "0", doc="Random margin for the stacks added.");
  Argument duration(AT_Decimal, "-1", doc="Duration to add the status stacks for, -1 for permanent.");
	Argument set_origin_empire(AT_Boolean, "False", doc="Whether to record the empire triggering this hook into the origin empire field of the resulting status. If not set, any hooks that refer to Origin Empire cannot not apply. Status effects with different origin empires set do not collapse into stacks.");
	Argument set_origin_object(AT_Boolean, "False", doc="Whether to record the object triggering this hook into the origin object field of the resulting status. If not set, any hooks that refer to Origin Object cannot not apply. Status effects with different origin objects set do not collapse into stacks.");
	Argument max_stacks(AT_Integer, "0", doc="If set to more than 0, never add stacks beyond a certain amount.");
  Argument interval(AT_Decimal, "0", doc="Interval in seconds between triggers, 0 for only one trigger.");
  Argument trigger_immediate(AT_Boolean, "True", doc="Whether to first trigger the effect right away before starting the timer. Must be true if there is only one trigger.");
  Argument random_interval_margin(AT_Decimal, "0", doc="Random margin for the interval. Not used if if there is only one trigger.");

  #section server
  	double getTimer() const {
  		double timer = interval.decimal;
      if (timer > 0) {
    		double margin = random_interval_margin.decimal;
    		if (margin != 0)
    			timer *= randomd(1.0 - margin, 1.0 + margin);
      }
  		return timer;
  	}

    void addStatusStacks(Object& obj) {
      if (obj is null)
        return;
      Empire@ origEmp = null;
      if (set_origin_empire.boolean)
        @origEmp = obj.owner;
      Object@ origObj = null;
      if (set_origin_object.boolean)
        @origObj = obj;
      uint actualStacks = uint(stacks.integer);
      uint randomMargin = uint(random_stack_margin.integer);
      if (randomMargin > 0)
        actualStacks += max(1, randomi(1.0 - randomMargin, 1.0 + randomMargin));
      if (max_stacks.integer > 0) {
        uint currentStacks = obj.getStatusStackCount(type.integer, originEmpire=origEmp, originObject=origObj);
        uint maxStacks = uint(max_stacks.integer);
        if (currentStacks >= maxStacks)
          return;
        else if (actualStacks + currentStacks > maxStacks)
          actualStacks -= (maxStacks - currentStacks);
      }
      for (uint i = 0, cnt = actualStacks; i < cnt; ++i)
        obj.addStatus(uint(type.integer), duration.decimal, originEmpire=origEmp, originObject=origObj);
    }

  	void enable(Object& obj, any@ data) const override {
  		PeriodicData@ dat;
  		if (!data.retrieve(@dat)) {
  			@dat = PeriodicData();
  			dat.timer = getTimer();
  			data.store(@dat);
  		}

  		if (trigger_immediate.boolean) {
        addStatusStacks(obj);
  			dat.count += 1;
  		}
  	}

  	void tick(Object& obj, any@ data, double tick) const override {
      if (interval.decimal > 0) {
    		PeriodicData@ dat;
    		data.retrieve(@dat);

    		dat.timer -= tick;
    		if (dat.timer <= 0.0) {
          addStatusStacks(obj);
  				dat.count += 1;
    			dat.timer += getTimer();
    		}
      }
  	}

    void save(any@ data, SaveFile& file) const override {
  		PeriodicData@ dat;
  		data.retrieve(@dat);

  		file << dat.timer;
  		file << dat.count;
  	}

  	void load(any@ data, SaveFile& file) const override {
  		PeriodicData dat;
  		data.store(@dat);

  		file >> dat.timer;
  		file >> dat.count;
  	}
  #section all
};

class SystemData {
  array<Object@> data;
  double timer = 0;
};

class AddStatusToPlanetsInSystem : GenericEffect {
	Document doc("Add an instance of a status effect to the planets in the system this is in.");
	Argument status(AT_Status, doc="Type of status effect to create.");
	Argument set_origin_empire(AT_Boolean, "False", doc="Whether to record the empire triggering this hook into the origin empire field of the resulting status. If not set, any hooks that refer to Origin Empire cannot not apply. Status effects with different origin empires set do not collapse into stacks.");
	Argument set_origin_object(AT_Boolean, "False", doc="Whether to record the object triggering this hook into the origin object field of the resulting status. If not set, any hooks that refer to Origin Object cannot not apply. Status effects with different origin objects set do not collapse into stacks.");
	Argument only_owned(AT_Boolean, "False", doc="Only apply the status if the planet is owned by this owner.");
	Argument allow_space(AT_Boolean, "False", doc="Also allow planets owned by space to receive this status.");
	Argument allow_quarantined(AT_Boolean, "False", doc="Also allow quarantined planets to receive this status.");

#section server
	void enable(Object& obj, any@ data) const override {
		SystemData@ prevObjs = SystemData();
		data.store(@prevObjs);
	}

	void tick(Object& obj, any@ data, double time) const override {
    SystemData@ prevObjs;
    data.retrieve(@prevObjs);

    prevObjs.timer -= time;
    if (prevObjs.timer <= 0) {
      prevObjs.timer += 10.0;

      uint plCnt = obj.region.planetCount;

      for (int i = prevObjs.data.length -1, cnt = 0; i >= cnt; --i) {
        Object@ prevObj = prevObjs.data[i];
        if (prevObj !is null) {
          bool found = false;
          for(uint i = 0; i < plCnt; ++i) {
            Object@ pl = obj.region.planets[i];
            if (pl !is null && pl is prevObj)
              found = true;
          }
          if (!found) {
            prevObj.removeStatusInstanceOfType(status.integer);
            prevObjs.data.remove(prevObj);
          }
        }
      }

      for (uint i = 0; i < plCnt; ++i) {
        Object@ newObj = obj.region.planets[i];
        if(newObj is null)
          continue;

      	if (newObj !is null && only_owned.boolean) {
      		Empire@ owner = obj.owner;
      		Empire@ otherOwner = newObj.owner;

      		if (owner !is otherOwner) {
      			if (!allow_space.boolean || otherOwner.valid) {
      				@newObj = null;
      			}
      		}
      	}

      	if (newObj !is null && newObj.hasSurfaceComponent) {
      		if (newObj.quarantined && !allow_quarantined.boolean) {
      			@newObj = null;
      		}
      	}

        if (newObj is null)
          continue;

        Empire@ origEmp = null;
        if (set_origin_empire.boolean)
          @origEmp = obj.owner;
        Object@ origObj = null;
        if (set_origin_object.boolean)
          @origObj = obj;

        if (newObj !is null && prevObjs.data.find(newObj) == -1) {
          newObj.addStatus(status.integer, originEmpire=origEmp, originObject=origObj);
          prevObjs.data.insertLast(newObj);
        }
      }
      data.store(@prevObjs);
    }
	}

	void ownerChange(Object& obj, any@ data, Empire@ prevOwner, Empire@ newOwner) const {
		disable(obj, data);
	}

	void disable(Object& obj, any@ data) const override {
		SystemData@ prevObjs;
		data.retrieve(@prevObjs);

    for (int i = prevObjs.data.length -1, cnt = 0; i >= cnt; --i) {
      Object@ prevObj = prevObjs.data[i];
      if (prevObj !is null) {
        prevObj.removeStatusInstanceOfType(status.integer);
        prevObjs.data.remove(prevObj);
      }
    }
    data.store(@prevObjs);
	}

	void save(any@ data, SaveFile& file) const override {
		SystemData@ objs;
		data.retrieve(@objs);
    uint cnt = objs.data.length;
    file << cnt;
    for (uint i = 0; i < cnt; ++i)
		  file << objs.data[i];
    file << objs.timer;
	}

	void load(any@ data, SaveFile& file) const override {
		Object@ obj;
    SystemData@ objs = SystemData();
    uint cnt = 0;
    file >> cnt;
    for (uint i = 0; i < cnt; ++i) {
		  file >> obj;
      objs.data.insertLast(obj);
    }
    file >> objs.timer;
		data.store(@objs);
	}
#section all
};

class AllowSettlement : GenericEffect {
	Document doc("Permits the ship to be a settlement for civilians. Does not work on orbitals.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(!obj.hasSettlement) {
			if(obj.isShip) {
				auto@ ship = cast<Ship>(obj);
				ship.activateSettlement();
				ship.initSettlement(ship.owner);
			}
			else
				return;
		}
	}
#section all
};
