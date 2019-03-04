import settlements;

tidy class Settlement : Component_Settlement {
  Object@ obj;
  uint _morale;
  uint _focusId;
  bool _autoFocus;
  int[] _civilActIds;

  void readSettlement(Message& msg) {
    _morale = msg.readSmall();
    _focusId = msg.readSmall();
    msg >> _autoFocus;
    if(!msg.readBit()) {
			if(_civilActIds.length != 0) {
				_civilActIds.length = 0;
			}
			return;
		}
		_civilActIds.length = msg.readSmall();
		for(uint i = 0, cnt = _civilActIds.length; i < cnt; ++i)
			msg >> _civilActIds[i];
    
    @obj = msg.readObject();
  }
};
