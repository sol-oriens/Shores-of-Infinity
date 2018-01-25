import hooks;
from target_filters import TargetFilter;

class TargetFilterNotStatusCount : TargetFilter {
	Document doc("Restricts target to objects with a particular status count or more.");
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
		if(targ.obj.getStatusStackCountAny(status.integer) >= uint(count.integer))
			return false;
		return true;
	}
};
