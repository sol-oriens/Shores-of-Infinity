import hooks;
import generic_effects;
import planet_effects;
import requirement_effects;

from settlements import ISettlementHook, SettlementHook, shipPopulationStatus, mothershipPopulationStatus;

class ModLocalMorale : SettlementHook {
	Document doc("Increases or decreases the morale of the settlement.");
	Argument descriptor(AT_Custom, doc="Descriptor of the morale modifier. Can be VeryPositive, Positive, Negative or VeryNegative");

	int value = 0;

	bool instantiate() override {
		value = LocalMoraleEffect(descriptor.str).stat;
		return true;
	}

#section server
	void enable(Object& obj, any@ data) const override {
		obj.modMorale(value);
	}

	void disable(Object& obj, any@ data) const override {
		obj.modMorale(-value);
	}
#section all
};

class ContainCivilUnrest : SettlementHook {
	Document doc("Decreases the chance of loyalty loss of the settlement due to low morale.");
	Argument amount(AT_Decimal, "0", doc="Additional chance of avoiding loyalty loss.");

#section server
	void enable(Object& obj, any@ data) const override {
		obj.modContainCivilUnrest(amount.decimal);
	}

	void disable(Object& obj, any@ data) const override {
		obj.modContainCivilUnrest(-amount.decimal);
	}
#section all
};

class AddSettlementResource : SettlementHook {
	Document doc("Add free resource income based on the settlement's current population.");
	Argument factor(AT_Decimal, doc="Multiplier to the settlement's current population to give in pressure-equivalent income.");
	Argument income(AT_TileResource, doc="Type of income to generate.");

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
				obj.modResource(income.integer, -amt);
		}
	}

	void tick(Object& obj, any@ data, double tick) const override {
		if(obj.isPlanet) {
			double amt = 0.0;
			data.retrieve(amt);

			double pop = max(obj.population, 0.0);
			double newAmt = pop * factor.decimal;
			if(amt != newAmt) {
				obj.modResource(income.integer, newAmt - amt);
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
