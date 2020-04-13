import settlements;

from attributes import getEmpAttribute;
from resources import MoneyType;

int ignoreMoraleModifiersAttribute = -1;

tidy class SettlementManager : Component_Settlement, Savable {
	Mutex mtx;
	float timer = 0.f;
	bool delta = false;

	Object@ obj;
	Settlement@ settlementType;
	SettlementFocus@ focus;
	array<CivilAct@> civilActs;
	private bool _isActive = false;
	private double _morale;
	private int _focusId;
	private bool _autoFocus;
	private int _taxFactor;
	private int _incomeModifier;

	private bool _notifiedCivilUnrest = false;

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
		if (obj.owner.getAttribute(ignoreMoraleModifiersAttribute) == 1)
			return;
		_morale += value;
	}

	uint get_settlementTypeId() const { return settlementType !is null ? settlementType.type.id : 0; }

	void setType(uint id) {
		const SettlementType@ type = getSettlementType(id);
		setType(type);
	}

	void setType(const SettlementType& type) {
		if (type !is null) {
			if (settlementType !is null) {
				settlementType.disable(obj);
				if (settlementType.type.moraleEffect.stat != 0)
					modMorale(-settlementType.type.moraleEffect.stat);
			}
			Settlement settlement(type);
			@settlementType = settlement;
			settlement.enable(obj);
			if (type.moraleEffect.stat != 0)
				modMorale(type.moraleEffect.stat);
		}
		delta = true;
	}

	uint get_focusId() const { return _focusId; }

	void setFocus(uint id) {
		const SettlementFocusType@ type = getSettlementFocusType(id);
		setFocus(type);
	}

	void setFocus(const SettlementFocusType& type) {
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
		delta = true;
	}

	bool get_autoFocus() const { return _autoFocus; }
	void set_autoFocus(bool value) {
		_autoFocus = value;
		delta = true;
	}

	int get_taxFactor() const { return _taxFactor; }
	void set_taxFactor(int value) { _taxFactor = value; }

	void refreshIncomeModifier() {
		int baseIncome = getSettlementBaseIncome(obj);
		int newMod = baseIncome * 2 * (_taxFactor - 0.5) * getSettlementPopulation(obj);
		if (newMod != _incomeModifier) {
			obj.owner.modMaintenance(-(newMod - _incomeModifier), MoT_Planet_Income);
			_incomeModifier = newMod;
		}
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
			civilAct.currentCommitment = civilAct.type.commitment;

			if (civilAct.currentDelay == 0.0)
				//Delayed civil acts are not enabled yet
				civilAct.enable(obj);

			civilActs.insertLast(civilAct);
			delta = true;
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
		delta = true;
	}

	void refreshMaintainCost(CivilAct& civilAct) {
		if (civilAct.type.maintainCost != 0) {
			int newMaint = civilAct.type.getMaintainCost(obj);
			if (newMaint != civilAct.currentMaint) {
				obj.owner.modMaintenance(newMaint - civilAct.currentMaint, MoT_Civil_Acts);
				civilAct.currentMaint = newMaint;
			}
		}
	}

	bool checkCivilUnrestContainment(double containCivilUnrest) {
		double lossThreshold = 0.8;
		if (obj.morale + obj.owner.GlobalMorale.value == SM_Critical)
			lossThreshold = 0.4;
		double roll = randomd(0.1 - containCivilUnrest, 1.0);
		if (roll >= lossThreshold || roll >= 0.95 /* Fumble! */)
			return false;
		return true;
	}

	void initSettlement(Object& obj) {
		@this.obj = obj;
		_morale = 0;
		_focusId = -1;
		_autoFocus = true;
		_isActive = true;
		_taxFactor = 0;
		_incomeModifier = 0;
		_notifiedCivilUnrest = false;
	}

	void clearSettlement(Object& obj, Empire@ emp) {
		Lock lck(mtx);
		if (obj is this.obj) {
			if (settlementType !is null) {
				settlementType.disable(obj);
				@settlementType = null;
			}
			if (focus !is null) {
				focus.disable(obj);
				@focus = null;
				_focusId = -1;
			}
			for (uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
				removeCivilAct(civilActs[i], emp, force = true);
				--i; --cnt;
			}
			_isActive = false;
		}
	}

	void settlementTick(Object& obj, double time) {
		if (!_isActive)
			return;

		if (morale <= SM_VeryLow && !_notifiedCivilUnrest) {
			notifySettlement(obj, obj.owner, SET_Civil_Unrest);
			_notifiedCivilUnrest = true;
		}
		else if (morale > SM_VeryLow && _notifiedCivilUnrest)
			_notifiedCivilUnrest = false;

		//Delay and spread expensive checks randomly over time
		if (float(time) >= timer) {
			timer = float(time + randomd(3.0, 5.0));

			const SettlementType@ settlement = getSettlement(obj);
			if (settlement !is null) {
				if (settlementType is null || settlement.id != settlementType.type.id)
					setType(settlement);
			}
			else
				error("settlementTick (" + obj.name + ", " + obj.owner.name + "): could not find any suitable settlement type");

			const SettlementFocusType@[] foci = getAvailableFoci(obj);
			if (foci.length > 0) {
				if (_focusId == -1 || _autoFocus && _focusId != int(foci[0].id))
					setFocus(foci[0]);
			}
			else
				error("settlementTick (" + obj.name + ", " + obj.owner.name + "): could not find any available focus");

			//refreshIncomeModifier();
		}

		if (settlementType !is null)
			settlementType.tick(obj, time);

		if (focus !is null)
			focus.tick(obj, time);

		for(uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
			auto@ civilAct = civilActs[i];
			if(!civilAct.type.canEnable(obj)) {
				removeCivilAct(civilAct, obj.owner, force = true);
				--i; --cnt;
				continue;
			}
			else {
				refreshMaintainCost(civilAct);
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
				civilAct.tick(obj, time);
			}
		}
	}

	void notifySettlement(Object@ owner, Empire@ emp, uint eventType) {
		emp.notifySettlement(owner, eventType);
	}

	void save(SaveFile& file) {
		file << obj;
		file << _isActive;

		if (!_isActive)
			return;

		file << _morale;
		file << _focusId;
		file << _autoFocus;
		if (settlementType is null)
			file.write0();
		else {
			file.write1();
			file << settlementType;
		}
		if (focus is null)
			file.write0();
		else {
			file.write1();
			file << focus;
		}
		uint cnt = civilActs.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i)
			file << civilActs[i];
		file << _notifiedCivilUnrest;
	}

	void load(SaveFile& file) {
		@obj = file.readObject();
		file >> _isActive;
		if (!_isActive)
			return;

		file >> _morale;
		file >> _focusId;
		file >> _autoFocus;
		if (!file.readBit())
			@settlementType = Settlement(getSettlementType(0));
		else {
			@settlementType = Settlement();
			file >> settlementType;
		}
		if (file.readBit()) {
			@focus = SettlementFocus();
			file >> focus;
		}
		uint cnt = 0;
		file >> cnt;
		civilActs.length = cnt;
		for (uint i = 0; i < cnt; ++i) {
			@civilActs[i] = CivilAct();
			file >> civilActs[i];
		}
		file >> _notifiedCivilUnrest;
	}

	void writeSettlement(Message& msg) const {
		msg << obj;
		msg << _isActive;

		if (!_isActive)
			return;

		msg << _morale;
		msg << _focusId;
		msg << _autoFocus;
		msg << settlementTypeId;
		Lock lck(mtx);
		if(civilActs.length == 0)
			msg.write0();
		else {
			msg.write1();
			uint cnt = civilActs.length;
			msg << cnt;
			for(uint i = 0; i < cnt; ++i) {
				msg << civilActs[i].type.id;
				msg << getCivilActTimerType(i);
				msg << getCivilActTimer(i);
			}
		}
	}

	bool writeSettlementDelta(Message& msg) {
		if(!delta)
			return false;
		msg.write1();
		writeSettlement(msg);
		delta = false;
		return true;
	}
};
