import settlements;

from statuses import getStatusID;

int shipPopulationStatusId = -1;
int mothershipPopulationStatusId = -1;

tidy class Settlement : Component_Settlement, Savable {
  Object@ obj;
  private uint _morale;
  private uint _focusId;
  private bool _autoFocus;
  
  Settlement() {
    if (shipPopulationStatusId == -1)
      shipPopulationStatusId = getStatusID("ShipPopulation");
    if (mothershipPopulationStatusId == -1)
      mothershipPopulationStatusId = getStatusID("MothershipPopulation");
  }
  
  bool get_isSettlement() const {
    if (obj is null)
      return false;
    if (obj.hasSurfaceComponent)
			return obj.population >= 1;
		else if (obj.hasStatuses)
			return obj.getStatusStackCountAny(shipPopulationStatusId) >= 1 || obj.getStatusStackCountAny(mothershipPopulationStatusId) >= 1;
    return false;
  }
  
  uint get_morale() const {
    return _morale;
  }
  
  void set_morale(uint value) {
    _morale = value;
  }
  
  uint get_focusId() const {
    return _focusId;
  }
  
  void set_focusId(uint value) {
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
    _focusId = (getAvailableFoci(obj, emp)[0]).id;
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
