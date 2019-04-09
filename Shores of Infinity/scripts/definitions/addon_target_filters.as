import hooks;
from target_filters import TargetFilter;

class TargetFilterNotStatusCount : TargetFilter {
	Document doc("Restricts target to objects with a less than a particular status count.");
	Argument targ(TT_Object);
	Argument status("Status", AT_Status, doc="Status to require.");
	Argument count("Count", AT_Integer, doc="Status count required to filter target.");

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return locale::NTRG_STATUS;
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		if(targ.obj is null)
			return false;
		if(!targ.obj.hasStatuses)
			return false;
		return targ.obj.getStatusStackCountAny(status.integer) < uint(count.integer);
	}
};

class TargetFilterRepairable : TargetFilter {
	Document doc("Restricts target to damaged repairables objects: ships, stations, orbitals.");
	Argument targ(TT_Object);

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return locale::NTRG_CANNOT_REPAIR;
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if (index != uint(arguments[0].integer))
			return true;
		if (targ.obj is null)
			return false;
		if (targ.obj.isShip) {
			auto@ ship = cast<Ship>(targ.obj);
			return ship.isDamaged;
		}
		else if(targ.obj.isOrbital) {
			auto@ orbital = cast<Orbital>(targ.obj);
			return orbital.isDamaged;
		}
		return false;
	}
};
