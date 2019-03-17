import settlements;

from statuses import getStatusID;
from resources import MoneyType;

tidy class Settlement : Component_Settlement, Savable {
  Object@ obj;
  SettlementFocus@ focus;
  array<CivilAct@> civilActs;
  private bool _isActive = false;
  private int _morale;
  private uint _focusId;
  private bool _autoFocus;
  
  bool get_isSettlement() const {
    if (obj is null)
      return false;
    if (obj.hasSurfaceComponent)
			return obj.population >= 1;
		else if (obj.hasStatuses)
			return obj.getStatusStackCountAny(shipPopulationStatus) >= 1 || obj.getStatusStackCountAny(mothershipPopulationStatus) >= 1;
    return false;
  }
  
  uint get_morale() const {
    if (_morale <= -2)
      return SM_Low;
    else if (_morale >= 2)
      return SM_High;
    else
      return SM_Medium;
  }
  
  void updateMorale(int value) {
    _morale += value;
  }
  
  uint get_focusId() const {
    return _focusId;
  }
  
  void setFocus(uint id) {
    const SettlementFocusType@ type = getSettlementFocusType(id);
    if(type !is null) {
      if (this.focus !is null) {
        this.focus.disable(obj);
        if (this.focus.type.moraleEffect != 0)
          updateMorale(-this.focus.type.moraleEffect);
      }
      SettlementFocus focus(type);
      @this.focus = focus;
      focus.enable(obj);
      if (type.moraleEffect != 0)
        updateMorale(type.moraleEffect);
      _focusId = id;
    }
  }
  
  bool get_autoFocus() const {
    return _autoFocus;
  }
  
  void set_autoFocus(bool value) {
    _autoFocus = value;
  }
  
  uint getCivilActTypeId(uint index) const {
    return civilActs[index].type.id;
  }
  
  void addCivilAct(uint id) {
		const CivilActType@ type = getCivilActType(id);
		if(type !is null) {
			CivilAct civilAct(type);
      civilActs.insertLast(civilAct);
      civilActs.sortAsc(); //Optimize lookups on type id which will always occur incrementally
		}
	}
  
  void removeCivilAct(uint id) {
    for(uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
			auto@ civilAct = civilActs[i];
      if (civilAct.type.id == id) {
        civilActs.remove(civilAct);
        --i; --cnt;
      }
    }
  }
  
  uint get_civilActCount() const {
    return civilActs.length;
  }
  
  void enableCivilAct(uint id) {
    for(uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
			auto@ civilAct = civilActs[i];
      if (civilAct.type.id == id) {
        civilAct.enable(obj);
        if (civilAct.type.moraleEffect != 0)
          updateMorale(civilAct.type.moraleEffect);
        if (civilAct.type.maintainCost != 0)
          obj.owner.modMaintenance(civilAct.type.maintainCost, MoT_Civil_Acts);
      }
    }
  }
  
  void disableCivilAct(uint id) {
    for(uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
			auto@ civilAct = civilActs[i];
      if (civilAct.type.id == id) {
        civilAct.disable(obj);
        if (civilAct.type.moraleEffect != 0)
          updateMorale(-civilAct.type.moraleEffect);
        if (civilAct.type.maintainCost != 0)
          obj.owner.modMaintenance(-civilAct.type.maintainCost, MoT_Civil_Acts);
      }
    }
  }
  
  void initSettlement(Object& obj) {
    SettlementFocusType@[] foci = getAvailableFoci(obj);
    if (foci.length == 0) {
      error("initSettlement (" + obj.name + ", " + obj.owner.name + "): could not find any available focus");
      return;
    }
    @this.obj = obj;
    _morale = 0;
    setFocus(foci[0].id);
    _autoFocus = true;
    _isActive = true;
  }
  
  void clearSettlement(Object& obj) {
    if (obj is this.obj) {
      focus.disable(obj);
      @focus = null;
  		for (uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
        civilActs[i].disable(obj);
  			civilActs.remove(civilActs[i]);
  		}
      _isActive = false;
    }
	}
  
  void settlementTick(Object& obj, double time) {
    if (_isActive) {
      if (!focus.type.canEnable(obj))
        focus.disable(obj);
      SettlementFocusType@[] foci = getAvailableFoci(obj);
      if (foci.length == 0) {
        error("settlementTick (" + obj.name + ", " + obj.owner.name + "): could not find any available focus");
        return;
      }
      if (_autoFocus && _focusId != foci[0].id)
        setFocus(foci[0].id);
        
      focus.tick(obj, time);
      
  		for(uint i = 0; i < civilActs.length; ++i) {
  			auto@ civilAct = civilActs[i];
  			if(!civilAct.type.canEnable(obj))
  				civilAct.disable(obj);
        else
          civilAct.tick(obj, time);
  		}
    }
	}
  
  void save(SaveFile& file) {
    file << _isActive;
    if (_isActive) {
      file << _morale;
      file << _focusId;
      file << _autoFocus;
      file << focus;
      uint cnt = civilActs.length;
  		file << cnt;
      for(uint i = 0; i < cnt; ++i)
  			file << civilActs[i];
      
      file << obj;
    }
  }
  
  void load(SaveFile& file) {
    file >> _isActive;
    if (_isActive) {
      file >> _morale;
      file >> _focusId;
      file >> _autoFocus;
      @focus = SettlementFocus();
      file >> focus;
      uint cnt = 0;
  		file >> cnt;
  		civilActs.length = cnt;
  		for(uint i = 0; i < cnt; ++i) {
  			@civilActs[i] = CivilAct();
  			file >> civilActs[i];
  		}
      
      @obj = file.readObject();
    }
  }
};
