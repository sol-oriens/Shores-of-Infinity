import hooks;
import generic_effects;
import planet_effects;
import requirement_effects;

from settlements import ISettlementHook, SettlementHook, getSettlementPopulation;

class ContainCivilUnrest : SettlementHook {
	Document doc("Decreases the chance of loyalty loss of the settlement due to low morale.");
	Argument amount(AT_Decimal, "0", doc="Additional chance of avoiding loyalty loss.");

#section server
	void enable(Object& obj, any@ data) const override {
		if (obj.isPlanet)
			obj.modContainSurfaceCivilUnrest(amount.decimal);
		else
			obj.modContainShipCivilUnrest(amount.decimal);
	}

	void disable(Object& obj, any@ data) const override {
		if (obj.isPlanet)
			obj.modContainSurfaceCivilUnrest(-amount.decimal);
		else
			obj.modContainShipCivilUnrest(-amount.decimal);
	}
#section all
};

class AddSettlementResource : SettlementHook {
	Document doc("Add free resource income based on the settlement's current population.");
	Argument factor(AT_Decimal, doc="Multiplier to the settlement's current population to give in pressure-equivalent income.");
	Argument type(AT_TileResource, doc="Type of income to generate.");

#section server
	void enable(Object& obj, any@ data) const override {
		double amt = 0.0;
		data.store(amt);
	}

	void disable(Object& obj, any@ data) const override {
		double amt = 0.0;
		data.retrieve(amt);
		if(amt != 0.0) {
			if (obj.isPlanet) {
				obj.modResource(type.integer, -amt);
			}
			else {
				modResource(obj, type.integer, -amt);
			}
		}
	}

	void tick(Object& obj, any@ data, double tick) const override {
		double pop = max(getSettlementPopulation(obj), 0.0);
		double amt = 0.0;
		data.retrieve(amt);

		double newAmt = pop * factor.decimal;
		if (amt != newAmt) {
			if (obj.isPlanet) {
				obj.modResource(type.integer, newAmt - amt);
				data.store(newAmt);
			}
			else {
				modResource(obj, type.integer, newAmt - amt);
				data.store(newAmt);
			}
		}
	}

