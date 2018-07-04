import settlements;

from statuses import getStatusID;

tidy class Settlement : Component_Settlement, Savable {
  Object@ obj;
  private uint _morale;
  private int _focusId;
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
    return _morale;
  }
  
  void set_morale(uint value) {
    _morale = value;
  }
  
  int get_focusId() const {
    return _focusId;
  }
  
  void set_focusId(int value) {
    _focusId = value;
  }
  
  bool get_autoFocus() const {
    return _autoFocus;
  }
  
  void set_autoFocus(bool value) {
    _autoFocus = value;
  }
  
  void initSettlement(Object& owner, Empire& emp) {
    @obj = owner;
    _morale = SM_Medium;
    SettlementFocus@[] foci = getAvailableFoci(obj, emp);
    _focusId = foci.length > 0 ? int(foci[0].id) : -1;
    _autoFocus = true;
  }
  
  void save(SaveFile& file) {
    file << _morale;
    file << _focusId;
    file << _autoFocus;
    
    file << obj;
  }
  
  void load(SaveFile& file) {
    file >> _morale;
    file >> _focusId;
    file >> _autoFocus;
    
    @obj = file.readObject();
  }

  void writeSettlement(Message& msg) const {
    msg.writeSmall(_morale);
    msg.writeSmall(_focusId);
    msg << _autoFocus;
    
    msg << obj;
  }
};
