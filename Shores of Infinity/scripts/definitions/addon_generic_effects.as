import hooks;
import generic_hooks;

class SystemData {
  array<Object@> data;
  double timer = 0;
};

class AddStatusToPlanetsInSystem : GenericEffect {
	Document doc("Add an instance of a status effect to the planet this is orbiting.");
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

      for(uint i = 0; i < plCnt; ++i) {
        Object@ newObj = obj.region.planets[i];
        if(newObj is null)
          continue;

      	if(newObj !is null && only_owned.boolean) {
      		Empire@ owner = obj.owner;
      		Empire@ otherOwner = newObj.owner;

      		if(owner !is otherOwner) {
      			if(!allow_space.boolean || otherOwner.valid) {
      				@newObj = null;
      			}
      		}
      	}

      	if(newObj !is null && newObj.hasSurfaceComponent) {
      		if(newObj.quarantined && !allow_quarantined.boolean) {
      			@newObj = null;
      		}
      	}

        if(newObj is null)
          continue;

        Empire@ origEmp = null;
        if(set_origin_empire.boolean)
          @origEmp = obj.owner;
        Object@ origObj = null;
        if(set_origin_object.boolean)
          @origObj = obj;

        if(newObj !is null && prevObjs.data.find(newObj) == -1) {
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
