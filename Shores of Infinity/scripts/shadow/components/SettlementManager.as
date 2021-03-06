import settlements;

from attributes import getEmpAttribute;
from resources import MoneyType;

int ignoreMoraleModifiersAttribute = -1;

tidy class SettlementManager : Component_Settlement {
	Mutex mtx;
	Object@ obj;
	Settlement@ settlementType;
	SettlementFocus@ focus;
	array<CivilAct@> civilActs;
	private bool _isActive = false;
	private double _morale;
	private int _focusId;
	private bool _autoFocus;

	SettlementManager() {
		ignoreMoraleModifiersAttribute = getEmpAttribute("IgnoreMoraleModifiers", create = false);
	}

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
		double totalMorale = _morale + obj.owner.GlobalMorale.value;
		if (totalMorale <= -3.0)
			return SM_Critical;
		if (totalMorale <= -2.0)
			return SM_VeryLow;
		if (totalMorale <= -1.0)
			return SM_Low;
		if (totalMorale >= 1.0)
			return SM_High;
		if (totalMorale >= 2.0)
			return SM_VeryHigh;
		return SM_Medium;
	}

	void modMorale(double value) {
		//PREDICTIVE
		if (obj.owner.getAttribute(ignoreMoraleModifiersAttribute) == 1)
			return;
		_morale += value;
	}

	uint get_settlementTypeId() const {
		return settlementType !is null ? settlementType.type.id : 0;
	}

	uint get_focusId() const {
		return _focusId;
	}

	void setFocus(uint id) {
		const SettlementFocusType@ type = getSettlementFocusType(id);
		setFocus(type);
	}

	void setFocus(const SettlementFocusType& type) {
		//PREDICTIVE
		if(type !is null) {
			if (this.focus !is null) {
				this.focus.disable(obj);
				if (this.focus.type.moraleEffect.stat != 0)
					modMorale(-this.focus.type.moraleEffect.stat);
			}
			SettlementFocus focus(type);
			@this.focus = focus;
			focus.enable(obj);
			if (type.moraleEffect.stat != 0)
				modMorale(type.moraleEffect.stat);
			_focusId = type.id;
		}
	}

	bool get_autoFocus() const {
		return _autoFocus;
	}

	void set_autoFocus(bool value) {
		//PREDICTIVE
		_autoFocus = value;
	}

	uint getCivilActTypeId(uint index) const {
		if (index >= civilActs.length)
			return uint(-1);
		return civilActs[index].type.id;
	}

	uint getCivilActTimerType(uint index) const {
		if (index < civilActs.length) {
			auto@ civilAct = civilActs[index];
			if (civilAct.currentDelay > 0)
				return CAT_Delay;
			if (civilAct.currentCommitment > 0)
				return CAT_Commitment;
			if (civilAct.currentDuration < INFINITY)
				return CAT_Duration;
		}
		return CAT_None;
	}

	double getCivilActTimer(uint index) const {
		if (index < civilActs.length) {
			auto@ civilAct = civilActs[index];
			if (civilAct.currentDelay > 0)
				return civilAct.currentDelay;
			if (civilAct.currentCommitment > 0)
				return civilAct.currentCommitment;
			if (civilAct.currentDuration < INFINITY)
				return civilAct.currentDuration;
		}
		return 0.0;
	}

	uint get_civilActCount() const {
		return civilActs.length;
	}

	void addCivilAct(uint id) {
		//PREDICTIVE
		const CivilActType@ type = getCivilActType(id);
		if(type !is null) {
			CivilAct civilAct(type);
			if (civilAct.type.moraleEffect.stat != 0)
				modMorale(civilAct.type.moraleEffect.stat);
			if (civilAct.type.maintainCost != 0) {
				int maint = civilAct.type.getMaintainCost(obj);
				obj.owner.modMaintenance(maint, MoT_Civil_Acts);
				civilAct.currentMaint = maint;
			}
			civilAct.currentDelay = civilAct.type.delay;
			civilAct.currentCommitment = max(0.0, civilAct.type.commitment - civilAct.type.delay);

			if (civilAct.currentDelay == 0.0)
				//Delayed civil acts are not enabled yet
				civilAct.enable(obj);

			civilActs.insertLast(civilAct);
		}
	}

	void removeCivilAct(uint id) {
		Lock lck(mtx);
		for(uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
			auto@ civilAct = civilActs[i];
			if (civilAct.type.id == id) {
				removeCivilAct(civilAct, obj.owner);
				return;
			}
		}
	}

	void removeCivilAct(CivilAct& civilAct, Empire@ emp, bool force = false) {
		if (civilAct.currentDelay == 0.0) {
			if (civilAct.currentCommitment > 0 && !force)
				return;
			//Delayed civil acts are not enabled yet
			civilAct.disable(obj);
		}
		if (civilAct.type.moraleEffect.stat != 0)
			modMorale(-civilAct.type.moraleEffect.stat);
		if (civilAct.type.maintainCost != 0)
			emp.modMaintenance(-civilAct.currentMaint, MoT_Civil_Acts);

		civilActs.remove(civilAct);
	}

	void settlementTick(Object& obj, double time) {
		if (!_isActive)
			return;

		Lock lck(mtx);
		for(uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
			auto@ civilAct = civilActs[i];
			if (civilAct.currentDelay > 0) {
				civilAct.currentDelay = max(0.0, civilAct.currentDelay - time);
				if (civilAct.currentDelay == 0.0)
					//Enable civil acts with expired delay
					civilAct.enable(obj);
				else continue;
			}
			else {
				if (civilAct.currentCommitment > 0)
					civilAct.currentCommitment = max(0.0, civilAct.currentCommitment - time);
				if (civilAct.currentDuration < INFINITY) {
					civilAct.currentDuration = max(0.0, civilAct.currentDuration - time);
					if (civilAct.currentDuration <= 0) {
						removeCivilAct(civilAct, obj.owner);
						--i; --cnt;
						continue;
					}
				}
			}
		}
	}

	void readSettlement(Message& msg) {
		uint id = 0;
		uint timerType = 0;
		double timer = 0;

		msg >> obj;
		msg >> _isActive;

		if (!_isActive)
			return;

		msg >> _morale;
		msg >> _focusId;
		msg >> _autoFocus;
		msg >> id;
		@settlementType = Settlement(getSettlementType(id));
		if (_focusId > -1)
			@focus = SettlementFocus(getSettlementFocusType(_focusId));
		if (!msg.readBit()) {
			if(civilActs.length != 0) {
				Lock lck(mtx);
				civilActs.length = 0;
			}
		}
		else {
			Lock lck(mtx);
			uint cnt = 0;
			msg >> cnt;
			civilActs.length = cnt;
			for(uint i = 0; i < cnt; ++i) {
				msg >> id;
				@civilActs[i] = CivilAct(getCivilActType(id));
				msg >> timerType;
				msg >> timer;
				switch (timerType) {
					case CAT_Delay:
						civilActs[i].currentDelay = timer;
						break;
					case CAT_Commitment:
						civilActs[i].currentDelay = 0;
						civilActs[i].currentCommitment = timer;
						break;
					case CAT_Duration:
						civilActs[i].currentDelay = 0;
						civilActs[i].currentCommitment = 0;
						civilActs[i].currentDuration = timer;
						break;
					default:
						civilActs[i].currentDelay = 0;
						civilActs[i].currentCommitment = 0;
						civilActs[i].currentDuration = INFINITY;
						break;
				}
			}
		}
	}

	void readSettlementDelta(Message& msg) {
		readSettlement(msg);
	}
};
