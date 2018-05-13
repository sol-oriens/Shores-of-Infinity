import hooks;
import generic_hooks;
import resources;

class StatusData {
  Object@ obj;
  int id = -1;
};

class OnExportAddStatus : ResourceHook {
	Document doc("Add a status to the object this resource is exported to.");
  Argument status(AT_Status, doc="Type of status effect to create.");
  Argument source_Flag(AT_SystemFlag, "NoFlag", doc="Identifier for the source system flag to check. Can be set to any arbitrary name, and the matching system flag will be created.");
	Argument destination_Flag(AT_SystemFlag, "NoFlag", doc="Identifier for the destination system flag to check. Can be set to any arbitrary name, and the matching system flag will be created.");

#section server
  void onTick(Object& obj, Resource@ r, double time) const override {
    StatusData@ prevObj;
    r.data[hookIndex].retrieve(@prevObj);
    if (prevObj is null) {
      @prevObj = StatusData();
      @prevObj.obj = obj;
    }

    auto@ newObj = StatusData();
    @newObj.obj = obj;
    newObj.id = prevObj.id;

    string noFlag = "NoFlag";
    bool sourceFlag = false;
    bool destFlag = false;
    Region@ reg;
    //Check source system flag if specified
    if (source_Flag.str == noFlag)
      sourceFlag = true;
    else {
        @reg = r.origin.region;
        if(reg !is null)
          sourceFlag = reg.getSystemFlag(r.origin.owner, source_Flag.integer);
    }
    //Check destination system flag if specified
    if (destination_Flag.str == noFlag)
      destFlag = true;
    else {
      @reg = newObj.obj.region;
      if(reg !is null)
        destFlag = reg.getSystemFlag(obj.owner, destination_Flag.integer);
    }
    if (sourceFlag && destFlag) {
      //Check export is valid
      Empire@ origEmp = r.origin.owner;
      Object@ origObj = r.origin;

      if(newObj.obj !is origObj && newObj.obj.owner is origEmp) {
        if (newObj.obj.getStatusStackCount(status.integer, originObject=origObj, originEmpire=origEmp) == 0)
          newObj.id = newObj.obj.addStatus(-1.0, status.integer, originEmpire=origEmp, originObject=origObj);
      }
      else
        newObj.obj.removeStatus(newObj.id);
    }
    else
      newObj.obj.removeStatus(newObj.id);

    r.data[hookIndex].store(@newObj);
  }

  void onRemove(Object& obj, Resource@ r) const override {
    StatusData@ prevObj;
    r.data[hookIndex].retrieve(@prevObj);
    if(prevObj !is null)
      prevObj.obj.removeStatus(prevObj.id);
  }
#section all
};
