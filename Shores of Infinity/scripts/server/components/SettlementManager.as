import settlements;

from statuses import getStatusID;
from resources import MoneyType;

tidy class SettlementManager : Component_Settlement, Savable {
	Mutex mtx;
	Object@ obj;
	Settlement@ settlementType;
	SettlementFocus@ focus;
	array<CivilAct@> civilActs;
	private bool _isActive = false;
	private double _morale;
	private uint _focusId;
	private bool _autoFocus;

	private bool _notifiedCivilUnrest = false;

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
			return SM_Low;
		if (totalMorale >= 2.0)
			return SM_High;
		return SM_Medium;
	}

	void modMorale(double value) {
		_morale += value;
	}

	uint get_settlementTypeId() const {
		return settlementType !is null ? settlementType.type.id : 0;
	}

	void setType(uint id) {
		const SettlementType@ type = getSettlementType(id);
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
	}

	uint get_focusId() const {
		return _focusId;
	}

	void setFocus(uint id) {
		const SettlementFocusType@ type = getSettlementFocusType(id);
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

	uint getCivilActTimerType(uint index) const {
		auto@ civilAct = civilActs[index];
		if (civilAct.currentDelay > 0)
			return CAT_Delay;
		if (civilAct.currentCommitment > 0)
			return CAT_Commitment;
		if (civilAct.currentDuration < INFINITY)
			return CAT_Duration;
		return CAT_None;
	}

	double getCivilActTimer(uint index) const {
		auto@ civilAct = civilActs[index];
		if (civilAct.currentDelay > 0)
			return civilAct.currentDelay;
		if (civilAct.currentCommitment > 0)
			return civilAct.currentCommitment;
		if (civilAct.currentDuration < INFINITY)
			return civilAct.currentDuration;
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

	void refreshMaintainCost(CivilAct& civilAct) {
		if (civilAct.type.maintainCost != 0) {
			int newMaint = civilAct.type.getMaintainCost(obj);
			if (newMaint != civilAct.currentMaint) {
				obj.owner.modMaintenance(newMaint - civilAct.currentMaint, MoT_Civil_Acts);
				civilAct.currentMaint = newMaint;
			}
		}
	}

	void initSettlement(Object& obj) {
		SettlementType@ settlement = getSettlement(obj);
		if (settlement is null) {
			error("initSettlement (" + obj.name + ", " + obj.owner.name + "): could not find any suitable settlement type");
			return;
		}
		SettlementFocusType@[] foci = getAvailableFoci(obj);
		if (foci.length == 0) {
			error("initSettlement (" + obj.name + ", " + obj.owner.name + "): could not find any available focus");
			return;
		}
		@this.obj = obj;
		_morale = 0;
		setType(settlement.id);
		setFocus(foci[0].id);
		_autoFocus = true;
		_isActive = true;
		_notifiedCivilUnrest = false;
	}

	void clearSettlement(Object& obj, Empire@ emp) {
		Lock lck(mtx);
		if (obj is this.obj) {
			settlementType.disable(obj);
			@settlementType = null;
			focus.disable(obj);
			@focus = null;
			for (uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
				removeCivilAct(civilActs[i], emp, force = true);
				--i; --cnt;
			}
			_isActive = false;
		}
	}

	void settlementTick(Object& obj, double time) {
		if (_isActive) {
			if (morale <= SM_Low && !_notifiedCivilUnrest) {
				notifySettlement(obj, obj.owner, SET_Civil_Unrest);
				_notifiedCivilUnrest = true;
			}
			else if (morale > SM_Low && _notifiedCivilUnrest)
				_notifiedCivilUnrest = false;

			if (!settlementType.type.canEnable(obj))
				settlementType.disable(obj);
			SettlementType@ settlement = getSettlement(obj);
			if (settlement is null) {
					error("settlementTick (" + obj.name + ", " + obj.owner.name + "): could not find any suitable settlement type");
					return;
			}
			if (settlement.id != settlementType.type.id)
				setType(settlement.id);

			settlementType.tick(obj, time);

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
					civilAct.tick(obj, time);
				}
			}
		}
	}

	void notifySettlement(Object@ owner, Empire@ emp, uint eventType) {
		emp.notifySettlement(owner, eventType);
	}

	void save(SaveFile& file) {
		file << _isActive;
		if (_isActive) {
			file << _morale;
			file << _focusId;
			file << _autoFocus;
			file << settlementType;
			file << focus;
			uint cnt = civilActs.length;
			file << cnt;
			for(uint i = 0; i < cnt; ++i)
				file << civilActs[i];
			file << _notifiedCivilUnrest;

			file << obj;
		}
	}

	void load(SaveFile& file) {
		file >> _isActive;
		if (_isActive) {
			file >> _morale;
			file >> _focusId;
			file >> _autoFocus;
			@settlementType = Settlement();
			file >> settlementType;
			@focus = SettlementFocus();
			file >> focus;
			uint cnt = 0;
			file >> cnt;
			civilActs.length = cnt;
			for(uint i = 0; i < cnt; ++i) {
				@civilActs[i] = CivilAct();
				file >> civilActs[i];
			}
			file >> _notifiedCivilUnrest;

			@obj = file.readObject();
		}
	}
};
