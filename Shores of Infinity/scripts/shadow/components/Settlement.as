import settlements;

tidy class Settlement : Component_Settlement {
  Object@ obj;
  uint _morale;
  uint _focusId;
  bool _autoFocus;

  void readSettlement(Message& msg) {
    _morale = msg.readSmall();
    _focusId = msg.readSmall();
    msg >> _autoFocus;
    
    @obj = msg.readObject();
  }
};