	void modResource(Object& obj, int type, double amt) {
		Empire@ emp = obj.owner;
		if(emp is null)
			return;
		switch(type) {
			case TR_Money:
				emp.modTotalBudget(amt * TILE_MONEY_RATE, MoT_Misc);
				break;
			case TR_Influence:
				emp.modInfluenceIncome(amt);
				break;
			case TR_Energy:
				emp.modEnergyIncome(amt * TILE_ENERGY_RATE);
				break;
			case TR_Research:
				emp.modResearchRate(amt * TILE_RESEARCH_RATE);
				break;
			case TR_Defense:
				emp.modDefenseRate(amt * DEFENSE_LABOR_PM / 60.0);
				break;
			case TR_Labor:
				obj.modLaborIncome(amt / 60.0);
				break;
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

class ConvertSettlementResource : SettlementHook {
	Document doc("Convert all civilian income of a particular type to income of a different type.");
	Argument resource(AT_TileResource, doc="Type of income resource to convert.");
	Argument factor(AT_Decimal, doc="Multiplier to the amount of income taken away.");
	Argument income(AT_TileResource, doc="Type of income to generate, after multiplication.");
	Argument maximum_converted(AT_Decimal, "-1", doc="Maximum amount of resource of the first type that is converted.");
	Argument convert_percent(AT_Decimal, "1", doc="Percentage of the original resource to be converted. The rest is left alone.");

#section server
	void enable(Object& obj, any@ data) const override {
		ConvertData info;
		data.store(@info);
	}

	void disable(Object& obj, any@ data) const override {
		ConvertData@ info;
		data.retrieve(@info);

		if(info.given > 0)
			modResource(obj, income.integer, -info.given);
		if(info.taken > 0)
			modResource(obj, resource.integer, +info.taken);
	}

	void tick(Object& obj, any@ data, double time) const override {
		ConvertData@ info;
		data.retrieve(@info);

		//Check rate
		double curProd = obj.isPlanet
			? obj.getResourceProduction(resource.integer)
			: 0; //TODO
		double total = info.taken + curProd;

		double target = total * (1.0 - convert_percent.decimal);
		target = clamp(target, 0.0, total);

		double newTaken = total - target;
		if(maximum_converted.decimal >= 0)
			newTaken = min(newTaken, maximum_converted.decimal);

		if(newTaken != info.taken) {
			modResource(obj, resource.integer, -(newTaken - info.taken));
			info.taken = newTaken;
		}

		double newGiven = newTaken * factor.decimal;
		if(newGiven != info.given) {
			modResource(obj, income.integer, newGiven - info.given);
			info.given = newGiven;
		}
	}

	void modResource(Object& obj, int type, double amt) {
		if (obj.isPlanet)
			obj.modResource(type, amt);
		// TODO else {}
	}

	void save(any@ data, SaveFile& file) const override {
		ConvertData@ info;
		data.retrieve(@info);
		file << info.given;
		file << info.taken;
	}

	void load(any@ data, SaveFile& file) const override {
		ConvertData info;
		if(file >= SV_0079) {
			file >> info.given;
			file >> info.taken;
		}
		else {
			double current = 0;
			double rate = 0;
			file >> current;
			if(file >= SV_0049)
				file >> rate;
		}
		data.store(@info);
	}
#section all
};

class AddSettlementPressureCap : SettlementHook {
	Document doc("Increase the planet's total pressure capacity based on the settlement's current population.");
	Argument factor(AT_Decimal, doc="Multiplier to the settlement's current population to add as pressure capacity, rounded down to the closest integer.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj.isPlanet) {
			int amt = 0;
			data.store(amt);
		}
	}

	void disable(Object& obj, any@ data) const override {
		if(obj.isPlanet) {
			int amt = 0;
			data.retrieve(amt);
			if(amt != 0) {
				obj.modPressureCapMod(floor(-amt));
			}
		}
	}

	void tick(Object& obj, any@ data, double tick) const override {
		if (!obj.isPlanet)
			return;

		double pop = max(getSettlementPopulation(obj), 0.0);
		int amt = 0;
		data.retrieve(amt);

		int newAmt = floor(pop * factor.decimal);
		if (amt != newAmt) {
			obj.modPressureCapMod(newAmt - amt);
			data.store(newAmt);
		}
	}

	void save(any@ data, SaveFile& file) const override {
		int amt = 0;
		data.retrieve(amt);
		file << amt;
	}

	void load(any@ data, SaveFile& file) const override {
		int amt = 0;
		file >> amt;
		data.store(amt);
	}
#section all
};

class ModSettlementPopulationGrowth : SettlementHook {
	Document doc("Increase the population growth multiplier on this settlement.");
	Argument amount(AT_Decimal, doc="Percentage increase to the population growth multiplier, eg. 0.1 for +10% population growth.");
	Argument status(AT_Status, doc="Type of variable status to add to ship settlements that will store the multiplier.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj.isPlanet)
			obj.modGrowthRate(amount.decimal);
		else if (obj.hasStatuses) {
			int64 id = obj.addStatus(-1.0, status.integer, variable = amount.decimal);
			if(data !is null)
				data.store(id);
		}
	}

	void disable(Object& obj, any@ data) const override {
		if(obj.isPlanet)
			obj.modGrowthRate(-amount.decimal);
		else if (obj.hasStatuses && data !is null) {
			int64 id = -1;
			data.retrieve(id);
			obj.removeStatus(id);
		}
	}

	void save(any@ data, SaveFile& file) const override {
		int64 id = -1;
		data.retrieve(id);
		file << id;
	}

	void load(any@ data, SaveFile& file) const override {
		int64 id = -1;
		file >> id;
		data.store(id);
	}
#section all
};
