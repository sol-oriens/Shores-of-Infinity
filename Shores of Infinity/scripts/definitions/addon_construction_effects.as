import hooks;
import generic_hooks;

from constructions import ConstructionHook;

tidy final class TriggerStartConstruction : ConstructionHook {
	Document doc("Runs a triggered hook on the target when the construction starts.");
	Argument targ(TT_Object);
	Argument hookID("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to run.");
	BonusEffect@ hook;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("Trigger(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return ConstructionHook::instantiate();
	}

#section server
	void start(Construction@ cons, Constructible@ qitem, any@ data) const {
		auto@ objTarg = targ.fromConstTarget(cons.targets);
		if(objTarg is null || objTarg.obj is null)
			return;
		if(hook !is null)
			hook.activate(objTarg.obj, cons.obj.owner);
	}
#section all
};

tidy final class TriggerCancelConstruction : ConstructionHook {
	Document doc("Runs a triggered hook on the target when the construction is canceled.");
	Argument targ(TT_Object);
	Argument hookID("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to run.");
	BonusEffect@ hook;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("Trigger(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return ConstructionHook::instantiate();
	}

#section server
	void cancel(Construction@ cons, Constructible@ qitem, any@ data) const {
		auto@ objTarg = targ.fromConstTarget(cons.targets);
		if(objTarg is null || objTarg.obj is null)
			return;
		if(hook !is null)
			hook.activate(objTarg.obj, cons.obj.owner);
	}
#section all
};
