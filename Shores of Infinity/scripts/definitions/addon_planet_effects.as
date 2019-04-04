import hooks;
import generic_effects;

class PerPopulationAddLoyalty : GenericEffect, TriggerableGeneric {
	Document doc("Increases the loyalty of the planet based on its current population.");
	Argument amount(AT_Integer, doc="Multiplier to the planet's current population to give as extra loyalty.");

	bool get_hasEffect() const override {
		return true;
	}

	string formatEffect(Object& obj, array<const IResourceHook@>& hooks) const override {
		return formatPosEffect(locale::SPICE_EFFECT, "+"+integerSum(hooks, 0));
	}

#section server
	void enable(Object& obj, any@ data) const override {
		double amt = 0.0;
		data.store(amt);
	}

	void disable(Object& obj, any@ data) const override {
		if(obj.isPlanet) {
			double amt = 0.0;
			data.retrieve(amt);
			if(amt != 0.0)
			obj.modBaseLoyalty(-amount.integer);
		}
	}

	void tick(Object& obj, any@ data, double tick) const override {
		if(obj.isPlanet) {
			double amt = 0.0;
			data.retrieve(amt);

			int pop = max(obj.population, 0.0);
			int newAmt = pop * amount.integer;
			if(amt != newAmt) {
				obj.modBaseLoyalty(newAmt - amt);
				data.store(newAmt);
			}
		}
	}

	void save(any@ data, SaveFile& file) const override {
		double amt = 0.0;
		data.retrieve(amt);
		file << amt;
	}

	void load(any@ data, SaveFile& file) const override {
		double amt = 0.0;
		file >> amt;
		data.store(amt);
	}
#section all
};
