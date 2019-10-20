import hooks;
import sites;
import research;
import planet_effects;
import bonus_effects;

from sites import ISiteHook, SiteHook;

class ProgressToState : SiteHook {
	Document doc("Progresses the site to a specified state.");
	Argument goal("State", AT_Custom, doc="ID of the target state.");
	const SiteState@ state;

#section server
	void init(SiteType@ type) override {
		@state = type.getState(goal.str);
		if(state is null)
			error("ProgressState(): Could not find state "+goal.str);
	}

	void choose(Site@ site, Empire@ emp) const override {
		if(state !is null)
			site.progressToState(state.id);
	}
#section all
};
