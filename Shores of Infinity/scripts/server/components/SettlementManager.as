import settlements;

from statuses import getStatusID;
from resources import MoneyType;

tidy class SettlementManager : Component_Settlement, Savable {
	Object@ obj;
	Settlement@ settlementType;
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
		if (_morale <= -3)
			return SM_Critical;
		else if (_morale <= -2)
			return SM_Low;
		else if (_morale >= 2)
			return SM_High;
		else
			return SM_Medium;
	}

	void modMorale(int value) {
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

	uint get_civilActCount() const {
		return civilActs.length;
	}

	void addCivilAct(uint id) {
		const CivilActType@ type = getCivilActType(id);
		if(type !is null) {
			CivilAct civilAct(type);
			civilAct.enable(obj);
			if (civilAct.type.moraleEffect.stat != 0)
				modMorale(civilAct.type.moraleEffect.stat);
			if (civilAct.type.maintainCost != 0) {
				int maint = civilAct.type.getMaintainCost(obj);
				obj.owner.modMaintenance(maint, MoT_Civil_Acts);
				civilAct.currentMaint = maint;
			}
			civilAct.currentDelay = civilAct.type.delay;
			civilAct.currentCommitment = civilAct.type.commitment;

			civilActs.insertLast(civilAct);
			civilActs.sortAsc(); //Optimize lookups on type id which will always occur incrementally
		}
	}

	void removeCivilAct(uint id) {
		for(uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
			auto@ civilAct = civilActs[i];
			if (civilAct.type.id == id) {
				removeCivilAct(civilAct, obj.owner);
				return;
			}
		}
	}

	void removeCivilAct(CivilAct& civilAct, Empire@ emp) {
		civilAct.disable(obj);
		if (civilAct.type.moraleEffect.stat != 0)
			modMorale(-civilAct.type.moraleEffect.stat);
		if (civilAct.type.maintainCost != 0)
			emp.modMaintenance(-civilAct.currentMaint, MoT_Civil_Acts);

		civilActs.remove(civilAct);
	}

	void refreshMaintainCost(CivilAct@ civilAct) {
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
	}

	void clearSettlement(Object& obj, Empire@ emp) {
		if (obj is this.obj) {
			settlementType.disable(obj);
			@settlementType = null;
			focus.disable(obj);
			@focus = null;
			for (uint i = 0, cnt = civilActs.length; i < cnt; ++i) {
				removeCivilAct(civilActs[i], emp);
				--i; --cnt;
			}
			_isActive = false;
		}
	}

	void settlementTick(Object& obj, double time) {
		if (_isActive) {
			if (!settlementType.type.canEnable(obj)) {
				settlementType.disable(obj);
				SettlementType@ settlement = getSettlement(obj);
				if (settlement is null) {
					error("initSettlement (" + obj.name + ", " + obj.owner.name + "): could not find any suitable settlement type");
					return;
				}
				setType(settlement.id);
			}

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
					removeCivilAct(civilAct, obj.owner);
					--i; --cnt;
				}
				else {
					refreshMaintainCost(civilAct);
					if (civilAct.currentDelay > 0)
						civilAct.currentDelay = max(0.0, civilAct.currentDelay - time);
					if (civilAct.currentCommitment > 0)
						civilAct.currentCommitment = max(0.0, civilAct.currentDuration - time);
					civilAct.tick(obj, time);
				}
			}
		}
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

			@obj = file.readObject();
		}
	}
};