import hooks;
import abilities;
from abilities import AbilityHook;

class ConsumeEitherStatuses : AbilityHook {
	Document doc("Consumes an instance of a status on the object, or an instance of a fallback status if necessary.");
	Argument type(AT_Status, doc="Type of status to take.");
  Argument fallback_type(AT_Status, doc="Type of status to take if the object has _not enough_ statuses of the first type.");
	Argument amount(AT_Integer, "1", doc="Amount of cargo taken to build per status.");
	Argument hide(AT_Boolean, "False", doc="If the object has _no_ statuses of these types, hide the option.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		Object@ obj = abl.obj;
		if(obj is null || !obj.hasStatuses)
			return false;

    int val1 = obj.getStatusStackCountAny(type.integer);
		int val2 = obj.getStatusStackCountAny(fallback_type.integer);
		if(hide.boolean && val1 < amount.integer && val2 < amount.integer)
			return false;
		if(ignoreCost)
			return true;
		return val1 >= amount.integer || val2 >= amount.integer;
	}

#section server
	bool consume(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ obj = abl.obj;
		if(obj is null || !obj.hasStatuses)
			return false;

    int consumedType = type.integer;
		int count = obj.getStatusStackCount(type.integer);
		if(count < amount.integer) {
			count = obj.getStatusStackCount(fallback_type.integer);
			if(count < amount.integer)
				return false;
			consumedType = fallback_type.integer;
		}

		for(int i = 0; i < amount.integer; ++i)
			obj.removeStatusInstanceOfType(consumedType);
    data.store(consumedType);

		return true;
	}

	void reverse(Ability@ abl, any@ data, const Targets@ targs) const override {
		Object@ obj = abl.obj;
		if(obj !is null && obj.hasStatuses) {
      int consumedType = type.integer;
      data.retrieve(consumedType);
			obj.addStatus(consumedType);
    }
	}
#section all
};

class RepairPerSecondFromLaborIncome : AbilityHook {
	Document doc("Repairs the flagship or orbital this is applied to for an amount depending of labor income.");
	Argument objTarg(TT_Object);
	Argument factor(AT_Decimal, "1.0", "Factor applied to labor income to evaluate repairs.");

#section server
	void changeTarget(Ability@ abl, any@ data, uint index, Target@ oldTarget, Target@ newTarget) const {
		if(index != uint(objTarg.integer))
			return;

		Object@ prev = oldTarget.obj;
		Object@ next = newTarget.obj;

		if(prev is next)
			return;
	}

	void tick(Ability@ abl, any@ data, double time) const override {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return;

		Object@ target = storeTarg.obj;
		if(target is null)
			return;

		double amt = abl.obj.laborIncome * 60 * factor.decimal * time;
		if(target.isShip) {
			auto@ ship = cast<Ship>(target);
			if (ship.isDamaged)
				ship.repairShip(amt);
			else {
				Target newTarg = storeTarg;
				@newTarg.obj = null;
				abl.changeTarget(objTarg, newTarg);
			}
		}
		else if(target.isOrbital) {
			auto@ orbital = cast<Orbital>(target);
			if (orbital.isDamaged)
				orbital.repairOrbital(amt);
			else {
				Target newTarg = storeTarg;
				@newTarg.obj = null;
				abl.changeTarget(objTarg, newTarg);
			}
		}
	}
#section all
};
